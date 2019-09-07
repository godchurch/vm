#!/bin/sh

if test -x /usr/bin/VBoxClient; then
  for i in ${HOME}/.vboxclient-*.pid; do test -w "$i" || rm -f "$i" done
  /usr/bin/VBoxClient --clipboard        || true
  /usr/bin/VBoxClient --checkhostversion || true
  /usr/bin/VBoxClient --display          || true
  /usr/bin/VBoxClient --seamless         || true
  /usr/bin/VBoxClient --draganddrop      || true
fi

if test -x /usr/bin/pulseaudio; then
  pulseaudio --check || pulseaudio --start

#  SINK="$(pactl info | awk '/^Default Sink:/ { print $3 }')"
#  SOURCE="$(pactl info | awk '/^Default Source:/ { print $3 }')"
#
#  test -n "$SINK" \
#    && pactl suspend-sink "$SINK" 0 \
#    && pactl set-sink-mute "$SINK" 0 \
#    && pactl set-sink-volume "$SINK" 100%
#  test -n "$SOURCE" \
#    && pactl set-source-volume "$SOURCE" 0% \
#    && pactl set-source-mute "$SOURCE" 1 \
#    && pactl suspend-source "$SOURCE" 1
#
#  unset SINK SOURCE
fi

test -x /usr/bin/xsetroot && /usr/bin/xsetroot -solid 'DEFAULT_BACKGROUND_COLOR'
test -x /usr/bin/setxkbmap && /usr/bin/setxkbmap -layout us -option caps:escape

exec DEFAULT_WINDOW_MANAGER
