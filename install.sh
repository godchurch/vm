#!/bin/sh

set -ex
EFFECTIVE_USER_ID="$(id -u)"
test "$EFFECTIVE_USER_ID" -eq 0

MOUNT="${1%/}"; test -n "$MOUNT"

DEFAULT_USERNAME="user"
USERS_HOME="$MOUNT/home/$DEFAULT_USERNAME"
LOGIN_SCRIPT="$USERS_HOME/.local/bin/customlogin"
SYSTEMD_SERVICE_DIR="/etc/systemd/system/getty@tty1.service.d"
AUTOLOGIN_SERVICE="$SYSTEMD_SERVICE_DIR/autologin.conf"
PKGS_TO_INSTALL="alsa-utils pulseaudio libavcodec-extra unzip curl xorg i3 xterm mpv firefox"
PKGS_TO_PURGE=""

mountpoint -q "$MOUNT";
test -d "$MOUNT/proc" || mkdir "$MOUNT/proc"; mount -t proc proc "$MOUNT/proc"
test -d "$MOUNT/sys" || mkdir "$MOUNT/sys"; mount -t sysfs sysfs "$MOUNT/sys"
test -d "$MOUNT/tmp" || mkdir "$MOUNT/tmp"; mount -t tmpfs tmpfs "$MOUNT/tmp"
if test -e "$MOUNT/etc/resolv.conf" || test -L "$MOUNT/etc/resolv.conf"; then
  RESOLV_CONF="$MOUNT/etc/resolv.conf"
  test -d "$MOUNT/run" || mkdir "$MOUNT/run"; mount -t tmpfs run "$MOUNT/run"
  printf "%s\n" "nameserver 1.1.1.1" > "$MOUNT/run/default-resolv.conf"
  if test -L "$RESOLV_CONF"; then
    RESOLV_CONF="$(readlink "$RESOLV_CONF")"
    case "$RESOLV_CONF" in
      /*) RESOLV_CONF="${TARGET}${RESOLV_CONF}" ;;
      *) RESOLV_CONF="$MOUNT/etc/$RESOLV_CONF" ;;
    esac
    test -f "$RESOLV_CONF" || install -Dm644 /dev/null "$RESOLV_CONF"
  fi
  mount --bind "$MOUNT/run/default-resolv.conf" "$RESOLV_CONF"
fi
test -d "$MOUNT/dev" || mkdir "$MOUNT/dev"; mount --bind /dev "$MOUNT/dev"
test -d "$MOUNT/tmp/skel" || mkdir "$MOUNT/tmp/skel"; mount --bind "${0%/*}/skel" "$MOUNT/tmp/skel"

LC_ALL=C chroot "$MOUNT" /bin/sh -c "
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
useradd -m -k /tmp/skel -d '$USERS_HOME' -s '$LOGIN_SCRIPT' '$DEFAULT_USERNAME'
passwd '$DEFAULT_USERNAME' << _HEREDOC
$DEFAULT_USERNAME
$DEFAULT_USERNAME
_HEREDOC
cp -R /etc/skel '$USERS_HOME'
"

LC_ALL=C chroot "$MOUNT" apt-get update -y
LC_ALL=C chroot "$MOUNT" apt-get dist-upgrade -y
test -n "$PKGS_TO_INSTALL" && LC_ALL=C chroot "$MOUNT" apt-get install -y --no-install-recommends $PKGS_TO_INSTALL
test -n "$PKGS_TO_PURGE" && LC_ALL=C chroot "$MOUNT" apt-get purge -y $PKGS_TO_PURGE
LC_ALL=C chroot "$MOUNT" apt-get autoremove --purge -y
LC_ALL=C chroot "$MOUNT" apt-get clean -y
