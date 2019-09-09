if test "$(tty)" = /dev/tty1; then
  if ! ps -U "$(id -u)" -o tty,comm | grep -qE '^tty1[[:blank:]]+i3$'; then
    exec startx
  fi
fi
