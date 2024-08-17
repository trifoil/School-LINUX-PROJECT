#!/bin/bash

clear

RED='\033[0;31m' #Red
BLUE='\e[38;5;33m' #Red
NC='\033[0m' # No Color

updatedb
systemctl enable --now cockpit.socket
firewall-cmd --permanent --zone=public --add-service=cockpit
firewall-cmd --reload
dnf -y install nfs-utils samba bind chrony fail2ban vsftpd rsync clamav clamd clamav-update bind-utils httpd php php-mysqlnd mariadb-server phpmyadmin mod_ssl

clear

# Function to display the menu
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
    echo ""
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
    echo ""
}

display_raid_menu() {
    echo ""
    echo "|----------------------------------------------------------------------|"
    echo -e "|                 ${BLUE}RAID Configuration Menu ${NC}                     |"
    echo "|----------------------------------------------------------------------|"
    echo "| 1. Create RAID                                                       |"
    echo "| 2. Display current RAID                                              |"
    echo "|----------------------------------------------------------------------|"
    echo "| q. Quit                                                              |"
    echo "|----------------------------------------------------------------------|"
    echo ""
}

display_unauth_share_menu() {
    echo ""
    echo "|----------------------------------------------------------------------|"
    echo -e "|                ${BLUE}Welcome to the unauth share assistant ${NC}                |"
    echo "|              Please select the tool you want to use                  |"
    echo "|----------------------------------------------------------------------|"
    echo "| 0. Activate NFS                                                      |"
    echo "| 1. Activate SMB                                                      |"
    echo "|----------------------------------------------------------------------|"
    echo "| q. Quit                                                              |"
    echo "|----------------------------------------------------------------------|"
    echo ""
}

display_web_menu() {
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

display_ntp_menu() {
    echo "|-------------------------------------------|"
    echo -e "|            ${GREEN}NTP server wizard${NC}              |"
    echo "|-------------------------------------------|"
    echo "|         What do you want to do?           |"
    echo "|-------------------------------------------|"
    echo "| 1. Setup the NTP (defaults to Eu/Bx)      |"
    echo "| 2. Choose a timezone                      |"
    echo "| 3. Show NTP statuses                      |"
    echo "|-------------------------------------------|"
    echo "| q. Quit                                   |"
    echo "|-------------------------------------------|"
    echo ""
}

set_hostname() {
while true; do

    clear
    display_hostname_menu
    read -p "Enter your choice: " hostname_choice
    case $hostname_choice in
        1) read -p "Enter the new hostname: " new_hostname
           hostnamectl set-hostname $new_hostname
           echo "Hostname set to $new_hostname"
           echo "Press any key to continue..."
           read -n 1 -s key
           clear
           ;;
        2) current_hostname=$(hostnamectl --static)
           echo "Current hostname: $current_hostname"
               echo "Press any key to continue..."
               read -n 1 -s key
               clear
           ;;
        q|Q) clear && echo "Exiting hostname configuration menu" && break ;;
        *) clear && echo "Invalid choice. Please enter a valid option." ;;
    esac
done
}

raid(){
    clear
    echo "Creating RAID..."
    # Install necessary packages
    sudo dnf install lvm2 mdadm -y
    # Create a RAID 5 array with 3 devices
    sudo mdadm --create --verbose /dev/md0 --level=5 --raid-devices=3 /dev/sdb /dev/sdc /dev/sdd
    # Create a physical volume on the RAID array
    sudo pvcreate /dev/md0
    # Create a volume group on the physical volume
    sudo vgcreate vg_raid5 /dev/md0
    # Create a logical volume named 'share' with a size of 500M
    sudo lvcreate -L 500M -n share vg_raid5
    # Format the 'share' logical volume with ext4 filesystem
    sudo mkfs.ext4 /dev/vg_raid5/share
    # Create a mount point for the 'share' logical volume
    sudo mkdir -p /mnt/raid5_share
    # Mount the 'share' logical volume
    sudo mount /dev/vg_raid5/share /mnt/raid5_share
    # Get the UUID of the 'share' logical volume and add it to fstab for automatic mounting
    sudo blkid /dev/vg_raid5/share | awk '{print $2 " /mnt/raid5_share ext4 defaults 0 0"}' | sudo tee -a /etc/fstab
    # Create a logical volume named 'web' with a size of 500M
    sudo lvcreate -L 500M -n web vg_raid5
    # Format the 'web' logical volume with ext4 filesystem
    sudo mkfs.ext4 /dev/vg_raid5/web
    # Create a mount point for the 'web' logical volume
    sudo mkdir -p /mnt/raid5_web
    # Mount the 'web' logical volume
    sudo mount /dev/vg_raid5/web /mnt/raid5_web
    # Get the UUID of the 'web' logical volume and add it to fstab for automatic mounting
    sudo blkid /dev/vg_raid5/web | awk '{print $2 " /mnt/raid5_web ext4 defaults 0 0"}' | sudo tee -a /etc/fstab
    systemctl daemon-reload
    # Verify mounts
    df -h
}

ssh(){
    clear
    echo "Starting ssh"
}

unauthshare(){
    smb(){
    echo "Installing Samba share"
    sudo mkdir -p /mnt/raid5_share
    dnf update -y
    dnf -y install samba samba-client
    systemctl enable smb --now
    systemctl enable nmb --now    

    firewall-cmd --permanent --add-service=samba
    firewall-cmd --reload

    chown -R nobody:nobody /mnt/raid5_share
    chmod -R 0777 /mnt/raid5_share
    
    cat <<EOL > /etc/samba/smb.unauth.conf
[unauth_share]
   path = /mnt/raid5_share/
   browsable = yes
   writable = yes
   guest ok = yes
   guest only = yes
   force user = nobody
   force group = nobody
   create mask = 0777
   directory mask = 0777
   read only = no
EOL
    
    PRIMARY_CONF="/etc/samba/smb.conf"
    INCLUDE_LINE="include = /etc/samba/smb.unauth.conf"

    # Check if the include line already exists in the primary configuration file
    if ! grep -Fxq "$INCLUDE_LINE" "$PRIMARY_CONF"; then
        # If not, append the include line to the end of the primary configuration file
        echo "$INCLUDE_LINE" >> "$PRIMARY_CONF"
        echo "Include line added to $PRIMARY_CONF"
    else
        echo "Include line already exists in $PRIMARY_CONF"
    fi

    # SELINUX RAHHHHHHHHHHH
    /sbin/restorecon -R -v /mnt/raid5_share
    setsebool -P samba_export_all_rw 1

    systemctl restart smb
    systemctl restart nmb

    echo "Samba services restarted"

    echo "Press any key to continue..."
    read -n 1 -s key
	clear
}

nfs(){
    echo "Installing NFS share"
    sudo mkdir -p /mnt/raid5_share
    dnf update -y
    dnf -y install nfs-utils
    systemctl enable nfs-server --now

    firewall-cmd --permanent --add-service=nfs
    firewall-cmd --permanent --add-service=mountd
    firewall-cmd --permanent --add-service=rpc-bind
    firewall-cmd --reload

    echo "/mnt/raid5_share *(rw,sync,no_root_squash)" > /etc/exports

    exportfs -a

    systemctl restart nfs-server

    echo "NFS services restarted"

    echo "Press any key to continue..."
    read -n 1 -s key
    clear
}

    clear
    echo "Starting unauthshare"
    while true; do
        display_unauth_share_menu
        read -p "Enter your choice: " choice
        case $choice in
            0) nfs ;;
            1) smb ;;
            q|Q) clear && echo "Exiting the web server configuration wizard." && exit ;;
            *) clear && echo "Invalid choice. Please enter a valid option." ;;
        esac
    done

}

webservices(){

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
    echo "meow"



    echo "Press any key to exit..."
    read -n 1 -s key
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

#     # Set up the virtual host for the user's mail subdomain (HTTP with redirect to HTTPS)
#     cat <<EOL > /etc/httpd/conf.d/mail-$USERNAME.conf
# <VirtualHost *:80>
#     ServerName mail.$USERNAME.$DOMAIN_NAME
#     DocumentRoot /usr/share/roundcubemail
#     <Directory /usr/share/roundcubemail>
#         AllowOverride All
#         Require all granted
#     </Directory>
#     DirectoryIndex index.php
#     ErrorLog /var/log/httpd/mail_${USERNAME}_error.log
#     CustomLog /var/log/httpd/mail_${USERNAME}_access.log combined

#     # Redirect all HTTP traffic to HTTPS
#     Redirect "/" "https://mail.$USERNAME.$DOMAIN_NAME/"
# </VirtualHost>

# <VirtualHost *:443>
#     ServerName mail.$USERNAME.$DOMAIN_NAME
#     DocumentRoot /usr/share/roundcubemail
#     <Directory /usr/share/roundcubemail>
#         AllowOverride All
#         Require all granted
#     </Directory>
#     DirectoryIndex index.php
#     SSLEngine on
#     SSLCertificateFile /etc/httpd/ssl/$DOMAIN_NAME.crt
#     SSLCertificateKeyFile /etc/httpd/ssl/$DOMAIN_NAME.key
#     ErrorLog /var/log/httpd/mail_${USERNAME}_ssl_error.log
#     CustomLog /var/log/httpd/mail_${USERNAME}_ssl_access.log combined
# </VirtualHost>
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

while true; do
    clear
    display_web_menu
    read -p "Enter your choice: " web_choice
    case $web_choice in
        0) basic_setup ;;
        1) add_user ;;
        2) remove_user ;;
        q|Q) clear && echo "Exiting the user management menu." && break ;;
        *) clear && echo "Invalid choice. Please enter a valid option." ;;
    esac
done
    echo "Starting webservices"
}


ntp(){
    clear
    echo "Starting ntp"

    setup_ntp() {
    clear 

    ip_server=$(hostname -I | sed 's/ *$//')/16
    ntp_pool="server 0.pool.ntp.org iburst\\nserver 1.pool.ntp.org iburst\\nserver 2.pool.ntp.org iburst\\nserver 3.pool.ntp.org iburst"
    dnf install chrony -y
    systemctl enable --now chronyd
    timedatectl set-timezone Europe/Brussels
    echo "Time zone set to Europe/Brussels"
    timedatectl set-ntp yes
    sed -i "s|#allow 192.168.0.0/16|allow $ip_server|g" /etc/chrony.conf
    sed -i "s/pool 2.almalinux.pool.ntp.org iburst/$ntp_pool/g" /etc/chrony.conf
    systemctl restart chronyd
    echo "Chrony restarted"

    echo "Press any key to continue..."
    read -n 1 -s key
}

timezone_choice() {
    clear

    timezones=$(timedatectl list-timezones)
    echo "Available timezones:"
    PS3="Please select a timezone by number: "

    select timezone in $timezones; do
    if [[ -n $timezone ]]; then
        echo "You selected $timezone"
        break
    else
        echo "Invalid selection. Please try again."
    fi
    done

    echo "Changing timezone to $timezone..."
    timedatectl set-timezone "$timezone"

    echo -e "\nTimezone changed successfully. Current timezone is now:"
    timedatectl | grep "Time zone"

    echo "Press any key to exit..."
    read -n 1 -s key

}

timezone_display() {
    clear

    echo "System Time and Date Information"
    echo "--------------------------------"

    echo -e "\nCurrent System Date and Time:"
    date

    echo -e "\nHardware Clock (RTC) Time:"
    hwclock

    echo -e "\nCurrent Timezone:"
    timedatectl | grep "Time zone"

    echo -e "\nTimedatectl Status:"
    timedatectl status

    echo -e "\nNTP Synchronization Status (timedatectl):"
    timedatectl show-timesync --all

    if command -v chronyc &> /dev/null; then
        echo -e "\nChrony Tracking Information:"
        chronyc tracking

        echo -e "\nChrony Sources:"
        chronyc sources

        echo -e "\nChrony Source Statistics:"
        chronyc sourcestats

        echo -e "\nChrony NTP Data:"
        chronyc ntpdata
    else
        echo -e "\nChrony is not installed or not found. Skipping chrony information."
    fi

    echo "--------------------------------"
    echo "All time and date information displayed successfully."

    # chronyc tracking
    # chronyc sources
    # cat /etc/chrony.conf
    echo "Press any key to exit..."
    read -n 1 -s key
}


        clear
        display_ntp_menu
        read -p "Enter your choice: " choice
        case $choice in
            1) setup_ntp ;;
            2) timezone_choice ;;
            3) timezone_display ;;
            q|Q) clear && echo "Exiting the web server configuration wizard." && break ;;
            *) clear && echo "Invalid choice. Please enter a valid option." ;;
        esac
}

security(){

    clear
    # Install ClamAV
    dnf update
    dnf install clamav -y

    # Update ClamAV database
    freshclam

    # Schedule regular scans
    # Edit the crontab file and add the daily scan command
    echo "0 2 * * * clamscan -r /" | sudo tee -a /etc/crontab

    # Enable automatic scanning on file access
    systemctl enable clamav-freshclam
    systemctl enable clamd@scan

    # Start ClamAV service
    systemctl start clamav-freshclam
    systemctl start clamd@scan

    # Verify ClamAV status
    systemctl status clamav-freshclam
    systemctl status clamd@scan

    # Configure ClamAV for local socket scanning
    sed -i 's/^#LocalSocket /LocalSocket /' /etc/clamd.d/scan.conf
    sed -i 's/^TCPSocket /#TCPSocket /' /etc/clamd.d/scan.conf


    # Restart ClamAV service to apply changes
    systemctl restart clamd@scan

    echo "Done..."
    echo "Press any key to continue..."
    read -n 1 -s key
    clear

}


backup(){
    clear
    echo "Starting backup"
}

logs(){
    clear
    echo "Starting logs"
}


main() {
    while true; do
        clear
        display_menu
        read -p "Enter your choice: " choice
        case $choice in
            0) set_hostname ;;
            1) raid ;;
            2) ssh ;;
            3) unauthshare ;;
            4) webservices ;;
            5) ntp ;;
            6) security ;;
            7) backup ;;
            8) logs ;;
            x) testing ;;
            q|Q) clear && echo "Exiting the web server configuration wizard." && exit ;;
            *) clear && echo "Invalid choice. Please enter a valid option." ;;
        esac
    done
}

main