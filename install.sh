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
    display_raid_menu
    read -p "Enter your choice: " raid_choice
    case $raid_choice in
        1) echo "Creating RAID..."
           # Add your RAID configuration code here

        # creating the lvm 

        # Install necessary packages
        sudo dnf install lvm2 mdadm -y

        # Prompt user for disk selection and display disk sizes
        echo "Available disks:"
        lsblk -d -n -o NAME,SIZE | awk '{print NR ". " $1 " (" $2 ")"}'
        read -p "Enter the numbers of the disks you want to include in the RAID (separated by spaces): " disk_numbers

        # Create an array of selected disk names
        selected_disks=()
        for number in $disk_numbers; do
            disk_name=$(lsblk -d -n -o NAME | awk "NR==$number")
            selected_disks+=($disk_name)
        done

        # Create a RAID 5 array with the selected devices
        sudo mdadm --create --verbose /dev/md0 --level=5 --raid-devices=${#selected_disks[@]} ${selected_disks[@]}

        # Wait for the RAID array to be created
        sleep 5

        # Create a physical volume on the RAID array
        sudo pvcreate /dev/md0

        # Create a volume group on the physical volume
        sudo vgcreate vg_raid5 /dev/md0

        # Create a logical volume named 'share' with a size of 500M
        sudo lvcreate -L 500M -n share vg_raid5

        # Format the 'share' logical volume with ext4 filesystem
        sudo mkfs.ext4 /dev/vg_raid5/share

        # Create a mount point for the 'share' logical volume
        sudo mkdir -p /mnt/raid5_share

        # Mount the 'share' logical volume
        sudo mount /dev/vg_raid5/share /mnt/raid5_share

        # Get the UUID of the 'share' logical volume and add it to fstab for automatic mounting
        sudo blkid /dev/vg_raid5/share | awk '{print $2 " /mnt/raid5_share ext4 defaults 0 0"}' | sudo tee -a /etc/fstab

        # Create a logical volume named 'web' with a size of 500M
        sudo lvcreate -L 500M -n web vg_raid5

        # Format the 'web' logical volume with ext4 filesystem
        sudo mkfs.ext4 /dev/vg_raid5/web

        # Create a mount point for the 'web' logical volume
        sudo mkdir -p /mnt/raid5_web

        # Mount the 'web' logical volume
        sudo mount /dev/vg_raid5/web /mnt/raid5_web

        # Get the UUID of the 'web' logical volume and add it to fstab for automatic mounting
        sudo blkid /dev/vg_raid5/web | awk '{print $2 " /mnt/raid5_web ext4 defaults 0 0"}' | sudo tee -a /etc/fstab

        systemctl daemon-reload

        # Verify mounts
        df -h

        echo "RAID created successfully"
        echo "Press any key to continue..."
        read -n 1 -s key
        clear
        ;;
        2) echo "Displaying current RAID..."
           # Add your code to display current RAID configuration here
           echo "Press any key to continue..."
           read -n 1 -s key
           clear
           ;;
        *) echo "Invalid choice. Please enter a valid option."
           ;;
    esac
}

ssh(){
    echo "Starting ssh"
}

unauthshare(){
    echo "Starting unauthshare"
}

webservices(){
    echo "Starting webservices"
}

usersmanagement(){
    echo "Starting usersmanagement"
}

ntp(){
    echo "Starting ntp"
}

security(){
    echo "Starting security"
}

backup(){
    echo "Starting backup"
}

logs(){
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