#!/bin/sh

set -ex
EFFECTIVE_USER_ID="$(id -u)"
test "$EFFECTIVE_USER_ID" -eq 0
NEW_USER="user"
apt-get update -y
apt-get dist-upgrade -y
PACKAGES_TO_INSTALL="alsa-utils pulseaudio libavcodec-extra unzip curl xorg i3 xterm mpv firefox"
PACKAGES_TO_PURGE=""
test -n "$PACKAGES_TO_INSTALL" && apt-get install -y --no-install-recommends $PACKAGES_TO_INSTALL
test -n "$PACKAGES_TO_PURGE" && apt-get purge -y $PACKAGES_TO_PURGE
apt-get autoremove --purge -y
apt-get clean -y
SYSTEMD_SERVICE="/etc/systemd/system/getty@tty1.service.d/autologin.conf"
test -d "${SYSTEMD_SERVICE%/*}" || mkdir -p "${SYSTEMD_SERVICE%/*}"
cat > "$SYSTEMD_SERVICE" << _HEREDOC
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $NEW_USER --noclear %I \\\$TERM
_HEREDOC
mkdir -p /ram
cat >> /etc/fstab << _HEREDOC
tmpfs /ram tmpfs rw 0 0
_HEREDOC
cp -R "${0%/*}/root"/* /
useradd -m -k "${0%/*}/skel" -s /usr/local/bin/customlogin "$NEW_USER"
passwd user << _HEREDOC
$NEW_USER
$NEW_USER
_HEREDOC
