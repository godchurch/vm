#!/bin/sh

set -ex
EFFECTIVE_USER_ID="$(id -u)"
test "$EFFECTIVE_USER_ID" -eq 0
test $# -ge 1
DEV="$1"
PART="${DEV}1"
test $# -eq 2 && CODENAME="$2" || CODENAME=""
BUILD_DIR="/target"

command -v debootstrap
command -v sfdisk

SCRIPT_DIR="${0%/*}"

DEFAULT_USERNAME="user"
USERS_HOME="/home/$DEFAULT_USERNAME"
LOGIN_SCRIPT="$USERS_HOME/.local/bin/customlogin"
SYSTEMD_SERVICE_DIR="/etc/systemd/system/getty@tty1.service.d"
AUTOLOGIN_SERVICE="$SYSTEMD_SERVICE_DIR/autologin.conf"
PKGS_TO_INSTALL="linux-image-generic linux-headers-generic grub-pc build-essential spice-vdagent alsa-utils pulseaudio libavcodec-extra unzip curl xorg i3 xterm mpv firefox"
PKGS_TO_PURGE=""

sfdisk "$DEV" << EOF
2048,
EOF
sfdisk --part-type "$DEV" 1 83
sfdisk -A "$DEV" 1
mkfs.ext4 "$PART"
test -d "$BUILD_DIR" || mkdir "$BUILD_DIR"; mount "$PART" "$BUILD_DIR"
test -z "$CODENAME" && CODENAME="$(lsb_release -sc)"

debootstrap --arch amd64 "$CODENAME" "$BUILD_DIR"

test -d "$BUILD_DIR/proc" || mkdir "$BUILD_DIR/proc"; mount -t proc proc "$BUILD_DIR/proc"
test -d "$BUILD_DIR/sys" || mkdir "$BUILD_DIR/sys"; mount -t sysfs sysfs "$BUILD_DIR/sys"
test -d "$BUILD_DIR/tmp" || mkdir "$BUILD_DIR/tmp"; mount -t tmpfs tmpfs "$BUILD_DIR/tmp"
test -d "$BUILD_DIR/run" || mkdir "$BUILD_DIR/run"; mount -t tmpfs run "$BUILD_DIR/run"
if test -e "$BUILD_DIR/etc/resolv.conf" || test -L "$BUILD_DIR/etc/resolv.conf"; then
  RESOLV_CONF="$BUILD_DIR/etc/resolv.conf"
  printf "%s\n" "nameserver 1.1.1.1" > "$BUILD_DIR/run/default-resolv.conf"
  if test -L "$RESOLV_CONF"; then
    RESOLV_CONF="$(readlink "$RESOLV_CONF")"
    case "$RESOLV_CONF" in
      /*) RESOLV_CONF="${BUILD_DIR}${RESOLV_CONF}" ;;
      *) RESOLV_CONF="$BUILD_DIR/etc/$RESOLV_CONF" ;;
    esac
    test -f "$RESOLV_CONF" || install -Dm644 /dev/null "$RESOLV_CONF"
  fi
  mount --bind "$BUILD_DIR/run/default-resolv.conf" "$RESOLV_CONF"
fi
test -d "$BUILD_DIR/dev" || mkdir "$BUILD_DIR/dev"; mount --bind /dev "$BUILD_DIR/dev"
test -d "$MOUNT/tmp/skel" || mkdir "$MOUNT/tmp/skel"; mount --bind "${0%/*}/skel" "$MOUNT/tmp/skel"

DEVICE_LINE="$(blkid "$PART")"
UUID="$(printf "%s\n" "$DEVICE_LINE" | sed 's/^.*[[:blank:]]\(UUID=\)"\([^"]\{1,\}\)"[[:blank:]].*$/\1\2/')"
TYPE="$(printf "%s\n" "$DEVICE_LINE" | sed 's/^.*[[:blank:]]TYPE="\([^"]\{1,\}\)"[[:blank:]].*$/\1/')"

AWK='BEGIN{ printf "network:\n  version: 2\n  renderer: %s\n  ethernets:", "networkd" }
/^[0-9]+/ && $2 != "lo:" { printf "\n    %s\n      dhcp4: true", $2 }'
IP="$(ip link show)"
FORMATED_IP="$(printf "%s\n" "$IP" | awk "$AWK")"

mkdir -p "$BUILD_DIR/etc/netplan"
cat > "$BUILD_DIR/etc/netplan/01-netcfg.yaml" << _EOF
${FORMATED_IP}
_EOF

cat > "$BUILD_DIR/etc/fstab" << _EOF
${UUID} / ${TYPE} errors=remount-ro 0 1
tmpfs /tmp tmpfs nosuid,nodev 0 0
_EOF

cat > "$BUILD_DIR/etc/hostname" << _EOF
ubuntu
_EOF

cat > "$BUILD_DIR/etc/hosts" << _EOF
127.0.0.1    localhost
127.0.1.1    ubuntu
_EOF

mkdir -p "$BUILD_DIR/etc/apt"
cat > "$BUILD_DIR/etc/apt/sources.list" << _EOF
# See http://help.ubuntu.com/community/UpgradeNotes for how to upgrade to
# newer versions of the distribution.
deb http://archive.ubuntu.com/ubuntu/ ${CODENAME} main restricted
# deb-src http://archive.ubuntu.com/ubuntu/ ${CODENAME} main restricted

## Major bug fix updates produced after the final release of the
## distribution.
deb http://archive.ubuntu.com/ubuntu/ ${CODENAME}-updates main restricted
# deb-src http://archive.ubuntu.com/ubuntu/ ${CODENAME}-updates main restricted

## N.B. software from this repository is ENTIRELY UNSUPPORTED by the Ubuntu
## team. Also, please note that software in universe WILL NOT receive any
## review or updates from the Ubuntu security team.
deb http://archive.ubuntu.com/ubuntu/ ${CODENAME} universe
# deb-src http://archive.ubuntu.com/ubuntu/ ${CODENAME} universe
deb http://archive.ubuntu.com/ubuntu/ ${CODENAME}-updates universe
# deb-src http://archive.ubuntu.com/ubuntu/ ${CODENAME}-updates universe

## N.B. software from this repository is ENTIRELY UNSUPPORTED by the Ubuntu
## team, and may not be under a free licence. Please satisfy yourself as to
## your rights to use the software. Also, please note that software in
## multiverse WILL NOT receive any review or updates from the Ubuntu
## security team.
deb http://archive.ubuntu.com/ubuntu/ ${CODENAME} multiverse
# deb-src http://archive.ubuntu.com/ubuntu/ ${CODENAME} multiverse
deb http://archive.ubuntu.com/ubuntu/ ${CODENAME}-updates multiverse
# deb-src http://archive.ubuntu.com/ubuntu/ ${CODENAME}-updates multiverse

## N.B. software from this repository may not have been tested as
## extensively as that contained in the main release, although it includes
## newer versions of some applications which may provide useful features.
## Also, please note that software in backports WILL NOT receive any review
## or updates from the Ubuntu security team.
deb http://archive.ubuntu.com/ubuntu/ ${CODENAME}-backports main restricted universe multiverse
# deb-src http://archive.ubuntu.com/ubuntu/ ${CODENAME}-backports main restricted universe multiverse

## Uncomment the following two lines to add software from Canonical's
## 'partner' repository.
## This software is not part of Ubuntu, but is offered by Canonical and the
## respective vendors as a service to Ubuntu users.
# deb http://archive.canonical.com/ubuntu ${CODENAME} partner
# deb-src http://archive.canonical.com/ubuntu ${CODENAME} partner

deb http://security.ubuntu.com/ubuntu ${CODENAME}-security main restricted
# deb-src http://security.ubuntu.com/ubuntu ${CODENAME}-security main restricted
deb http://security.ubuntu.com/ubuntu ${CODENAME}-security universe
# deb-src http://security.ubuntu.com/ubuntu ${CODENAME}-security universe
deb http://security.ubuntu.com/ubuntu ${CODENAME}-security multiverse
# deb-src http://security.ubuntu.com/ubuntu ${CODENAME}-security multiverse
_EOF

LC_ALL=C chroot "$BUILD_DIR" /bin/sh -c "set -ex
set -ex
mkdir -p '$SYSTEMD_SERVICE_DIR'
cat > '$AUTOLOGIN_SERVICE' << _HEREDOC
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin '$DEFAULT_USERNAME' --noclear %I \\\$TERM
_HEREDOC
mkdir -p /ram
cat >> /etc/fstab << _HEREDOC
tmpfs /ram tmpfs rw 0 0
_HEREDOC
for FILE in .bash_logout .bashrc .profile; do
  test ! -f \"/tmp/skel/\$FILE\" \
    && test -f \"/etc/skel/\$FILE\" \
    && cp \"/etc/skel/\$FILE\" \"/tmp/skel/\$FILE\"
done
useradd -m -k /tmp/skel -d '$USERS_HOME' -s '$LOGIN_SCRIPT' '$DEFAULT_USERNAME'
passwd '$DEFAULT_USERNAME' << _HEREDOC
$DEFAULT_USERNAME
$DEFAULT_USERNAME
_HEREDOC
apt-get update -y
apt-get dist-upgrade -y
test -n '$PKGS_TO_INSTALL' && apt-get install -y --no-install-recommends $PKGS_TO_INSTALL
test -n '$PKGS_TO_PURGE' && apt-get purge -y $PKGS_TO_PURGE
apt-get autoremove --purge -y
apt-get clean -y"
