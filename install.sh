#!/bin/bash

clear

RED='\033[0;31m' #Red
GREEN='\033[0;32m' #Red
NC='\033[0m' # No Color

updatedb
systemctl enable --now cockpit.socket
firewall-cmd --permanent --zone=public --add-service=cockpit
firewall-cmd --reload

# Function to display the menu
display_menu() {
    echo ""
    echo "|----------------------------------------------------------------------|"
    echo -e "|                 ${GREEN}Welcome to the server assistant ${NC}                     |"
    echo "|              Please select the tool you want to use                  |"
    echo "|----------------------------------------------------------------------|"
    echo "| 0. Say Hello                                                         |"
    echo "| 1. SSH connection                                                    |"
    echo "| 2. NFS/SAMBA shared directory (no auth)                              |"
    echo "| 3. Users Management Menu                                             |"
    #contains
    #server, mail, users management, domain mangement
    #
    echo "| 4. NTP Time Server                                                   |"
    echo "| 5. Security Settings                                                 |"
    echo "| 6. Consult Logs Dashboard                                            |"
    echo "|----------------------------------------------------------------------|"
    echo "| q. Quit                                                              |"
    echo "|----------------------------------------------------------------------|"
    echo ""
}

0(){
    echo "hello"
}

1(){
    echo test
}

2(){

}

# Main function
main() {
    while true; do
        display_menu
        read -p "Enter your choice: " choice
        case $choice in
            0) sayhello ;;
            1) 1 ;;
            2) 2 ;;
            q|Q) clear && echo "Exiting the web server configuration wizard." && exit ;;
            *) clear && echo "Invalid choice. Please enter a valid option." ;;
        esac
    done
}

main