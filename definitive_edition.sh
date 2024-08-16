#!/bin/bash

clear

RED='\033[0;31m' #Red
BLUE='\e[38;5;33m' #Red
NC='\033[0m' # No Color

updatedb
systemctl enable --now cockpit.socket
firewall-cmd --permanent --zone=public --add-service=cockpit
firewall-cmd --reload
dnf -y install nfs-utils samba bind chrony fail2ban vsftpd rsync clamav clamd clamav-update bind-utils httpd php php-mysqlnd mariadb-server phpmyadmin mod_ssl

clear

# Function to display the menu
display_menu() {
    echo ""
    echo "|----------------------------------------------------------------------|"
    echo -e "|                 ${BLUE}Welcome to the server assistant ${NC}                     |"
    echo "|              Please select the tool you want to use                  |"
    echo "|----------------------------------------------------------------------|"
    echo "| 0. Set server hostname                                               |"
    echo "| 1. RAID Configuration                                                |"
    echo "| 2. SSH Connection                                                    |"
    echo "| 3. NFS/SAMBA Shared Directory (no auth)                              |"
    echo "| 4. Web services management                                           |"
    echo "| 5. Users Management Menu                                             |"
    echo "| 6. NTP Time Server                                                   |"
    echo "| 7. Security Settings                                                 |"
    echo "| 8. Backup                                                            |"
    echo "| 9. Consult Logs Dashboard                                            |"
    echo "|----------------------------------------------------------------------|"
    echo "| q. Quit                                                              |"
    echo "|----------------------------------------------------------------------|"
    echo ""
}

display_hostname_menu() {
    echo ""
    echo "|----------------------------------------------------------------------|"
    echo -e "|                 ${BLUE}Hostname Configuration Menu ${NC}                     |"
    echo "|----------------------------------------------------------------------|"
    echo "| 1. Set hostname                                                      |"
    echo "| 2. Display current hostname                                          |"
    echo "|----------------------------------------------------------------------|"
    echo ""
}

display_raid_menu() {
    echo ""
    echo "|----------------------------------------------------------------------|"
    echo -e "|                 ${BLUE}RAID Configuration Menu ${NC}                     |"
    echo "|----------------------------------------------------------------------|"
    echo "| 1. Create RAID                                                       |"
    echo "| 2. Display current RAID                                              |"
    echo "|----------------------------------------------------------------------|"
    echo ""
}

display_unauth_share_menu() {
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

set_hostname() {
    clear
    display_hostname_menu
    read -p "Enter your choice: " hostname_choice
    case $hostname_choice in
        1) read -p "Enter the new hostname: " new_hostname
           hostnamectl set-hostname $new_hostname
           echo "Hostname set to $new_hostname"
           echo "Press any key to continue..."
           read -n 1 -s key
           clear
           ;;
        2) current_hostname=$(hostnamectl --static)
           echo "Current hostname: $current_hostname"
               echo "Press any key to continue..."
               read -n 1 -s key
               clear
           ;;
        *) echo "Invalid choice. Please enter a valid option."
           ;;
    esac
}

raid(){
    clear
    echo "Creating RAID..."
}

ssh(){
    clear
    echo "Starting ssh"
}

unauthshare(){
    smb(){
    echo "Installing Samba share"
    sudo mkdir -p /mnt/raid5_share
    dnf update -y
    dnf -y install samba samba-client
    systemctl enable smb --now
    systemctl enable nmb --now    

    firewall-cmd --permanent --add-service=samba
    firewall-cmd --reload

    chown -R nobody:nobody /mnt/raid5_share
    chmod -R 0777 /mnt/raid5_share
    
    cp scripts/3_unauth_share.conf /etc/samba/smb.unauth.conf
    
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

nfs(){
    echo "Installing NFS share"
    sudo mkdir -p /mnt/raid5_share
    dnf update -y
    dnf -y install nfs-utils
    systemctl enable nfs-server --now

    firewall-cmd --permanent --add-service=nfs
    firewall-cmd --permanent --add-service=mountd
    firewall-cmd --permanent --add-service=rpc-bind
    firewall-cmd --reload

    echo "/mnt/raid5_share *(rw,sync,no_root_squash)" > /etc/exports

    exportfs -a

    systemctl restart nfs-server

    echo "NFS services restarted"

    echo "Press any key to continue..."
    read -n 1 -s key
    clear
}

    clear
    echo "Starting unauthshare"
    while true; do
        display_unauth_share_menu
        read -p "Enter your choice: " choice
        case $choice in
            0) nfs ;;
            1) smb ;;
            q|Q) clear && echo "Exiting the web server configuration wizard." && exit ;;
            *) clear && echo "Invalid choice. Please enter a valid option." ;;
        esac
    done

}

webservices(){
    clear
    echo "Starting webservices"
}

usersmanagement(){
    clear
    echo "Starting usersmanagement"
}

ntp(){
    clear
    echo "Starting ntp"
}

security(){
    clear
    echo "Starting security"
}

backup(){
    clear
    echo "Starting backup"
}

logs(){
    clear
    echo "Starting logs"
}

# Main function

    while true; do
        clear
        display_menu
        read -p "Enter your choice: " choice
        case $choice in
            0) set_hostname ;;
            1) raid ;;
            2) ssh ;;
            3) unauthshare ;;
            4) webservices ;;
            5) usersmanagement ;;
            6) ntp ;;
            7) security ;;
            8) backup ;;
            9) logs ;;
            x) testing ;;
            q|Q) clear && echo "Exiting the web server configuration wizard." && exit ;;
            *) clear && echo "Invalid choice. Please enter a valid option." ;;
        esac
    done
}

main