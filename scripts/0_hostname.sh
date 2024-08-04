#!/bin/bash

PINK='\x1b[38;5;162m' 
CURRENT_HOSTNAME=$(hostname)

clear
display_menu() {
    echo ""
    echo "|----------------------------------------------------------------------|"
    echo -e "|                   ${PINK}Hostname assistant${PINK}                   |"
    echo "|----------------------------------------------------------------------|"
}

display_menu
read -p "Enter your choice (q to abort) : " choice
case $HOSTNAME in
            q|Q) clear && echo "Exiting ... " && exit ;;
            *) hostname $HOSTNAME && echo "Invalid choice. Please enter a valid option." ;;
esac