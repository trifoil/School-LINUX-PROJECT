#!/bin/bash

# Install ClamAV
 dnf update
 dnf install clamav -y

# Update ClamAV database
 freshclam

# Schedule regular scans
# Edit the crontab file
 crontab -e
# Add the following line to run a daily scan at 2 AM
echo "0 2 * * * clamscan -r /" | tee -a /etc/crontab

# Enable automatic scanning on file access
 systemctl enable clamav-freshclam
 systemctl enable clamav-daemon

# Start ClamAV service
 systemctl start clamav-freshclam
 systemctl start clamav-daemon

# Verify ClamAV status
 systemctl status clamav-freshclam
 systemctl status clamav-daemon


echo "Done..."
echo "Press any key to continue..."
read -n 1 -s key
clear