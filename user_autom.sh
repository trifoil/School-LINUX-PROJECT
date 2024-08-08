#!/bin/bash

# Check if user exists
if id -u "$1" >/dev/null 2>&1; then
    echo "User $1 already exists. Aborting."
    exit 1
fi

USERNAME=$1
PASSWORD=$2
DOMAIN_NAME=$3

# Add the user to Unix
useradd -m "$USERNAME"
echo "$USERNAME:$PASSWORD" | chpasswd
echo "Unix user $USERNAME created."

# Add the user to Samba
(echo "$PASSWORD"; echo "$PASSWORD") | smbpasswd -a "$USERNAME"
echo "Samba user $USERNAME created."

# Create user directory
USER_DIR="/mnt/raid5_web/$USERNAME"
mkdir -p "$USER_DIR"
chown "$USERNAME:$USERNAME" "$USER_DIR"
chmod 700 "$USER_DIR"
echo "Directory $USER_DIR created."

# Configure Samba share
cat <<EOL >> /etc/samba/smb.conf

[$USERNAME]
   path = $USER_DIR
   valid users = $USERNAME
   read only = no
EOL

# Restart Samba to apply changes
systemctl restart smb

# Create a VirtualHost for the user
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

# Restart Apache to apply changes
systemctl restart httpd
echo "VirtualHost for $USERNAME created."

# Install PHP, SQL server, phpMyAdmin
dnf -y install php mariadb-server phpmyadmin
systemctl start mariadb
systemctl enable mariadb
mysql -e "CREATE USER '$USERNAME'@'localhost' IDENTIFIED BY '$PASSWORD';"
mysql -e "GRANT ALL PRIVILEGES ON *.* TO '$USERNAME'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"
echo "PHP, SQL server, and phpMyAdmin installed and configured."

# Install and configure Roundcube
dnf -y install roundcubemail
systemctl start httpd
mysql -e "CREATE DATABASE roundcube;"
mysql -e "GRANT ALL PRIVILEGES ON roundcube.* TO 'roundcube'@'localhost' IDENTIFIED BY '$PASSWORD';"
mysql -e "FLUSH PRIVILEGES;"
/usr/share/roundcubemail/bin/updatedb.sh --dir /usr/share/roundcubemail/SQL --package roundcube
echo "Roundcube installed and configured for $USERNAME."

echo "User $USERNAME setup completed."
