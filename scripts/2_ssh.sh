#!/bin/bash

# Generate SSH key pair if not already done
if [ ! -f ~/.ssh/id_rsa ]; then
    ssh-keygen -t rsa -b 4096 -N "" -f ~/.ssh/id_rsa
fi

# Install SSH server if not already installed
if ! rpm -q openssh-server >/dev/null 2>&1; then
    sudo dnf install openssh-server
fi

# Configure SSH server
sudo sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config
sudo sed -i 's/#AuthorizedKeysFile/AuthorizedKeysFile/' /etc/ssh/sshd_config

# Restart SSH server
sudo systemctl restart sshd

echo "Press any key to exit..."
read -n 1 -s key
clear