import QtQuick
import Quickshell
import Quickshell.Io

PanelWindow {
    id: masterWindow
    color: "transparent"
    visible: false

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    IpcHandler {
        target: "main"

        function forceReload(): void {
            Quickshell.reload(true);
        }

        function handleCommand(cmd: string, targetWidget: string, arg: string): void {
            cmd = cmd || "";
            targetWidget = targetWidget || "";

            if (cmd === "launcher" || targetWidget === "launcher") {
                if (cmd === "close") {
                    LauncherController.hide();
                } else if (cmd === "open") {
                    ClipboardController.hide();
                    LauncherController.show();
                } else {
                    ClipboardController.hide();
                    LauncherController.toggle();
                }
                return;
            }

            if (cmd === "clipboard" || targetWidget === "clipboard" || cmd === "clip" || targetWidget === "clip") {
                if (cmd === "close") {
                    ClipboardController.hide();
                } else if (cmd === "open") {
                    LauncherController.hide();
                    ClipboardController.show();
                } else {
                    LauncherController.hide();
                    ClipboardController.toggle();
                }
                return;
            }

            if (cmd === "autohide" || targetWidget === "autohide") {
                let bar = Config.getSetting("bar", {});
                bar.autohide = !bar.autohide;
                Config.setSetting("bar", bar);
                return;
            }

            if (cmd === "syspanel" || targetWidget === "syspanel") {
                if (cmd === "close") {
                    SystemPanelController.hide();
                } else if (cmd === "open") {
                    SystemPanelController.show();
                } else {
                    SystemPanelController.toggle();
                }
                return;
            }

            if (cmd === "wifipanel" || targetWidget === "wifipanel") {
                if (cmd === "close") {
                    WifiPanelController.hide();
                } else if (cmd === "open") {
                    WifiPanelController.show();
                } else {
                    WifiPanelController.toggle();
                }
                return;
            }

            if (cmd === "btpanel" || targetWidget === "btpanel") {
                if (cmd === "close") {
                    BtPanelController.hide();
                } else if (cmd === "open") {
                    BtPanelController.show();
                } else {
                    BtPanelController.toggle();
                }
                return;
            }

            if (cmd === "batpanel" || targetWidget === "batpanel") {
                if (cmd === "close") {
                    BatPanelController.hide();
                } else if (cmd === "open") {
                    BatPanelController.show();
                } else {
                    BatPanelController.toggle();
                }
                return;
            }

            if (cmd === "notifpanel" || targetWidget === "notifpanel") {
                if (cmd === "close") {
                    NotifPanelController.hide();
                } else if (cmd === "open") {
                    NotifPanelController.show();
                } else {
                    NotifPanelController.toggle();
                }
                return;
            }

            if (cmd === "cheatsheet" || targetWidget === "cheatsheet") {
                if (cmd === "close") {
                    CheatSheetController.hide();
                } else if (cmd === "open") {
                    CheatSheetController.show();
                } else {
                    CheatSheetController.toggle();
                }
                return;
            }
        }
    }
}
