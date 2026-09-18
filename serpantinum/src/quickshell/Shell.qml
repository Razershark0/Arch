import QtQuick
import Quickshell

ShellRoot {
    Connections {
        target: Quickshell
        function onReloadCompleted() { Quickshell.inhibitReloadPopup() }
        function onReloadFailed(errorString) { Quickshell.inhibitReloadPopup() }
    }

    ScreenshotOverlay {}
    Main {}
    Bar {}

    Launcher {}
    Clipboard {}

    PopoutManager {}
    NotificationPopups {}
    SystemPanel {}
    WifiPanel {}
    BtPanel {}
    BatPanel {}

    Lock {}
    Idle {}

    Loader {
        active: CheatSheetController.isVisible
        sourceComponent: CheatSheet {}
    }
}
