#!/bin/bash -x

# update variables to match your environment
USER_NAME="yourusername"
USER_PASSWORD="admin"

# perform actions from here
apt update
apt-get install git -y
cd /home
rm -r /home/devtools
git clone https://github.com/rahul-yr/devtools.git
bash /home/devtools/cloud-virtual-desktop/debian-remote-desktop.sh
echo -e "$USER_PASSWORD\n$USER_PASSWORD" | passwd $USER_NAME
# sudo journalctl -o cat -f _SYSTEMD_UNIT=google-startup-scripts.service  