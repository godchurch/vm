#!/bin/sh

set -e -x

NEW_USER="user"

INSTALL="virtualbox-guest-x11 pulseaudio libavcodec-extra xorg i3 rxvt-unicode firefox mpv"
PURGE=""

if ! test -f /run/systemd/resolve/stub-resolv.conf; then
  mkdir -p /run/systemd/resolve
  echo "nameserver 1.1.1.1" > /run/systemd/resolve/stub-resolv.conf
fi

ln -sf ../run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

apt-get update -y
apt-get dist-upgrade -y --allow-downgrades
test -n "$INSTALL" && apt-get install -y --no-install-recommends $INSTALL
test -n "$PURGE" && apt-get purge -y $PURGE
apt-get autoremove --purge -y
apt-get clean -y

sed -i 's/^\(GRUB_CMDLINE_LINUX_DEFAULT="\).*\("\)$/\1\2/' /etc/default/grub
update-grub

if ! test -d /etc/systemd/system/getty@tty1.service.d; then
  mkdir -p /etc/systemd/system/getty@tty1.service.d
fi

cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf << _HEREDOC
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $NEW_USER --noclear %I \\\$TERM
_HEREDOC

sed -i 's/^\(\/swapfile\)/#\1/' /etc/fstab
echo "tmpfs /tmp tmpfs rw,nosuid,nodev 0 0" >> /etc/fstab

rm -Rf /swapfile
cp -R /tmp/root/* /

useradd -m -k /tmp/skel -s /bin/sh "$NEW_USER"
passwd user << _HEREDOC
$NEW_USER
$NEW_USER
_HEREDOC
