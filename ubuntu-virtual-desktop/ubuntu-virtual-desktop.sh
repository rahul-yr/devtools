#!/bin/sh

# Official source for installation
echo "+ Official Source : https://ubuntu.com/blog/launch-ubuntu-desktop-on-google-cloud"

echo "==============================================================="
echo "+ Installing dependencies"

sudo apt update
sudo apt install --assume-yes wget tasksel

echo "+ Installing Google Chrome Remote Desktop"
# install chrome remote desktop
sudo wget https://dl.google.com/linux/direct/chrome-remote-desktop_current_amd64.deb
sudo apt-get install --assume-yes ./chrome-remote-desktop_current_amd64.deb

echo "+ Installing Ubuntu Desktop Minimal"
# install ubuntu desktop minimal GUI
sudo tasksel install ubuntu-desktop-minimal
sudo bash -c 'echo "exec /etc/X11/Xsession /usr/bin/gnome-session" > /etc/chrome-remote-desktop-session'

echo "==============================================================="
echo "Done installing dependencies"
echo "Next Steps : "
echo "First reboot the machine using 'sudo reboot' command"
echo "Then ssh into the machine"
echo "Copy and paste chrome remote desktop authentication details"
echo "Then add the 6 digit login password to the machine"
echo "sudo systemctl status chrome-remote-desktop@$USER"
echo "use the above command to check if chrome remote desktop is running"

# ==================================================================
# Helper commands
# sudo systemctl status chrome-remote-desktop@$USER
