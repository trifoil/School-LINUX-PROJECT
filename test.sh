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
    echo "| 0. Basic setup (main DNS, web, DB, mail, SSL)                        |"
    echo "| 1. Add User                                                          |"
    echo "| 2. Remove User                                                       |"
    echo "|----------------------------------------------------------------------|"
    echo "| q. Quit                                                              |"
    echo "|----------------------------------------------------------------------|"
    echo ""
}

install_ssl_certificates(){
    DOMAIN_NAME=$1
    EMAIL=$2

    # Install Certbot
    dnf -y install certbot python3-certbot-apache

    # Obtain the certificate
    certbot --apache -d $DOMAIN_NAME -d www.$DOMAIN_NAME --non-interactive --agree-tos -m $EMAIL

    # Automatically renew the certificate
    echo "0 3 * * * root certbot renew --quiet" >> /etc/crontab
}

basic_root_website(){
    DOMAIN_NAME=$1
    EMAIL=$2
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

    # Install and configure SSL certificates
    install_ssl_certificates $DOMAIN_NAME $EMAIL

    echo "Verifying HTTPS Access..."
    curl -k https://$DOMAIN_NAME
}

add_user(){
    echo "Adding a user ..."
    read -p "Enter the server domain name (e.g., test.toto) : " DOMAIN_NAME
    read -p "Enter a username: " USERNAME
    read -sp "Enter a password: " PASSWORD
    echo
    DIR="/mnt/raid5_web/$USERNAME"
    mkdir -p "$DIR"
    echo "Created $DIR directory ... " 
    useradd $USERNAME
    echo "$USERNAME:$PASSWORD" | chpasswd
    smbpasswd -a $USERNAME
    echo "smb user created"

    chown -R $USERNAME:$USERNAME "$DIR"
    chmod -R 755 "$DIR"

    # Create the user's database
    mysql -u root -prootpassword -e "CREATE DATABASE ${USERNAME}_db;"
    mysql -u root -prootpassword -e "GRANT ALL PRIVILEGES ON ${USERNAME}_db.* TO '$USERNAME'@'localhost' IDENTIFIED BY '$PASSWORD';"

    # Create a simple index.php file in the user's directory
    echo "<html><body><h1>Welcome, $USERNAME!</h1><p>Your database name is ${USERNAME}_db.</p><?php phpinfo(); ?></body></html>" > "$DIR/index.php"

    # Set up the virtual host for the user's website
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

    # Set up the virtual host for the user's mail subdomain
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
</VirtualHost>
EOL

    # Set up Maildir for the user
    maildirmake.dovecot /home/$USERNAME/Maildir
    chown -R $USERNAME:$USERNAME /home/$USERNAME/Maildir

    # Add the user to the Roundcube database
    mysql -u root -prootpassword -e "INSERT INTO roundcubemail.users (username, mail_host, created) VALUES ('$USERNAME', 'localhost', NOW());"

    semanage fcontext -a -e /var/www /mnt/raid5_web
    restorecon -Rv /mnt
    systemctl restart httpd

    # Install and configure SSL certificates for the user
    install_ssl_certificates $USERNAME.$DOMAIN_NAME $EMAIL

    echo "User $USERNAME has been created with a mail account and a database."
    echo "Mail can be accessed at https://mail.$USERNAME.$DOMAIN_NAME"
}

basic_setup(){
    echo "Installing required components"
    read -p "Enter the IP address : " IP_ADDRESS
    read -p "Enter the server domain name (e.g., test.toto) : " DOMAIN_NAME
    read -p "Enter your email for SSL certificates : " EMAIL
    basic_dns $IP_ADDRESS $DOMAIN_NAME
    echo "Main DNS configuration done ... "

    basic_root_website $DOMAIN_NAME $EMAIL
    echo "Web server configuration done ... "

    basic_db $DOMAIN_NAME
    echo "Database server configuration done ... "

    basic_mail $DOMAIN_NAME
    echo "Mail server configuration done ... "

    echo "Press any key to exit..."
    read -n 1 -s key
    clear
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
