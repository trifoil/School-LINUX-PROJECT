#!/bin/bash

dnf install httpd -y

# Variables
IP_ADDRESS="192.168.1.102"
DOMAIN_NAME="trifoil.caca"
NETWORK=$(echo $IP_ADDRESS | cut -d"." -f1-3).0/24
REVERSE_ZONE=$(echo $IP_ADDRESS | awk -F. '{print $3"."$2"."$1".in-addr.arpa"}')
REVERSE_IP=$(echo $IP_ADDRESS | awk -F. '{print $4}')
CUSTOMER_NAME="$1"
WEB_SUBDOMAIN="$CUSTOMER_NAME.$DOMAIN_NAME"

if [ -z "$CUSTOMER_NAME" ]; then
    echo "Usage: $0 <customer_name>"
    exit 1
fi

# Function to update DNS zone files
update_dns_zones() {
    # Update forward zone
    cat <<EOL >> /var/named/$DOMAIN_NAME.lan
$CUSTOMER_NAME IN  A   $IP_ADDRESS
EOL

    # Update reverse zone
    cat <<EOL >> /var/named/$REVERSE_ZONE.db
$REVERSE_IP.$CUSTOMER_NAME IN  PTR $WEB_SUBDOMAIN.
EOL

    # Reload named service
    systemctl reload named
}

# Function to create Apache virtual host
create_apache_vhost() {
    # Configure Apache virtual host
    cat <<EOL > /etc/httpd/conf.d/$WEB_SUBDOMAIN.conf
<VirtualHost *:80>
    ServerName $WEB_SUBDOMAIN
    DocumentRoot /var/www/$WEB_SUBDOMAIN
    <Directory /var/www/$WEB_SUBDOMAIN>
        AllowOverride All
        Require all granted
    </Directory>
    ErrorLog /var/log/httpd/$WEB_SUBDOMAIN-error.log
    CustomLog /var/log/httpd/$WEB_SUBDOMAIN-access.log combined
</VirtualHost>
EOL

    # Create document root and a sample index.html
    mkdir -p /var/www/$WEB_SUBDOMAIN
    echo "<html><body><h1>Welcome to $CUSTOMER_NAME's website at $WEB_SUBDOMAIN</h1></body></html>" > /var/www/$WEB_SUBDOMAIN/index.html

    # Set proper permissions
    chown -R apache:apache /var/www/$WEB_SUBDOMAIN

    # Reload Apache to apply the new configuration
    systemctl reload httpd
}

# Main execution
update_dns_zones
create_apache_vhost

echo "Website configuration for $WEB_SUBDOMAIN completed successfully."
