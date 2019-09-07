#!/bin/sh

set -e -x

INSTALL="alsa-utils xorg i3 gnome-themes-standard adwaita-icon-theme DEFAULT_BROWSER"
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
