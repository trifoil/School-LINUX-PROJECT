#!/bin/bash

# Usage function
usage() {
    echo "Usage: $0 <IP_ADDRESS> <DOMAIN_NAME>"
    exit 1
}

# Check if IP address and domain name are provided
if [ $# -ne 2 ]; then
    usage
fi

IP_ADDRESS=$1
DOMAIN_NAME=$2
NETWORK=$(echo $IP_ADDRESS | cut -d"." -f1-3).0/24
REVERSE_ZONE=$(echo $IP_ADDRESS | awk -F. '{print $3"."$2"."$1".in-addr.arpa"}')
REVERSE_IP=$(echo $IP_ADDRESS | awk -F. '{print $4}')

# Install BIND
dnf -y install bind bind-utils

# Configure /etc/named.conf
cat <<EOL > /etc/named.conf
acl internal-network {
        $NETWORK;
};

options {
        listen-on port 53 { any; };
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

zone "$DOMAIN_NAME" IN {
        type primary;
        file "$DOMAIN_NAME.lan";
        allow-update { none; };
};

zone "$REVERSE_ZONE" IN {
        type primary;
        file "$REVERSE_ZONE.db";
        allow-update { none; };
};
EOL

# Configure /etc/sysconfig/named to use only IPv4
echo 'OPTIONS="-4"' >> /etc/sysconfig/named

# Create the zone files
cat <<EOL > /var/named/$DOMAIN_NAME.lan
\$TTL 86400
@   IN  SOA ns.$DOMAIN_NAME. root.$DOMAIN_NAME. (
               $(date +%Y%m%d%H) ; Serial
               3600       ; Refresh
               1800       ; Retry
               604800     ; Expire
               86400 )    ; Minimum TTL
@       IN  NS  ns.$DOMAIN_NAME.
ns      IN  A   $IP_ADDRESS
EOL

cat <<EOL > /var/named/$REVERSE_ZONE.db
\$TTL 86400
@   IN  SOA ns.$DOMAIN_NAME. root.$DOMAIN_NAME. (
               $(date +%Y%m%d%H) ; Serial
               3600       ; Refresh
               1800       ; Retry
               604800     ; Expire
               86400 )    ; Minimum TTL
@       IN  NS  ns.$DOMAIN_NAME.
$REVERSE_IP      IN  PTR ns.$DOMAIN_NAME.
EOL

# Start and enable BIND
systemctl start named
systemctl enable named

# Open firewall ports for DNS
firewall-cmd --add-service=dns --permanent
firewall-cmd --reload

# Verify BIND configuration
named-checkconf
named-checkzone $DOMAIN_NAME /var/named/$DOMAIN_NAME.lan
named-checkzone $REVERSE_ZONE /var/named/$REVERSE_ZONE.db

echo "BIND configuration completed successfully."
