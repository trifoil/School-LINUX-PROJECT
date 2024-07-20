#!/bin/bash

# creating the lvm 

sudo dnf install lvm2 mdadm
sudo mdadm --create --verbose /dev/md0 --level=5 --raid-devices=3 /dev/sdb /dev/sdc /dev/sdd
sudo pvcreate /dev/md0
sudo vgcreate vg_raid5 /dev/md0

sudo lvcreate -L 500M -n share vg_raid5
sudo mkfs.ext4 /dev/vg_raid5/share
sudo mkdir /mnt/raid5_data
sudo mount /dev/vg_raid5/share /mnt/raid5_data
sudo blkid /dev/vg_raid5/share

sudo lvcreate -L 500M -n web vg_raid5
sudo mkfs.ext4 /dev/vg_raid5/web
sudo mkdir /mnt/raid5_data
sudo mount /dev/vg_raid5/web /mnt/raid5_data
sudo blkid /dev/vg_raid5/web

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
