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
    echo "| 0. Add User                                                          |"
    echo "| 1. Remove User                                                       |"
    echo "|----------------------------------------------------------------------|"
    echo "| q. Quit                                                              |"
    echo "|----------------------------------------------------------------------|"
    echo ""
}



add() {
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
    smbpasswd -a $smbuser
    echo "smb user created"

    # Samba set up

    echo "Installing Samba share"
    dnf update -y
    dnf -y install samba samba-client
    systemctl enable smb --now
    systemctl enable nmb --now 
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
            0) add ;;
            1) remove ;;
            q|Q) clear && echo "Exiting the web server configuration wizard." && exit ;;
            *) clear && echo "Invalid choice. Please enter a valid option." ;;
        esac
    done
}

main