#!/bin/bash

BLUE='\e[38;5;33m' #Red
NC='\033[0m' # No Color

clear
display_menu() {
    echo ""
    echo "|----------------------------------------------------------------------|"
    echo -e "|                ${BLUE}Welcome To The User Management Menu ${NC}                  |"
    echo "|               Please select the tool you want to use                 |"
    echo "|----------------------------------------------------------------------|"
    echo "| 0. Install PHP and SQL                                               |"
    echo "| 1. Add User                                                          |"
    echo "| 2. Remove User                                                       |"
    echo "| 3. Test                                                              |"
    echo "| 4. Enable DNS                                                        |"
    echo "|----------------------------------------------------------------------|"
    echo "| q. Quit                                                              |"
    echo "|----------------------------------------------------------------------|"
    echo ""
}


backup_file(){

# Define the named.conf file path
NAMED_CONF=$1

# Check if the named.conf file exists
if [ ! -f "$NAMED_CONF" ]; then
    echo "Error: $NAMED_CONF does not exist."
    exit 1
fi

# Create a timestamp
TIMESTAMP=$(date +"%Y%m%d%H%M%S")

# Define the backup file name
BACKUP_FILE="/etc/named.conf.backup.$TIMESTAMP"

# Rename the named.conf to the backup file
mv "$NAMED_CONF" "$BACKUP_FILE"

# Check if the rename was successful
if [ $? -eq 0 ]; then
    echo "Successfully backed up $NAMED_CONF to $BACKUP_FILE"
else
    echo "Error: Failed to back up $NAMED_CONF"
    exit 1
fi
}

enable_dns(){
echo "installing bind..."
dnf install bind bind-utils -y

backup_file "/etc/named.conf"

echo "adding firewall rules..."
firewall-cmd --permanent --add-service=dns
firewall-cmd --reload
systemctl enable --now named


# bash -c 'cat > /etc/named.conf <<EOF
# # 
# # 
# # EOF'

}

disable_dns(){

}

test(){

# Prompt for a username
read -p "Enter a username: " USERNAME
read -sp "Enter a password: " PASSWORD

# Define the directory
DIR="/mnt/raid5_web/$USERNAME"

# Check if the directory already exists
if [ -d "$DIR" ]; then
    echo "Directory $DIR already exists. "
    if [ -z "$( ls -A '/path/to/dir' )" ]; then
        echo "The directory $DIR is empty"
    else
        echo "The directory $DIR is not Empty"
    fi
fi

# Create the directory
mkdir -p "$DIR"
echo "Created $DIR directory" 
# Install necessary packages if not already installed
dnf install -y bind bind-utils httpd php php-mysqlnd mariadb-server phpmyadmin

# Enable and start MariaDB
systemctl enable mariadb
systemctl start mariadb

# Secure MariaDB installation (You might want to automate this part with expect or do it manually)
#sudo mysql_secure_installation
#check_success "Failed to secure MariaDB installation"

# Create a MySQL user and database
# mysql -u root -p <<EOF
# CREATE DATABASE ${username}_db;
# CREATE USER '$username'@'localhost' IDENTIFIED BY '$password';
# GRANT ALL PRIVILEGES ON ${username}_db.* TO '$username'@'localhost';
# FLUSH PRIVILEGES;
# EOF
# check_success "Failed to create MySQL user and database"

# # Set up DNS server with local.arpa domain
# sudo bash -c 'cat > /etc/named.conf <<EOF
# options {
#     listen-on port 53 { 127.0.0.1; };
#     directory       "/var/named";
#     dump-file       "/var/named/data/cache_dump.db";
#     statistics-file "/var/named/data/named_stats.txt";
#     memstatistics-file "/var/named/data/named_mem_stats.txt";
#     allow-query     { localhost; };

#     recursion yes;

#     dnssec-enable yes;
#     dnssec-validation yes;

#     /* Path to ISC DLV key */
#     bindkeys-file "/etc/named.root.key";

#     managed-keys-directory "/var/named/dynamic";
# };

# logging {
#     channel default_debug {
#         file "data/named.run";
#         severity dynamic;
#     };
# };

# zone "." IN {
#     type hint;
#     file "named.ca";
# };

# zone "local.arpa" IN {
#     type master;
#     file "local.arpa.zone";
# };

# include "/etc/named.rfc1912.zones";
# include "/etc/named.root.key";
# EOF'

# sudo bash -c 'cat > /var/named/local.arpa.zone <<EOF
# \$TTL 86400
# @   IN  SOA local.arpa. root.local.arpa. (
#         2021070401  ; Serial
#         3600        ; Refresh
#         1800        ; Retry
#         604800      ; Expire
#         86400 )     ; Minimum TTL
# ;
#     IN  NS  local.arpa.
# \$ORIGIN local.arpa.
# $username  IN  A   127.0.0.1
# EOF'

# Enable and start the DNS server
systemctl enable named
systemctl start named

# # Troubleshoot DNS server if it fails to start
# if ! systemctl is-active --quiet named; then
#   echo "DNS server failed to start. Checking logs..."
#   sudo journalctl -u named -n 50
#   exit 1
# fi

# # Configure Apache for the user
# sudo bash -c "cat > /etc/httpd/conf.d/${username}.conf <<EOF
# <VirtualHost *:80>
#     ServerName ${username}.local.arpa
#     DocumentRoot $dir
#     <Directory $dir>
#         Options Indexes FollowSymLinks
#         AllowOverride All
#         Require all granted
#     </Directory>
# </VirtualHost>
# EOF"

# # Add domain to /etc/hosts
# sudo bash -c "echo '127.0.0.1 ${username}.local.arpa' >> /etc/hosts"

# # Enable and start Apache
# sudo systemctl enable httpd
# sudo systemctl start httpd
# check_success "Failed to start Apache"

# echo "Setup complete. You can access the website at http://${username}.local.arpa"

}

setup() {

    sudo dnf update -y
    sudo dnf install httpd vsftpd samba mariadb-server bind bind-utils -y

    # Samba set up
    echo "Installing Samba"
    dnf update -y
    dnf -y install samba samba-client
    systemctl enable smb --now
    systemctl enable nmb --now 

    # Php and SQL set up
    sudo dnf install httpd php php-mysqlnd mariadb-server

    sudo systemctl start httpd
    sudo systemctl enable httpd
    sudo systemctl start mariadb
    sudo systemctl enable mariadb

    sudo mysql_secure_installation
}

add(){
    # Storing the name in variable "name"

    echo "Please input the user name : "
    read name



    # Dir creation

    mkdir -p "/mnt/raid5_web/$name"

    # Check if the directory was created successfully
    if [ $? -eq 0 ];    then
        echo "Directory '/mnt/raid5_web/$name' created successfully."
    else
        echo "Failed to create directory '/mnt/raid5_web/$name'."
    fi

    # Creating user

    useradd $name
    echo "unix user created"
    smbpasswd -a $name
    echo "smb user created"

}

remove() {
    echo "which user do you want to remove?"
    pdbedit -L
}

main() {
    while true; do
        display_menu
        read -p "Enter your choice: " choice
        case $choice in
            0) setup ;;
            1) add ;;
            2) remove ;;
            3) test ;;
            4) enable_dns ;;
            q|Q) clear && echo "Exiting the web server configuration wizard." && exit ;;
            *) clear && echo "Invalid choice. Please enter a valid option." ;;
        esac
    done
}

main