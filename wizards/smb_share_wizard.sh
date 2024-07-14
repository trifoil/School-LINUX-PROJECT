#!/bin/bash

RED='\033[0;31m' #Red
GREEN='\033[0;32m' #Red
NC='\033[0m' # No Color

display_menu() {
    echo "|-------------------------------------------|"
    echo -e "|            ${GREEN}SMB server wizard${NC}              |"
    echo "|-------------------------------------------|"
    echo "|         What do you want to do?           |"
    echo "|-------------------------------------------|"
    echo "| 0. Display UNIX users                     |"
    echo "| 1. Display SMB user                       |"
    echo "| 2. Add UNIX users                         |"
    echo "| 3. Add SMB user                           |"
    echo "| 4. Remove SMB user                        |"
    echo "| 5. Remove all SMB users                   |"
    echo "| 6. Disable SMB user                       |"
    echo "| 7. Enable SMB user                        |"
    echo "| 8. Install SMB                            |"
    echo "| 9. testing                                |"
    echo "|-------------------------------------------|"
    echo "| q. Quit                                   |"
    echo "|-------------------------------------------|"
    echo ""
}

testing() {

    cp -f config_files/smb/smb.conf /etc/samba/smb.conf
    mkdir -p /srv/filesharing
    chown -R nobody:nobody /srv/filesharing
    chmod -R 0775 /srv/filesharing

    systemctl restart smb
    systemctl restart nmb

    #chcon -t samba_share_t /share

    testparm

    echo "Press any key to continue..."
    read -n 1 -s key
}

install_samba() {
    dnf update -y
    dnf -y install samba samba-client
    systemctl enable smb --now
    systemctl enable nmb --now    

    firewall-cmd --permanent --add-service=samba
    firewall-cmd --reload

    echo "Press any key to continue..."
    read -n 1 -s key
	clear
}

display_unix_users() {
    getent passwd | awk -F: '$3 >= 1000 && $3 < 65534 {print $1}'
    echo "Press any key to continue..."
    read -n 1 -s key
    echo "" 
}

display_smb_users() {
clear
    echo "These smb users already exist :"
    pdbedit -L -w
    echo "Press any key to continue..."
    read -n 1 -s key
    echo ""
}

add_unix_user() {
    echo "which unix user do you want to add?"
    read unixuser
    useradd $unixuser
}

add_smb_user() {
    echo "which smb user do you want to add?"
    read smbuser
    smbpasswd -a $smbuser
}

remove_smb_user() {
    echo "which smb user do you want to remove?"
    read smbuser
    sudo smbpasswd -x $smbuser
}

remove_all_smb_users() {
    echo "RIP to all smb users"
    # Get a list of all Samba users
    users=$( pdbedit -L -v | awk -F: '/Unix username:/ {print $2}' | tr -d ' ')

    # Remove each user
    for user in $users; do
    smbpasswd -x "$user"
    done
}

main() {
	echo "Starting the samba configuration wizard..."
	sleep 1
    	while true; do
    	clear
        display_menu
        read -p "Enter your choice: " choice
        case $choice in
            0) display_unix_users ;;
            1) display_smb_users ;;
            2) add_unix_user ;;
            3) add_smb_user ;;
            4) remove_smb_user ;;
            5) remove_all_smb_users ;;
            8) install_samba ;;
            9) testing ;;
            q|Q) clear && echo "Exiting the web server configuration wizard." && exit ;;
            *) clear && echo "Invalid choice. Please enter a valid option." ;;
        esac
    done
}

main