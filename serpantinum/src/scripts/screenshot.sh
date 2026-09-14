#!/usr/bin/env bash

EDIT_MODE=false
FULL_MODE=false
RECORD_MODE=false
GEOMETRY=""
DESK_VOL="1.0"
DESK_MUTE="false"
MIC_VOL="1.0"
MIC_MUTE="false"
MIC_DEVICE=""
VIDEO_BACKEND="gpu-screen-recorder"
TARGET_MON=""

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --edit) EDIT_MODE=true; shift ;;
        --full) FULL_MODE=true; shift ;;
        --record) RECORD_MODE=true; shift ;;
        --geometry) GEOMETRY="$2"; shift 2 ;;
        --desk-vol) DESK_VOL="$2"; shift 2 ;;
        --desk-mute) DESK_MUTE="$2"; shift 2 ;;
        --mic-vol) MIC_VOL="$2"; shift 2 ;;
        --mic-mute) MIC_MUTE="$2"; shift 2 ;;
        --mic-dev) MIC_DEVICE="$2"; shift 2 ;;
        --backend) VIDEO_BACKEND="$2"; shift 2 ;;
        --monitor) TARGET_MON="$2"; shift 2 ;;
        *) shift ;;
    esac
done

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
source "$SCRIPT_DIR/caching.sh"
source "$SCRIPT_DIR/i18n.sh"
qs_ensure_cache "screenshot"
qs_ensure_cache "recording"

CACHE_DIR="$QS_CACHE_RECORDING"
SAVE_DIR="${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
RECORD_DIR="${XDG_VIDEOS_DIR:-$HOME/Videos}/Recordings"
mkdir -p "$SAVE_DIR" "$RECORD_DIR"

REQUIRED_CMDS=("grim" "satty" "wl-copy" "pactl" "quickshell" "python3")
MISSING_CMDS=()
for cmd in "${REQUIRED_CMDS[@]}"; do
    if ! command -v "$cmd" &> /dev/null; then
        MISSING_CMDS+=("$cmd")
    fi
done

if [ "$RECORD_MODE" = true ]; then
    if ! command -v "$VIDEO_BACKEND" &> /dev/null; then
        MISSING_CMDS+=("$VIDEO_BACKEND")
    fi
fi

if [ ${#MISSING_CMDS[@]} -ne 0 ]; then
    notif_app="$(t "screenshot.notifications.system_app_name")"
    notif_title="$(t "screenshot.notifications.missing_deps_title")"
    notif_body="$(t "screenshot.notifications.missing_deps_body" "cmds=${MISSING_CMDS[*]}")"
    notify-send -u critical -a "$notif_app" "$notif_title" "$notif_body"
    exit 1
fi

if [ -f "$CACHE_DIR/rec_pid" ]; then
    REC_PID=$(cat "$CACHE_DIR/rec_pid" 2>/dev/null)
    FINAL_FILE=$(cat "$CACHE_DIR/final_file" 2>/dev/null)
    
    if [ -n "$REC_PID" ] && kill -0 "$REC_PID" 2>/dev/null; then
        [ -f "$CACHE_DIR/processing.lock" ] && exit 0
        touch "$CACHE_DIR/processing.lock"
        
        kill -SIGINT "$REC_PID" 2>/dev/null
        timeout=30
        while kill -0 "$REC_PID" 2>/dev/null && [ $timeout -gt 0 ]; do
            sleep 0.1
            timeout=$((timeout - 1))
        done
        kill -9 "$REC_PID" 2>/dev/null
        
        if [ -f "$FINAL_FILE" ]; then
            (
                VIDEO_THUMB="$QS_RUN_SCREENSHOT/thumb_$$.png"
                if command -v ffmpeg &> /dev/null; then
                    ffmpeg -ss 00:00:00.500 -i "$FINAL_FILE" -vframes 1 "$VIDEO_THUMB" -y &>/dev/null
                    NOTIF_ICON="$VIDEO_THUMB"
                else
                    NOTIF_ICON=""
                fi
                notif_app="$(t "screenshot.notifications.recorder_app_name")"
                notif_action="$(t "screenshot.notifications.open_folder")"
                notif_title="$(t "screenshot.notifications.recording_saved_title")"
                notif_body="$(t "screenshot.notifications.recording_saved_body" "file=$(basename "$FINAL_FILE")" "folder=$RECORD_DIR")"
                ACTION=$(notify-send -a "$notif_app" -i "$NOTIF_ICON" -h "string:image-path:$NOTIF_ICON" -A "default=$notif_action" "$notif_title" "$notif_body")
                rm -f "$VIDEO_THUMB"
                if [ "$ACTION" = "default" ]; then
                    if command -v nautilus &> /dev/null; then
                        nautilus "$RECORD_DIR"
                    else
                        xdg-open "$RECORD_DIR"
                    fi
                fi
            ) &
        else
            notif_app="$(t "screenshot.notifications.recorder_app_name")"
            notif_title="$(t "screenshot.notifications.recording_error_title")"
            notif_body="$(t "screenshot.notifications.recording_error_body")"
            notify-send -a "$notif_app" "$notif_title" "$notif_body"
        fi
        rm -f "$CACHE_DIR/processing.lock" "$CACHE_DIR/rec_pid" "$CACHE_DIR/final_file" "$CACHE_DIR/rec_start_epoch"
        exit 0
    else
        rm -f "$CACHE_DIR/processing.lock" "$CACHE_DIR/rec_pid" "$CACHE_DIR/final_file" "$CACHE_DIR/rec_start_epoch"
    fi
fi

get_active_monitor() {
    local mon=""
    if command -v hyprctl &>/dev/null; then
        mon=$(hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused == true) | .name' 2>/dev/null)
        if [ -z "$mon" ] || [ "$mon" = "null" ]; then
            mon=$(hyprctl activeworkspace -j 2>/dev/null | jq -r '.monitor // empty' 2>/dev/null)
        fi
    fi
    if [ -z "$mon" ] && command -v niri &>/dev/null; then
        mon=$(niri msg -j focused-output 2>/dev/null | jq -r '.name // empty' 2>/dev/null)
        if [ -z "$mon" ] || [ "$mon" = "null" ]; then
            mon=$(niri msg -j outputs 2>/dev/null | jq -r 'to_entries[]? | select(.value.is_focused == true) | .value.name // .key' 2>/dev/null)
        fi
    fi
    if [ -z "$mon" ] && command -v swaymsg &>/dev/null; then
        mon=$(swaymsg -t get_outputs 2>/dev/null | jq -r '.[] | select(.focused == true) | .name' 2>/dev/null)
    fi
    if [ -z "$mon" ] || [ "$mon" = "null" ]; then
        if [ -f "$SCRIPT_DIR/monitors_detect.sh" ]; then
            mon=$(bash "$SCRIPT_DIR/monitors_detect.sh" 2>/dev/null | head -n 1)
        fi
    fi
    echo "$mon"
}

if [ -z "$TARGET_MON" ]; then
    TARGET_MON=$(get_active_monitor)
fi

if [ "$RECORD_MODE" = false ] && [ "$FULL_MODE" = false ] && [ -z "$GEOMETRY" ]; then
    PREFS="$QS_STATE_SCREENSHOT/audio_prefs"
    if [ -f "$PREFS" ]; then
        IFS=',' read -r QS_DESK_VOL QS_DESK_MUTE QS_MIC_VOL QS_MIC_MUTE QS_MIC_DEV < "$PREFS"
    else
        QS_DESK_VOL="1.0"; QS_DESK_MUTE="false"; QS_MIC_VOL="1.0"; QS_MIC_MUTE="false"; QS_MIC_DEV=""
    fi

    CACHE_FILE="$QS_CACHE_SCREENSHOT/geometry"
    VIDEO_CACHE_FILE="$QS_CACHE_SCREENSHOT/geometry_video"
    MODE_CACHE_FILE="$QS_CACHE_SCREENSHOT/video_mode"
    BACKEND_CACHE_FILE="$QS_CACHE_SCREENSHOT/video_backend"
    [ -f "$CACHE_FILE" ] && QS_CACHED_GEOM=$(cat "$CACHE_FILE") || QS_CACHED_GEOM=""
    [ -f "$VIDEO_CACHE_FILE" ] && QS_CACHED_VIDEO_GEOM=$(cat "$VIDEO_CACHE_FILE") || QS_CACHED_VIDEO_GEOM=""
    [ -f "$MODE_CACHE_FILE" ] && QS_CACHED_MODE=$(cat "$MODE_CACHE_FILE") || QS_CACHED_MODE="false"
    [ -f "$BACKEND_CACHE_FILE" ] && QS_CACHED_BACKEND=$(cat "$BACKEND_CACHE_FILE") || QS_CACHED_BACKEND="gpu-screen-recorder"

    if [ "$EDIT_MODE" = true ]; then
        QS_CACHED_MODE="false"
    fi

    if [ "$QS_CACHED_MODE" = "true" ]; then
        FREEZE_IMG=""
    else
        FREEZE_IMG="$QS_RUN_SCREENSHOT/freeze_$$.png"
        if [ -n "$TARGET_MON" ]; then
            grim -o "$TARGET_MON" -l 0 "$FREEZE_IMG" 2>/dev/null || grim -l 0 "$FREEZE_IMG"
        else
            grim -l 0 "$FREEZE_IMG"
        fi
    fi

    QS_AUDIO_PREFS="${QS_DESK_VOL},${QS_DESK_MUTE},${QS_MIC_VOL},${QS_MIC_MUTE},${QS_MIC_DEV}"

    exec quickshell ${MAIN_QML:+-p "$MAIN_QML"} ipc call screenshotOverlay toggle "$FREEZE_IMG" "$EDIT_MODE" "$QS_AUDIO_PREFS" "$QS_CACHED_GEOM" "$QS_CACHED_VIDEO_GEOM" "$QS_CACHED_MODE" "$QS_CACHED_BACKEND" "$TARGET_MON"
fi

time=$(date +'%Y-%m-%d-%H%M%S')
FILENAME="$SAVE_DIR/Screenshot_$time.png"
VID_FILENAME="$RECORD_DIR/Recording_$time.mp4"

if [ "$FULL_MODE" = true ] || [ -n "$GEOMETRY" ]; then
    if [ "$RECORD_MODE" = true ]; then
        if [ "$VIDEO_BACKEND" = "wf-recorder" ]; then
            WF_ARGS=(-f "$VID_FILENAME")
            if [ -n "$GEOMETRY" ]; then
                WF_ARGS+=(-g "$GEOMETRY")
            elif [ -n "$TARGET_MON" ]; then
                WF_ARGS+=(-o "$TARGET_MON")
            fi
            if [ "$DESK_MUTE" != "true" ]; then
                DESK_SINK=$(pactl get-default-sink 2>/dev/null)
                if [ -n "$DESK_SINK" ]; then
                    WF_ARGS+=(--audio="${DESK_SINK}.monitor")
                else
                    WF_ARGS+=(--audio)
                fi
            elif [ "$MIC_MUTE" != "true" ]; then
                if [ -n "$MIC_DEVICE" ] && [ "$MIC_DEVICE" != "null" ]; then
                    MIC_DEV="$MIC_DEVICE"
                else
                    MIC_DEV=$(pactl get-default-source 2>/dev/null)
                fi
                if [ -n "$MIC_DEV" ]; then
                    WF_ARGS+=(--audio="$MIC_DEV")
                else
                    WF_ARGS+=(--audio)
                fi
            fi
            wf-recorder "${WF_ARGS[@]}" > /dev/null 2>&1 &
            REC_PID=$!
        else
            GSR_ARGS=(-w "${TARGET_MON:-screen}" -c "mp4" -f "60" -ac "aac")
            if [ "$DESK_MUTE" != "true" ]; then
                DESK_SINK=$(pactl get-default-sink 2>/dev/null)
                if [ -n "$DESK_SINK" ]; then
                    GSR_ARGS+=(-a "${DESK_SINK}.monitor")
                else
                    GSR_ARGS+=(-a "default_output")
                fi
            fi
            if [ "$MIC_MUTE" != "true" ]; then
                if [ -n "$MIC_DEVICE" ] && [ "$MIC_DEVICE" != "null" ]; then
                    MIC_DEV="$MIC_DEVICE"
                else
                    MIC_DEV=$(pactl get-default-source 2>/dev/null)
                fi
                if [ -n "$MIC_DEV" ]; then
                    GSR_ARGS+=(-a "$MIC_DEV")
                else
                    GSR_ARGS+=(-a "default_input")
                fi
            fi
            gpu-screen-recorder "${GSR_ARGS[@]}" -o "$VID_FILENAME" > /dev/null 2>&1 &
            REC_PID=$!
        fi
        date +%s > "$CACHE_DIR/rec_start_epoch"
        echo "$VID_FILENAME" > "$CACHE_DIR/final_file"
        echo "$REC_PID" > "$CACHE_DIR/rec_pid"
        notif_app="$(t "screenshot.notifications.recorder_app_name")"
        notif_title="$(t "screenshot.notifications.recording_started_title")"
        notif_body="$(t "screenshot.notifications.recording_started_body")"
        notify-send -a "$notif_app" "$notif_title" "$notif_body"
        exit 0
    fi

    TMP_SCREENSHOT="/tmp/instant_snap_$$.png"
    if [ -n "$GEOMETRY" ]; then
        grim -l 0 -g "$GEOMETRY" "$TMP_SCREENSHOT"
    elif [ -n "$TARGET_MON" ]; then
        grim -o "$TARGET_MON" -l 0 "$TMP_SCREENSHOT" 2>/dev/null || grim -l 0 "$TMP_SCREENSHOT"
    else
        grim -l 0 "$TMP_SCREENSHOT"
    fi

    if [ "$EDIT_MODE" = true ]; then
        GSK_RENDERER=gl satty --filename "$TMP_SCREENSHOT" --output-filename "$FILENAME" --init-tool brush --copy-command "wl-copy --type image/png"
    else
        cp "$TMP_SCREENSHOT" "$FILENAME"
    fi
    rm -f "$TMP_SCREENSHOT"

    if [ -s "$FILENAME" ]; then
        wl-copy --type image/png < "$FILENAME"
        (
            notif_app="$(t "screenshot.notifications.screenshot_app_name")"
            notif_action="$(t "screenshot.notifications.open_folder")"
            notif_title="$(t "screenshot.notifications.screenshot_saved_title")"
            notif_body="$(t "screenshot.notifications.screenshot_saved_body" "file=Screenshot_$time.png" "folder=$SAVE_DIR")"
            ACTION=$(notify-send -a "$notif_app" -i "$FILENAME" -h "string:image-path:$FILENAME" -A "default=$notif_action" "$notif_title" "$notif_body")
            if [ "$ACTION" = "default" ]; then
                if command -v nautilus &> /dev/null; then
                    nautilus "$SAVE_DIR"
                else
                    xdg-open "$SAVE_DIR"
                fi
            fi
        ) &
    fi
    exit 0
fi
