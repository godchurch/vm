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
