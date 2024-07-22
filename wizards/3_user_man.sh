#!/bin/bash

BLUE='\e[38;5;33m' #Red
NC='\033[0m' # No Color

clear
display_menu() {
    echo ""
    echo "|----------------------------------------------------------------------|"
    echo -e "|              ${BLUE}Welcome To The User Management Menu ${NC}              |"
    echo "|              Please select the tool you want to use                  |"        .
    echo "|----------------------------------------------------------------------|"
    echo "| 0.                                                     |"
    echo "| 1.                                                      |"
    echo "|----------------------------------------------------------------------|"
    echo "| q. Quit                                                              |"
    echo "|----------------------------------------------------------------------|"
    echo ""
}



main() {
    while true; do
        display_menu
        read -p "Enter your choice: " choice
        case $choice in
            0)  ;;
            1)  ;;
            q|Q) clear && echo "Exiting the web server configuration wizard." && exit ;;
            *) clear && echo "Invalid choice. Please enter a valid option." ;;
        esac
    done
}

main