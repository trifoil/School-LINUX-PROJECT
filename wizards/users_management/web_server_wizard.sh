    #!/bin/bash

    display_menu() {
        echo "| What do you want to do?         |"
        echo "| 0. Install web server           |"
        echo "| 1. Show httpd status            |"
        echo "| 2. Create web dir for user      |"
        echo "| 3. Remove web directory of user |"
        echo "| 4. Display web directories      |"
        echo "| q. Quit                         |"
    }

    install_web_server() {
        echo "Installing required HTTP packages"
        dnf -y install httpd httpd-tools mod_ssl mod_md 
        echo "Done"
        echo "Adding the service to firewall"
        firewall-cmd --add-service=https --permanent
        firewall-cmd --add-service=http  --permanent
        firewall-cmd --reload
        echo "Installing php 8.1 and modules"
        sudo dnf install php -y
        sudo dnf module enable php:8.1 -y
        sudo dnf erase php -y
        sudo dnf install php -y
        dnf install php-mysqlnd php-dom php-simplexml php-xml php-xmlreader php-curl php-exif php-ftp php-gd php-iconv php-json php-mbstring php-posix php-sockets php-tokenizer -y
        echo "Php 8.1 installed"
        systemctl start httpd
        echo "Starting and enabling the service"
        systemctl restart httpd
        systemctl enable httpd
        echo "Config vhost for mankou.lan"
        cat ../config_files/web/conf.d | sudo tee /etc/httpd/conf.d/mankou.lan.conf
        sed -i 's|SHORT_DESCR|mankou.lan serveur prod hebergement web|g' /etc/httpd/conf.d/mankou.lan.conf
        sed -i 's|FQN_NAME|mankou.lan|g' /etc/httpd/conf.d/mankou.lan.conf
        sed -i 's|BASE_NAME|mankou|g' /etc/httpd/conf.d/mankou.lan.conf
        sed -i 's|OPTIONAL_ALIAS|www.mankou.lan|g' /etc/httpd/conf.d/mankou.lan.conf
        echo "vhost for mankou.lan installed successfully."
        echo "Creating the directory /srv/mankou"
        mkdir -p /srv/mankou
        echo "Directory /srv/mankou created successfully."
        echo "Create info.php file in /srv/mankou"
        echo "<?php phpinfo(); ?>" | sudo tee /srv/mankou/info.php
    }

    show_httpd_status() {
        systemctl status httpd
    }

    create_user_dir() {
        display_submenu() {
            echo "Select a user to create a directory for:"
            i=1
            
            for user in $(getent passwd | awk -F: '$3 >= 1000 && $3 < 65534 {print $1}'); do
                echo "$i. $user"
                ((i++))
            done
            echo "q. Quit"
            echo -n "Enter your choice: "
        }
        
        create_directory() {
            users=($(getent passwd | awk -F: '$3 >= 1000 && $3 < 65534 {print $1}'))
            selected_user="${users[$1-1]}"
            cd /srv
            mkdir -p "$selected_user"
            echo "Directory '$selected_user' created successfully."
            cat ../config_files/web/conf.d | sudo tee /etc/httpd/conf.d/$selected_user.lan.conf
            sed -i "s|SHORT_DESCR|$selected_user.lan serveur prod hebergement web|g" /etc/httpd/conf.d/$selected_user.lan.conf
            sed -i "s|FQN_NAME|$selected_user.lan|g" /etc/httpd/conf.d/$selected_user.lan.conf
            sed -i "s|BASE_NAME|$selected_user|g" /etc/httpd/conf.d/$selected_user.lan.conf
            sed -i "s|OPTIONAL_ALIAS|www.$selected_user.lan|g" /etc/httpd/conf.d/$selected_user.lan.conf
            echo "vhost for $selected_user.lan installed successfully."

        }

        # Main menu loop
        while true; do
            display_submenu
            read choice
            
            if [[ "$choice" == [qQ] ]]; then
                echo "Aborting..."
                break
            elif [[ $choice -gt 0 && $choice -le $(($(getent passwd | awk -F: '$3 >= 1000 && $3 < 65534' | wc -l) + 1)) ]]; then
                create_directory "$choice"
            else 
                echo "Invalid input"
            fi
        done
    }

    delete_user_dir() {
            
        display_submenu() {
            echo "Select a user to remove a directory for:"
            i=1
            
            for user in $(getent passwd | awk -F: '$3 >= 1000 && $3 < 65534 {print $1}'); do
                echo "$i. $user"
                ((i++))
            done
            echo "q. Quit"
            echo -n "Enter your choice: "
        }
        
        delete_directory() {
            users=($(getent passwd | awk -F: '$3 >= 1000 && $3 < 65534 {print $1}'))
            selected_user="${users[$1-1]}"
            cd /srv
            rm -rf "$selected_user"
            echo "Directory '$selected_user' erased successfully."
            rm -rf /etc/httpd/conf.d/$selected_user.lan.conf
            echo "vhost for $selected_user.lan erased successfully."
        }

        # sub menu loop
        while true; do
            display_submenu
            read choice
            
            if [[ "$choice" == [qQ] ]]; then
                echo "Aborting..."
                break
            elif [[ $choice -gt 0 && $choice -le $(($(getent passwd | awk -F: '$3 >= 1000 && $3 < 65534' | wc -l) + 1)) ]]; then
                delete_directory "$choice"
            else 
                echo "Invalid input"
            fi
        done
    }

    display_user_dir() {
        cd /srv
        ls -l
        echo "Press any key to continue..."
        read -n 1 -s key
        echo ""
    }

    main() {
        dnf -y install 
        clear
        echo "Starting the web server configuration wizard..."
        sleep 1
            while true; do
            clear
            display_menu
            read -p "Enter your choice: " choice
            case $choice in
                0) install_web_server ;;
                1) show_httpd_status ;;
                2) create_user_dir ;;
                3) delete_user_dir ;;
                4) display_user_dir ;;
                q|Q) clear && echo "Exiting the web server configuration wizard." && exit ;;
                *) clear && echo "Invalid choice. Please enter a valid option." ;;
            esac
        done
    }

    main