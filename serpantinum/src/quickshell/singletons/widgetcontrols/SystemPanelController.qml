pragma Singleton
import QtQuick
import "../../"

Item {
    id: controller

    property bool isVisible: false
    property real topOffset: 0
    property real panelWidth: 320

    function show() {
        WifiPanelController.hide();
        NotifPanelController.hide();
        BtPanelController.hide();
        BatPanelController.hide();
        LauncherController.hide();
        ClipboardController.hide();
        CheatSheetController.hide();
        controller.isVisible = true;
    }
    function hide() { controller.isVisible = false; }
    function toggle() {
        if (controller.isVisible) hide();
        else show();
    }
}
