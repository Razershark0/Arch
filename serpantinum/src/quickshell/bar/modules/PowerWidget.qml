import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../../reusables"
import "../../"

Rectangle {
    id: powerWidgetRoot

    property var barWindow
    property bool isSolid: false
    property bool distinctPills: barWindow ? (barWindow.distinctPills !== undefined ? barWindow.distinctPills : false) : false
    property bool moduleActive: true
    property bool isGrouped: false
    property bool isCompact: isGrouped || (isSolid && distinctPills)

    property alias powerButton: powerButton

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

    property real targetWidth: moduleActive ? (powerLayout.width + (barWindow ? barWindow.s(isCompact ? 8 : 10) : (isCompact ? 8 : 10))) : 0
    width: targetWidth
    Behavior on width { NumberAnimation { duration: 450; easing.type: Easing.OutQuint } }

    opacity: (showLayout && moduleActive) ? ((barWindow && barWindow.barOpacity !== undefined) ? barWindow.barOpacity : 1.0) : 0.0
    visible: opacity > 0
    enabled: moduleActive

    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    transform: Translate {
        x: powerWidgetRoot.showLayout ? 0 : (barWindow ? barWindow.s(60) : 60)
        Behavior on x { NumberAnimation { duration: 800; easing.type: Easing.OutQuint } }
    }

    Row {
        id: powerLayout
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: barWindow ? barWindow.s(powerWidgetRoot.isCompact ? 4 : 5) : (powerWidgetRoot.isCompact ? 4 : 5)
        spacing: barWindow ? barWindow.s(powerWidgetRoot.isCompact ? 5 : 6) : (powerWidgetRoot.isCompact ? 5 : 6)

        property int pillHeight: barWindow ? barWindow.s(powerWidgetRoot.isCompact ? 28 : 30) : (powerWidgetRoot.isCompact ? 28 : 30)

        IconButton {
            id: powerButton
            height: powerLayout.pillHeight
            width: barWindow ? barWindow.s(powerWidgetRoot.isCompact ? 30 : 32) : (powerWidgetRoot.isCompact ? 30 : 32)
            visible: true

            cornerRadius: barWindow ? barWindow.s(powerWidgetRoot.isCompact ? 9 : 10) : (powerWidgetRoot.isCompact ? 9 : 10)
            iconOffsetX: -2
            buttonIcon: "󰐥"
            iconFontSize: barWindow ? barWindow.s(powerWidgetRoot.isCompact ? 18 : 20) : (powerWidgetRoot.isCompact ? 18 : 20)
            accentColor: powerWidgetRoot.isCompact ? Qt.lighter(ThemeBackend.surface0, 1.18) : ThemeBackend.surface0
            textColor: isHoveredOrHighlighted ? ThemeBackend.red : "#F0E3B6"

            opacity: powerWidgetRoot.showLayout ? 1.0 : 0.0
            transform: Translate {
                y: powerWidgetRoot.showLayout ? 0 : (barWindow ? barWindow.s(15) : 15)
                Behavior on y { NumberAnimation { duration: 620; easing.type: Easing.OutQuint } }
            }
            Behavior on opacity { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }

            onClicked: SystemPanelController.toggle()
        }
    }
}
