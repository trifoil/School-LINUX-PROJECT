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
    echo "| 2. Remove User                                                       |"
    echo "|----------------------------------------------------------------------|"
    echo "| q. Quit                                                              |"
    echo "|----------------------------------------------------------------------|"
    echo ""
}

# --------------------
# Secondary functions
# --------------------

create_directory(){
    touch "/mnt/raid5_web/$1"
}

remove_directory(){
    rm -rf "/mnt/raid5_web/$1"
}

add_quota(){
    echo "Adding quota ... "
}

remove_quota(){
    echo "Removing quota ... "
}

add_website(){
    echo "Adding user website ... "s
}

remove_website(){
    echo "Removing user website ... "
}

add_db(){
    echo "Adding user DB ... "
}

remove_db(){
    echo "Removing user DB ... "
}

# ---------------
# Main functions
# ---------------

add_user(){
    read -p "Input a username : " USERNAME
    read -p "Input a quota : " QUOTA
    echo "Adding user ... "
    create_directory $USERNAME
    
    echo "Done."
    echo "Press any key to continue..."
    read -n 1 -s key
	clear
}

remove_user(){
    read -p "Input a username : " USERNAME
    echo "Removing user ... "
    remove_directory $USERNAME
    
    echo "Done."
    echo "Press any key to continue..."
    read -n 1 -s key
	clear
}

display_users(){
    echo "List of the users that are in the system : "
}

main() {
    while true; do
        clear
        display_menu
        read -p "Enter your choice: " choice
        case $choice in
            0) add_user ;;
            1) remove_user ;;
            2) display_users ;;
            q|Q) clear && echo "Exiting the web server configuration wizard." && exit ;;
            *) clear && echo "Invalid choice. Please enter a valid option." ;;
        esac
    done
}

main