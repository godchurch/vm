#!/bin/sh

set -e -x

if ! test -f /run/systemd/resolve/stub-resolv.conf; then
  mkdir -p /run/systemd/resolve
  echo "nameserver 1.1.1.1" > /run/systemd/resolve/stub-resolv.conf
fi

ln -sf ../run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

INSTALL="virtualbox-guest-x11 pulseaudio libavcodec-extra xorg i3 rxvt-unicode firefox"
PURGE=""

apt-get update -y
apt-get dist-upgrade -y --allow-downgrades
test -n "$INSTALL" && apt-get install -y --no-install-recommends $INSTALL
test -n "$PURGE" && apt-get purge -y $PURGE
apt-get autoremove --purge -y
apt-get clean -y

sed -i 's/^\(\/swapfile\)/#\1/' /etc/fstab
echo "tmpfs /tmp tmpfs rw,nosuid,nodev 0 0" >> /etc/fstab

test -d /usr/local/bin || mkdir -p /usr/local/bin
cp -R /tmp/bin/* /usr/local/bin

useradd -m -k /tmp/skel user
passwd user
