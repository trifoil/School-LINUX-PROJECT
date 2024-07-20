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
    echo "| 0. RAID Configuration                                                |"
    echo "| 1. SSH Connection                                                    |"
    echo "| 2. NFS/SAMBA Shared Directory (no auth)                              |"
    echo "| 3. Users Management Menu                                             |"
    #contains
    #server, mail, users management, domain mangement
    #
    echo "| 4. NTP Time Server                                                   |"
    echo "| 5. Security Settings                                                 |"
    echo "| 6. Backup                                                            |"
    echo "| 7. Consult Logs Dashboard                                            |"
    echo "|----------------------------------------------------------------------|"
    echo "| q. Quit                                                              |"
    echo "|----------------------------------------------------------------------|"
    echo ""
}

raid(){
    chmod +x wizards/0_raid.sh
    sh wizards/0_raid.sh
}

ssh(){
    chmod +x wizards/1_ssh.sh
    sh wizards/1_ssh.sh
}

unauthshare(){
    chmod +x wizards/2_unauth_share.sh
    sh wizards/2_unauth_share.sh
}

usersmanagement(){
    chmod +x wizards/3_user_man.sh
    sh wizards/3_user_man.sh
}

ntp(){
    chmod +x wizards/4_ntp_server.sh
    sh wizards/4_ntp_server.sh
}

security(){
    chmod +x wizards/5_security.sh
    sh wizards/5_security.sh
}

logs(){
    chmod +x wizards/7_logs.sh
    sh wizards/7_logs.sh
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