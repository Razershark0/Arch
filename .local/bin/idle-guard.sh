#!/bin/bash
# Central handler for every hypridle idle stage -- the equivalent of the
# Kali rice's `xidlehook --not-when-audio --not-when-fullscreen`. hypridle
# has no such conditions, so the checks below gate each action: skip while
# audio is playing (music with no idle-inhibitor) or a window is fullscreen.
#
#   idle-guard.sh matrix      (5 min)  show the matrix rain
#   idle-guard.sh screen-off  (10 min) kill the rain, power the panel off
#   idle-guard.sh screen-on            power the panel back on   (resume)
#   idle-guard.sh dismiss             kill the rain             (resume)
#   idle-guard.sh suspend     (20 min) systemctl suspend

PIDFILE=/tmp/matrix-idle.pid

audio_playing()     { pactl list short sinks 2>/dev/null | grep -qw RUNNING; }
window_fullscreen() {
    hyprctl activewindow -j 2>/dev/null | jq -e '.fullscreen != 0' >/dev/null 2>&1
}
kill_rain() { [ -f "$PIDFILE" ] && kill "$(cat "$PIDFILE" 2>/dev/null)" 2>/dev/null; rm -f "$PIDFILE"; }

case "${1:-}" in
    matrix)
        audio_playing && exit 0
        window_fullscreen && exit 0
        [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE" 2>/dev/null)" 2>/dev/null && exit 0
        exec "$HOME/.local/bin/matrix-idle.sh"
        ;;
    screen-off)
        # Kill the rain first: the matrix window is itself fullscreen, so the
        # check below must run against whatever is underneath it.
        kill_rain
        sleep 0.3
        window_fullscreen && exit 0
        exec hyprctl dispatch dpms off
        ;;
    screen-on)
        exec hyprctl dispatch dpms on
        ;;
    dismiss)
        kill_rain
        ;;
    suspend)
        audio_playing && exit 0
        window_fullscreen && exit 0
        exec systemctl suspend
        ;;
    *)
        echo "usage: idle-guard.sh {matrix|screen-off|screen-on|dismiss|suspend}" >&2
        exit 1
        ;;
esac
