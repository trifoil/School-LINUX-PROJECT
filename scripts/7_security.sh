#!/bin/bash

# Install ClamAV
sudo dnf update
sudo dnf install clamav -y

# Update ClamAV database
sudo freshclam

# Schedule regular scans
# Edit the crontab file
sudo crontab -e
# Add the following line to run a daily scan at 2 AM
echo "0 2 * * * clamscan -r /" | sudo tee -a /etc/crontab

# Enable automatic scanning on file access
sudo systemctl enable clamav-freshclam
sudo systemctl enable clamav-daemon

# Start ClamAV service
sudo systemctl start clamav-freshclam
sudo systemctl start clamav-daemon

# Verify ClamAV status
sudo systemctl status clamav-freshclam
sudo systemctl status clamav-daemon


echo "Done..."
echo "Press any key to continue..."
read -n 1 -s key
clear