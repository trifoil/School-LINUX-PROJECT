#!/bin/bash

clear

RED='\033[0;31m' #Red
GREEN='\033[0;32m' #Red
NC='\033[0m' # No Color

updatedb
systemctl enable --now cockpit.socket
firewall-cmd --permanent --zone=public --add-service=cockpit
firewall-cmd --reload

# Function to display the menu
display_menu() {
    echo ""
    echo "|----------------------------------------------------------------------|"
    echo -e "|                 ${GREEN}Welcome to the server assistant ${NC}                     |"
    echo "|              Please select the tool you want to use                  |"
    echo "|----------------------------------------------------------------------|"
    echo "| Networking :                                                         |"
    echo "|----------------------------------------------------------------------|"
    echo "| 0. NFS share wizard                                                  |"
    echo "| 1. SMB share wizard                                                  |"
    echo "| 2. Web server wizard                                                 |"
    echo "| 3. FTP server wizard                                                 |"
    echo "| 4. MySQL server wizard                                               |"
    echo "| 5. DNS server wizard                                                 |"
    echo "| 6. NTP server wizard                                                 |"
    echo "|----------------------------------------------------------------------|"
    echo "| Server health :                                                      |"
    echo "|----------------------------------------------------------------------|"
    echo "| 7. IP (User policy/quota/disk-man/updates/antivirus-firewall)        |"
    echo "| 8. Backup                                                            |"
    echo "|----------------------------------------------------------------------|"
    echo "| q. Quit                                                              |"
    echo "|----------------------------------------------------------------------|"
    echo ""
}