#!/bin/sh

set -ex
EFFECTIVE_USER_ID="$(id -u)"
test "$EFFECTIVE_USER_ID" -eq 0

MOUNT="${1%/}"
test -n "$MOUNT"

DEFAULT_USERNAME="default_user"
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


SYSTEMD_SERVICE="$MOUNT/etc/systemd/system/getty@tty1.service.d/autologin.conf"
test -d "${SYSTEMD_SERVICE%/*}" || mkdir -p "${SYSTEMD_SERVICE%/*}"
cat > "$SYSTEMD_SERVICE" << _HEREDOC
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $DEFAULT_USERNAME --noclear %I \\\$TERM
_HEREDOC


CUSTOM_LOGIN="$MOUNT/usr/local/bin/customlogin"
test -d "${CUSTOM_LOGIN%/*}" || mkdir -p "${CUSTOM_LOGIN%/*}"
cat > "$CUSTOM_LOGIN" << '_HEREDOC'
#!/bin/sh

test "$(tty)" = /dev/tty1 \
  && ! ps -U "$(id -u)" -o tty,comm | grep -qE '^tty1[[:blank:]]+i3$' \
  && exec startx

exec /bin/bash
_HEREDOC
chmod 755 "$CUSTOM_LOGIN"


mkdir -p "$MOUNT/ram"
cat >> "$MOUNT/etc/fstab" << _HEREDOC
tmpfs /ram tmpfs rw 0 0
_HEREDOC

cp -R skel "$MOUNT/tmp/skel"

_CHROOT() { LC_ALL=C chroot "$MOUNT" "$@"; }
_CHROOT useradd -m -k "tmp/skel" -s "${CUSTOM_LOGIN#$MOUNT} "$DEFAULT_USERNAME"
_CHROOT passwd "$DEFAULT_USERNAME" << _HEREDOC
$DEFAULT_USERNAME
$DEFAULT_USERNAME
_HEREDOC
_CHROOT apt-get update -y
_CHROOT apt-get dist-upgrade -y
test -n "$PKGS_TO_INSTALL" && _CHROOT apt-get install -y --no-install-recommends $PKGS_TO_INSTALL
test -n "$PKGS_TO_PURGE" && _CHROOT apt-get purge -y $PKGS_TO_PURGE
_CHROOT apt-get autoremove --purge -y
_CHROOT apt-get clean -y
