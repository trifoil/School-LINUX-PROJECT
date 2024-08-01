#!/bin/bash

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