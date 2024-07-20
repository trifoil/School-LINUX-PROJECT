#!/bin/bash

clear
display_menu() {
    echo ""
    echo "|----------------------------------------------------------------------|"
    echo -e "|                ${GREEN}Welcome to the unauth share assistant ${NC}                |"
    echo "|              Please select the tool you want to use                  |"
    echo "|----------------------------------------------------------------------|"
    echo "| 0. Create directory in /mnt/raid_5_share                             |"
    echo "| 1. Activate NFS                                                      |"
    echo "| 2. Activate SMB                                                      |"
    echo "|----------------------------------------------------------------------|"
    echo "| q. Quit                                                              |"
    echo "|----------------------------------------------------------------------|"
    echo ""
}

make_dir(){
    mkdir /mnt/raid5_share/unauth_share
}

nfs(){
    echo "test"
}

smb(){
    echo "test"
}

main() {
    while true; do
        display_menu
        read -p "Enter your choice: " choice
        case $choice in
            0) make_dir ;;
            1) nfs ;;
            2) smb ;;
            q|Q) clear && echo "Exiting the web server configuration wizard." && exit ;;
            *) clear && echo "Invalid choice. Please enter a valid option." ;;
        esac
    done
}

main