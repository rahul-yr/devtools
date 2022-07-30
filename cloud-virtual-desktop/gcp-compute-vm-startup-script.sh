#!/bin/bash -x

USER_PASSWORD="admin"

apt update

apt install git

cd /home

rm -r /home/devtools

git clone https://github.com/rahul-yr/devtools.git

# update user name and password below
# This details should be your own
echo -e "$USER_PASSWORD\n$USER_PASSWORD" | passwd rahul

bash /home/devtools/cloud-virtual-desktop/debian-remote-desktop.sh

# sudo journalctl -o cat -f _SYSTEMD_UNIT=google-startup-scripts.service  