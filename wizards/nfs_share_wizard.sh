#!/bin/bash
# install_nfs_server(){}
dnf install -y libnfsidmap
dnf install -y sssd-nfs-idmap
dnf install -y nfs-utils
mkdir /srv/nfs

sudo adduser -c 'x' -m /nonexisting -M  -r  -s /sbin/nologin  nfs

