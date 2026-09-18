import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import "../../../reusables"
import "../../../"

Rectangle {
    id: sysMonWidgetRoot
    property var barWindow
    property bool isSolid: false
    property bool distinctPills: barWindow ? (barWindow.distinctPills !== undefined ? barWindow.distinctPills : false) : false
    property bool moduleActive: true
    property bool isGrouped: false
    property bool isCompact: isGrouped || (isSolid && distinctPills)
    property real targetX: 0
    property bool showLayout: moduleActive && (barWindow ? (barWindow.isStartupReady && barWindow.isDataReady) : true)

    property bool isSysVisible: moduleActive && showLayout

    function updateSubscription() {
        if (isSysVisible) {
            SysData.subscribe()
        } else {
            SysData.unsubscribe()
        }
    }

    Component.onDestruction: SysData.unsubscribe()
    onIsSysVisibleChanged: updateSubscription()

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

    property bool expanded: false

    property int pillHeight: barWindow ? barWindow.s(isCompact ? 28 : 30) : (isCompact ? 28 : 30)
    property int pillWidth: barWindow ? barWindow.s(isCompact ? 48 : 52) : (isCompact ? 48 : 52)
    property real innerSpacing: barWindow ? barWindow.s(4) : 4
    property real sidePadding: barWindow ? barWindow.s(isCompact ? 8 : 10) : (isCompact ? 8 : 10)

    // The icon's screen position stays fixed no matter what the bar's
    // reposition animation is doing. We snapshot the widget's settled right
    // edge (only once things have actually stopped moving, never mid-slide)
    // and continuously counter the widget's own x against that snapshot so
    // the icon never visually moves.
    property real restingRightEdge: 0
    // Until the first settled snapshot, the icon just follows the widget's
    // right edge like the other bar widgets do, so it doesn't sit at a stale
    // position and jump once the snapshot timer finally fires.
    property bool restSettled: false

    function syncRestingEdge() {
        if (!restSettled && !expanded) restingRightEdge = x + width;
    }

    onXChanged: syncRestingEdge()
    onWidthChanged: syncRestingEdge()

    Component.onCompleted: {
        updateSubscription();
        restingRightEdge = x + width;
    }

    Timer {
        id: captureRestTimer
        interval: 900
        onTriggered: {
            sysMonWidgetRoot.restingRightEdge = sysMonWidgetRoot.x + sysMonWidgetRoot.width;
            sysMonWidgetRoot.restSettled = true;
        }
    }

    onExpandedChanged: {
        if (!expanded) captureRestTimer.restart();
    }

    // Layout isn't meaningfully settled until showLayout flips on (gated by
    // barWindow being ready), so that's the other point we need a fresh,
    // correct snapshot beyond just "after a collapse."
    onShowLayoutChanged: if (showLayout) captureRestTimer.restart()

    property real targetWidth: moduleActive ? (pillHeight + sidePadding + (sidePadding / 4) + (expanded ? (innerSpacing + statsRow.implicitWidth) : 0)) : 0
    width: targetWidth
    Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

    opacity: (showLayout && moduleActive) ? ((barWindow && barWindow.barOpacity !== undefined) ? barWindow.barOpacity : 1.0) : 0.0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    transform: Translate {
        x: sysMonWidgetRoot.showLayout ? 0 : (barWindow ? barWindow.s(60) : 60)
        Behavior on x { NumberAnimation { duration: 800; easing.type: Easing.OutQuint } }
    }

    component SysMonPill: Rectangle {
        id: pillRoot
        property real value: 0
        property string textVal: ""
        property string icon: ""
        property color accentColor: ThemeBackend.mauve
        property bool initAnimTrigger: sysMonWidgetRoot.showLayout

        height: sysMonWidgetRoot.pillHeight
        width: sysMonWidgetRoot.pillWidth
        radius: Math.min(barWindow ? barWindow.s(sysMonWidgetRoot.isCompact ? 9 : 10) : (sysMonWidgetRoot.isCompact ? 9 : 10), height / 2)
        color: sysMonWidgetRoot.isCompact ? Qt.lighter(ThemeBackend.surface0, 1.18) : ThemeBackend.surface0
        border.width: 0
        clip: true

        opacity: initAnimTrigger ? 1.0 : 0.0
        transform: Translate {
            y: initAnimTrigger ? 0 : (barWindow ? barWindow.s(15) : 15)
            Behavior on y { NumberAnimation { duration: 620; easing.type: Easing.OutQuint } }
        }
        Behavior on opacity { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }

        Row {
            id: baseContentRow
            anchors.centerIn: parent
            spacing: barWindow ? barWindow.s(sysMonWidgetRoot.isCompact ? 3 : 4) : (sysMonWidgetRoot.isCompact ? 3 : 4)

            Text {
                text: icon
                font.family: ThemeBackend.fontFamily
                font.pixelSize: barWindow ? barWindow.s(sysMonWidgetRoot.isCompact ? 13.5 : 14.5) : (sysMonWidgetRoot.isCompact ? 13.5 : 14.5)
                color: "#F0E3B6"
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: textVal
                font.family: ThemeBackend.fontFamily
                font.pixelSize: barWindow ? barWindow.s(sysMonWidgetRoot.isCompact ? 12 : 13) : (sysMonWidgetRoot.isCompact ? 12 : 13)
                font.bold: true
                color: "#F0E3B6"
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    Rectangle {
        id: monitorIcon
        z: 10
        width: sysMonWidgetRoot.pillHeight
        height: sysMonWidgetRoot.pillHeight
        anchors.verticalCenter: parent.verticalCenter
        // Compensates for sysMonWidgetRoot.x so this icon's screen position
        // never moves, even while the widget itself slides to make room.
        x: sysMonWidgetRoot.restingRightEdge - sysMonWidgetRoot.x - width - (sysMonWidgetRoot.sidePadding / 2)
        radius: Math.min(barWindow ? barWindow.s(sysMonWidgetRoot.isCompact ? 9 : 10) : (sysMonWidgetRoot.isCompact ? 9 : 10), height / 2)
        color: sysMonWidgetRoot.isCompact ? Qt.lighter(ThemeBackend.surface0, 1.18) : ThemeBackend.surface0
        border.width: 0

        opacity: sysMonWidgetRoot.showLayout ? 1.0 : 0.0
        transform: Translate {
            y: sysMonWidgetRoot.showLayout ? 0 : (barWindow ? barWindow.s(15) : 15)
            Behavior on y { NumberAnimation { duration: 620; easing.type: Easing.OutQuint } }
        }
        Behavior on opacity { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }

        Text {
            anchors.centerIn: parent
            text: "\u{F0379}"
            font.family: ThemeBackend.fontFamily
            font.pixelSize: barWindow ? barWindow.s(sysMonWidgetRoot.isCompact ? 14 : 15) : (sysMonWidgetRoot.isCompact ? 14 : 15)
            color: "#F0E3B6"
        }

        MouseArea {
            z: 10
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: Quickshell.execDetached(["alacritty", "--class", "btop-monitor", "-e", "btop"])
        }
    }

    Item {
        id: statsGroup
        height: sysMonWidgetRoot.pillHeight
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: monitorIcon.left
        anchors.rightMargin: sysMonWidgetRoot.expanded ? sysMonWidgetRoot.innerSpacing : 0
        width: sysMonWidgetRoot.expanded ? statsRow.implicitWidth : 0
        clip: true

        Row {
            id: statsRow
            anchors.right: parent.right
            spacing: sysMonWidgetRoot.innerSpacing

            SysMonPill {
                value: isNaN(SysData.cpu) ? 0 : SysData.cpu / 100.0
                textVal: (isNaN(SysData.cpu) ? 0 : Math.round(SysData.cpu)) + "%"
                icon: ""
                accentColor: ThemeBackend.mauve
            }

            SysMonPill {
                value: isNaN(SysData.ramPercent) ? 0 : SysData.ramPercent / 100.0
                textVal: (isNaN(SysData.ramPercent) ? 0 : Math.round(SysData.ramPercent)) + "%"
                icon: "\u{F035B}"
                accentColor: ThemeBackend.sapphire
            }

            SysMonPill {
                value: isNaN(SysData.temp) ? 0 : Math.max(0, Math.min(1, SysData.temp / 100.0))
                textVal: (isNaN(SysData.temp) ? 0 : Math.round(SysData.temp)) + "°"
                icon: ""
                accentColor: ThemeBackend.red
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: sysMonWidgetRoot.expanded = true
        onExited: sysMonWidgetRoot.expanded = false
    }
}
