pragma Singleton
import QtQuick

Item {
    id: controller

    property bool isVisible: false

    function show() { controller.isVisible = true; }
    function hide() { controller.isVisible = false; }
    function toggle() { controller.isVisible = !controller.isVisible; }
}
