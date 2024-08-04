#!/bin/bash

BLUE='\e[38;5;33m'
NC='\033[0m'

display_menu() {
    echo ""
    echo "|----------------------------------------------------------------------|"
    echo -e "|                 ${BLUE}Welcome to the users assistant ${NC}                     |"
    echo "|              Please select the tool you want to use                  |"
    echo "|----------------------------------------------------------------------|"
    echo "| 0. Add User                                                          |"
    echo "| 1. Remove User                                                       |"
    echo "|----------------------------------------------------------------------|"
    echo "| q. Quit                                                              |"
    echo "|----------------------------------------------------------------------|"
    echo ""
}

create_directory(){
    touch "/mnt/raid5_web/$1"
}

remove_directory(){
    rm -rf "/mnt/raid5_web/$1"
}

add_user(){
    read -p "Input a username : " USERNAME
    echo "Adding user ... "
    create_directory $USERNAME
}

remove_user(){
    echo "Removing user ... "
}

main() {
    while true; do
        clear
        display_menu
        read -p "Enter your choice: " choice
        case $choice in
            0) add_user ;;
            1) remove_user ;;
            q|Q) clear && echo "Exiting the web server configuration wizard." && exit ;;
            *) clear && echo "Invalid choice. Please enter a valid option." ;;
        esac
    done
}

main