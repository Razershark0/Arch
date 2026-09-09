#!/bin/bash
# Matrix idle screen: fullscreen unimatrix rain over a dedicated alacritty
# window, wallpaper visible through it via the 0.65 opacity set below.
#
# Cursor hiding and dismiss-on-activity are both handled outside this script
# now (Hyprland's cursor:inactive_timeout + hypridle's on-resume), replacing
# the old X11-only hidecursor/xdotool/xprintidle polling loop entirely.

alacritty --class matrix-idle \
  --config-file ~/.config/alacritty/matrix-idle.toml \
  -o 'window.opacity=0.65' \
  -e unimatrix -c magenta -n -s 92 -i &

echo $! > /tmp/matrix-idle.pid
