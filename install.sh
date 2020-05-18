#!/bin/sh

set -e

GUEST_ADDITIONS=""
test "$#" -eq 1 && GUEST_ADDITIONS="$1"

NEW_USER="user"

printf "%s\n" "Checking for root privileges..."
EFFECTIVE_USER_ID="$(id -u)"
test "$EFFECTIVE_USER_ID" -eq 0

printf "%s\n" "Checking kernel version..."
CURRENT_KERNEL="$(uname -r 2> /dev/null)"

printf "%s\n" "Creating package lists..."
PACKAGES_TO_INSTALL="build-essential dkms linux-headers-${CURRENT_KERNEL} alsa-utils libavcodec-extra unzip xorg i3 rxvt-unicode firefox-esr mpv"
PACKAGES_TO_PURGE=""

printf "%s\n" "Updating system..."
apt-get update --assume-yes
printf "%s\n" "Upgrading system..."
apt-get dist-upgrade --assume-yes
if test -n "$PACKAGES_TO_INSTALL"; then
  printf "%s\n" "Installing packages..."
  apt-get install --assume-yes --no-install-recommends $PACKAGES_TO_INSTALL
fi
if test -n "$PACKAGES_TO_PURGE"; then
  printf "%s\n" "Removing packages..."
  apt-get purge --assume-yes $PACKAGES_TO_PURGE
fi
printf "%s\n" "Removing unnecessary packages..."
apt-get autoremove --purge --assume-yes
printf "%s\n" "Cleaning local repository..."
apt-get clean --assume-yes

printf "%s\n" "Setting up autologin..."
test -d /etc/systemd/system/getty@tty1.service.d || mkdir -p /etc/systemd/system/getty@tty1.service.d
cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf << _HEREDOC
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $NEW_USER --noclear %I \\\$TERM
_HEREDOC

printf "%s\n" "Setting up tempfs..."
cat >> /etc/fstab << _HEREDOC
tmpfs /tmp tmpfs rw,nosuid,nodev 0 0
tmpfs /ram tmpfs rw 0 0
_HEREDOC

printf "%s\n" "Copying root files..."
cp -R root/* /

printf "%s\n" "Creating new user..."
useradd -m -k skel -s /usr/local/bin/customlogin "$NEW_USER"
passwd user << _HEREDOC
$NEW_USER
$NEW_USER
_HEREDOC

test -n "$GUEST_ADDITIONS" && test -x "$GUEST_ADDITIONS" && "$GUEST_ADDITIONS"

printf "%s\n" "Done!"
