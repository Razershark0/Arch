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
