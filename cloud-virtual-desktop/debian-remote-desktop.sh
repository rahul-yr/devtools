#!/bin/bash
#
# Startup script to install Chrome remote desktop and a desktop environment.
#
# See environmental variables at then end of the script for configuration
#

echo "Official source for this script is at:"
echo "https://cloud.google.com/architecture/chrome-desktop-remote-on-compute-engine#automating_the_installation_process"
# sudo journalctl -o cat -f _SYSTEMD_UNIT=google-startup-scripts.service

function install_desktop_env {
  PACKAGES="desktop-base xscreensaver dbus-x11"

  if [[ "$INSTALL_XFCE" != "yes" && "$INSTALL_CINNAMON" != "yes" ]] ; then
    # neither XFCE nor cinnamon specified; install both
    INSTALL_XFCE=yes
    INSTALL_CINNAMON=yes
  fi

  if [[ "$INSTALL_XFCE" = "yes" ]] ; then
    PACKAGES="$PACKAGES xfce4"
    echo "exec xfce4-session" > /etc/chrome-remote-desktop-session
    [[ "$INSTALL_FULL_DESKTOP" = "yes" ]] && \
      PACKAGES="$PACKAGES task-xfce-desktop"
  fi

  if [[ "$INSTALL_CINNAMON" = "yes" ]] ; then
    PACKAGES="$PACKAGES cinnamon-core"
    echo "exec cinnamon-session-cinnamon2d" > /etc/chrome-remote-desktop-session
    [[ "$INSTALL_FULL_DESKTOP" = "yes" ]] && \
      PACKAGES="$PACKAGES task-cinnamon-desktop"
  fi

  DEBIAN_FRONTEND=noninteractive \
    apt-get install --assume-yes $PACKAGES $EXTRA_PACKAGES

  systemctl disable lightdm.service
  
}

function download_and_install { # args URL FILENAME
  curl -L -o "$2" "$1"
  dpkg --install "$2"
  apt-get install --assume-yes --fix-broken
}

function is_installed {  # args PACKAGE_NAME
  dpkg-query --list "$1" | grep -q "^ii" 2>/dev/null
  return $?
}

function update_user_password {
    whoami
    
    echo -e "$USER_PASSWORD\n$USER_PASSWORD" | passwd $USER

}

function install_custom_packages {
    DEBIAN_FRONTEND=noninteractive apt-get install --assume-yes $CUSTOM_PACKAGES

    # Install snap core packages
    snap install core

    # install vs code
    snap install code --classic
}

# Configure the following environmental variables as required:
INSTALL_XFCE=yes
INSTALL_CINNAMON=no
INSTALL_CHROME=yes
INSTALL_FULL_DESKTOP=yes
USER_PASSWORD="rahuldev"

# Any additional packages that should be installed on startup can be added here
EXTRA_PACKAGES="less bzip2 zip unzip tasksel wget"

# Custom packages can be added here
CUSTOM_PACKAGES="nano snapd nodejs npm git"

apt-get update

# Install backports version of libgbm1 on Debian 9/stretch
[[ $(/usr/bin/lsb_release --codename --short) == "stretch" ]] && \
  apt-get install --assume-yes libgbm1/stretch-backports

! is_installed chrome-remote-desktop && \
  download_and_install \
    https://dl.google.com/linux/direct/chrome-remote-desktop_current_amd64.deb \
    /tmp/chrome-remote-desktop_current_amd64.deb

install_desktop_env

[[ "$INSTALL_CHROME" = "yes" ]] && \
  ! is_installed google-chrome-stable && \
  download_and_install \
    https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
    /tmp/google-chrome-stable_current_amd64.deb

install_custom_packages

update_user_password

echo "Chrome remote desktop installation completed"