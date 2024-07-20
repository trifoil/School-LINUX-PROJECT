#!/bin/bash

# creating the lvm 


# Install necessary packages
sudo dnf install lvm2 mdadm -y

# Create a RAID 5 array with 3 devices
sudo mdadm --create --verbose /dev/md0 --level=5 --raid-devices=3 /dev/sdb /dev/sdc /dev/sdd

# Create a physical volume on the RAID array
sudo pvcreate /dev/md0

# Create a volume group on the physical volume
sudo vgcreate vg_raid5 /dev/md0

# Create a logical volume named 'share' with a size of 500M
sudo lvcreate -L 500M -n share vg_raid5

# Format the 'share' logical volume with ext4 filesystem
sudo mkfs.ext4 /dev/vg_raid5/share

# Create a mount point for the 'share' logical volume
sudo mkdir -p /mnt/raid5_share

# Mount the 'share' logical volume
sudo mount /dev/vg_raid5/share /mnt/raid5_share

# Get the UUID of the 'share' logical volume and add it to fstab for automatic mounting
sudo blkid /dev/vg_raid5/share | awk '{print $2 " /mnt/raid5_share ext4 defaults 0 0"}' | sudo tee -a /etc/fstab

# Create a logical volume named 'web' with a size of 500M
sudo lvcreate -L 500M -n web vg_raid5

# Format the 'web' logical volume with ext4 filesystem
sudo mkfs.ext4 /dev/vg_raid5/web

# Create a mount point for the 'web' logical volume
sudo mkdir -p /mnt/raid5_web

# Mount the 'web' logical volume
sudo mount /dev/vg_raid5/web /mnt/raid5_web

# Get the UUID of the 'web' logical volume and add it to fstab for automatic mounting
sudo blkid /dev/vg_raid5/web | awk '{print $2 " /mnt/raid5_web ext4 defaults 0 0"}' | sudo tee -a /etc/fstab

systemctl daemon-reload

# Verify mounts
df -h


# sudo dnf install lvm2 mdadm
# sudo mdadm --create --verbose /dev/md0 --level=5 --raid-devices=3 /dev/sdb /dev/sdc /dev/sdd
# sudo pvcreate /dev/md0
# sudo vgcreate vg_raid5 /dev/md0

# sudo lvcreate -L 500M -n share vg_raid5
# sudo mkfs.ext4 /dev/vg_raid5/share
# sudo mkdir /mnt/raid5_data
# sudo mount /dev/vg_raid5/share /mnt/raid5_data
# sudo blkid /dev/vg_raid5/share

# sudo lvcreate -L 500M -n web vg_raid5
# sudo mkfs.ext4 /dev/vg_raid5/web
# sudo mkdir /mnt/raid5_data
# sudo mount /dev/vg_raid5/web /mnt/raid5_data
# sudo blkid /dev/vg_raid5/web

# # deleting all raid and wiping disks

# sudo umount /mnt/raid5_data
# sudo lvremove /dev/vg_raid5/web
# sudo lvremove /dev/vg_raid5/share
# sudo vgremove vg_raid5
# sudo pvremove /dev/md0
# sudo mdadm --stop /dev/md0
# sudo mdadm --remove /dev/md0

# sudo mdadm --zero-superblock /dev/sdb
# sudo mdadm --zero-superblock /dev/sdc
# sudo mdadm --zero-superblock /dev/sdd

# sudo wipefs -a /dev/sdb
# sudo wipefs -a /dev/sdc
# sudo wipefs -a /dev/sdd

# # mounting an existing raid array

# sudo mdadm --assemble --scan
# sudo mdadm --assemble /dev/md0 /dev/sdb /dev/sdc /dev/sdd
# sudo vgscan
# sudo vgchange -ay

# sudo mkdir /mnt/raid5_data
# sudo mount /dev/vg_raid5/web /mnt/raid5_data
# sudo mount /dev/vg_raid5/share /mnt/raid5_data
# sudo blkid /dev/vg_raid5/l
