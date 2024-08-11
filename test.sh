#!/bin/bash

BLUE='\e[38;5;33m'
NC='\033[0m'

clear
display_menu() {
    echo ""
    echo "|----------------------------------------------------------------------|"
    echo -e "|                ${BLUE}Welcome To The User Management Menu ${NC}                  |"
    echo "|               Please select the tool you want to use                 |"
    echo "|----------------------------------------------------------------------|"
    echo "| 0. Basic setup (main DNS, web, DB)                                   |"
    echo "| 1. Add User                                                          |"
    echo "| 2. Remove User                                                       |"
    echo "|----------------------------------------------------------------------|"
    echo "| q. Quit                                                              |"
    echo "|----------------------------------------------------------------------|"
    echo ""
}

ip_set(){
    INTERFACE=$1
    ADDRESS=$2
    nmcli connection modify "$INTERFACE" ipv4.method manual
    nmcli connection modify "$INTERFACE" ipv4.addresses "$ADDRESS/24"
    nmcli connection up "$INTERFACE"
    arping -c 3 -I $INTERFACE $ADDRESS
    echo "Done..."
    echo "Press any key to continue..."
    read -n 1 -s key
    clear
}

backup_file(){
    ORIGINAL_FILE=$1
    if [ ! -f "$ORIGINAL_FILE" ]; then
        echo "Error: $ORIGINAL_FILE does not exist."
        exit 1
    fi
    TIMESTAMP=$(date +"%Y%m%d%H%M%S")
    BACKUP_FILE="/etc/named.conf.bak.$TIMESTAMP"
    mv "$ORIGINAL_FILE" "$BACKUP_FILE"
    touch "$ORIGINAL_FILE"
    if [ $? -eq 0 ]; then
        echo "Successfully backed up $ORIGINAL_FILE to $BACKUP_FILE"
    else
        echo "Error: Failed to back up $ORIGINAL_FILE"
        exit 1
    fi
}

basic_dns(){
    firewall-cmd --add-service=dns --permanent
    firewall-cmd --reload
    IP_ADDRESS=$1
    DOMAIN_NAME=$2
    NETWORK=$(echo $IP_ADDRESS | cut -d"." -f1-3).0/24
    REVERSE_ZONE=$(echo $IP_ADDRESS | awk -F. '{print $3"."$2"."$1".in-addr.arpa"}')
    REVERSE_IP=$(echo $IP_ADDRESS | awk -F. '{print $4}')
    backup_file "/etc/named.conf"
    dnf -y install bind bind-utils

cat <<EOL > /etc/named.conf
options {
    listen-on port 53 { any; };
    directory "/var/named";
    dump-file "/var/named/data/cache_dump.db";
    statistics-file "/var/named/data/named_stats.txt";
    memstatistics-file "/var/named/data/named_mem_stats.txt";
    secroots-file   "/var/named/data/named.secroots";
    recursing-file  "/var/named/data/named.recursing";
    allow-query { any; };
    recursion yes;
};

logging {
        channel default_debug {
                file "data/named.run";
                severity dynamic;
        };
};

zone "." IN {
        type hint;
        file "named.ca";
};

zone "$DOMAIN_NAME" IN {
    type master;
    file "forward.$DOMAIN_NAME";
    allow-update { none; };
};

zone "$REVERSE_ZONE" IN {
    type master;
    file "reverse.$DOMAIN_NAME";
    allow-update { none; };
};
EOL

cat <<EOL > /var/named/forward.$DOMAIN_NAME
\$TTL 86400
@   IN  SOA     ns.$DOMAIN_NAME. root.$DOMAIN_NAME. (
            2024052101 ; Serial
            3600       ; Refresh
            1800       ; Retry
            604800     ; Expire
            86400 )    ; Minimum TTL
;
@       IN  NS      ns.$DOMAIN_NAME.
ns      IN  A       $IP_ADDRESS
@       IN  A       $IP_ADDRESS
*       IN  A       $IP_ADDRESS
EOL

cat <<EOL > /var/named/reverse.$DOMAIN_NAME
\$TTL 86400
@   IN  SOA     ns.$DOMAIN_NAME. root.$DOMAIN_NAME. (
            2024052101 ; Serial
            3600       ; Refresh
            1800       ; Retry
            604800     ; Expire
            86400 )    ; Minimum TTL
;
@       IN  NS      ns.$DOMAIN_NAME.
$REVERSE_IP       IN  PTR     $DOMAIN_NAME.
EOL

echo 'OPTIONS="-4"' >> /etc/sysconfig/named

cat <<EOL > /etc/hosts
$IP_ADDRESS $DOMAIN_NAME
127.0.0.1   $DOMAIN_NAME
EOL

cat <<EOL > /etc/hostname
$DOMAIN_NAME
EOL

    systemctl start named
    systemctl enable named

    systemctl restart named 

cat <<EOL > /etc/resolv.conf
nameserver  $DOMAIN_NAME
options edns0 trust-ad
search home.arpa
EOL
}

basic_root_website(){
    DOMAIN_NAME=$1
    dnf -y install httpd

    # Create the directory for the root website
    mkdir -p /mnt/raid5_web/root

    # Create a simple index.php file for the root website
    echo "<html><body><h1>Welcome to $DOMAIN_NAME</h1><?php phpinfo(); ?></body></html>" > /mnt/raid5_web/root/index.php

    # Set ownership and permissions
    chown -R apache:apache /mnt/raid5_web/root
    chcon -R --type=httpd_sys_content_t /mnt/raid5_web/root

    chmod -R 755 /mnt/raid5_web/root

    # Set up the virtual host for the root domain
    cat <<EOL > /etc/httpd/conf.d/root.conf
<VirtualHost *:80>
    ServerName $DOMAIN_NAME
    ServerAlias *.$DOMAIN_NAME
    DocumentRoot /mnt/raid5_web/root
    <Directory /mnt/raid5_web/root>
        AllowOverride All
        Require all granted
    </Directory>
    DirectoryIndex index.php
    ErrorLog /var/log/httpd/root_error.log
    CustomLog /var/log/httpd/root_access.log combined
</VirtualHost>
EOL

    systemctl start httpd
    systemctl enable httpd
    systemctl restart httpd

    firewall-cmd --add-service=http --permanent
    firewall-cmd --reload

    # Verify HTTP Access
    echo "Verifying HTTP Access..."
    curl http://$DOMAIN_NAME
}


basic_db(){
    DOMAIN_NAME=$1
    dnf -y install mariadb-server phpmyadmin
    systemctl start mariadb
    systemctl enable mariadb

    mysql_secure_installation <<EOF

y
rootpassword
rootpassword
y
y
y
y
EOF

    firewall-cmd --add-service=mysql --permanent
    firewall-cmd --reload

    ln -s /usr/share/phpmyadmin /mnt/raid5_web/root/phpmyadmin

    echo "<html><body><h1>PHPMyAdmin installed. <a href='/phpmyadmin'>Access it here</a></h1></body></html>" > /mnt/raid5_web/root/index.php

    systemctl restart httpd
}

basic_setup(){
    echo "Installing required components"
    read -p "Enter the IP address : " IP_ADDRESS
    read -p "Enter the server domain name (e.g., test.toto) : " DOMAIN_NAME
    basic_dns $IP_ADDRESS $DOMAIN_NAME
    echo "Main DNS configuration done ... "

    basic_root_website $DOMAIN_NAME
    echo "Web server configuration done ... "

    echo "Press any key to exit..."
    read -n 1 -s key
    clear
}

add_user(){
    echo "Adding a user ..."
    read -p "Enter a username: " USERNAME
    read -sp "Enter a password: " PASSWORD
    DIR="/mnt/raid5_web/$USERNAME"
    mkdir -p "$DIR"
    echo "Created $DIR directory ... " 
    useradd $USERNAME
    echo "$USERNAME:$PASSWORD" | chpasswd
    smbpasswd -a $USERNAME
    echo "smb user created"

    chown -R $USERNAME:$USERNAME "$DIR"
    chmod -R 755 "$DIR"

    mysql -u root -prootpassword -e "CREATE DATABASE ${USERNAME}_db;"
    mysql -u root -prootpassword -e "GRANT ALL PRIVILEGES ON ${USERNAME}_db.* TO '$USERNAME'@'localhost' IDENTIFIED BY '$PASSWORD';"

    echo "<html><body><h1>Welcome, $USERNAME!</h1><p>Your database name is ${USERNAME}_db.</p><?php phpinfo(); ?></body></html>" > "$DIR/index.php"

    # Set up the virtual host for the user
    cat <<EOL > /etc/httpd/conf.d/001-$USERNAME.conf
<VirtualHost *:80>
    ServerName $USERNAME.$DOMAIN_NAME
    DocumentRoot /mnt/raid5_web/$USERNAME
    <Directory /mnt/raid5_web/$USERNAME>
        AllowOverride All
        Require all granted
    </Directory>
    DirectoryIndex index.php
    ErrorLog /var/log/httpd/${USERNAME}_error.log
    CustomLog /var/log/httpd/${USERNAME}_access.log combined
</VirtualHost>
EOL
    semanage fcontext -a -e /var/www /mnt/raid5_web
    restorecon -Rv /mnt
    systemctl restart httpd
}

remove_user(){
    echo "Removing a user ... "
    echo "Users list : "
    pdbedit -L
    read -p "Enter a user to delete: " USERNAME
    userdel $USERNAME
    smbpasswd -x $USERNAME
    rm -rf /mnt/raid5_web/$USERNAME
    mysql -u root -prootpassword -e "DROP DATABASE ${USERNAME}_db;"
    rm -f /etc/httpd/conf.d/001-$USERNAME.conf
    systemctl restart httpd
    echo "User $USERNAME and their data have been removed."
}

main() {
    while true; do
        display_menu
        read -p "Enter your choice: " choice
        case $choice in
            0) basic_setup ;;
            1) add_user ;;
            2) remove_user ;;
            q|Q) clear && echo "Exiting the web server configuration wizard." && exit ;;
            *) clear && echo "Invalid choice. Please enter a valid option." ;;
        esac
    done
}

main