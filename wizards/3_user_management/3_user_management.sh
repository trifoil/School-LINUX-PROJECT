#!/bin/bash

BLUE='\e[38;5;33m' #Red
NC='\033[0m' # No Color

clear
display_menu() {
    echo ""
    echo "|----------------------------------------------------------------------|"
    echo -e "|              ${BLUE}Welcome To The User Management Menu ${NC}              |"
    echo "|              Please select the tool you want to use                  |"
    echo "|----------------------------------------------------------------------|"
    echo "| 0. Install PHP and SQL                                               |"
    echo "| 1. Add User                                                          |"
    echo "| 2. Remove User                                                       |"
    echo "| 3. Test                                                              |"
    echo "|----------------------------------------------------------------------|"
    echo "| q. Quit                                                              |"
    echo "|----------------------------------------------------------------------|"
    echo ""
}


test(){
echo "hi"

# Function to check if a command succeeded
check_success() {
  if [ $? -ne 0 ]; then
    echo "Error: $1"
    exit 1
  fi
}

# Prompt for a username
read -p "Enter a username: " username

# Prompt for a password
read -sp "Enter a password: " password
echo

# Define the directory
dir="/mnt/raid5_web/$username"

# Check if the directory already exists
# if [ -d "$dir" ]; then
#   echo "Directory $dir already exists. Exiting."
#   exit 1
# fi

# Create the directory
mkdir -p "$dir"
check_success "Failed to create directory $dir"

# Install necessary packages if not already installed
sudo dnf install -y bind bind-utils httpd php php-mysqlnd mariadb-server phpmyadmin
check_success "Failed to install necessary packages"

# Enable and start MariaDB
sudo systemctl enable mariadb
sudo systemctl start mariadb
check_success "Failed to start MariaDB"

# Secure MariaDB installation (You might want to automate this part with expect or do it manually)
sudo mysql_secure_installation
check_success "Failed to secure MariaDB installation"

# Create a MySQL user and database
mysql -u root -p <<EOF
CREATE DATABASE ${username}_db;
CREATE USER '$username'@'localhost' IDENTIFIED BY '$password';
GRANT ALL PRIVILEGES ON ${username}_db.* TO '$username'@'localhost';
FLUSH PRIVILEGES;
EOF
check_success "Failed to create MySQL user and database"

# Set up DNS server with local.arpa domain
sudo bash -c 'cat > /etc/named.conf <<EOF
options {
    listen-on port 53 { 127.0.0.1; };
    directory       "/var/named";
    dump-file       "/var/named/data/cache_dump.db";
    statistics-file "/var/named/data/named_stats.txt";
    memstatistics-file "/var/named/data/named_mem_stats.txt";
    allow-query     { localhost; };

    recursion yes;

    dnssec-enable yes;
    dnssec-validation yes;

    /* Path to ISC DLV key */
    bindkeys-file "/etc/named.root.key";

    managed-keys-directory "/var/named/dynamic";
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

zone "local.arpa" IN {
    type master;
    file "local.arpa.zone";
};

include "/etc/named.rfc1912.zones";
include "/etc/named.root.key";
EOF'

sudo bash -c 'cat > /var/named/local.arpa.zone <<EOF
\$TTL 86400
@   IN  SOA local.arpa. root.local.arpa. (
        2021070401  ; Serial
        3600        ; Refresh
        1800        ; Retry
        604800      ; Expire
        86400 )     ; Minimum TTL
;
    IN  NS  local.arpa.
\$ORIGIN local.arpa.
$username  IN  A   127.0.0.1
EOF'

# Enable and start the DNS server
sudo systemctl enable named
sudo systemctl start named
check_success "Failed to start DNS server"

# Configure Apache for the user
sudo bash -c "cat > /etc/httpd/conf.d/${username}.conf <<EOF
<VirtualHost *:80>
    ServerName ${username}.local.arpa
    DocumentRoot $dir
    <Directory $dir>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOF"

# Add domain to /etc/hosts
sudo bash -c "echo '127.0.0.1 ${username}.local.arpa' >> /etc/hosts"

# Enable and start Apache
sudo systemctl enable httpd
sudo systemctl start httpd
check_success "Failed to start Apache"

echo "Setup complete. You can access the website at http://${username}.local.arpa"

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
            q|Q) clear && echo "Exiting the web server configuration wizard." && exit ;;
            *) clear && echo "Invalid choice. Please enter a valid option." ;;
        esac
    done
}

main