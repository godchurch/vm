#!/bin/sh

set -e

show() { printf "%s\n" "$@"; }

GUEST_ADDITIONS=""
test "$#" -eq 1 && GUEST_ADDITIONS="$1"

NEW_USER="user"

show "Checking for root privileges..."
EFFECTIVE_USER_ID="$(id -u)"
test "$EFFECTIVE_USER_ID" -eq 0

show "Updating system..."; apt-get update -y
show "Upgrading system..."; apt-get dist-upgrade -y

show "Checking kernel version..."; CURRENT_KERNEL="$(uname -r 2> /dev/null)"
show "Creating package lists..."
PACKAGES_TO_INSTALL="build-essential dkms linux-headers-${CURRENT_KERNEL} alsa-utils libavcodec-extra unzip xorg i3 rxvt-unicode firefox-esr mpv"
PACKAGES_TO_PURGE=""

test -n "$PACKAGES_TO_INSTALL" && { show "Installing packages..."; apt-get install -y --no-install-recommends $PACKAGES_TO_INSTALL; }
test -n "$PACKAGES_TO_PURGE" && { show "Removing packages..."; apt-get purge -y $PACKAGES_TO_PURGE; }

show "Removing unnecessary packages..."; apt-get autoremove --purge -y
show "Cleaning local repository..."; apt-get clean -y

show "Setting up autologin..."
test -d /etc/systemd/system/getty@tty1.service.d || mkdir -p /etc/systemd/system/getty@tty1.service.d
cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf << _HEREDOC
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $NEW_USER --noclear %I \\\$TERM
_HEREDOC

show "Creating ram directory..."; mkdir /ram
show "Setting up tempfs..."
cat >> /etc/fstab << _HEREDOC
tmpfs /tmp tmpfs rw,nosuid,nodev 0 0
tmpfs /ram tmpfs rw 0 0
_HEREDOC

show "Copying root files..."; cp -R "${0%/*}/root"/* /

show "Creating new user..."
useradd -m -k "${0%/*}/skel" -s /usr/local/bin/customlogin "$NEW_USER"
passwd user << _HEREDOC
$NEW_USER
$NEW_USER
_HEREDOC

test -n "$GUEST_ADDITIONS" && test -x "$GUEST_ADDITIONS" && "$GUEST_ADDITIONS"

show "Done!"
