#!/bin/bash
# Matrix idle screen, ported 1:1 from the Kali i3 rice: unimatrix rain
# inside a fullscreen alacritty window at 65% opacity (matches the rice's
# `-o 'window.opacity=0.65'`), so the wallpaper shows through behind the
# rain instead of solid black.
#
# Dismissal is handled externally now, by Serpantinum's own idle system
# (Quickshell's native Wayland idle-notify binding) calling this script's
# resume action to kill the PID in $PIDFILE the moment real activity is
# detected -- keypress also makes unimatrix exit on its own as a backup.
# No external idle daemon (hypridle/swayidle) is needed for this anymore.
#
# Guarded against a second instance stacking on top.

PIDFILE=/tmp/matrix-idle.pid
[ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE" 2>/dev/null)" 2>/dev/null && exit 0

alacritty --class matrix-idle \
  --config-file "$HOME/.config/alacritty/matrix-idle.toml" \
  -o 'window.opacity=0.65' \
  -e "$HOME/.local/bin/unimatrix" -c magenta -n -s 92 &
PID=$!
echo "$PID" > "$PIDFILE"

trap 'rm -f "$PIDFILE"' EXIT
wait "$PID"
