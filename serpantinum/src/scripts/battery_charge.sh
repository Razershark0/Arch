#!/usr/bin/env bash
set -euo pipefail

CONF=/etc/tlp.conf
ACTION=${1:-}

set_thresh() {
    local start=$1 stop=$2
    sed -i -E "s/^#?START_CHARGE_THRESH_BAT1=.*/START_CHARGE_THRESH_BAT1=${start}/" "$CONF"
    sed -i -E "s/^#?STOP_CHARGE_THRESH_BAT1=.*/STOP_CHARGE_THRESH_BAT1=${stop}/" "$CONF"
    tlp start >/dev/null
}

case "$ACTION" in
    longevity) set_thresh 75 80 ;;
    balanced) set_thresh 75 90 ;;
    full) set_thresh 0 100 ;;
    chargeonce) tlp chargeonce >/dev/null ;;
    *)
        printf 'Unknown battery_charge action: %s\n' "$ACTION" >&2
        exit 2
        ;;
esac
