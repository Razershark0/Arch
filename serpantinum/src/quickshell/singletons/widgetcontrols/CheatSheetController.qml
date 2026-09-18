pragma Singleton
import QtQuick
import "../../"

Item {
    id: controller

    property bool isVisible: false

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
}
