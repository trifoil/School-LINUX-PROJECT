#!/bin/bash

clear

RED='\033[0;31m' 
BLUE='\e[38;5;33m' 
NC='\033[0m' 

updatedb
systemctl enable --now cockpit.socket
firewall-cmd --permanent --zone=public --add-service=cockpit
firewall-cmd --reload
dnf -y install nfs-utils samba bind chrony fail2ban vsftpd rsync clamav clamd clamav-update bind-utils httpd php php-mysqlnd mariadb-server phpmyadmin mod_ssl

clear

display_menu() {
    echo ""
    echo "|----------------------------------------------------------------------|"
    echo -e "|                 ${BLUE}Welcome to the server assistant ${NC}                     |"
    echo "|              Please select the tool you want to use                  |"
    echo "|----------------------------------------------------------------------|"
    echo "| 0. Set server hostname                                               |"
    echo "| 1. RAID Configuration                                                |"
    echo "| 2. SSH Connection                                                    |"
    echo "| 3. NFS/SAMBA Shared Directory (no auth)                              |"
    echo "| 4. Web services management                                           |"
    echo "| 5. NTP Time Server                                                   |"
    echo "| 6. Install clamav                                                    |"
    echo "| 7. Backup                                                            |"
    echo "| 8. Consult Logs Dashboard                                            |"
    echo "|----------------------------------------------------------------------|"
    echo "| q. Quit                                                              |"
    echo "|----------------------------------------------------------------------|"
}

display_hostname_menu() {
    echo ""
    echo "|----------------------------------------------------------------------|"
    echo -e "|                     ${BLUE}Hostname Configuration Menu ${NC}                     |"
    echo "|----------------------------------------------------------------------|"
    echo "| 1. Set hostname                                                      |"
    echo "| 2. Display current hostname                                          |"
    echo "|----------------------------------------------------------------------|"
    echo "| q. Quit                                                              |"
    echo "|----------------------------------------------------------------------|"
}

configure_roundcube() {
    DB_PASSWORD=$(openssl rand -base64 12)
    DOMAIN_NAME=$1

    # Create a database for Roundcube
    mysql -u root -p<<MYSQL_SCRIPT
    CREATE DATABASE roundcube_db;
    GRANT ALL PRIVILEGES ON roundcube_db.* TO 'roundcube'@'localhost' IDENTIFIED BY '$DB_PASSWORD';
    FLUSH PRIVILEGES;
MYSQL_SCRIPT

    # Generate the Roundcube config file
    cat <<EOL > /etc/roundcubemail/config.inc.php
<?php
\$config['db_dsnw'] = 'mysql://roundcube:$DB_PASSWORD@127.0.0.1/roundcube_db';
\$config['default_host'] = '127.0.0.1';
\$config['smtp_server'] = '127.0.0.1';
\$config['mail_domain'] = '$DOMAIN_NAME';
\$config['product_name'] = 'Caca Mail';
\$config['des_key'] = '$(openssl rand -base64 24)';
\$config['plugins'] = [];
\$config['enable_spellcheck'] = true;
?>
EOL

    # Apply SELinux and restart Apache
    setsebool -P httpd_can_sendmail 1

    # Create a self-signed SSL certificate
    mkdir -p /etc/ssl/private
    openssl req -new -newkey rsa:2048 -days 365 -nodes -x509 \
        -subj "/C=US/ST=State/L=City/O=Organization/OU=Department/CN=mail.$DOMAIN_NAME" \
        -keyout /etc/ssl/private/mail.$DOMAIN_NAME.key \
        -out /etc/ssl/certs/mail.$DOMAIN_NAME.crt

    # Create a virtual host for Roundcube (HTTP)
    cat <<EOL > /etc/httpd/conf.d/roundcube.conf
<VirtualHost *:80>
    ServerName mail.$DOMAIN_NAME
    DocumentRoot /usr/share/roundcubemail
    <Directory /usr/share/roundcubemail>
        Options -Indexes
        AllowOverride All
        Require all granted
    </Directory>
    ErrorLog /var/log/httpd/roundcube_error.log
    CustomLog /var/log/httpd/roundcube_access.log combined
</VirtualHost>
EOL

    # Create a virtual host for Roundcube (HTTPS)
    cat <<EOL > /etc/httpd/conf.d/roundcube-ssl.conf
<VirtualHost *:443>
    ServerName mail.$DOMAIN_NAME
    DocumentRoot /usr/share/roundcubemail
    SSLEngine on
    SSLCertificateFile /etc/ssl/certs/mail.$DOMAIN_NAME.crt
    SSLCertificateKeyFile /etc/ssl/private/mail.$DOMAIN_NAME.key
    <Directory /usr/share/roundcubemail>
        Options -Indexes
        AllowOverride All
        Require all granted
    </Directory>
    ErrorLog /var/log/httpd/roundcube_ssl_error.log
    CustomLog /var/log/httpd/roundcube_ssl_access.log combined
</VirtualHost>
EOL

    systemctl restart httpd

    echo "Roundcube configured with the domain $DOMAIN_NAME."
    echo "Press any key to exit..."
    read -n 1 -s key
}

basic_mail(){
    sudo dnf -y install postfix dovecot roundcubemail
    DOMAIN_NAME=$1

    echo "meow"

    configure_postfix(){
    DOMAIN_NAME=$1

    postconf -e "myhostname = mail.$DOMAIN_NAME"
    postconf -e "mydomain = $DOMAIN_NAME"
    postconf -e "myorigin = /etc/mailname"
    postconf -e "inet_interfaces = all"
    postconf -e "inet_protocols = all"
    postconf -e "mydestination = $DOMAIN_NAME, localhost.localdomain, localhost"
    postconf -e "relayhost ="
    postconfe "mynetworks = 127.0.0.0/8"
    postconf -e "mailbox_size_limit = 0"
    postconf -e "recipient_delimiter = +"
    postconf -e "inet_interfaces = all"
    postconf -e "inet_protocols = ipv4"

    # Add domain to /etc/mailname
    echo "$DOMAIN_NAME" > /etc/mailname

    # Restart Postfix
    systemctl restart postfix
    systemctl enable postfix

    echo "Postfix configured for domain $DOMAIN_NAME."
    echo "Press any key to exit..."
    read -n 1 -s key
}

configure_dovecot(){
    DOMAIN_NAME=$1

    # Backup the original config files
    cp /etc/dovecot/dovecot.conf /etc/dovecot/dovecot.conf.bak
    if [ ! -f "/etc/dovecot/dovecot.conf" ]; then
        touch /etc/dovecot/dovecot.conf
    fi
    cp /etc/dovecot/conf.d/10-mail.conf /etc/dovecot/conf.d/10-mail.conf.bak
    if [ ! -f "/etc/dovecot/conf.d/10-mail.conf" ]; then
        touch /etc/dovecot/conf.d/10-mail.conf
    fi
    # Configure Dovecot
    cat <<EOL > /etc/dovecot/dovecot.conf
disable_plaintext_auth = yes
mail_privileged_group = mail
mail_location = maildir:~/Maildir
namespace inbox {
  inbox = yes
}
service auth {
  unix_listener /var/spool/postfix/private/auth {
    mode = 0660
    user = postfix
    group = postfix
  }
}
userdb {
  driver = passwd
}
passdb {
  driver = pam
}
ssl = required
ssl_cert = </etc/pki/dovecot/certs/dovecot.pem
ssl_key = </etc/pki/dovecot/private/dovecot.pem
EOL

    # Restart Dovecot
    systemctl restart dovecot
    systemctl enable dovecot

    echo "Dovecot configured for domain $DOMAIN_NAME."
    echo "Press any key to exit..."
    read -n 1 -s key
}

    DOMAIN_NAME=$1

    echo "Setting up the mail server for domain $DOMAIN_NAME..."

    configure_postfix $DOMAIN_NAME
    configure_dovecot $DOMAIN_NAME
    configure_roundcube $DOMAIN_NAME

    echo "Mail server setup completed."
    echo "Press any key to exit..."
    read -n 1 -s key
}

# ... (existing code)