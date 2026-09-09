#!/usr/bin/env bash
# Volume / mic / brightness OSD for i3, backed by wpctl (PipeWire) and
# brightnessctl. Notifications replace in-place via dunst's stack-tag hint,
# and every percentage shown is clamped to 100.
set -euo pipefail
clamp100() {
    local n="$1"
    (( n > 100 )) && n=100
    (( n < 0 )) && n=0
    echo "$n"
}
sink_pct() {
    wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{n=$2*100; printf "%d", (n>100?100:n)}'
}
sink_muted() { wpctl get-volume @DEFAULT_AUDIO_SINK@ | grep -q MUTED; }
source_muted() { wpctl get-volume @DEFAULT_AUDIO_SOURCE@ | grep -q MUTED; }
notify_bar() {
    local tag="$1" icon="$2" title="$3" value="$4" body="$5"
    notify-send -h string:x-dunst-stack-tag:"$tag" -h int:value:"$value" \
        -i "$icon" -a "osd" "$title" "$body"
}
case "${1:-}" in
    volume-up)
        wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+
        pct=$(sink_pct)
        if sink_muted; then notify_bar volume audio-volume-muted "Volume" 0 "Muted"
        else notify_bar volume audio-volume-high "Volume" "$pct" "${pct}%"; fi ;;
    volume-down)
        wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%-
        pct=$(sink_pct)
        if sink_muted; then notify_bar volume audio-volume-muted "Volume" 0 "Muted"
        else notify_bar volume audio-volume-low "Volume" "$pct" "${pct}%"; fi ;;
    volume-mute)
        wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
        if sink_muted; then notify_bar volume audio-volume-muted "Volume" 0 "Muted"
        else notify_bar volume audio-volume-high "Volume" "$(sink_pct)" "$(sink_pct)%"; fi ;;
    mic-mute)
        wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
        if source_muted; then notify_bar mic microphone-sensitivity-muted-symbolic "Microphone" 0 "Muted"
        else notify_bar mic microphone-sensitivity-high-symbolic "Microphone" 100 "Unmuted"; fi ;;
    brightness-up)
        brightnessctl set +5% -q
        cur=$(brightnessctl get); max=$(brightnessctl max)
        pct=$(clamp100 $(( cur * 100 / max )))
        notify_bar brightness display-brightness-symbolic "Brightness" "$pct" "${pct}%" ;;
    brightness-down)
        brightnessctl set 5%- -q
        cur=$(brightnessctl get); max=$(brightnessctl max)
        pct=$(clamp100 $(( cur * 100 / max )))
        notify_bar brightness display-brightness-symbolic "Brightness" "$pct" "${pct}%" ;;
    *)
        echo "usage: osd.sh {volume-up|volume-down|volume-mute|mic-mute|brightness-up|brightness-down}" >&2
        exit 1 ;;
esac
