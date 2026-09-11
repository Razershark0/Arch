#!/bin/bash
# Matrix idle screen, ported 1:1 from the Kali i3 rice: unimatrix rain
# inside a fullscreen alacritty window at 65% opacity (matches the rice's
# `-o 'window.opacity=0.65'`), so the wallpaper shows through behind the
# rain instead of solid black. Since the window is real-fullscreen (its own
# startup_mode = "Fullscreen"), it's on top of and covers every other
# window on the workspace, so only the wallpaper -- not other windows --
# can show through the translucency.
#
# Dismissed by ANY input:
#   - keypress -> unimatrix exits on its own (no -i), the window closes
#   - mouse    -> a scoped one-shot hypridle instance below fires on the
#     first activity and kills the window (the i3 rice used a scoped
#     `swayidle -w timeout 1` for the same purpose)
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

DISMISS_CONF=$(mktemp /tmp/matrix-dismiss-XXXX.conf)
cat > "$DISMISS_CONF" <<EOF
listener {
    timeout = 1
    on-resume = kill $PID 2>/dev/null
}
EOF
hypridle -c "$DISMISS_CONF" &
HI=$!

trap 'kill "$PID" "$HI" 2>/dev/null; rm -f "$PIDFILE" "$DISMISS_CONF"' EXIT
wait "$PID"
