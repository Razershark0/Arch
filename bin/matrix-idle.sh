#!/bin/bash
# Matrix idle screen, ported 1:1 from the Kali i3 rice: unimatrix rain
# inside a fullscreen alacritty window at 65% opacity (matches the rice's
# `-o 'window.opacity=0.65'`), so the wallpaper shows through behind the
# rain instead of solid black.
#
# Dismissal is handled externally, by Serpantinum's own idle system
# (Quickshell's native Wayland idle-notify binding) calling this script's
# resume action to kill the PID in $PIDFILE the moment real activity is
# detected. No external idle daemon (hypridle/swayidle) is needed for this.
#
# -i (--ignore-keyboard) disables unimatrix's own keyboard controls, so
# speed/color/etc. can't be changed by a stray keypress -- it stays static
# at -s 92 until the resume action above kills it.
#
# Guarded against a second instance stacking on top.

PIDFILE=/tmp/matrix-idle.pid
[ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE" 2>/dev/null)" 2>/dev/null && exit 0

alacritty --class matrix-idle \
  --config-file "$HOME/.config/alacritty/matrix-idle.toml" \
  -o 'window.opacity=0.65' \
  -e "$HOME/.local/bin/unimatrix" -c magenta -n -s 92 -i &
PID=$!
echo "$PID" > "$PIDFILE"

trap 'rm -f "$PIDFILE"' EXIT
wait "$PID"
