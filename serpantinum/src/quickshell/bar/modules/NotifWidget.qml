import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../../reusables"
import "../../"

Rectangle {
    id: notifWidgetRoot

    property var barWindow
    property bool isSolid: false
    property bool distinctPills: barWindow ? (barWindow.distinctPills !== undefined ? barWindow.distinctPills : false) : false
    property bool moduleActive: true
    property bool isGrouped: false
    property bool isCompact: isGrouped || (isSolid && distinctPills)

    property alias notifButton: notifButton

    property real targetX: 0
    property bool showLayout: moduleActive && (barWindow ? (barWindow.isStartupReady && barWindow.isDataReady) : true)

    x: targetX
    Behavior on x {
        enabled: barWindow && barWindow.startupCascadeFinished
        NumberAnimation { duration: 600; easing.type: Easing.OutQuint }
    }

    height: barWindow ? (isGrouped ? barWindow.barHeight - 8 : ((isSolid && distinctPills) ? barWindow.barHeight - 6 : barWindow.barHeight)) : (isGrouped ? 22 : ((isSolid && distinctPills) ? 24 : 30))
    y: barWindow ? barWindow.baseOffsetY + (barWindow.barHeight - height) / 2 : 0
    radius: ThemeBackend.borderRadius
    border.width: 0
    color: isGrouped ? "transparent" : (isSolid ? (distinctPills ? "#110915" : "transparent") : ThemeBackend.base)
    clip: true

    property real targetWidth: moduleActive ? (notifLayout.width + (barWindow ? barWindow.s(isCompact ? 8 : 10) : (isCompact ? 8 : 10))) : 0
    width: targetWidth
    Behavior on width { NumberAnimation { duration: 450; easing.type: Easing.OutQuint } }

    opacity: (showLayout && moduleActive) ? ((barWindow && barWindow.barOpacity !== undefined) ? barWindow.barOpacity : 1.0) : 0.0
    visible: opacity > 0
    enabled: moduleActive

    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    transform: Translate {
        x: notifWidgetRoot.showLayout ? 0 : (barWindow ? barWindow.s(60) : 60)
        Behavior on x { NumberAnimation { duration: 800; easing.type: Easing.OutQuint } }
    }

    Row {
        id: notifLayout
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: barWindow ? barWindow.s(notifWidgetRoot.isCompact ? 4 : 5) : (notifWidgetRoot.isCompact ? 4 : 5)
        spacing: barWindow ? barWindow.s(notifWidgetRoot.isCompact ? 5 : 6) : (notifWidgetRoot.isCompact ? 5 : 6)

        property int pillHeight: barWindow ? barWindow.s(notifWidgetRoot.isCompact ? 28 : 30) : (notifWidgetRoot.isCompact ? 28 : 30)

        IconButton {
            id: notifButton
            height: notifLayout.pillHeight
            width: barWindow ? barWindow.s(notifWidgetRoot.isCompact ? 30 : 32) : (notifWidgetRoot.isCompact ? 30 : 32)
            visible: true

            cornerRadius: barWindow ? barWindow.s(notifWidgetRoot.isCompact ? 9 : 10) : (notifWidgetRoot.isCompact ? 9 : 10)
            iconOffsetX: -2
            buttonIcon: "󰂚"
            iconFontSize: barWindow ? barWindow.s(notifWidgetRoot.isCompact ? 18 : 20) : (notifWidgetRoot.isCompact ? 18 : 20)
            accentColor: notifWidgetRoot.isCompact ? Qt.lighter(ThemeBackend.surface0, 1.18) : ThemeBackend.surface0
            textColor: "#F0E3B6"

            opacity: notifWidgetRoot.showLayout ? 1.0 : 0.0
            transform: Translate {
                y: notifWidgetRoot.showLayout ? 0 : (barWindow ? barWindow.s(15) : 15)
                Behavior on y { NumberAnimation { duration: 620; easing.type: Easing.OutQuint } }
            }
            Behavior on opacity { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }

            onClicked: NotifPanelController.toggle()

            Rectangle {
                visible: NotificationManager.unreadCount > 0
                width: barWindow ? barWindow.s(7) : 7
                height: width
                radius: width / 2
                color: ThemeBackend.red
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: barWindow ? barWindow.s(5) : 5
                anchors.rightMargin: barWindow ? barWindow.s(6) : 6
            }
        }
    }
}
