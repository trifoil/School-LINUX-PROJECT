#!/bin/bash

#source: https://doc.fedora-fr.org/wiki/Vsftpd_:_Installation_et_configuration

RED='\033[0;31m' #Red
GREEN='\033[0;32m' #Red
NC='\033[0m' # No Color

display_menu() {
    echo "|-------------------------------------------|"
    echo -e "|            ${GREEN}FTP server wizard${NC}              |"
    echo "|-------------------------------------------|"
    echo "|         What do you want to do?           |"
    echo "|-------------------------------------------|"
    echo "| 1. Install and enable ftp server (vsftpd) |"
    echo "| 2. Start ftp server                       |"
    echo "| 3. Stop ftp server                        |"
    echo "| 4. Enable ftp server                      |"    
    echo "| 5. Disable ftp server                     |"
    echo "| 6. Show ftp server status                 |"
    echo "| 7. Directory attribution                  |"
    echo "| 8. Load config files                      |"
    echo "| 9. PAM config                             |"
    echo "|-------------------------------------------|"
    echo "| q. Quit                                   |"
    echo "|-------------------------------------------|"
    echo ""
}

install_ftp_server() {
    echo "Installing"
    dnf -y install vsftpd
    systemctl enable vsftpd.service
    mv -f /etc/vsftpd/vsftpd.conf /etc/vsftpd/vsftpd.conf.default
    cp config_files/ftp/vsftpd.conf /etc/vsftpd/vsftpd.conf
    chmod 600 /etc/vsftpd/vsftpd.conf

    chmod -v 777 -R "/srv"

    firewall-cmd --permanent --add-port=20/tcp
    firewall-cmd --permanent --add-port=21/tcp
    firewall-cmd --reload
    firewall-cmd --list-ports

    echo "Press any key to continue..."
    read -n 1 -s key
    # go to script location
    sleep 1
}

fonction_de_merde() {
    CONF_DIR="/etc/vsftpd/vsftpd_user_conf"
    FTP_DIR_BASE="/srv"


    # Check if the configuration directory exists
    if [ ! -d "$CONF_DIR" ]; then
    echo "Configuration directory $CONF_DIR does not exist. Exiting."
    exit 1
    fi

    # Iterate through each user configuration file in the CONF_DIR
    for conf_file in "$CONF_DIR"/*; do
    # Extract the username from the configuration file name
    user=$(basename "$conf_file")

    # Define the user's FTP directory
    user_ftp_dir="$FTP_DIR_BASE/$user"

    # Create the user's FTP directory if it doesn't exist
    if [ ! -d "$user_ftp_dir" ]; then
        mkdir -p "$user_ftp_dir"
        echo "Created directory $user_ftp_dir"
    else
        echo "Directory $user_ftp_dir already exists"
    fi

    # Check if the user's FTP directory is already in their configuration file
    if ! grep -q "local_root=$user_ftp_dir" "$conf_file"; then
        # Add the directory path to the user's configuration file
        echo "local_root=$user_ftp_dir" >> "$conf_file"
        echo "Added local_root=$user_ftp_dir to $conf_file"
    else
        echo "local_root=$user_ftp_dir already present in $conf_file"
    fi
    done

    echo "Script execution completed."
}

upload_config() {
    cp -f config_files/ftp/login.txt /etc/vsftpd/login.txt
    sudo dnf -y install libdb-utils
    mkdir /etc/vsftpd/vsftpd_user_conf
    chmod 
    txt2db /etc/vsftpd/login.txt /etc/vsftpd/login.db
    cleanconf
    cp -f config_files/ftp/pam/vsftpd /etc/pam.d/vsftpd
    systemctl restart vsftpd.service
    echo "Press any key to continue..."
    
    echo "loading users dirs"
    fonction_de_merde

    systemctl restart vsftpd.service
    echo "Press any key to continue..."

    read -n 1 -s key
}

txt2db() {
    if [ $# = "2" ]; then
        rm -f $2
        db_load -T -t hash -f $1 $2
        chmod 600 /etc/vsftpd/login.*
        echo "Base crée"
        lignes=$(cat $1)
        nb=1
        for ligne in $lignes
        do
            if [ $(($nb%2)) -ne 0  ];
            then
                if [ ! -e vsftpd_user_conf/$ligne ];
                then
                    touch /etc/vsftpd/vsftpd_user_conf/$ligne
                    echo "fichier $ligne crée"
                fi
            fi
            nb=$(($nb+1))
        done
    else
        echo "Il faut donner le fichier d'entrée et le fichier de sortie"
    fi
    echo "text2db done"
    echo "Press any key to continue..."
    read -n 1 -s key
}

cleanconf() {
    fichiers=$(ls /etc/vsftpd/vsftpd_user_conf)
    users=""
    lignes=$(cat /etc/vsftpd/login.txt)
    nb=1
    for ligne in $lignes
    do
        if [ $(($nb%2)) -ne 0  ];
        then
            users="$users $ligne"
        fi
    nb=$(($nb+1))
    done
    for conf in $fichiers
    do
    found=0
    for user in $users
    do
        if [ $conf = $user ];
        then
            found="1"
        fi
    done
    if [ $found != "1" ];
    then
        rm -f vsftpd_user_conf/$conf
        echo "Fichier $conf supprimé"
    fi
    done
    echo "cleanconf done"
    echo "Press any key to continue..."
    read -n 1 -s key
}

pam_config() {
    cp -f config_files/ftp/pam/vsftpd /etc/pam.d/vsftpd
    systemctl restart vsftpd.service
    echo "Done"
    echo "Press any key to continue..."
    read -n 1 -s key
}

start_ftp_server () {
    echo "Starting..."
    systemctl start vsftpd.service
    sleep 1
}

stop_ftp_server () {
    echo "Stopping..."
    systemctl stop vsftpd.service
    sleep 1
}

enable_ftp_server () {
    echo "Enabling..."
    systemctl enable vsftpd.service
    sleep 1
}

disable_ftp_server () {
    echo "Disabling..."
    systemctl disable vsftpd.service
    sleep 1
}

show_ftp_status () {
    systemctl status vsftpd.service
        sleep 1

}

directory_attribution () {
    echo "test"

}

main() {
    while true; do
        clear
        display_menu
        read -p "Enter your choice: " choice
        case $choice in
            1) install_ftp_server ;;
            2) start_ftp_server ;;
            3) stop_ftp_server ;;
            4) enable_ftp_server ;;
            5) disable_ftp_server ;;
            6) show_ftp_status ;;
            7) directory_attribution ;;
            8) upload_config ;;
            9) pam_config ;;
            q|Q) clear && echo "Exiting the web server configuration wizard." && exit ;;
            *) clear && echo "Invalid choice. Please enter a valid option." ;;
        esac
        ##clear
    done
}

main