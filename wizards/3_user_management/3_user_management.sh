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
    echo "| 0. Install PHP and SQL                                               |"
    echo "| 1. Add User                                                          |"
    echo "| 2. Remove User                                                       |"
    echo "|----------------------------------------------------------------------|"
    echo "| q. Quit                                                              |"
    echo "|----------------------------------------------------------------------|"
    echo ""
}


setup() {

    sudo dnf update -y
    sudo dnf install httpd vsftpd samba mariadb-server bind bind-utils -y

    # Samba set up
    echo "Installing Samba"
    dnf update -y
    dnf -y install samba samba-client
    systemctl enable smb --now
    systemctl enable nmb --now 

    # Php and SQL set up
    sudo dnf install httpd php php-mysqlnd mariadb-server

    sudo systemctl start httpd
    sudo systemctl enable httpd
    sudo systemctl start mariadb
    sudo systemctl enable mariadb

    sudo mysql_secure_installation
}

test(){
    echo "testing"
}


add(){
    # Storing the name in variable "name"

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
    smbpasswd -a $name
    echo "smb user created"

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
            0) setup ;;
            1) add ;;
            2) remove ;;
            3) test ;;
            q|Q) clear && echo "Exiting the web server configuration wizard." && exit ;;
            *) clear && echo "Invalid choice. Please enter a valid option." ;;
        esac
    done
}

main