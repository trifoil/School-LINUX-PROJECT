#!/bin/bash

# Variables
read -p "Enter the username : " USERNAME
read -p "Enter the server domain name : " DOMAIN_NAME

# Check if a username was provided
if [ -z "$USERNAME" ]; then
    echo "Error: No username provided."
    exit 1
fi

# Check if the user already exists
if id "$USERNAME" &>/dev/null; then
    echo "Error: User $USERNAME already exists."
    exit 1
fi

# Add the user to the system
useradd -m -s /bin/bash "$USERNAME"
if [ $? -ne 0 ]; then
    echo "Error: Failed to add Unix user."
    exit 1
fi

# Set a Samba password for the user
(echo "password"; echo "password") | smbpasswd -a -s "$USERNAME"
if [ $? -ne 0 ]; then
    echo "Error: Failed to add Samba user."
    exit 1
fi

# Create the user's directory
USER_DIR="/mnt/raid5_web/$USERNAME"
mkdir -p "$USER_DIR"
chown "$USERNAME:$USERNAME" "$USER_DIR"
chmod 700 "$USER_DIR"

# Configure Samba share
echo "[$USERNAME]
    path = $USER_DIR
    valid users = $USERNAME
    read only = no
    browsable = yes
    create mask = 0700
    directory mask = 0700" >> /etc/samba/smb.conf

# Restart Samba to apply changes
systemctl restart smb

# Create Apache virtual host configuration
cat <<EOL > /etc/httpd/conf.d/$USERNAME.conf
<VirtualHost *:80>
    ServerName $USERNAME.$DOMAIN_NAME
    DocumentRoot $USER_DIR
    <Directory $USER_DIR>
        AllowOverride All
        Require all granted
    </Directory>
    ErrorLog /var/log/httpd/${USERNAME}_error.log
    CustomLog /var/log/httpd/${USERNAME}_access.log combined
</VirtualHost>
EOL

echo "<html><body><h1>Welcome to $USERNAME.$DOMAIN_NAME</h1></body></html>" >  $USER_DIR/index.html

# Restart Apache to apply changes
systemctl restart httpd

# Install necessary packages
yum install -y php mariadb-server phpmyadmin httpd roundcubemail

# Start and enable services
systemctl start mariadb
systemctl enable mariadb
systemctl restart httpd

# Set up MySQL user and database
MYSQL_ROOT_PASSWORD="rootpassword"
MYSQL_USER_PASSWORD="userpassword"

mysql -u root -p"$MYSQL_ROOT_PASSWORD" <<MYSQL_SCRIPT
CREATE DATABASE ${USERNAME}_db;
CREATE USER '$USERNAME'@'localhost' IDENTIFIED BY '$MYSQL_USER_PASSWORD';
GRANT ALL PRIVILEGES ON ${USERNAME}_db.* TO '$USERNAME'@'localhost';
FLUSH PRIVILEGES;
MYSQL_SCRIPT

# Configure phpMyAdmin (optional: secure it)
echo "Alias /phpmyadmin /usr/share/phpMyAdmin" >> /etc/httpd/conf.d/phpmyadmin.conf
sed -i "s/^# \$dbuser =.*/\$dbuser = '$USERNAME';/g" /etc/phpMyAdmin/config.inc.php
sed -i "s/^# \$dbpass =.*/\$dbpass = '$MYSQL_USER_PASSWORD';/g" /etc/phpMyAdmin/config.inc.php
systemctl restart httpd

# Configure Roundcube (optional: secure it)
# Assuming roundcubemail is installed and configured

# Add a webpage for the user
echo "<html><body><h1>Welcome $USERNAME!</h1></body></html>" > "$USER_DIR/index.html"
chown "$USERNAME:$USERNAME" "$USER_DIR/index.html"

echo "Setup completed for user $USERNAME"
