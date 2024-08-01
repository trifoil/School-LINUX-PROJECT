#!/bin/bash

BLUE='\e[38;5;33m' #Red
NC='\033[0m' # No Color

clear
display_menu() {
    echo ""
    echo "|----------------------------------------------------------------------|"
    echo -e "|                ${BLUE}Welcome To The User Management Menu ${NC}                  |"
    echo "|               Please select the tool you want to use                 |"
    echo "|----------------------------------------------------------------------|"
    echo "| 0. Basic setup                                                       |"
    echo "| 1. Add User                                                          |"
    echo "| 2. Remove User                                                       |"
    echo "|----------------------------------------------------------------------|"
    echo "| q. Quit                                                              |"
    echo "|----------------------------------------------------------------------|"
    echo ""
}

ip_set(){
    INTERFACE=$1
    ADDRESS=$2
    nmcli connection modify "$INTERFACE" ipv4.method manual
    nmcli connection modify "$INTERFACE" ipv4.addresses "$ADDRESS/24"
    nmcli connection up "$INTERFACE"
    arping -c 3 -I $INTERFACE $ADDRESS
    echo "Done..."
    echo "Press any key to continue..."
    read -n 1 -s key
	clear
}

backup_file(){
    # Define the named.conf file path
    ORIGINAL_FILE=$1
    # Check if the named.conf file exists
    if [ ! -f "$ORIGINAL_FILE" ]; then
        echo "Error: $ORIGINAL_FILE does not exist."
        exit 1
    fi
    # Create a timestamp
    TIMESTAMP=$(date +"%Y%m%d%H%M%S")
    # Define the backup file name
    BACKUP_FILE="/etc/named.conf.bak.$TIMESTAMP"
    # Rename the named.conf to the backup file
    mv "$ORIGINAL_FILE" "$BACKUP_FILE"
    touch "$ORIGINAL_FILE"
    # Check if the rename was successful
    if [ $? -eq 0 ]; then
        echo "Successfully backed up $ORIGINAL_FILE to $BACKUP_FILE"
    else
        echo "Error: Failed to back up $ORIGINAL_FILE"
        exit 1
    fi
}

dns_setup(){
    IP_ADDRESS=$1
    SERVERNAME=$2
    DOMAIN_NAME=$3
    backup_file "/etc/named.conf"
    cat <<EOL > /etc/named.conf
options {
        listen-on port 53 { $IP_ADDRESS; };
        listen-on-v6 { none; };
        directory       "/var/named";
        dump-file       "/var/named/data/cache_dump.db";
        statistics-file "/var/named/data/named_stats.txt";
        memstatistics-file "/var/named/data/named_mem_stats.txt";
        secroots-file   "/var/named/data/named.secroots";
        recursing-file  "/var/named/data/named.recursing";
        allow-query     { localhost; internal-network; };
        allow-transfer  { localhost; };
        recursion yes;
        dnssec-validation yes;

        forwarders {
                8.8.8.8;  // Serveur DNS Google
                1.1.1.1;  // Serveur DNS Cloudflare
        };

        managed-keys-directory "/var/named/dynamic";
        pid-file "/run/named/named.pid";
        session-keyfile "/run/named/session.key";
        include "/etc/crypto-policies/back-ends/bind.config";
};

logging {
        channel default_debug {
                file "data/named.run";
                severity dynamic;
        };
};

zone "." IN {
        type hint;
        file "named.ca";
};

include "/etc/named.rfc1912.zones";
include "/etc/named.root.key";

zone "$SERVERNAME.$DOMAIN_NAME" IN {
        type master;
        file "$SERVERNAME.forward";
        allow-update {none; };
};

zone "1.168.192.in-addr.arpa" IN {
        type master;
        file "$SERVERNAME.reversed";
        allow-update {none;};
};
EOL

cat << EOL > /var/named/$SERVERNAME.forward
\$TTL 86400
@   IN  SOA     $DOMAIN. root.$SERVERNAME.$DOMAIN. (
        2023022101  ;Serial
        3600        ;Refresh
        1800        ;Retry
        604800      ;Expire
        86400       ;Minimum TTL
)
        IN  NS      $SERVERNAME.$DOMAIN.
        IN  A       $IPADD

$SERVERNAME.$DOMAIN     IN  A       $IPADD
EOL

cat << EOL > /var/named/$SERVERNAME.reversed
\$TTL 86400
@   IN  SOA    $DOMAIN. root.$SERVERNAME.$DOMAIN. (
        2023022101  ;Serial
        3600        ;Refresh
        1800        ;Retry
        604800      ;Expire
        86400       ;Minimum TTL
)
        IN  NS      $SERVERNAME.$DOMAIN.

$LAST8BITS      IN  PTR     $SERVERNAME.$DOMAIN.
EOL

echo 'OPTIONS="-4"' >> /etc/sysconfig/named

chown named:named /var/named/$SERVERNAME.forward
chmod 640 /var/named/$SERVERNAME.forward
chown named:named /var/named/$SERVERNAME.reversed
chmod 640 /var/named/$SERVERNAME.reversed

# Rechargement du cache DNS chaque heure
bash -c "(crontab -l 2>/dev/null; echo '0 * * * *  rndc dumpdb -cache') | crontab -"
bash -c "(crontab -l 2>/dev/null; echo '* 17 * * *  rndc flush') | crontab -"

systemctl restart named 

echo "nameserver $IP_ADDRESS" > /etc/resolv.conf

}

basic_setup(){
    echo "Installing required components"
    read -p "Enter the IP address : " IP_ADDRESS
    read -p "Enter the server name : " SERVERNAME
    read -p "Enter the server domain name : " DOMAIN_NAME
    dnf install -y bind bind-utils httpd php php-mysqlnd mariadb-server phpmyadmin vsftpd samba
    overwriting_named $IP_ADDRESS $SERVERNAME $DOMAIN_NAME
    echo "main DNS configuration done ... "
}

add_user(){
    echo "Adding an user ..."
    read -p "Enter a username: " USERNAME
    read -sp "Enter a password: " PASSWORD
    DIR="/mnt/raid5_web/$USERNAME"
    mkdir -p "$DIR"
    echo "Created $DIR directory ... " 
    useradd $USERNAME
    echo "unix user created"
    smbpasswd -a $USERNAME
    echo "smb user created"
}

remove_user(){
    echo "Removing an user ... "
    echo "Users list : "
    pdbedit -L
    read -p "Enter a user to delete: " USERNAME
}

main() {
    while true; do
        display_menu
        read -p "Enter your choice: " choice
        case $choice in
            0) basic_setup ;;
            1) add_user ;;
            2) remove_user ;;
            q|Q) clear && echo "Exiting the web server configuration wizard." && exit ;;
            *) clear && echo "Invalid choice. Please enter a valid option." ;;
        esac
    done
}

main