# Arch + Hyprland setup notes (resume-from-scratch reference)

Generated after a long session porting a Kali i3 "rice" to Hyprland/Wayland.
This replaces the old `~/Arch` git repo (deleted — history was a messy
Hyprland→Sway→Hyprland migration, not worth preserving). If reinstalling
from scratch, this doc plus a fresh `pacman -S` of the list below should
get back to the current working state.

## 1. Full package list (explicit installs)

```
alacritty
base
base-devel
brightnessctl
calibre
chafa
cliphist
cryptsetup
dunst
efibootmgr
fd
fzf
git
grim
grub
hypridle
hyprland
hyprpaper
jq
linux
linux-firmware
mpv
nano
neovim
networkmanager
noto-fonts-cjk
openssh
openvpn
pipewire
pipewire-pulse
python
python-pipx
ripgrep
rofi              # this is rofi-wayland, which provides the `rofi` package name
slurp
sudo
tlp
tmux
ttf-jetbrains-mono
ttf-nerd-fonts-symbols-common
ttf-nerd-fonts-symbols-mono
ueberzugpp
ufw
unzip
waterfox-bin
waybar
wget
wireplumber
wl-clipboard
yay
yay-debug
yazi
```

Install with: `sudo pacman -S <space-separated list above>`

Note: `rofi-wayland` is the actual package to install by name (it replaces/
provides `rofi`) — installing plain `rofi` will conflict.

### Font setup (not just a package install)
We deliberately do NOT use `ttf-jetbrains-mono-nerd` (232 MiB — huge because
it bakes icon glyphs into every weight). Instead: `ttf-jetbrains-mono` (plain
text font) + `ttf-nerd-fonts-symbols-mono`/`-common` (icon glyphs only, ~2.5MB)
via a fontconfig fallback rule:

```
sudo ln -sf /usr/share/fontconfig/conf.avail/10-nerd-font-symbols.conf /etc/fonts/conf.d/
fc-cache -f
```

This makes any app fall back to the symbols font automatically for icon
glyphs it doesn't have. Confirmed working in Alacritty, waybar, rofi, dunst.
Family names to reference in configs: `JetBrains Mono` (text), `Symbols Nerd
Font Mono` (icons, auto-applied via the fallback rule — don't need to name it
explicitly in configs unless troubleshooting).

## 2. Services to enable

```
sudo systemctl enable --now tlp
sudo systemctl enable --now ufw
sudo systemctl enable --now NetworkManager
sudo systemctl enable --now systemd-timesyncd
```

`ufw` config: default deny incoming, allow outgoing (`sudo ufw enable`,
defaults are already correct out of the box, no custom rules added).

`sshd` is intentionally NOT enabled (openssh installed is just the client).

## 3. System settings

- **Timezone**: `sudo timedatectl set-timezone America/New_York && sudo timedatectl set-ntp true`
- **Shell prompt** (`~/.bashrc`): changed `PS1='[\u@\h \W]\$ '` → `PS1='\u\$ '`
  (just username, no hostname/path)
- **Alacritty launcher rename**: created `~/.local/share/applications/Alacritty.desktop`
  (user-level override, don't edit the system one) with `Name=Terminal` instead
  of `Name=Alacritty` so it shows as "Terminal" in rofi.
- **LRF viewer hidden**: `sudo rm /usr/share/applications/calibre-lrfviewer.desktop`
  (it's bundled inside the `calibre` package, not separately removable —
  this just hides the launcher entry, the binary still exists on disk).

## 4. Config files (full content)

All of these live under `~/.config/` directly now (real files/folders, no
longer symlinked from a git repo).

### `~/.config/hypr/hyprland.lua`
```lua
-- Migrated from hyprland.conf (hyprlang syntax deprecated since 0.55,
-- removed in 0.57). See https://wiki.hypr.land/Configuring/Start/

local mod = "SUPER"

------------------
---- MONITORS ----
------------------

hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "auto",
})

-----------------------
---- LOOK AND FEEL ----
-----------------------

-- Colors ported from the Kali i3 rice's wal vars
-- wal-bg #110915  wal-fg #c3c1c4  wal-orange #A37E56  wal-urgent #63514C
hl.config({
    general = {
        gaps_in     = 8,
        gaps_out    = 8,
        border_size = 2,

        col = {
            active_border   = "rgb(A37E56)",
            inactive_border = "rgb(110915)",
        },

        layout = "dwindle",
    },

    decoration = {
        rounding         = 12,
        active_opacity   = 1.0,
        inactive_opacity = 1.0,

        blur = {
            enabled = false,
        },
    },

    -- Splash text/logo disabled (also set via hyprpaper.conf's `splash = false`,
    -- which is where the joke quote actually gets drawn from)
    misc = {
        disable_hyprland_logo    = true,
        disable_splash_rendering = true,
    },
})

-- Plain numeric workspaces (1-10), each given a persistent display name via
-- default_name -- NOT named ("name:xxx") workspaces. Named workspaces get
-- arbitrary negative internal IDs assigned in creation order, which breaks
-- the slide-animation direction (it compares actual IDs): switching "1"->"2"
-- could slide backwards if "2" happened to get a more-negative ID than "1".
-- Plain numeric IDs keep proper ascending order so the animation direction
-- always matches the visible number.
hl.workspace_rule({ workspace = "1",  default_name = "WEB" })
hl.workspace_rule({ workspace = "2",  default_name = "TERM" })
hl.workspace_rule({ workspace = "3",  default_name = "CODE" })
hl.workspace_rule({ workspace = "4",  default_name = "NET" })
hl.workspace_rule({ workspace = "5",  default_name = "TOOLS" })
hl.workspace_rule({ workspace = "6",  default_name = "FILES" })
hl.workspace_rule({ workspace = "7",  default_name = "NOTES" })
hl.workspace_rule({ workspace = "8",  default_name = "CHAT" })
hl.workspace_rule({ workspace = "9",  default_name = "MEDIA" })
hl.workspace_rule({ workspace = "10", default_name = "MON" })

-- Note: i3-gaps' "inner" gap applies to screen edges too (only "outer" is
-- purely additive on top), so i3's inner:10/outer:0 still shows a 10px edge
-- gap around a lone window. Hyprland's gaps_in/gaps_out split the same idea
-- differently: gaps_in is ONLY between adjacent windows and never touches
-- the screen edge, gaps_out is what controls edge spacing -- so matching
-- the i3 config's literal outer:0 value here would show no edge gap at all.
-- gaps_out = 8 (above, in general) is what actually reproduces the i3
-- rice's visual result. i3's "smart_gaps on" (zeroes outer for one window)
-- has no Hyprland equivalent needed here since we're not aiming to remove
-- that edge gap for single windows in the first place.

hl.config({
    input = {
        follow_mouse = 1,
    },
})

-- dwindle already auto-splits by window aspect ratio, same effect as the
-- i3 config's `exec_always autotiling`
hl.config({
    dwindle = {
        preserve_split = true,
    },
})

-------------------
---- AUTOSTART ----
-------------------

hl.on("hyprland.start", function()
    hl.exec_cmd("hyprpaper")
    hl.exec_cmd("waybar")
    hl.exec_cmd("dunst")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("nm-applet")
    hl.exec_cmd("blueman-applet")
    hl.exec_cmd("copyq")
end)

-- Matrix idle window's own startup_mode = "Fullscreen" in matrix-idle.toml
-- requests real fullscreen directly from the client -- no Hyprland-side
-- window rule needed (and windowrulev2 is deprecated in this build anyway).

---------------------
---- KEYBINDINGS ----
---------------------

-- Workspaces — plain numeric IDs (see default_name rules above for the
-- exact i3-matching "N: LABEL" display names/symbols)
hl.bind(mod .. " + 1", hl.dsp.focus({ workspace = 1 }))
hl.bind(mod .. " + 2", hl.dsp.focus({ workspace = 2 }))
hl.bind(mod .. " + 3", hl.dsp.focus({ workspace = 3 }))
hl.bind(mod .. " + 4", hl.dsp.focus({ workspace = 4 }))
hl.bind(mod .. " + 5", hl.dsp.focus({ workspace = 5 }))
hl.bind(mod .. " + 6", hl.dsp.focus({ workspace = 6 }))
hl.bind(mod .. " + 7", hl.dsp.focus({ workspace = 7 }))
hl.bind(mod .. " + 8", hl.dsp.focus({ workspace = 8 }))
hl.bind(mod .. " + 9", hl.dsp.focus({ workspace = 9 }))
hl.bind(mod .. " + 0", hl.dsp.focus({ workspace = 10 }))

hl.bind(mod .. " + SHIFT + 1", hl.dsp.window.move({ workspace = 1 }))
hl.bind(mod .. " + SHIFT + 2", hl.dsp.window.move({ workspace = 2 }))
hl.bind(mod .. " + SHIFT + 3", hl.dsp.window.move({ workspace = 3 }))
hl.bind(mod .. " + SHIFT + 4", hl.dsp.window.move({ workspace = 4 }))
hl.bind(mod .. " + SHIFT + 5", hl.dsp.window.move({ workspace = 5 }))
hl.bind(mod .. " + SHIFT + 6", hl.dsp.window.move({ workspace = 6 }))
hl.bind(mod .. " + SHIFT + 7", hl.dsp.window.move({ workspace = 7 }))
hl.bind(mod .. " + SHIFT + 8", hl.dsp.window.move({ workspace = 8 }))
hl.bind(mod .. " + SHIFT + 9", hl.dsp.window.move({ workspace = 9 }))
hl.bind(mod .. " + SHIFT + 0", hl.dsp.window.move({ workspace = 10 }))

-- Launch / windows
hl.bind(mod .. " + RETURN",       hl.dsp.exec_cmd("alacritty"))
hl.bind(mod .. " + Q",            hl.dsp.window.close())
hl.bind(mod .. " + D",            hl.dsp.exec_cmd("rofi -show drun"))
hl.bind(mod .. " + F",            hl.dsp.window.fullscreen({}))
hl.bind(mod .. " + SHIFT + SPACE", hl.dsp.window.float({}))
hl.bind(mod .. " + SPACE",        hl.dsp.window.float({}))
-- i3's `layout stacking/tabbed/toggle split` -> closest Hyprland analogue is grouping
hl.bind(mod .. " + S", hl.dsp.group.toggle())
hl.bind(mod .. " + W", hl.dsp.group.lock_active({ action = "toggle" }))
hl.bind(mod .. " + E", hl.dsp.group.next())

-- Focus (i3's unusual j=left k=down l=up ;=right mapping, kept as-is)
hl.bind(mod .. " + J",         hl.dsp.focus({ direction = "l" }))
hl.bind(mod .. " + K",         hl.dsp.focus({ direction = "d" }))
hl.bind(mod .. " + L",         hl.dsp.focus({ direction = "u" }))
hl.bind(mod .. " + semicolon", hl.dsp.focus({ direction = "r" }))
hl.bind(mod .. " + Left",      hl.dsp.focus({ direction = "l" }))
hl.bind(mod .. " + Down",      hl.dsp.focus({ direction = "d" }))
hl.bind(mod .. " + Up",        hl.dsp.focus({ direction = "u" }))
hl.bind(mod .. " + Right",     hl.dsp.focus({ direction = "r" }))

-- Move focused window
hl.bind(mod .. " + SHIFT + J",         hl.dsp.window.move({ direction = "l" }))
hl.bind(mod .. " + SHIFT + K",         hl.dsp.window.move({ direction = "d" }))
hl.bind(mod .. " + SHIFT + L",         hl.dsp.window.move({ direction = "u" }))
hl.bind(mod .. " + SHIFT + semicolon", hl.dsp.window.move({ direction = "r" }))
hl.bind(mod .. " + SHIFT + Left",      hl.dsp.window.move({ direction = "l" }))
hl.bind(mod .. " + SHIFT + Down",      hl.dsp.window.move({ direction = "d" }))
hl.bind(mod .. " + SHIFT + Up",        hl.dsp.window.move({ direction = "u" }))
hl.bind(mod .. " + SHIFT + Right",     hl.dsp.window.move({ direction = "r" }))

-- Reload / exit (Hyprland has no i3-style "restart in place"; SHIFT+C just re-sources the config)
hl.bind(mod .. " + SHIFT + C", hl.dsp.exec_cmd("hyprctl reload"))
hl.bind(mod .. " + SHIFT + E", hl.dsp.exit())

-- Resize mode (i3's `mode "resize"`)
hl.bind(mod .. " + R", hl.dsp.submap("resize"))
hl.define_submap("resize", function()
    hl.bind("left",  hl.dsp.window.resize({ x = -10, y = 0,   relative = true }), { repeating = true })
    hl.bind("down",  hl.dsp.window.resize({ x = 0,   y = 10,  relative = true }), { repeating = true })
    hl.bind("up",    hl.dsp.window.resize({ x = 0,   y = -10, relative = true }), { repeating = true })
    hl.bind("right", hl.dsp.window.resize({ x = 10,  y = 0,   relative = true }), { repeating = true })
    hl.bind("return", hl.dsp.submap("reset"))
    hl.bind("escape", hl.dsp.submap("reset"))
    hl.bind(mod .. " + R", hl.dsp.submap("reset"))
end)

-- Matrix idle screensaver
hl.bind(mod .. " + SHIFT + M", hl.dsp.exec_cmd("~/.local/bin/matrix-idle.sh"))

-- Volume/mic/brightness OSD, backed by osd.sh
hl.bind("XF86AudioRaiseVolume",   hl.dsp.exec_cmd("~/.local/bin/osd.sh volume-up"),       { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume",   hl.dsp.exec_cmd("~/.local/bin/osd.sh volume-down"),     { locked = true, repeating = true })
hl.bind("XF86AudioMute",          hl.dsp.exec_cmd("~/.local/bin/osd.sh volume-mute"),     { locked = true, repeating = true })
hl.bind("XF86AudioMicMute",       hl.dsp.exec_cmd("~/.local/bin/osd.sh mic-mute"),        { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp",    hl.dsp.exec_cmd("~/.local/bin/osd.sh brightness-up"),   { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown",  hl.dsp.exec_cmd("~/.local/bin/osd.sh brightness-down"), { locked = true, repeating = true })

-- Screenshots (maim+xclip -> grim+slurp+wl-clipboard), same keys as i3
hl.bind("Print",       hl.dsp.exec_cmd('grim -g "$(slurp)" - | wl-copy -t image/png'))
hl.bind(mod .. " + Print", hl.dsp.exec_cmd('grim ~/Pictures/screenshot-$(date +%Y%m%d-%H%M%S).png'))

-- Clipboard history (same tool as the i3 rice: CopyQ, native GUI with image
-- thumbnails -- no cliphist/rofi scripting needed)
hl.bind(mod .. " + P", hl.dsp.exec_cmd("copyq show"))

-- Scratchpad -> Hyprland's named special workspace
hl.bind(mod .. " + SHIFT + minus", hl.dsp.window.move({ workspace = "special:scratchpad" }))
hl.bind(mod .. " + minus",         hl.dsp.workspace.toggle_special("scratchpad"))

hl.config({
    cursor = {
        inactive_timeout = 3,
    },
})

-- i3 has no window-open/close animations at all, and the default "pop in
-- from small" one is what made the matrix screensaver look like it was
-- growing out of a small terminal. Disabled globally to match i3 -- the
-- workspace slide animation (not asked about) is left as-is.
hl.animation({ leaf = "windows", enabled = false })
```

### `~/.config/hypr/hypridle.conf`
```
general {
    lock_cmd = pidof hyprlock || hyprlock
    before_sleep_cmd = loginctl lock-session
    after_sleep_cmd = ~/.local/bin/idle-guard.sh screen-on
}

# 5 min idle -> matrix screensaver, 10 min -> suspend. idle-guard.sh gates
# each stage on fullscreen/audio (skip if watching a video or music playing).
listener {
    timeout = 300
    on-timeout = ~/.local/bin/idle-guard.sh matrix
    on-resume = ~/.local/bin/idle-guard.sh dismiss
}

listener {
    timeout = 600
    on-timeout = ~/.local/bin/idle-guard.sh suspend
}
```

NOTE: `lock_cmd` references `hyprlock`, which is **not installed**. Idle
suspend works, but the screen won't actually lock. See "known gaps" below.

### `~/.config/hypr/hyprpaper.conf`
```
wallpaper {
    monitor = eDP-1
    path = /home/Raze/Pictures/wallpapers/mimikyu.jpg
    fit_mode = fill
}
```
Note: this Hyprland/hyprpaper build uses a newer config schema than most
online docs show — no `preload`/`wallpaper = monitor,path` lines, it's a
`wallpaper { }` block. `fit_mode = fill` = true non-uniform stretch (not
just aspect-preserving cover).

### `~/.local/bin/matrix-idle.sh`
```bash
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
```
IMPORTANT bug history: the dismiss listener MUST use `on-resume`, not
`on-timeout` — using `on-timeout` fires after 1s of continued idle
regardless of actual input, killing the screensaver almost instantly.
`unimatrix` itself comes from `pipx install unimatrix` (symlinked into
`~/.local/bin/unimatrix` by pipx automatically).

### `~/.local/bin/idle-guard.sh`
```bash
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
```
(The `screen-off` case is now unused by hypridle.conf's simplified 2-stage
schedule, but left in the script in case a screen-off-only stage is wanted
again later.)

### `~/.local/bin/osd.sh`
```bash
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
```
All three scripts need `chmod +x`.

### `~/.config/alacritty/alacritty.toml`
```toml
[window]
opacity = 0.75
padding = { x = 10, y = 10 }

[font]
normal = { family = "JetBrains Mono", style = "Regular" }
bold = { family = "JetBrains Mono", style = "Bold" }
italic = { family = "JetBrains Mono", style = "Italic" }
bold_italic = { family = "JetBrains Mono", style = "Bold Italic" }
size = 11.0

[[keyboard.bindings]]
key = "Return"
mods = "Shift"
chars = "\r"
```
Watch out: that last `chars` line is fragile to how it's typed/pasted —
it must be the literal 8 characters `\`, `u`, `0`, `0`, `1`, `B`, `\`, `r`
(TOML unicode+control escapes), NOT an actual raw ESC byte pasted in.

### `~/.config/alacritty/matrix-idle.toml`
```toml
[colors.primary]
background = "#000000"

[colors.normal]
magenta = "#9b30ff"

[colors.bright]
magenta = "#b266ff"

[window]
startup_mode = "Fullscreen"
decorations = "None"
```

### `~/.config/waybar/config`
Key structural changes from the stock waybar example config (which
defaults to Sway module names and doesn't work under Hyprland at all):
- `"layer": "top"`, `"position": "top"` (was commented out)
- `modules-left`: `["hyprland/workspaces", "hyprland/submap", "custom/media"]`
  (was `sway/workspaces`, `sway/mode`, `sway/scratchpad`)
- `modules-center`: `["hyprland/window"]` (was `sway/window`)
- `modules-right`: unchanged from stock except `sway/language` was left in
  (harmless — auto-disables under Hyprland) and `mpd`/`battery#bat2`/
  `custom/power` are dead/non-functional (see "known gaps")
- `"hyprland/workspaces"` config block:
```json
"hyprland/workspaces": {
    "format": "{icon} {name}",
    "format-icons": {
        "active:WEB": "", "WEB": "",
        "active:TERM": "", "TERM": "",
        "active:CODE": "", "CODE": "",
        "active:NET": "", "NET": "",
        "active:TOOLS": "", "TOOLS": "",
        "active:FILES": "", "FILES": "",
        "active:NOTES": "", "NOTES": "",
        "active:CHAT": "", "CHAT": "",
        "active:MEDIA": "", "MEDIA": "",
        "active:MON": "", "MON": ""
    }
},
"hyprland/submap": {
    "format": "<span style=\"italic\">{}</span>"
},
```
These exact icon codepoints were reverse-engineered from the real i3 rice's
`$ws1.."$ws10` strings (they're invisible on a plain text read — confirmed
via Python `repr()` on the raw file bytes). IMPORTANT: waybar's icon lookup
checks `active:<name>` BEFORE plain `<name>` — you need BOTH keys per
workspace or the icon won't show while that workspace is focused.

### `~/.config/waybar/style.css`
Two changes from stock:
```css
* {
    font-family: "JetBrains Mono", sans-serif;   /* was FontAwesome (not installed) */
    font-size: 13px;
}
```
```css
#workspaces button.focused, #workspaces button.active {
    background-color: #A37E56; /* wal-orange, matches the window border color */
    box-shadow: inset 0 -3px #A37E56;
}
```
(was `background-color: #64727D; box-shadow: inset 0 -3px #ffffff;`)
Everything else in style.css is untouched stock waybar defaults.

### `~/.config/rofi/config.rasi`
```
configuration {
    modi: "drun,run,window";
    show-icons: true;
    icon-theme: "Flat-Remix-Purple-Dark";
    display-drun: "Apps";
    drun-display-format: "{name}";
    location: 0;
    yoffset: 0;
    xoffset: 0;
    width: 25%;
    lines: 8;
    font: "JetBrains Mono 12";
    matching: "fuzzy";
    sort: true;
    sorting-method: "fzf";
}
@theme "/usr/share/rofi/themes/Arc-Dark.rasi"
@import "~/.config/rofi/colors-wal.rasi"
inputbar {
    children: [ prompt, textbox-prompt-colon, entry ];
}
scrollbar {
    handle-rounded-corners: true;
}
```

### `~/.config/rofi/colors-wal.rasi`
```
/* generated by hardcoded wal-colors script — do not edit by hand */
* {
    wal-background: #110915FF;
    wal-foreground: #c3c1c4FF;
    wal-accent:     #A37E56FF;
    background-color: @wal-background;
    border-color:     @wal-accent;
    selected-normal-background: @wal-accent;
    selected-normal-foreground: @wal-background;
}
window {
    background-color: @wal-background;
    border-color: @wal-accent;
    border: 2px;
    border-radius: 12px;
}
element selected {
    background-color: @wal-accent;
    text-color: @wal-background;
}
```
Note: `icon-theme: "Flat-Remix-Purple-Dark"` isn't installed — rofi falls
back gracefully, just cosmetic (see "known gaps").

### `~/.config/dunst/dunstrc`
Base file is 100% stock dunst default config EXCEPT these specific lines
(diff against `/etc/dunst/dunstrc`):
```
progress_bar_corner_radius = 8      (was 0)
icon_corner_radius = 8              (was 0)
frame_color = "#A37E56"             (was "#aaaaaa")
font = JetBrains Mono 11            (was "Monospace 8")
icon_theme = "Flat-Remix-Purple-Dark"  (was Adwaita — not installed, falls back)
min_icon_size = 24                  (was 32)
max_icon_size = 48                  (was 128)
corner_radius = 10                  (was 0)

# [urgency_low]
background = "#110915"  foreground = "#c3c1c4"  timeout = 3
# [urgency_normal]
background = "#110915"  foreground = "#c3c1c4"  timeout = 3
# [urgency_critical]
background = "#110915"  foreground = "#c3c1c4"  frame_color = "#63514C"
```
Easiest to regenerate: copy `/etc/dunst/dunstrc` then apply the 8 line
changes above by hand (it's a huge file, not worth pasting in full here).

### `~/.bashrc`
Only change: `PS1='[\u@\h \W]\$ '` → `PS1='\u\$ '`

## 5. Wallpaper
`/home/Raze/Pictures/wallpapers/mimikyu.jpg` — keep this file, referenced
directly by `hyprpaper.conf`.

## 6. Known gaps / deliberately not installed

- **`hyprlock`** — `hypridle.conf`'s `lock_cmd` references it but it's not
  installed, so idle/manual lock currently does nothing (suspend still
  works fine, screen just won't be password-locked). Recommended, never
  actioned — user said "need to think about it."
- **`slurp`** was a gap, now fixed (installed) — region-select screenshots work.
- **File manager**: none installed. Landed on `yazi` (not `nnn` — user had
  heard `nnn`'s UX is rough, and confirmed `yazi` on its own merits: async/fast,
  built-in image preview, sensible defaults). Needs `ueberzugpp` too (see below).
- **`Flat-Remix-Purple-Dark` icon theme**: referenced by both dunstrc and
  rofi config.rasi, not installed. Falls back to default icons, cosmetic
  gap only, never fixed.
- **`copyq`**: deliberately dropped, replaced by `cliphist` (Wayland-native,
  lighter). Same keybind (`$mod+P`) repurposed for it.
- **VPN**: only `openvpn` installed (client). No `.ovpn` config file
  provided yet — nothing to connect to until the user has one.
- **VS Code / GUI code editor**: discussed, not yet installed. Only
  `neovim` is currently available for editing.
- **pavucontrol**: waybar's volume module has an `on-click` wired to it,
  but it's not installed — dead click currently.
- **power_menu.xml**: waybar's stock `custom/power` module references this
  file for a shutdown/reboot/suspend menu; it doesn't exist, so the power
  button in the bar does nothing. Never built.

## 7. Yazi setup specifics
- Installed with: `chafa`, `fd`, `ripgrep` as companions (image preview,
  fast search).
- **Critical**: image preview additionally needs `ueberzugpp` (separate
  package, not a yazi dependency that auto-pulls in) — without it, yazi
  silently shows a blank preview pane with zero error message. This was a
  real bug hunt this session; `ya env` (run inside a real terminal) is the
  diagnostic command that reveals the picked adapter under `Adapter
  Drivers.matches` and whether its backing tool (chafa/ueberzugpp/etc.) is
  actually present under "Dependencies".
- No custom yazi config was created (`~/.config/yazi/` doesn't exist) —
  running on pure defaults, which work fine once `ueberzugpp` is present.

## 8. Misc facts worth remembering
- This Hyprland build is notably newer/different from most online docs/
  examples: `windowrulev2` is deprecated with no working non-deprecated
  `.conf` equivalent (paints a permanent on-screen error banner if used at
  all) — avoid it entirely, use plain `windowrule` instead where a rule is
  truly needed, or global `general{}`/`animations{}` settings.
- `hyprpaper`'s config format is the newer block-based `wallpaper { }`
  syntax, not the old `preload =` / `wallpaper = monitor,path` one-liners
  most tutorials show.
- Named Hyprland workspaces (`workspace, name:xxx`) get unpredictable
  negative internal IDs — always prefer plain numeric workspace IDs +
  `defaultName` config rules if you want animation direction / ordering to
  behave sanely.
- `renameworkspace` (hyprctl dispatch) and `ya env` were the two most
  useful diagnostic commands discovered this session.
