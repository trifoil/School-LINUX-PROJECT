#!/bin/bash

RED='\033[0;31m' #Red
GREEN='\033[0;32m' #Red
NC='\033[0m' # No Color

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
    dnf update -y
    dnf -y install samba samba-client
    systemctl enable smb --now
    systemctl enable nmb --now    

    firewall-cmd --permanent --add-service=samba
    firewall-cmd --reload

    chown -R nobody:nobody /mnt/raid5_share/unauth_share
    chmod -R 0777 /mnt/raid5_share/unauth_share
    
    cp wizards/2_unauth_share.conf /etc/samba/smb.unauth.conf
    
    PRIMARY_CONF="/etc/samba/smb.conf"
    INCLUDE_LINE="include = /etc/samba/smb.unauth.conf"

    # Check if the include line already exists in the primary configuration file
    if ! grep -Fxq "$INCLUDE_LINE" "$PRIMARY_CONF"; then
        # If not, append the include line to the end of the primary configuration file
        echo "$INCLUDE_LINE" >> "$PRIMARY_CONF"
        echo "Include line added to $PRIMARY_CONF"
    else
        echo "Include line already exists in $PRIMARY_CONF"
    fi

    # Restart Samba services to apply changes
    systemctl restart smb
    systemctl restart nmb

    echo "Samba services restarted"

    echo "Press any key to continue..."
    read -n 1 -s key
	clear
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