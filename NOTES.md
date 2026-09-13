# Arch + Hyprland setup notes (resume-from-scratch reference)

Generated after a long session porting a Kali i3 "rice" to Hyprland/Wayland.
This replaces the old `~/Arch` git repo (deleted — history was a messy
Hyprland→Sway→Hyprland migration, not worth preserving). If reinstalling
from scratch, this doc plus a fresh `pacman -S` of the list below should
get back to the current working state.

## 1. Full package list (explicit installs)

**Updated 2026-09-12** — this section previously documented an aspirational
i3-to-Hyprland migration state (waybar/rofi/dunst/cliphist) that was never
actually installed; the live system instead grew a custom Quickshell-based
bar+launcher+lock ("the pill") which has since been **removed entirely**
after a long debugging session found it duplicated ~19 apps' worth of
functionality in one process at 2-3x the RAM, with real bugs that survived
hours of live debugging. The list below is the actual current explicit
install list (`pacman -Qe`), also tracked machine-readably in
`packages.txt`/`aur-packages.txt` in this repo. Waybar/rofi/dunst are being
rebuilt for real as of this same cleanup — see the note at the end of this
list.

```
alacritty
base
base-devel
bluez
bluez-utils
brightnessctl
btop
calibre
chafa
cifs-utils
copyq
cryptsetup
efibootmgr
fd
fzf
git
grim
grub
hypridle
hyprland
hyprlock
hyprpaper
hyprsunset
jq
linux
linux-firmware
mpv
nano
neovim
networkmanager
network-manager-applet
openssh
openvpn
pipewire
pipewire-pulse
python
python-pipx
ripgrep
slurp
smbclient
sudo
tlp
tmux
ttf-jetbrains-mono
ttf-nerd-fonts-symbols-common
ttf-nerd-fonts-symbols-mono
ueberzugpp
ufw
unzip
upower
waterfox-bin
wget
wireplumber
wl-clipboard
yay
yazi
zathura
zathura-pdf-mupdf
```

Install with: `sudo pacman -S <space-separated list above>` (waterfox-bin
and yay itself are AUR — see `aur-packages.txt`, install via `yay -S`).

`hyprlock` was added same-day as the quickshell removal to close a lock-
screen gap (the old `lock_cmd` shelled out to a script that poked the now-
deleted quickshell lock app's file watch — dead on removal). It's currently
using a bare functional config (`~/.config/hypr/hyprlock.conf`), not yet
themed to match the rest of the setup.

Waybar, rofi, dunst, hyprpolkitagent, xdg-desktop-portal-hyprland, blueman,
and wlogout were all added same-day as the direct replacement for the pill.
`rofi` (not `rofi-wayland` — that fork was merged upstream as of rofi 2.0,
which is what's in the official repos now) is the launcher (`mod+D`),
`wlogout` is the power menu (`mod+O`). See section 4 below for the actual
configs.

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

require("modules.env")
require("modules.input")
require("modules.autostart")

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
        gaps_in     = 3,
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
    hl.exec_cmd("nm-applet")
    hl.exec_cmd("copyq --start-server")
    -- hyprsunset.service is enabled but only starts under graphical-session.target,
    -- which nothing in this session reaches -- start the unit directly instead of
    -- the target so hypridle (also gated on that target) stays untouched.
    hl.exec_cmd("systemctl --user start hyprsunset")
end)

-- Matrix idle window's own startup_mode = "Fullscreen" in matrix-idle.toml
-- requests real fullscreen directly from the client -- no Hyprland-side
-- window rule needed (and windowrulev2 is deprecated in this build anyway).

-- CopyQ: disable_tray=true in its own config means it has no tray icon to
-- hide into, so it force-shows its main window the moment its server starts.
-- Route around that instead of fighting it: let it start (and begin
-- recording clipboard history) at login as normal, but immediately banish
-- its window to a hidden special workspace, same scratchpad trick as
-- "special:scratchpad" below. mod+P then just toggles that workspace into
-- view instead of asking CopyQ to show/hide itself.
hl.window_rule({
    name      = "copyq-hidden",
    match     = { class = "com.github.hluk.copyq" },
    workspace = "special:copyq silent",
})

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
-- mod+D: launcher -- quickshell removed, rofi not wired up yet (next phase)
-- hl.bind(mod .. " + D", hl.dsp.exec_cmd("rofi -show drun"))
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
hl.bind(mod .. " + P", hl.dsp.workspace.toggle_special("copyq"))

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

NOTE: `hyprlock` is now installed (2026-09-12) with a bare functional
config at `~/.config/hypr/hyprlock.conf` — locking has been verified
working (renders, locks the session). Not yet themed to match the rest of
the setup.

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
**Rebuilt 2026-09-12** replacing the quickshell pill. Structural base adapted
from elifouts/Dotfiles (github.com/elifouts/Dotfiles), trimmed to this
machine's actual tools and re-colored to the existing wal palette instead of
importing someone else's theme.
```jsonc
// -*- mode: jsonc -*-
// Structural base adapted from elifouts/Dotfiles (github.com/elifouts/Dotfiles,
// MIT-style personal dotfiles repo) -- trimmed to this machine's actual tools
// (tlp not power-profiles-daemon, blueman not a generic tray rename, dunst not
// swaync, wlogout for the power menu) and this machine's color scheme.
{
    "layer": "top",
    "position": "top",
    "height": 30,
    "spacing": 4,
    "reload_style_on_change": true,

    "modules-left": ["hyprland/workspaces", "hyprland/window"],
    "modules-center": ["clock"],
    "modules-right": ["tray", "pulseaudio", "network", "bluetooth", "battery", "custom/power"],

    "hyprland/workspaces": {
        "format": "{id}",
        "on-click": "activate",
        "persistent-workspaces": {
            "*": [1, 2, 3, 4, 5]
        }
    },

    "hyprland/window": {
        "format": "{title}",
        "max-length": 50,
        "separate-outputs": true
    },

    "clock": {
        "format": "{:%H:%M   %a %d %b}",
        "tooltip-format": "<tt>{calendar}</tt>",
        "on-click": "copyq show"
    },

    "tray": {
        "icon-size": 16,
        "spacing": 10
    },

    "pulseaudio": {
        "format": "{volume}% {icon}",
        "format-muted": " muted",
        "format-icons": {
            "headphone": "",
            "default": ["", "", ""]
        },
        "on-click": "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle",
        "on-scroll-up": "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+",
        "on-scroll-down": "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
    },

    "network": {
        "format-wifi": "{signalStrength}% ",
        "format-ethernet": "{ipaddr}/{cidr} ",
        "format-disconnected": "disconnected ⚠",
        "tooltip-format-wifi": "{essid} ({signalStrength}%)",
        "on-click": "alacritty -e nmtui"
    },

    "bluetooth": {
        "format-on": "",
        "format-off": "off",
        "format-disabled": "disabled",
        "format-connected": "{num_connections} ",
        "tooltip-format": "{controller_alias}\t{controller_address}",
        "tooltip-format-connected": "{controller_alias}\t{controller_address}\n\n{device_enumerate}",
        "tooltip-format-enumerate-connected": "{device_alias}",
        "on-click": "blueman-manager"
    },

    "battery": {
        "states": {
            "warning": 30,
            "critical": 15
        },
        "format": "{capacity}% {icon}",
        "format-charging": "{capacity}% ",
        "format-plugged": "{capacity}% ",
        "format-icons": ["", "", "", "", ""]
    },

    "custom/power": {
        "format": "⏻",
        "tooltip": false,
        "on-click": "wlogout"
    }
}
```

### `~/.config/waybar/style.css`
```css
/* Structural base adapted from elifouts/Dotfiles -- colors hardcoded to this
 * machine's wal-derived palette (same values as hyprland.lua / hyprlock.conf)
 * instead of a pywal @import, since pywal isn't part of this setup. */
@define-color bg #110915;
@define-color fg #c3c1c4;
@define-color accent #A37E56;
@define-color urgent #63514C;

* {
    font-family: "JetBrainsMono Nerd Font", "JetBrains Mono", sans-serif;
    font-size: 13px;
    min-height: 0;
}

window#waybar {
    background: transparent;
}

.modules-left, .modules-center, .modules-right {
    background: alpha(@bg, 0.75);
    border-radius: 10px;
    margin: 6px 0 0 0;
    padding: 0 8px;
}

.modules-left { margin-left: 8px; }
.modules-right { margin-right: 8px; }

tooltip {
    background: @bg;
    border: 1px solid @accent;
    border-radius: 8px;
}
tooltip label {
    color: @fg;
}

#workspaces button {
    all: unset;
    padding: 0 6px;
    color: alpha(@fg, 0.4);
    transition: color .2s ease;
}
#workspaces button.active {
    color: @accent;
}
#workspaces button:hover {
    color: @fg;
}

#window,
#clock,
#tray,
#pulseaudio,
#network,
#bluetooth,
#battery,
#custom-power {
    padding: 0 8px;
    color: @fg;
}

#window {
    color: alpha(@fg, 0.7);
}

#battery.warning:not(.charging) {
    color: @accent;
}
#battery.critical:not(.charging) {
    color: @urgent;
    animation: blink 1s linear infinite alternate;
}
@keyframes blink {
    to { opacity: 0.4; }
}

#custom-power {
    color: @urgent;
}
#custom-power:hover {
    color: @accent;
}

#tray > .passive {
    -gtk-icon-effect: dim;
}
#tray > .needs-attention {
    -gtk-icon-effect: highlight;
    color: @urgent;
}
```

### `~/.config/rofi/config.rasi`
Only change from the prior (never-actually-installed) version: `icon-theme`
now points at `Adwaita` (actually installed) instead of the missing
`Flat-Remix-Purple-Dark`.
```
configuration {
    modi: "drun,run,window";
    show-icons: true;
    icon-theme: "Adwaita";
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
Unchanged, was already correct (hardcoded wal-derived palette, no pywal
dependency).
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

### `~/.config/dunst/dunstrc`
Was already fully written and correctly themed (colors, corner radii, font)
from the earlier i3-migration work, just never had the `dunst` package
actually installed until 2026-09-12. Only change made: `icon_theme` now
points at `Adwaita` instead of the missing `Flat-Remix-Purple-Dark`. Full
current file:
```
# See dunst(5) for all configuration options

[global]
    ### Display ###

    # Which monitor should the notifications be displayed on.
    monitor = 0

    # Display notification on focused monitor.  Possible modes are:
    #   mouse: follow mouse pointer
    #   keyboard: follow window with keyboard focus
    #   none: don't follow anything
    #
    # "keyboard" needs a window manager that exports the
    # _NET_ACTIVE_WINDOW property.
    # This should be the case for almost all modern window managers.
    #
    # If this option is set to mouse or keyboard, the monitor option
    # will be ignored.
    follow = none

    ### Geometry ###

    # The width of the window, excluding the frame.
    # dynamic width from 0 to 300
    # width = (0, 300)
    # constant width of 300
    width = 300

    # The height of a single notification, excluding the frame.
    # dynamic height from 0 to 300
    height = (0, 300)
    # constant height of 300
    # height = 300
    # NOTE: Dunst from version 1.11 and older don't support dynamic height
    #       and the given value is treated as the maximum height

    # Position the notification in the top right corner
    origin = top-right

    # Offset from the origin
    # NOTE: Dunst from version 1.11 and older use this alternative notation
    # offset = 10x50
    offset = (10, 50)

    # Scale factor. It is auto-detected if value is 0.
    scale = 0

    # Maximum number of notification (0 means no limit)
    notification_limit = 20

    ### Progress bar ###

    # Turn on the progress bar. It appears when a progress hint is passed with
    # for example dunstify -h int:value:12
    progress_bar = true

    # Set the progress bar height. This includes the frame, so make sure
    # it's at least twice as big as the frame width.
    progress_bar_height = 10

    # Set the frame width of the progress bar
    progress_bar_frame_width = 1

    # Set the minimum width for the progress bar
    progress_bar_min_width = 150

    # Set the maximum width for the progress bar
    progress_bar_max_width = 300

    # Corner radius for the progress bar. 0 disables rounded corners.
    progress_bar_corner_radius = 8

    # Define which corners to round when drawing the progress bar. If progress_bar_corner_radius
    # is set to 0 this option will be ignored.
    progress_bar_corners = all

    # Corner radius for the icon image.
    icon_corner_radius = 8

    # Define which corners to round when drawing the icon image. If icon_corner_radius
    # is set to 0 this option will be ignored.
    icon_corners = all

    # Show how many messages are currently hidden (because of
    # notification_limit).
    indicate_hidden = yes

    # The transparency of the window.  Range: [0; 100].
    # This option will only work if a compositing window manager is
    # present (e.g. xcompmgr, compiz, etc.). (X11 only)
    transparency = 0

    # Draw a line of "separator_height" pixel height between two
    # notifications.
    # Set to 0 to disable.
    # If gap_size is greater than 0, this setting will be ignored.
    separator_height = 2

    # Padding between text and separator.
    padding = 8

    # Horizontal padding.
    horizontal_padding = 8

    # Padding between text and icon.
    text_icon_padding = 0

    # Defines width in pixels of frame around the notification window.
    # Set to 0 to disable.
    frame_width = 3

    # Defines color of the frame around the notification window.
    frame_color = "#A37E56"

    # Size of gap to display between notifications - requires a compositor.
    # If value is greater than 0, separator_height will be ignored and a border
    # of size frame_width will be drawn around each notification instead.
    # Click events on gaps do not currently propagate to applications below.
    gap_size = 0

    # Define a color for the separator.
    # possible values are:
    #  * auto: dunst tries to find a color fitting to the background;
    #  * foreground: use the same color as the foreground;
    #  * frame: use the same color as the frame;
    #  * anything else will be interpreted as a X color.
    separator_color = frame

    # Sort type.
    # possible values are:
    #  * id: sort by id
    #  * urgency_ascending: sort by urgency (low then normal then critical)
    #  * urgency_descending: sort by urgency (critical then normal then low)
    #  * update: sort by update (most recent always at the top)
    sort = yes

    # Don't remove messages, if the user is idle (no mouse or keyboard input)
    # for longer than idle_threshold seconds.
    # Set to 0 to disable.
    # A client can set the 'transient' hint to bypass this. See the rules
    # section for how to disable this if necessary
    # idle_threshold = 120

    ### Text ###

    font = JetBrains Mono 11

    # The spacing between lines.  If the height is smaller than the
    # font height, it will get raised to the font height.
    line_height = 0

    # Possible values are:
    # full: Allow a small subset of html markup in notifications:
    #        <b>bold</b>
    #        <i>italic</i>
    #        <s>strikethrough</s>
    #        <u>underline</u>
    #
    #        For a complete reference see
    #        <https://docs.gtk.org/Pango/pango_markup.html>.
    #
    # strip: This setting is provided for compatibility with some broken
    #        clients that send markup even though it's not enabled on the
    #        server. Dunst will try to strip the markup but the parsing is
    #        simplistic so using this option outside of matching rules for
    #        specific applications *IS GREATLY DISCOURAGED*.
    #
    # no:    Disable markup parsing, incoming notifications will be treated as
    #        plain text. Dunst will not advertise that it has the body-markup
    #        capability if this is set as a global setting.
    #
    # It's important to note that markup inside the format option will be parsed
    # regardless of what this is set to.
    markup = full

    # The format of the message.  Possible variables are:
    #   %a  appname
    #   %s  summary
    #   %b  body
    #   %c  category
    #   %S  stack_tag
    #   %i  iconname (including its path)
    #   %I  iconname (without its path)
    #   %p  progress value if set ([  0%] to [100%]) or nothing
    #   %n  progress value if set without any extra characters
    #   %%  literal %
    # Markup is allowed
    format = "<b>%s</b>\n%b"

    # Alignment of message text.
    # Possible values are "left", "center" and "right".
    alignment = left

    # Vertical alignment of message text and icon.
    # Possible values are "top", "center" and "bottom".
    vertical_alignment = center

    # Show age of message if message is older than show_age_threshold
    # seconds.
    # Set to -1 to disable.
    show_age_threshold = 60

    # Specify where to make an ellipsis in long lines.
    # Possible values are "start", "middle" and "end".
    ellipsize = middle

    # Ignore newlines '\n' in notifications.
    ignore_newline = no

    # Stack together notifications with the same content
    stack_duplicates = true

    # Hide the count of stacked notifications with the same content
    hide_duplicate_count = false

    # Display indicators for URLs (U) and actions (A).
    show_indicators = yes

    # When set to true (recommended), you can use POSIX regular expressions for filtering rules.
    # If this is set to false (not recommended), dunst will use fnmatch(3) for matching strings.
    # Dunst doesn't pass any flags to fnmatch, so you cannot make use of extended patterns.
    #
    # Note that this will eventually be true by default.
    enable_posix_regex = false

    ### Icons ###

    # Recursive icon lookup. You can set a single theme, instead of having to
    # define all lookup paths.
    enable_recursive_icon_lookup = true

    # Set icon theme (only used for recursive icon lookup)
    icon_theme = "Adwaita"
    # You can also set multiple icon themes, with the leftmost one being used first.
    # icon_theme = "Adwaita, breeze"

    # Align icons left/right/top/off
    icon_position = left

    # Scale small icons up to this size, set to 0 to disable. Helpful
    # for e.g. small files or high-dpi screens. In case of conflict,
    # max_icon_size takes precedence over this.
    min_icon_size = 24

    # Scale larger icons down to this size, set to 0 to disable
    max_icon_size = 48

    # Paths to default icons (only necessary when not using recursive icon lookup)
    icon_path = /usr/share/icons/gnome/16x16/status/:/usr/share/icons/gnome/16x16/devices/

    ### History ###

    # Should a notification popped up from history be sticky or timeout
    # as if it would normally do.
    sticky_history = yes

    # Maximum amount of notifications kept in history
    history_length = 20

    ### Misc/Advanced ###

    # dmenu path.
    dmenu = /usr/bin/dmenu -p dunst:

    # Browser for opening urls in context menu.
    browser = /usr/bin/xdg-open

    # Always run rule-defined scripts, even if the notification is suppressed
    always_run_script = true

    # Define the title of the windows spawned by dunst (X11 only)
    title = Dunst

    # Define the class of the windows spawned by dunst (X11 only)
    class = Dunst

    # Define the corner radius of the notification window
    # in pixel size. If the radius is 0, you have no rounded
    # corners.
    # The radius will be automatically lowered if it exceeds half of the
    # notification height to avoid clipping text and/or icons.
    corner_radius = 10

    # Define which corners to round when drawing the window. If the corner radius
    # is set to 0 this option will be ignored.
    #
    # Comma-separated list of the corners. The accepted corner values are bottom-right,
    # bottom-left, top-right, top-left, top, bottom, left, right or all.
    corners = all

    # Ignore the dbus closeNotification message.
    # Useful to enforce the timeout set by dunst configuration. Without this
    # parameter, an application may close the notification sent before the
    # user defined timeout.
    ignore_dbusclose = false

    ### Wayland ###
    # These settings are Wayland-specific. They have no effect when using X11

    # Uncomment this if you want to let notifications appear under fullscreen
    # applications (default: overlay)
    # layer = top

    # Set this to true to use X11 output on Wayland.
    force_xwayland = false

    ### Legacy

    # Use the Xinerama extension instead of RandR for multi-monitor support.
    # This setting is provided for compatibility with older nVidia drivers that
    # do not support RandR and using it on systems that support RandR is highly
    # discouraged.
    #
    # By enabling this setting dunst will not be able to detect when a monitor
    # is connected or disconnected which might break follow mode if the screen
    # layout changes.
    force_xinerama = false

    ### mouse

    # Defines list of actions for each mouse event
    # Possible values are:
    # * none: Don't do anything.
    # * do_action: Invoke the action determined by the action_name rule. If there is no
    #              such action, open the context menu.
    # * open_url: If the notification has exactly one url, open it. If there are multiple
    #             ones, open the context menu.
    # * close_current: Close current notification.
    # * remove_current: Remove current notification from history.
    # * close_all: Close all notifications.
    # * context: Open context menu for the notification.
    # * context_all: Open context menu for all notifications.
    # These values can be strung together for each mouse event, and
    # will be executed in sequence.
    mouse_left_click = close_current
    mouse_middle_click = do_action, close_current
    mouse_right_click = close_all

# Experimental features that may or may not work correctly. Do not expect them
# to have a consistent behaviour across releases.
[experimental]
    # Calculate the dpi to use on a per-monitor basis.
    # If this setting is enabled the Xft.dpi value will be ignored and instead
    # dunst will attempt to calculate an appropriate dpi value for each monitor
    # using the resolution and physical size. This might be useful in setups
    # where there are multiple screens with very different dpi values.
    per_monitor_dpi = false

    # Pause notification timeout when mouse hovers over the notification window.
    # When enabled, notifications won't timeout while the mouse pointer is over
    # them. The timeout resumes when the pointer leaves the window.
    # Only works on Wayland.
    pause_on_mouse_over = false

    # Use PCRE regular expressions for filtering rules.
    # This setting overrides enable_posix_regex.
    enable_pcre_regex = false

[urgency_low]
    # IMPORTANT: colors have to be defined in quotation marks.
    # Otherwise the "#" and following would be interpreted as a comment.
    background = "#110915"
    foreground = "#c3c1c4"
    timeout = 3
    # Icon for notifications with low urgency
    default_icon = dialog-information

[urgency_normal]
    background = "#110915"
    foreground = "#c3c1c4"
    timeout = 3
    override_pause_level = 30
    # Icon for notifications with normal urgency
    default_icon = dialog-information

[urgency_critical]
    background = "#110915"
    foreground = "#c3c1c4"
    frame_color = "#63514C"
    timeout = 0
    override_pause_level = 60
    # Icon for notifications with critical urgency
    default_icon = dialog-warning

# Every section that isn't one of the above is interpreted as a rules to
# override settings for certain messages.
#
# Messages can be matched by
#    appname (discouraged, see desktop_entry)
#    body
#    category
#    desktop_entry
#    icon
#    match_transient
#    msg_urgency
#    stack_tag
#    summary
#
# and you can override the
#    background
#    foreground
#    format
#    frame_color
#    fullscreen
#    new_icon
#    set_stack_tag
#    set_transient
#    set_category
#    timeout
#    urgency
#    icon_position
#    skip_display
#    history_ignore
#    action_name
#    word_wrap
#    ellipsize
#    alignment
#    hide_text
#    override_pause_level
#
# Shell-like globbing will get expanded.
#
# Instead of the appname filter, it's recommended to use the desktop_entry filter.
# GLib based applications export their desktop-entry name. In comparison to the appname,
# the desktop-entry won't get localized.
#
# You can also allow a notification to appear even when paused. Notification will appear whenever notification's override_pause_level >= dunst's paused level.
# This can be used to set partial pause modes, where more urgent notifications get through, but less urgent stay paused. To do that, you can override the following in the rules:
# override_pause_level = X

# SCRIPTING
# You can specify a script that gets run when the rule matches by
# setting the "script" option.
# The script will be called as follows:
#   script appname summary body icon urgency
# where urgency can be "LOW", "NORMAL" or "CRITICAL".
#
# NOTE: It might be helpful to run dunst -print in a terminal in order
# to find fitting options for rules.

# Disable the transient hint so that idle_threshold cannot be bypassed from the
# client
#[transient_disable]
#    match_transient = yes
#    set_transient = no
#
# Make the handling of transient notifications more strict by making them not
# be placed in history.
#[transient_history_ignore]
#    match_transient = yes
#    history_ignore = yes

# fullscreen values
# show: show the notifications, regardless if there is a fullscreen window opened
# delay: displays the new notification, if there is no fullscreen window active
#        If the notification is already drawn, it won't get undrawn.
# pushback: same as delay, but when switching into fullscreen, the notification will get
#           withdrawn from screen again and will get delayed like a new notification
# suppress: withdraw the displayed notification when entering fullscreen and never show
#           the new notifications that arrive during fullscreen mode
#[fullscreen_delay_everything]
#    fullscreen = delay
#[fullscreen_show_critical]
#    msg_urgency = critical
#    fullscreen = show

#[espeak]
#    summary = "*"
#    script = dunst_espeak.sh

#[script-test]
#    summary = "*script*"
#    script = dunst_test.sh

#[ignore]
#    # This notification will not be displayed
#    summary = "foobar"
#    skip_display = true

#[history-ignore]
#    # This notification will not be saved in history
#    summary = "foobar"
#    history_ignore = yes

#[skip-display]
#    # This notification will not be displayed, but will be included in the history
#    summary = "foobar"
#    skip_display = yes

#[signed_on]
#    appname = Pidgin
#    summary = "*signed on*"
#    urgency = low
#
#[signed_off]
#    appname = Pidgin
#    summary = *signed off*
#    urgency = low
#
#[says]
#    appname = Pidgin
#    summary = *says*
#    urgency = critical
#
#[twitter]
#    appname = Pidgin
#    summary = *twitter.com*
#    urgency = normal
#
#[stack-volumes]
#    appname = "some_volume_notifiers"
#    set_stack_tag = "volume"
#
```

### `~/.config/wlogout/layout` and `style.css`
New 2026-09-12, replacing the pill's power menu. Layout is stock wlogout
defaults except the `lock` action, which calls `pidof hyprlock || hyprlock`
directly rather than `loginctl lock-session` (that only marks the logind
session locked -- it does NOT itself invoke hyprlock, so the button would
otherwise appear to do nothing).
```json
{
    "label" : "lock",
    "action" : "pidof hyprlock || hyprlock",
    "text" : "Lock",
    "keybind" : "l"
}
{
    "label" : "hibernate",
    "action" : "systemctl hibernate",
    "text" : "Hibernate",
    "keybind" : "h"
}
{
    "label" : "logout",
    "action" : "loginctl terminate-user $USER",
    "text" : "Logout",
    "keybind" : "e"
}
{
    "label" : "shutdown",
    "action" : "systemctl poweroff",
    "text" : "Shutdown",
    "keybind" : "s"
}
{
    "label" : "suspend",
    "action" : "systemctl suspend",
    "text" : "Suspend",
    "keybind" : "u"
}
{
    "label" : "reboot",
    "action" : "systemctl reboot",
    "text" : "Reboot",
    "keybind" : "r"
}
```
```css
* {
    background-image: none;
    box-shadow: none;
}

window {
    background-color: alpha(#110915, 0.85);
}

button {
    color: #c3c1c4;
    background-color: #110915;
    border: 2px solid #A37E56;
    border-radius: 12px;
    background-repeat: no-repeat;
    background-position: center;
    background-size: 25%;
    margin: 10px;
    transition: all 0.2s ease;
}

button:focus, button:active, button:hover {
    background-color: #A37E56;
    outline-style: none;
}

#lock {
    background-image: image(url("/usr/share/wlogout/icons/lock.png"));
}
#logout {
    background-image: image(url("/usr/share/wlogout/icons/logout.png"));
}
#suspend {
    background-image: image(url("/usr/share/wlogout/icons/suspend.png"));
}
#hibernate {
    background-image: image(url("/usr/share/wlogout/icons/hibernate.png"));
}
#shutdown {
    background-image: image(url("/usr/share/wlogout/icons/shutdown.png"));
}
#reboot {
    background-image: image(url("/usr/share/wlogout/icons/reboot.png"));
}
```

### `~/.bashrc`
Only change: `PS1='[\u@\h \W]\$ '` → `PS1='\u\$ '`

## 5. Wallpaper
`/home/Raze/Pictures/wallpapers/mimikyu.jpg` — keep this file, referenced
directly by `hyprpaper.conf`.

## 6. Known gaps / deliberately not installed

- ~~`hyprlock`~~ — installed 2026-09-12, see section 1. Gap closed.
- **`slurp`** was a gap, now fixed (installed) — region-select screenshots work.
- **File manager**: none installed. Landed on `yazi` (not `nnn` — user had
  heard `nnn`'s UX is rough, and confirmed `yazi` on its own merits: async/fast,
  built-in image preview, sensible defaults). Needs `ueberzugpp` too (see below).
- ~~`Flat-Remix-Purple-Dark` icon theme~~ — fixed 2026-09-12: dunstrc and
  rofi config.rasi both now point at `Adwaita` (actually installed) instead.
- **`copyq`**: kept, deliberately, as of the 2026-09-12 cleanup — the user
  was asked cliphist vs CopyQ directly and chose to keep CopyQ. (This
  contradicts older i3-migration-era notes that said the opposite; this
  line is the current, correct answer.)
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
