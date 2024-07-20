#!/bin/bash

# Specify the network interface
INTERFACE="eth0"

# Get the network details for the specified interface
NETWORK_INFO=$(nmcli device show $INTERFACE)

# Extract the subnet and gateway information
GATEWAY=$(echo "$NETWORK_INFO" | grep 'IP4.GATEWAY' | awk '{print $2}')
SUBNET=$(echo "$NETWORK_INFO" | grep 'IP4.ADDRESS' | awk '{print $2}' | cut -d/ -f2)
NETWORK=$(echo "$NETWORK_INFO" | grep 'IP4.ROUTE' | grep $GATEWAY | awk '{print $1}')

# Calculate the second available IP in the subnet
IFS=. read -r i1 i2 i3 i4 <<< "$(echo $NETWORK | cut -d/ -f1)"
SECOND_IP="${i1}.${i2}.${i3}.$((i4 + 100))"

# Set the second available IP as the static IP
nmcli connection modify $INTERFACE ipv4.addresses $SECOND_IP/$SUBNET
nmcli connection modify $INTERFACE ipv4.gateway $GATEWAY
nmcli connection modify $INTERFACE ipv4.dns 8.8.8.8
nmcli connection modify $INTERFACE ipv4.method manual

# Apply the changes
nmcli connection up $INTERFACE

# Verify the new IP address
ip a show $INTERFACE

echo "Press any key to continue..."
read -n 1 -s key