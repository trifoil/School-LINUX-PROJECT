#!/bin/bash

BLUE='\e[38;5;33m'
CURRENT_HOSTNAME=$(hostname)

display_menu() {
    echo ""
    echo "|----------------------------------------------------------------------|"
    echo -e "|                ${BLUE}Welcome to the hostname assistant ${NC}                    |"
    echo "|                  Please input your new hostname                      |"
    echo "|----------------------------------------------------------------------|"
    echo ""
    echo -e "Current : ${CURRENT_HOSTNAME}"
    echo ""
}

display_menu
read -p "Enter your choice (q to abort) : " HOSTNAME
case $HOSTNAME in
            q|Q) clear && echo "Exiting ... " && exit ;;
            *) hostname $HOSTNAME && echo "Done" && exit;;
esac