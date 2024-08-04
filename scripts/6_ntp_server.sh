#!/bin/bash
clear

RED='\033[0;31m' #Red
GREEN='\033[0;32m' #Red
NC='\033[0m' # No Color



display_menu() {
    echo "|-------------------------------------------|"
    echo -e "|            ${GREEN}NTP server wizard${NC}              |"
    echo "|-------------------------------------------|"
    echo "|         What do you want to do?           |"
    echo "|-------------------------------------------|"
    echo "| 1. Setup the NTP (defaults to Eu/Bx)      |"
    echo "| 2. Choose a timezone                      |"
    echo "| 3. Show NTP statuses                      |"
    echo "|-------------------------------------------|"
    echo "| q. Quit                                   |"
    echo "|-------------------------------------------|"
    echo ""
}

setup() {
    clear 

    ip_server=$(hostname -I | sed 's/ *$//')/16
    ntp_pool="server 0.pool.ntp.org iburst\\nserver 1.pool.ntp.org iburst\\nserver 2.pool.ntp.org iburst\\nserver 3.pool.ntp.org iburst"
    dnf install chrony -y
    systemctl enable --now chronyd
    timedatectl set-timezone Europe/Brussels
    timedatectl set-ntp yes
    sed -i "s|#allow 192.168.0.0/16|allow $ip_server|g" /etc/chrony.conf
    sed -i "s/pool 2.almalinux.pool.ntp.org iburst/$ntp_pool/g" /etc/chrony.conf
    systemctl restart chronyd
    
    echo "Press any key to continue..."
    read -n 1 -s key
}

timezone_choice() {
    clear

    timezones=$(timedatectl list-timezones)
    echo "Available timezones:"
    PS3="Please select a timezone by number: "

    select timezone in $timezones; do
    if [[ -n $timezone ]]; then
        echo "You selected $timezone"
        break
    else
        echo "Invalid selection. Please try again."
    fi
    done

    echo "Changing timezone to $timezone..."
    timedatectl set-timezone "$timezone"

    echo -e "\nTimezone changed successfully. Current timezone is now:"
    timedatectl | grep "Time zone"

    echo "Press any key to exit..."
    read -n 1 -s key

}

timezone_display() {
    clear

    echo "System Time and Date Information"
    echo "--------------------------------"

    echo -e "\nCurrent System Date and Time:"
    date

    echo -e "\nHardware Clock (RTC) Time:"
    hwclock

    echo -e "\nCurrent Timezone:"
    timedatectl | grep "Time zone"

    echo -e "\nTimedatectl Status:"
    timedatectl status

    echo -e "\nNTP Synchronization Status (timedatectl):"
    timedatectl show-timesync --all

    if command -v chronyc &> /dev/null; then
        echo -e "\nChrony Tracking Information:"
        chronyc tracking

        echo -e "\nChrony Sources:"
        chronyc sources

        echo -e "\nChrony Source Statistics:"
        chronyc sourcestats

        echo -e "\nChrony NTP Data:"
        chronyc ntpdata
    else
        echo -e "\nChrony is not installed or not found. Skipping chrony information."
    fi

    echo "--------------------------------"
    echo "All time and date information displayed successfully."

    # chronyc tracking
    # chronyc sources
    # cat /etc/chrony.conf
    echo "Press any key to exit..."
    read -n 1 -s key
}



main() {
    while true; do
        clear
        display_menu
        read -p "Enter your choice: " choice
        case $choice in
            1) setup ;;
            2) timezone_choice ;;
            3) timezone_display ;;
            q|Q) clear && echo "Exiting the web server configuration wizard." && exit ;;
            *) clear && echo "Invalid choice. Please enter a valid option." ;;
        esac
        ##clear
    done
}

main