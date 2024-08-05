#!/bin/bash

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
    directory "/var/named";
    dump-file "/var/named/data/cache_dump.db";
    statistics-file "/var/named/data/named_stats.txt";
    memstatistics-file "/var/named/data/named_mem_stats.txt";
    allow-query { any; };
    recursion yes;
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

    echo 'OPTIONS="-4"' >> /etc/sysconfig/named

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

    systemctl start named
    systemctl enable named
    systemctl restart named 
    echo "nameserver $IP_ADDRESS" > /etc/resolv.conf
}

generate_ssl_certificate(){
    mkdir -p /etc/ssl/certs
    mkdir -p /etc/ssl/private
    openssl req -new -newkey rsa:2048 -days 365 -nodes -x509 \
        -subj "/C=US/ST=State/L=City/O=Organization/OU=Unit/CN=$DOMAIN_NAME" \
        -keyout /etc/ssl/private/httpd-selfsigned.key -out /etc/ssl/certs/httpd-selfsigned.crt
}

basic_website(){
    IP_ADDRESS=$1
    DOMAIN_NAME=$2

    # Update system time
    timedatectl set-ntp true
    timedatectl set-timezone UTC
    ntpdate pool.ntp.org

    # Clean DNF cache
    dnf clean packages
    dnf clean metadata

    # Install Apache and dependencies
    dnf -y install httpd mod_ssl
    if [ $? -ne 0 ]; then
        echo "Error: Failed to install Apache and dependencies."
        exit 1
    fi

    generate_ssl_certificate

    systemctl start httpd
    systemctl enable httpd
    if [ $? -ne 0 ]; then
        echo "Error: Failed to start httpd service."
        exit 1
    fi

    rm -f /etc/httpd/conf.d/welcome.conf
    HTTPD_CONF="/etc/httpd/conf/httpd.conf"
    sed -i "100s/.*/ServerName $DOMAIN_NAME:80/" $HTTPD_CONF
    sed -i '149s/.*/Options FollowSymLinks/' $HTTPD_CONF
    sed -i '156s/.*/AllowOverride All/' $HTTPD_CONF
    sed -i '169s/.*/DirectoryIndex index.html index.php index.cgi/' $HTTPD_CONF
    echo "# server's response header" >> $HTTPD_CONF
    echo "ServerTokens Prod" >> $HTTPD_CONF

    mkdir -p /mnt/raid5_web/main
    cat << EOL > /etc/httpd/conf.d/main.conf
<VirtualHost *:80>
    ServerName $DOMAIN_NAME
    ServerAlias www.$DOMAIN_NAME
    Redirect permanent / https://$DOMAIN_NAME/
</VirtualHost>
<VirtualHost _default_:443>
    ServerName $DOMAIN_NAME
    DocumentRoot /mnt/raid5_web/main/
    SSLEngine On
    SSLCertificateFile /etc/ssl/certs/httpd-selfsigned.crt
    SSLCertificateKeyFile /etc/ssl/private/httpd-selfsigned.key
</VirtualHost>  
ServerTokens Prod                       
EOL

    cat << EOL > /mnt/raid5_web/main/index.html
<!DOCTYPE html>
<html>
    <head>
        <meta charset="utf-8">
        <title>Welcome Page</title>
    </head>
    <body>
        <h1>Welcome to the main page</h1>
    </body>
</html>
EOL

    firewall-cmd --add-service=http --permanent
    firewall-cmd --add-service=https --permanent
    firewall-cmd --reload
    systemctl restart httpd
    if [ $? -ne 0 ]; then
        echo "Error: Failed to restart httpd service."
        exit 1
    fi
}

add_user(){
    echo "Adding a user ..."
    read -p "Enter a username: " USERNAME
    read -sp "Enter a password: " PASSWORD
    echo
    DIR="/mnt/raid5_web/$USERNAME"
    mkdir -p "$DIR"
    echo "Created $DIR directory ..." 
    useradd $USERNAME
    echo "$USERNAME:$PASSWORD" | chpasswd
    smbpasswd -a $USERNAME
    echo "unix user and smb user created"

    cat <<EOL > /etc/httpd/conf.d/$USERNAME.conf
<VirtualHost *:80>
    ServerName $USERNAME.$DOMAIN_NAME
    DocumentRoot $DIR
</VirtualHost>
EOL

    cat <<EOL > $DIR/index.html
<!DOCTYPE html>
<html>
    <head>
        <meta charset="utf-8">
        <title>Welcome Page</title>
    </head>
    <body>
        <h1>Welcome to $USERNAME's page</h1>
    </body>
</html>
EOL

    systemctl restart httpd
    echo "User $USERNAME added and website configured."
}

remove_user(){
    echo "Removing a user ..."
    echo "Users list : "
    pdbedit -L
    read -p "Enter a user to delete: " USERNAME
    userdel $USERNAME
    smbpasswd -x $USERNAME
    rm -rf /mnt/raid5_web/$USERNAME
    rm /etc/httpd/conf.d/$USERNAME.conf
    systemctl restart httpd
    echo "User $USERNAME removed and configuration cleaned."
}

basic_setup(){
    echo "Installing required components"
    read -p "Enter the IP address : " IP_ADDRESS
    read -p "Enter the server domain name : " DOMAIN_NAME
    basic_dns $IP_ADDRESS $DOMAIN_NAME
    echo "Main DNS configuration done ... "
    echo "Installing basic website ... "
    basic_website $IP_ADDRESS $DOMAIN_NAME
    echo "Basic website configuration done."
    echo "Press any key to exit..."
    read -n 1 -s key
    clear
}

# Main script execution
echo "Choose an option:"
echo "1) Basic Setup"
echo "2) Add User"
echo "3) Remove User"
read -p "Option: " OPTION

case $OPTION in
    1)
        basic_setup
        ;;
    2)
        add_user
        ;;
    3)
        remove_user
        ;;
    *)
        echo "Invalid option."
        ;;
esac
