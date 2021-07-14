#!/bin/sh

set -ex

EFFECTIVE_USER_ID="$(id -u)"
test "$EFFECTIVE_USER_ID" -eq 0

command -v debootstrap
command -v sfdisk

test $# -ge 1
test $# -eq 2 && CODENAME="$2" || CODENAME="$(lsb_release -sc)"

SCRIPT_DIR="${0%/*}"

DEV="$1"
PART="${DEV}1"

BUILD_DIR="/target"

DEFAULT_USERNAME="user"
USERS_HOME="/home/$DEFAULT_USERNAME"
LOGIN_SCRIPT="$USERS_HOME/.local/bin/customlogin"
SYSTEMD_SERVICE_DIR="/etc/systemd/system/getty@tty1.service.d"
AUTOLOGIN_SERVICE="$SYSTEMD_SERVICE_DIR/autologin.conf"
PKGS_TO_INSTALL="linux-image-generic linux-headers-generic grub-pc build-essential alsa-utils pulseaudio libavcodec-extra unzip curl xorg i3 xterm mpv firefox"
PKGS_TO_PURGE=""

sfdisk -f "$DEV" << EOF
2048,
EOF
sfdisk -f --part-type "$DEV" 1 83
sfdisk -f -A "$DEV" 1
mkfs.ext4 "$PART"

mkdir -p "$BUILD_DIR"; mount "$PART" "$BUILD_DIR"

debootstrap --arch amd64 "$CODENAME" "$BUILD_DIR"

mkdir -p "$BUILD_DIR/proc"; mount -t proc proc "$BUILD_DIR/proc"
mkdir -p "$BUILD_DIR/sys"; mount -t sysfs sysfs "$BUILD_DIR/sys"
mkdir -p "$BUILD_DIR/tmp"; mount -t tmpfs tmpfs "$BUILD_DIR/tmp"
mkdir -p "$BUILD_DIR/run"; mount -t tmpfs run "$BUILD_DIR/run"
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
mkdir -p "$BUILD_DIR/dev"; mount --bind /dev "$BUILD_DIR/dev"
mkdir -p "$BUILD_DIR/tmp/skel"; mount --bind "${0%/*}/skel" "$BUILD_DIR/tmp/skel"

DEVICE_LINE="$(blkid "$PART")"
DEVICE_LINE="$(printf "%s\n" "$DEVICE_LINE" \
  | sed 's/^.*[[:blank:]]UUID="\([^"]\{1,\}\).*[[:blank:]]TYPE="\([^"]\{1,\}\)".*$/UUID=\1 \/ \2 defaults 0 1/')"

ETHERNET="$(ip link show)"
ETHERNET="$(printf "%s\n" "$ETHERNET" \
  | sed -n 's/^[[:digit:]]*: \([[:alnum:]]*\):.*$/\1/p' | grep -v 'lo')"

mkdir -p "$BUILD_DIR/etc/netplan"
cat > "$BUILD_DIR/etc/netplan/01-netcfg.yaml" << _EOF
network:
  ethernets:
    ${ETHERNET}:
      dhcp4: true
  version: 2
_EOF

cat > "$BUILD_DIR/etc/fstab" << _EOF
${DEVICE_LINE} defaults 0 1
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
deb http://archive.ubuntu.com/ubuntu/ ${CODENAME} main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ ${CODENAME}-updates main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ ${CODENAME}-backports main restricted universe multiverse
deb http://security.ubuntu.com/ubuntu ${CODENAME}-security main restricted universe multiverse
# deb http://archive.canonical.com/ubuntu ${CODENAME} partner
_EOF

LC_ALL=C chroot "$BUILD_DIR" /bin/sh -c "#!/bin/sh
set -e
set -x
apt-get update -y
apt-get dist-upgrade -y
test -n '$PKGS_TO_INSTALL' && apt-get install -y $PKGS_TO_INSTALL
test -n '$PKGS_TO_PURGE' && apt-get purge -y $PKGS_TO_PURGE
apt-get autoremove --purge -y
apt-get clean -y
sed 's/^\(GRUB_CMDLINE_LINUX_DEFAULT\)=\".*\"$/#&\\
\1=\"\"/' /etc/default/grub > /tmp/grub_file
cp /tmp/grub_file /etc/default/grub
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
_HEREDOC"
