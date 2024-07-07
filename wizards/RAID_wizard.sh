#!/bin/bash

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