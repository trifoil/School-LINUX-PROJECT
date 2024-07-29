#!/bin/bash

clear

RED='\033[0;31m' #Red
BLUE='\e[38;5;33m' #Red
NC='\033[0m' # No Color

updatedb
systemctl enable --now cockpit.socket
firewall-cmd --permanent --zone=public --add-service=cockpit
firewall-cmd --reload

# Function to display the menu
display_menu() {
    echo ""
    echo "|----------------------------------------------------------------------|"
    echo -e "|                 ${BLUE}Welcome to the server assistant ${NC}                     |"
    echo "|              Please select the tool you want to use                  |"
    echo "|----------------------------------------------------------------------|"
    echo "| 0. RAID Configuration                                                |"
    echo "| 1. SSH Connection                                                    |"
    echo "| 2. NFS/SAMBA Shared Directory (no auth)                              |"
    echo "| 3. Users Management Menu                                             |"
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
    . wizards/0_raid/0_raid.sh
}

ssh(){
    chmod +x wizards/1_ssh/1_ssh.sh
    sh wizards/1_ssh/1_ssh.sh
}

unauthshare(){
    chmod +x wizards/2_unauth_share/2_unauth_share.sh
    sh wizards/2_unauth_share/2_unauth_share.sh
}

usersmanagement(){
    chmod +x wizards/3_user_management/3_user_management.sh
    sh wizards/3_user_management/3_user_management.sh
}

ntp(){
    chmod +x wizards/4_ntp_server.sh
    sh wizards/4_ntp_server.sh
}

security(){
    chmod +x wizards/5_security.sh
    sh wizards/5_security.sh
}

backup(){
    chmod +x wizards/6_backup.sh
    sh wizards/6_backup.sh
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
            0) raid ;;
            1) ssh ;;
            2) unauthshare ;;
            3) usersmanagement ;;
            4) ntp ;;
            5) security ;;
            6) backup ;;
            7) logs ;;
            q|Q) clear && echo "Exiting the web server configuration wizard." && exit ;;
            *) clear && echo "Invalid choice. Please enter a valid option." ;;
        esac
    done
}

main