pragma Singleton
import QtQuick
import "../../"

Item {
    id: controller

    property bool isVisible: false
    property real panelWidth: 320
    property real topOffset: 0
    property real seamlessX: 0
    property real seamlessWidth: 0

    function show() {
        WifiPanelController.hide();
        BtPanelController.hide();
        controller.isVisible = true;
    }
    function hide() { controller.isVisible = false; }
    function toggle() {
        if (controller.isVisible) hide();
        else show();
    }
}
