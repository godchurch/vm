#!/bin/sh

exit 0

#!/bin/sh

# check for DEVICE and CHROOT operands
if test "$#" -ne 2; then
  printf "Usage: %s [DEVICE] [CHROOT]\n" "$0"
  exit 1
fi

set -e -x

DEVICE="${1%/}"
CHROOT="${2%/}"

# mount file systems
mount "$DEVICE" "$CHROOT"
mount proc   "$CHROOT/proc"    -t proc     -o nosuid,nodev,noexec
mount sys    "$CHROOT/sys"     -t sysfs    -o nosuid,nodev,noexec,ro
mount udev   "$CHROOT/dev"     -t devtmpfs -o mode=0755,nosuid
mount devpts "$CHROOT/dev/pts" -t devpts   -o mode=0620,gid=5,nosuid,noexec
mount shm    "$CHROOT/dev/shm" -t tmpfs    -o mode=1777,nosuid,nodev
mount run    "$CHROOT/run"     -t tmpfs    -o mode=0755,nosuid,nodev
mount tmp    "$CHROOT/tmp"     -t tmpfs    -o mode=1777,strictatime,nodev,nosuid

cp -R src/* "$CHROOT/tmp"
chroot "$CHROOT" /tmp/chroot.sh

#!/bin/sh

set -e -x

NEW_USER="user"

INSTALL="virtualbox-guest-utils virtualbox-guest-x11 pulseaudio libavcodec-extra unzip xorg i3 rxvt-unicode firefox mpv"
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

if ! test -d /etc/systemd/system/getty@tty1.service.d; then
  mkdir -p /etc/systemd/system/getty@tty1.service.d
fi

cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf << _HEREDOC
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $NEW_USER --noclear %I \\\$TERM
_HEREDOC

sed -i 's/^\(\/swapfile\)/#\1/' /etc/fstab
cat >> /etc/fstab << _HEREDOC
tmpfs /tmp tmpfs rw,nosuid,nodev 0 0
tmpfs /ram tmpfs rw 0 0
_HEREDOC

rm -Rf /swapfile
cp -R /tmp/root/* /

useradd -m -k /tmp/skel -s /usr/local/bin/customlogin "$NEW_USER"
passwd user << _HEREDOC
$NEW_USER
$NEW_USER
_HEREDOC
