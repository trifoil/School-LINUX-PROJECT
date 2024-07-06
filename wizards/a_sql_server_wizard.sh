#!/bin/bash

dnf install phpMyAdmin mariadb-server mariadb -y
sed -i '\|<Directory /usr/share/phpMyAdmin>|,\|</Directory>| s|Require local|Require all granted|' /etc/httpd/conf.d/phpMyAdmin.conf
sudo ln -s /usr/share/phpMyAdmin /srv/mankou/phpMyAdmin
systemctl enable --now mariadb
service httpd restart


# mysql_secure_installation mais en bash + ajout d'un utilisateur admin
# disallow remote login for root
sudo mysql -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
# Kill the anonymous users
sudo mysql -e "DROP USER ''@'localhost';"
# Because our hostname varies we'll use some Bash magic here.
sudo mysql -e "DROP USER ''@'$(hostname)';"
# Kill off the demo database
sudo mysql -e "DROP DATABASE test;"
# Create a admin user
sudo mysql -e "CREATE USER 'mankou'@'localhost' IDENTIFIED BY 'test123';"
# Grant all privileges on all databases to mankou (admin user)
sudo mysql -e "GRANT ALL PRIVILEGES ON *.* TO 'mankou'@'localhost' WITH GRANT OPTION;"
# Make our changes take effect
sudo mysql -e "FLUSH PRIVILEGES"

display_menu() {
    echo "| What do you want to do?         |"
    echo "| 0. Edit profil                  |"
    echo "| 1. delete profil                |"
    echo "| q. Quit                         |"
}

edit_profil(){}

delete_profil(){}



    while true; do
        display_menu
        read -p "Enter your choice: " choice
        case $choice in
            0) edit_profil ;;
            1) delete_profil ;;
            
            q|Q) clear && echo "Exiting the web server configuration wizard." && exit ;;
            *) clear && echo "Invalid choice. Please enter a valid option." ;;
        esac
    done
}

main
