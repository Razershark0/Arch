pragma Singleton
import QtQuick
import "../../"

Item {
    id: controller

    property bool isVisible: false
    property real panelWidth: 320
    property real topOffset: 0

    function show() {
        WifiPanelController.hide();
        BtPanelController.hide();
        BatPanelController.hide();
        SystemPanelController.hide();
        controller.isVisible = true;
    }
    function hide() { controller.isVisible = false; }
    function toggle() {
        if (controller.isVisible) hide();
        else show();
    }

    // Popups are suppressed while the list is on screen, and everything in it
    // counts as seen once the panel closes.
    onIsVisibleChanged: {
        NotificationManager.sysPanelOpen = isVisible;
        if (!isVisible) NotificationManager.markAllRead();
    }
}
