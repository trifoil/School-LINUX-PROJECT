#!/bin/bash

RED='\033[0;31m' #Red
BLUE='\e[38;5;33m' #Red
NC='\033[0m' # No Color

clear
display_menu() {
    echo ""
    echo "|----------------------------------------------------------------------|"
    echo -e "|                ${BLUE}Welcome to the unauth share assistant ${NC}                |"
    echo "|              Please select the tool you want to use                  |"
    echo "|----------------------------------------------------------------------|"
    echo "| 0. Activate NFS                                                      |"
    echo "| 1. Activate SMB                                                      |"
    echo "|----------------------------------------------------------------------|"
    echo "| q. Quit                                                              |"
    echo "|----------------------------------------------------------------------|"
    echo ""
}


nfs(){
    echo "Installing NFS share"
    dnf install nfs-utils
    mkdir -p /mnt/raid5_share/unauth_share
    
    # Define the NFS export line
    EXPORT_LINE="/mnt/raid5_share/unauth_share *(rw,sync,no_subtree_check,no_root_squash)"

    # Check if the line is already in /etc/exports
    if ! grep -qF "$EXPORT_LINE" /etc/exports; then
        echo "Adding NFS export line to /etc/exports"
        echo "$EXPORT_LINE" | sudo tee -a /etc/exports
    else
        echo "NFS export line already exists in /etc/exports"
    fi

    exportfs -a
    systemctl start nfs-server
    systemctl enable nfs-server

    firewall-cmd --permanent --add-service=nfs
    firewall-cmd --permanent --add-service=mountd
    firewall-cmd --permanent --add-service=rpc-bind
    firewall-cmd --reload

    showmount -e
}

smb(){
    echo "Installing Samba share"
    sudo mkdir -p /mnt/raid5_share/unauth_share
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

    # SELINUX RAHHHHHHHHHHH
    /sbin/restorecon -R -v /mnt/raid5_share
    setsebool -P samba_export_all_rw 1

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
            0) nfs ;;
            1) smb ;;
            q|Q) clear && echo "Exiting the web server configuration wizard." && exit ;;
            *) clear && echo "Invalid choice. Please enter a valid option." ;;
        esac
    done
}

main