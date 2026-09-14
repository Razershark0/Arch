#!/usr/bin/env bash

if [[ "${BASH_SOURCE[0]}" == */* ]]; then
    SCRIPT_DIR="$(cd -- "${BASH_SOURCE[0]%/*}" 2>/dev/null && pwd -P)"
else
    SCRIPT_DIR="$(pwd -P)"
fi

source "$SCRIPT_DIR/caching.sh" 2>/dev/null || true
source "$SCRIPT_DIR/config.sh" 2>/dev/null || true

ACTION="$1"
TARGET="$2"
SUBTARGET="$3"

send_qs_ipc() {
    if [[ -n "$MAIN_QML" ]]; then
        quickshell -p "$MAIN_QML" ipc call main handleCommand "$@" >/dev/null 2>&1
    else
        quickshell ipc call main handleCommand "$@" >/dev/null 2>&1
    fi
}

if [[ "$ACTION" == "workspace" ]]; then
    if [[ "$2" =~ ^[0-9]+$ ]]; then
        ACTION="$2"; TARGET="$3"; SUBTARGET="$4"
    elif [[ "$3" =~ ^[0-9]+$ ]]; then
        ACTION="$3"; TARGET="$2"; SUBTARGET="$4"
    else
        ACTION="$2"; TARGET="$3"; SUBTARGET="$4"
    fi
fi

if [[ "$ACTION" =~ ^[0-9]+$ ]]; then
    if command -v _config_ensure_settings &>/dev/null; then
        _config_ensure_settings
    fi

    MAX_WORKSPACES=8
    if [[ -n "$CONFIG_SETTINGS_JSON" && -f "$CONFIG_SETTINGS_JSON" ]]; then
        MAX_WORKSPACES="$(jq -r '.bar.workspaceCount // .workspaceCount // 8' "$CONFIG_SETTINGS_JSON" 2>/dev/null)"
        [[ "$MAX_WORKSPACES" =~ ^[0-9]+$ ]] && (( MAX_WORKSPACES >= 1 )) || MAX_WORKSPACES=8
    fi

    (( ACTION < 1 || ACTION > MAX_WORKSPACES )) && exit 0

    if [[ "$TARGET" == "move" ]]; then
        hyprctl dispatch 'hl.dsp.window.move({ workspace = "'"$ACTION"'" })' >/dev/null 2>&1 &
    else
        hyprctl dispatch 'hl.dsp.focus({ workspace = "'"$ACTION"'" })' >/dev/null 2>&1 &
    fi

    send_qs_ipc "close" "" "" &
    exit 0
fi

if [[ "$ACTION" == "close" ]]; then
    send_qs_ipc "close" "" ""
    exit 0
fi

if [[ "$ACTION" == "open" || "$ACTION" == "toggle" ]]; then
    send_qs_ipc "$ACTION" "$TARGET" "$SUBTARGET"
    exit 0
fi
