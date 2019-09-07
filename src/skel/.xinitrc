#!/bin/sh

if test -x /usr/bin/VBoxClient; then
  for i in ${HOME}/.vboxclient-*.pid; do test -w "$i" || rm -f "$i" done
  /usr/bin/VBoxClient --clipboard        || true
  /usr/bin/VBoxClient --checkhostversion || true
  /usr/bin/VBoxClient --display          || true
  /usr/bin/VBoxClient --seamless         || true
  /usr/bin/VBoxClient --draganddrop      || true
fi

if test -x /usr/bin/amixer; then
  /usr/bin/amixer set Master unmute
  /usr/bin/amixer set Master 100%
  /usr/bin/amixer set PCM unmute
  /usr/bin/amixer set PCM 100%
fi

test -x /usr/bin/xsetroot && /usr/bin/xsetroot -solid 'DEFAULT_BACKGROUND_COLOR'
test -x /usr/bin/setxkbmap && /usr/bin/setxkbmap -layout us -option caps:escape

exec DEFAULT_WINDOW_MANAGER
