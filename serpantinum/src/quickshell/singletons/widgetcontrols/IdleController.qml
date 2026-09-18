pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Shared state for the lock screen: the wallpaper and darkening it draws over,
// and the pointer hiding while the session is locked.
Item {
    id: controller

    // Set by Lock while the session is locked.
    property bool sessionLocked: false

    // While locked the pointer is only shown while it is being moved: Hyprland
    // hides it after 3 seconds without movement and brings it back as soon as
    // it moves. A surface can't do this itself: the pointer only picks up a
    // surface's cursor request once it moves over it. The option is put back to
    // 0 (Hyprland's default: never hide) when the lock goes away, and on every
    // shell start in case a crash left it set.
    onSessionLockedChanged: setPointerTimeout(sessionLocked ? 3 : 0)
    Component.onCompleted: setPointerTimeout(0)

    // Changes are applied one at a time and in order, so a quick 0-then-1 can't
    // land as 1-then-0. If a change comes in while one is running, the latest
    // value is applied as soon as that one exits.
    Process {
        id: pointerProc
        property int seconds: 0
        property int applied: -1
        command: ["hyprctl", "eval", "hl.config({ cursor = { inactive_timeout = " + applied + " } })"]
        onExited: {
            if (applied !== seconds) {
                applied = seconds;
                running = true;
            }
        }
    }

    function setPointerTimeout(seconds) {
        pointerProc.seconds = seconds;
        if (!pointerProc.running) {
            pointerProc.applied = seconds;
            pointerProc.running = true;
        }
    }

    property string wallpaperPath: ""

    // Same sizing as hyprpaper: fill stretches to the screen, contain fits
    // inside it, anything else (cover, the default) crops to fill.
    property int wallpaperFillMode: Image.PreserveAspectCrop

    // The terminal's own background opacity, so the dimmed wallpaper behind
    // the rain reads the same as it does behind a terminal.
    property real terminalOpacity: 0.75

    FileView {
        path: (Quickshell.env("HOME") ?? "") + "/.config/hypr/hyprpaper.conf"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            let t = text();
            let m = t.match(/^\s*path\s*=\s*(.+?)\s*$/m);
            if (m && m[1]) controller.wallpaperPath = m[1];
            let f = t.match(/^\s*fit_mode\s*=\s*(\w+)/m);
            let mode = f ? f[1].toLowerCase() : "cover";
            controller.wallpaperFillMode = mode === "fill" ? Image.Stretch
                : (mode === "contain" ? Image.PreserveAspectFit : Image.PreserveAspectCrop);
        }
    }

    FileView {
        path: (Quickshell.env("HOME") ?? "") + "/.config/alacritty/alacritty.toml"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            let m = text().match(/^\s*opacity\s*=\s*([0-9.]+)/m);
            if (m) controller.terminalOpacity = Math.max(0, Math.min(1, parseFloat(m[1])));
        }
    }
}
