#!/bin/sh

# has user specified DEVICE and CHROOT directory
if test "$#" -ne 2; then
  printf "Usage: %s [DEVICE] [CHROOT]\n" "$0"; exit 1
fi

set -e -x

DEVICE="${1%/}"
CHROOT="${2%/}"

DESTINATION="$CHROOT/tmp/chroot"
INSTALL="pulseaudio libavcodec-extra xorg i3 rxvt-unicode firefox"
PURGE=""

SED="\
s|DEFAULT_I3_MODIFIER|Mod1|g;
s|DEFAULT_I3_UP|j|g;
s|DEFAULT_I3_DOWN|k|g;
s|DEFAULT_I3_LEFT|h|g;
s|DEFAULT_I3_RIGHT|l|g;
s|DEFAULT_BACKGROUND_COLOR|#AF5FAF|g;
s|DEFAULT_THEME|Adwaita|g;
s|DEFAULT_FONT|Sans 10|g;
s|DEFAULT_WINDOW_MANAGER|i3|g;
s|DEFAULT_BROWSER|firefox|g;"

# mount file systems
mount "$DEVICE" "$CHROOT"
mount proc   "$CHROOT/proc"    -t proc     -o nosuid,nodev,noexec
mount sys    "$CHROOT/sys"     -t sysfs    -o nosuid,nodev,noexec,ro
mount udev   "$CHROOT/dev"     -t devtmpfs -o mode=0755,nosuid
mount devpts "$CHROOT/dev/pts" -t devpts   -o mode=0620,gid=5,nosuid,noexec
mount shm    "$CHROOT/dev/shm" -t tmpfs    -o mode=1777,nosuid,nodev
mount run    "$CHROOT/run"     -t tmpfs    -o mode=0755,nosuid,nodev
mount tmp    "$CHROOT/tmp"     -t tmpfs    -o mode=1777,strictatime,nodev,nosuid

test -d "$DESTINATION" || mkdir -p "$DESTINATION"      # does destination exist, create if not
cp -R src/* "$DESTINATION"                             # copy chroot files
find "$DESTINATION" -type f -exec sed -i "$SED" {} \;  # edit chroot files

if ! test -f "$CHROOT/run/systemd/resolve/stub-resolv.conf"; then
  mkdir -p "$CHROOT/run/systemd/resolve"
  echo "nameserver 1.1.1.1" > "$CHROOT/run/systemd/resolve/stub-resolv.conf"
fi

chroot "$CHROOT" ln -sf ../run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

chroot "$CHROOT" apt-get update -y
chroot "$CHROOT" apt-get dist-upgrade -y --allow-downgrades
test -n "$INSTALL" && chroot "$CHROOT" apt-get install -y --no-install-recommends $INSTALL
test -n "$PURGE" && chroot "$CHROOT" apt-get purge -y $PURGE
chroot "$CHROOT" apt-get autoremove --purge -y
chroot "$CHROOT" apt-get clean -y
