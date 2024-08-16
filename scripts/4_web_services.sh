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
    echo "| 0. Basic setup (main DNS, web, DB, mail)                             |"
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
mail    IN  A       $IP_ADDRESS
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

    # Install Apache HTTP server and mod_ssl for SSL support
    dnf -y install httpd mod_ssl

    # Create the directory for the root website
    mkdir -p /mnt/raid5_web/root

    # Create a simple index.php file for the root website
    echo "<html><body><h1>Welcome to $DOMAIN_NAME</h1></body></html>" > /mnt/raid5_web/root/index.php
    #echo "<html><body><h1>Welcome to $DOMAIN_NAME</h1><?php phpinfo(); ?></body></html>" > /mnt/raid5_web/root/index.php

    # Set ownership and permissions
    chown -R apache:apache /mnt/raid5_web/root
    chcon -R --type=httpd_sys_content_t /mnt/raid5_web/root

    chmod -R 755 /mnt/raid5_web/root

    # Set up the virtual host for the root domain (HTTP)
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

    # Redirect all traffic to HTTPS
    Redirect "/" "https://$DOMAIN_NAME/"
</VirtualHost>
EOL

    # Generate a wildcard self-signed SSL certificate
    mkdir -p /etc/httpd/ssl
    openssl req -new -newkey rsa:2048 -days 365 -nodes -x509 \
        -keyout /etc/httpd/ssl/$DOMAIN_NAME.key \
        -out /etc/httpd/ssl/$DOMAIN_NAME.crt \
        -subj "/C=US/ST=State/L=City/O=Organization/OU=Department/CN=*.$DOMAIN_NAME"

    # Set up the virtual host for HTTPS
    cat <<EOL > /etc/httpd/conf.d/root-ssl.conf
<VirtualHost *:443>
    ServerName $DOMAIN_NAME
    ServerAlias *.$DOMAIN_NAME
    DocumentRoot /mnt/raid5_web/root
    <Directory /mnt/raid5_web/root>
        AllowOverride All
        Require all granted
    </Directory>
    DirectoryIndex index.php
    SSLEngine on
    SSLCertificateFile /etc/httpd/ssl/$DOMAIN_NAME.crt
    SSLCertificateKeyFile /etc/httpd/ssl/$DOMAIN_NAME.key
    ErrorLog /var/log/httpd/root_ssl_error.log
    CustomLog /var/log/httpd/root_ssl_access.log combined
</VirtualHost>
EOL

    # Start and enable the Apache HTTP server
    systemctl start httpd
    systemctl enable httpd
    systemctl restart httpd

    # Open the HTTP and HTTPS ports in the firewall
    firewall-cmd --add-service=http --permanent
    firewall-cmd --add-service=https --permanent
    firewall-cmd --reload

    # Verify HTTP and HTTPS Access
    echo "Verifying HTTP Access..."
    curl -I http://$DOMAIN_NAME

    echo "Verifying HTTPS Access..."
    curl -I https://$DOMAIN_NAME
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

    # Define the configuration file path
    conf_file="/etc/httpd/conf.d/phpMyAdmin.conf"


cat <<EOL > $conf_file
# phpMyAdmin - Web based MySQL browser written in php
# 
# Allows only localhost by default
#
# But allowing phpMyAdmin to anyone other than localhost should be considered
# dangerous unless properly secured by SSL

Alias /phpmyadmin /usr/share/phpMyAdmin

<Directory /usr/share/phpMyAdmin/>
    AddDefaultCharset UTF-8

    Require all granted
</Directory>

<Directory /usr/share/phpMyAdmin/setup/>
   Require local
</Directory>

# These directories do not require access over HTTP - taken from the original
# phpMyAdmin upstream tarball
#
<Directory /usr/share/phpMyAdmin/libraries/>
    Require all denied
</Directory>

<Directory /usr/share/phpMyAdmin/templates/>
    Require all denied
</Directory>

<Directory /usr/share/phpMyAdmin/setup/lib/>
    Require all denied
</Directory>

<Directory /usr/share/phpMyAdmin/setup/frames/>
    Require all denied
</Directory>

# This configuration prevents mod_security at phpMyAdmin directories from
# filtering SQL etc.  This may break your mod_security implementation.
#
#<IfModule mod_security.c>
#    <Directory /usr/share/phpMyAdmin/>
#        SecRuleInheritance Off
#    </Directory>
#</IfModule>
EOL

    # Restart Apache to apply changes
    systemctl restart httpd

    echo "Configuration updated and Apache restarted."

    ausearch -c 'mariadbd' --raw | audit2allow -M my-mariadbd
    semodule -X 300 -i my-mariadbd.pp

    echo "<html><body><h1>PHPMyAdmin installed. <a href='/phpmyadmin'>Access it here</a></h1></body></html>" > /mnt/raid5_web/root/index.php

    systemctl restart httpd
}

basic_mail(){
    DOMAIN_NAME=$1
    dnf -y install postfix dovecot roundcubemail

    # Configure Postfix
    sed -i 's/#myhostname = host.domain.tld/myhostname = mail.'"$DOMAIN_NAME"'/' /etc/postfix/main.cf
    sed -i 's/#mydomain = domain.tld/mydomain = '"$DOMAIN_NAME"'/' /etc/postfix/main.cf
    sed -i 's/#myorigin = $mydomain/myorigin = $mydomain/' /etc/postfix/main.cf
    sed -i 's/inet_interfaces = localhost/inet_interfaces = all/' /etc/postfix/main.cf
    sed -i 's/#home_mailbox = Maildir\//home_mailbox = Maildir\//' /etc/postfix/main.cf

    systemctl start postfix
    systemctl enable postfix

    # Configure Dovecot
    sed -i 's/#protocols = imap pop3 lmtp/protocols = imap pop3 lmtp/' /etc/dovecot/dovecot.conf
    sed -i 's/#mail_location =/mail_location = maildir:~\/Maildir/' /etc/dovecot/conf.d/10-mail.conf

    systemctl start dovecot
    systemctl enable dovecot

    # Configure Roundcube
    cat <<EOL > /etc/httpd/conf.d/roundcube.conf
Alias /roundcube /usr/share/roundcubemail
<Directory /usr/share/roundcubemail>
    Options -Indexes
    AllowOverride None
    Require all granted
</Directory>
EOL

    mysql -u root -prootpassword -e "CREATE DATABASE roundcubemail;"
    mysql -u root -prootpassword -e "GRANT ALL PRIVILEGES ON roundcubemail.* TO 'roundcube'@'localhost' IDENTIFIED BY 'roundcube_pass';"
    mysql -u root -prootpassword roundcubemail < /usr/share/doc/roundcubemail*/SQL/mysql.initial.sql

    # Configure Roundcube database connection
    sed -i "s|^\(\$config\['db_dsnw'\] = \).*|\1'mysql://roundcube:roundcube_pass@localhost/roundcubemail';|" /etc/roundcubemail/config.inc.php

    systemctl restart httpd

    firewall-cmd --add-service=smtp --permanent
    firewall-cmd --add-service=imap --permanent
    firewall-cmd --add-service=pop3 --permanent
    firewall-cmd --reload

    echo "Roundcube webmail setup is complete."
}

basic_setup(){
    echo "Installing required components"
    read -p "Enter the IP address : " IP_ADDRESS
    read -p "Enter the server domain name (e.g., test.toto) : " DOMAIN_NAME
    basic_dns $IP_ADDRESS $DOMAIN_NAME
    echo "Main DNS configuration done ... "

    basic_root_website $DOMAIN_NAME
    echo "Web server configuration done ... "

    basic_db $DOMAIN_NAME
    echo "Database server configuration done ... "

    basic_mail $DOMAIN_NAME
    echo "Mail server configuration done ... "

    echo "Press any key to exit..."
    read -n 1 -s key
    clear
}

add_user(){
    echo "Adding a user ..."
    read -p "Enter the server domain name (e.g., example.com) : " DOMAIN_NAME
    read -p "Enter a username: " USERNAME
    read -sp "Enter a password: " PASSWORD
    echo
    DIR="/mnt/raid5_web/$USERNAME"
    mkdir -p "$DIR"
    echo "Created $DIR directory ... " 
    useradd $USERNAME
    echo "$USERNAME:$PASSWORD" | chpasswd
    smbpasswd -a $USERNAME
    echo "SMB user created"

    chown -R $USERNAME:$USERNAME "$DIR"
    chmod -R 755 "$DIR"

    # Create the user's database
    mysql -u root -prootpassword -e "CREATE DATABASE ${USERNAME}_db;"
    mysql -u root -prootpassword -e "GRANT ALL PRIVILEGES ON ${USERNAME}_db.* TO '$USERNAME'@'localhost' IDENTIFIED BY '$PASSWORD';"

    # Create a simple index.php file in the user's directory
    echo "<html><body><h1>Welcome, $USERNAME!</h1><p>Your database name is ${USERNAME}_db.</p><?php phpinfo(); ?></body></html>" > "$DIR/index.php"

    # Set up the virtual host for the user's website (HTTP with redirect to HTTPS)
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

    # Redirect all HTTP traffic to HTTPS
    Redirect "/" "https://$USERNAME.$DOMAIN_NAME/"
</VirtualHost>

<VirtualHost *:443>
    ServerName $USERNAME.$DOMAIN_NAME
    DocumentRoot /mnt/raid5_web/$USERNAME
    <Directory /mnt/raid5_web/$USERNAME>
        AllowOverride All
        Require all granted
    </Directory>
    DirectoryIndex index.php
    SSLEngine on
    SSLCertificateFile /etc/httpd/ssl/$DOMAIN_NAME.crt
    SSLCertificateKeyFile /etc/httpd/ssl/$DOMAIN_NAME.key
    ErrorLog /var/log/httpd/${USERNAME}_ssl_error.log
    CustomLog /var/log/httpd/${USERNAME}_ssl_access.log combined
</VirtualHost>
EOL

    # Set up the virtual host for the user's mail subdomain (HTTP with redirect to HTTPS)
    cat <<EOL > /etc/httpd/conf.d/mail-$USERNAME.conf
<VirtualHost *:80>
    ServerName mail.$USERNAME.$DOMAIN_NAME
    DocumentRoot /usr/share/roundcubemail
    <Directory /usr/share/roundcubemail>
        AllowOverride All
        Require all granted
    </Directory>
    DirectoryIndex index.php
    ErrorLog /var/log/httpd/mail_${USERNAME}_error.log
    CustomLog /var/log/httpd/mail_${USERNAME}_access.log combined

    # Redirect all HTTP traffic to HTTPS
    Redirect "/" "https://mail.$USERNAME.$DOMAIN_NAME/"
</VirtualHost>

<VirtualHost *:443>
    ServerName mail.$USERNAME.$DOMAIN_NAME
    DocumentRoot /usr/share/roundcubemail
    <Directory /usr/share/roundcubemail>
        AllowOverride All
        Require all granted
    </Directory>
    DirectoryIndex index.php
    SSLEngine on
    SSLCertificateFile /etc/httpd/ssl/$DOMAIN_NAME.crt
    SSLCertificateKeyFile /etc/httpd/ssl/$DOMAIN_NAME.key
    ErrorLog /var/log/httpd/mail_${USERNAME}_ssl_error.log
    CustomLog /var/log/httpd/mail_${USERNAME}_ssl_access.log combined
</VirtualHost>
EOL

    # Set up Maildir for the user
    maildirmake.dovecot /home/$USERNAME/Maildir
    chown -R $USERNAME:$USERNAME /home/$USERNAME/Maildir

    # Add the user to the Roundcube database
    mysql -u root -prootpassword -e "INSERT INTO roundcubemail.users (username, mail_host, created) VALUES ('$USERNAME', 'localhost', NOW());"

    # Ensure proper SELinux context and restart Apache
    semanage fcontext -a -e /var/www /mnt/raid5_web
    restorecon -Rv /mnt
    systemctl restart httpd

    echo "User $USERNAME has been created with a mail account and a database."
    echo "Mail can be accessed at https://mail.$USERNAME.$DOMAIN_NAME"
}

# Example usage
# add_user



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
    rm -rf /home/$USERNAME/Maildir

    # Remove the user from the Roundcube database
    mysql -u root -prootpassword -e "DELETE FROM roundcubemail.users WHERE username = '$USERNAME';"

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
