#!/bin/bash

BLUE='\e[38;5;33m'
NC='\033[0m'

clear
display_menu() {
    echo ""
    echo "|----------------------------------------------------------------------|"
    echo -e "|                ${BLUE}Welcome To The User Management Menu ${NC}                  |"
    echo "|               Please select the tool you want to use                 |"
    echo "|----------------------------------------------------------------------|"
    echo "| 0. Basic setup (main DNS, web, DB)                                   |"
    echo "|----------------------------------------------------------------------|"
    echo "| q. Quit                                                              |"
    echo "|----------------------------------------------------------------------|"
    echo ""
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

basic_dns(){
    firewall-cmd --add-service=dns --permanent
    firewall-cmd --reload
    IP_ADDRESS=$1
    DOMAIN_NAME=$2
    NETWORK=$(echo $IP_ADDRESS | cut -d"." -f1-3).0/24
    REVERSE_ZONE=$(echo $IP_ADDRESS | awk -F. '{print $3"."$2"."$1".in-addr.arpa"}')
    REVERSE_IP=$(echo $IP_ADDRESS | awk -F. '{print $4}')
    backup_file "/etc/named.conf"
    dnf -y install bind bind-utils

cat <<EOL > /etc/named.conf
options {
    listen-on port 53 { any; };
    directory "/var/named";
    dump-file "/var/named/data/cache_dump.db";
    statistics-file "/var/named/data/named_stats.txt";
    memstatistics-file "/var/named/data/named_mem_stats.txt";
    secroots-file   "/var/named/data/named.secroots";
    recursing-file  "/var/named/data/named.recursing";
    allow-query { any; };
    recursion yes;
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

zone "$DOMAIN_NAME" IN {
    type master;
    file "forward.$DOMAIN_NAME";
    allow-update { none; };
};

zone "$REVERSE_ZONE" IN {
    type master;
    file "reverse.$DOMAIN_NAME";
    allow-update { none; };
};
EOL

# Configure /etc/sysconfig/named to use only IPv4
echo 'OPTIONS="-4"' >> /etc/sysconfig/named

# Create the zone files
cat <<EOL > /var/named/forward.$DOMAIN_NAME
\$TTL 86400
@   IN  SOA     ns.$DOMAIN_NAME. root.$DOMAIN_NAME. (
            2024052101 ; Serial
            3600       ; Refresh
            1800       ; Retry
            604800     ; Expire
            86400 )    ; Minimum TTL
;
@       IN  NS      ns.$DOMAIN_NAME.
ns      IN  A       $IP_ADDRESS
@       IN  A       $IP_ADDRESS
main    IN  A       $IP_ADDRESS
secondpage IN A     $IP_ADDRESS
EOL

cat <<EOL > /var/named/reverse.$DOMAIN_NAME
\$TTL 86400
@   IN  SOA     ns.$DOMAIN_NAME. root.$DOMAIN_NAME. (
            2024052101 ; Serial
            3600       ; Refresh
            1800       ; Retry
            604800     ; Expire
            86400 )    ; Minimum TTL
;
@       IN  NS      ns.$DOMAIN_NAME.
$REVERSE_IP       IN  PTR     $DOMAIN_NAME.
EOL

    systemctl start named
    systemctl enable named
    systemctl restart named 
    echo "nameserver $IP_ADDRESS" > /etc/resolv.conf

    # Verify DNS Configuration
    echo "Verifying DNS Configuration..."
    host main.$DOMAIN_NAME
    host secondpage.$DOMAIN_NAME
}

basic_website(){
    DOMAIN_NAME=$1
    dnf -y install httpd

    # Create directories for the websites
    mkdir -p /mnt/raid5_web/main
    mkdir -p /mnt/raid5_web/secondpage

    # Create a simple index.html for both websites
    echo "<html><body><h1>Welcome to main.$DOMAIN_NAME</h1></body></html>" > /mnt/raid5_web/main/index.html
    echo "<html><body><h1>Welcome to secondpage.$DOMAIN_NAME</h1></body></html>" > /mnt/raid5_web/secondpage/index.html

    # Set ownership and permissions
    chown -R apache:apache /mnt/raid5_web/main
    chown -R apache:apache /mnt/raid5_web/secondpage
    chcon -R --type=httpd_sys_content_t /mnt/raid5_web/main
    chcon -R --type=httpd_sys_content_t /mnt/raid5_web/secondpage

    chmod -R 755 /mnt/raid5_web

    # Set up virtual hosts
    cat <<EOL > /etc/httpd/conf.d/main.conf
<VirtualHost *:80>
    ServerName main.$DOMAIN_NAME
    DocumentRoot /mnt/raid5_web/main
    <Directory /mnt/raid5_web/main>
        AllowOverride All
        Require all granted
    </Directory>
    ErrorLog /var/log/httpd/main_error.log
    CustomLog /var/log/httpd/main_access.log combined
</VirtualHost>
EOL

    cat <<EOL > /etc/httpd/conf.d/secondpage.conf
<VirtualHost *:80>
    ServerName secondpage.$DOMAIN_NAME
    DocumentRoot /mnt/raid5_web/secondpage
    <Directory /mnt/raid5_web/secondpage>
        AllowOverride All
        Require all granted
    </Directory>
    ErrorLog /var/log/httpd/secondpage_error.log
    CustomLog /var/log/httpd/secondpage_access.log combined
</VirtualHost>
EOL

    systemctl start httpd
    systemctl enable httpd
    systemctl restart httpd

    firewall-cmd --add-service=http --permanent
    firewall-cmd --reload

    # Verify HTTP Access
    echo "Verifying HTTP Access..."
    curl http://main.$DOMAIN_NAME
    curl http://secondpage.$DOMAIN_NAME
}

basic_setup(){
    echo "Installing required components"
    read -p "Enter the IP address : " IP_ADDRESS
    read -p "Enter the server domain name : " DOMAIN_NAME
    basic_dns $IP_ADDRESS $DOMAIN_NAME
    echo "Main DNS configuration done ... "

    basic_website $DOMAIN_NAME
    echo "Web server configuration done ... "

    echo "Press any key to exit..."
    read -n 1 -s key
    clear
}

main() {
    while true; do
        display_menu
        read -p "Enter your choice: " choice
        case $choice in
            0) basic_setup ;;
            q|Q) clear && exit 0 ;;
            *) echo "Invalid choice. Please try again." ;;
        esac
    done
}

main
