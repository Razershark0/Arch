import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower
import "../../../reusables"
import "../../../"

Rectangle {
    id: batWidgetRoot
    property var barWindow
    property bool isSolid: false
    property bool distinctPills: barWindow ? (barWindow.distinctPills !== undefined ? barWindow.distinctPills : false) : false
    property bool moduleActive: true
    property bool isGrouped: false
    property bool isCompact: isGrouped || (isSolid && distinctPills)

    property bool isDesktop: UPower.displayDevice.ready ? !UPower.displayDevice.isLaptopBattery : SystemInfo.isDesktop
    readonly property int batCap: UPower.displayDevice.ready ? Math.round(UPower.displayDevice.percentage * 100) : 0
    readonly property string batPercent: batCap + "%"

    readonly property string batStatus: UPower.displayDevice.ready ? (UPower.displayDevice.state === UPowerDeviceState.FullyCharged ? "Full" : (UPower.displayDevice.state === UPowerDeviceState.Charging ? "Charging" : "Unknown")) : "Unknown"
    readonly property bool isCharging: UPower.displayDevice.ready && (UPower.displayDevice.state === UPowerDeviceState.Charging || UPower.displayDevice.state === UPowerDeviceState.FullyCharged)
    readonly property string batIcon: isDesktop ? "󰐥" : (isCharging ? "󰂄" : (batCap > 20 ? "󰁹" : "󰂃"))

    property color batDynamicColor: ThemeBackend.overlay1

    property real targetX: 0
    property bool showLayout: false
    property alias batPill: batPill

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
    layer.enabled: true

    property real targetWidth: (moduleActive && sysLayout.implicitWidth > 0) ? (sysLayout.implicitWidth + (barWindow ? barWindow.s(isCompact ? 8 : 10) : (isCompact ? 8 : 10))) : 0
    width: targetWidth

    opacity: (showLayout && moduleActive) ? ((barWindow && barWindow.barOpacity !== undefined) ? barWindow.barOpacity : 1.0) : 0.0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    property real globalWavePhase: 0.0
    NumberAnimation on globalWavePhase {
        from: 0
        to: Math.PI * 2
        duration: batWidgetRoot.isCharging ? 1800 : 3600
        loops: Animation.Infinite
        running: batWidgetRoot.showLayout && batWidgetRoot.moduleActive
    }

    Timer {
        running: batWidgetRoot.moduleActive && barWindow && barWindow.isStartupReady && barWindow.isDataReady
        interval: 100
        onTriggered: batWidgetRoot.showLayout = true
    }

    transform: Translate {
        x: batWidgetRoot.showLayout ? 0 : (barWindow ? barWindow.s(60) : 60)
        Behavior on x { NumberAnimation { duration: 800; easing.type: Easing.OutQuint } }
    }

    Row {
        id: sysLayout
        anchors.centerIn: parent
        property int pillHeight: barWindow ? barWindow.s(batWidgetRoot.isCompact ? 28 : 30) : (batWidgetRoot.isCompact ? 28 : 30)

        Rectangle {
            id: batPill
            property bool initAnimTrigger: false

            property real value: batWidgetRoot.isDesktop ? 0.0 : (UPower.displayDevice.ready ? UPower.displayDevice.percentage : 0.0)
            property real animValue: value
            Behavior on animValue { NumberAnimation { duration: 600; easing.type: Easing.OutQuint } }

            property real fillRatio: Math.max(0.0, Math.min(1.0, isNaN(animValue) ? 0.0 : animValue))
            property real fillY: height * (1.0 - fillRatio)
            property real maxWaveAmp: batWidgetRoot.isCharging ? (barWindow ? barWindow.s(3.5) : 3.5) : (barWindow ? barWindow.s(0.5) : 0.5)
            property real waveAmp: (fillRatio < 0.99 && fillRatio > 0.01) ? maxWaveAmp * Math.sin(fillRatio * Math.PI) : 0
            property real waveCenterOffset: 0.375 * waveAmp * (Math.sin(batWidgetRoot.globalWavePhase) - Math.cos(batWidgetRoot.globalWavePhase))

            height: sysLayout.pillHeight
            property real targetWidth: batWidgetRoot.isDesktop ? (barWindow ? barWindow.s(batWidgetRoot.isCompact ? 30 : 32) : (batWidgetRoot.isCompact ? 30 : 32)) : (baseContentRow.implicitWidth + (barWindow ? barWindow.s(batWidgetRoot.isCompact ? 16 : 18) : (batWidgetRoot.isCompact ? 16 : 18)))
            width: targetWidth
            Behavior on width { NumberAnimation { duration: 480; easing.type: Easing.OutQuint } }

            radius: barWindow ? barWindow.s(batWidgetRoot.isCompact ? 9 : 10) : (batWidgetRoot.isCompact ? 9 : 10)
            color: batWidgetRoot.isCompact ? Qt.lighter(ThemeBackend.surface0, 1.18) : ThemeBackend.surface0
            border.width: 0
            clip: true

            Timer {
                running: batWidgetRoot.moduleActive && batWidgetRoot.showLayout && !batPill.initAnimTrigger
                interval: 150
                onTriggered: batPill.initAnimTrigger = true
            }

            opacity: initAnimTrigger ? 1.0 : 0.0
            transform: Translate {
                y: batPill.initAnimTrigger ? 0 : (barWindow ? barWindow.s(15) : 15)
                Behavior on y { NumberAnimation { duration: 620; easing.type: Easing.OutQuint } }
            }
            Behavior on opacity { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }

            Row {
                id: baseContentRow
                anchors.centerIn: parent
                spacing: batWidgetRoot.isDesktop ? 0 : (barWindow ? barWindow.s(5) : 5)

                Text {
                    text: batWidgetRoot.batIcon
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: batWidgetRoot.isDesktop ? (barWindow ? barWindow.s(batWidgetRoot.isCompact ? 15 : 16) : (batWidgetRoot.isCompact ? 15 : 16)) : (barWindow ? barWindow.s(batWidgetRoot.isCompact ? 12 : 13.5) : (batWidgetRoot.isCompact ? 12 : 13.5))
                    color: "#A37E56"
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    visible: !batWidgetRoot.isDesktop
                    text: batWidgetRoot.batPercent
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: barWindow ? barWindow.s(batWidgetRoot.isCompact ? 11 : 12.6) : (batWidgetRoot.isCompact ? 11 : 12.6)
                    font.bold: true
                    color: "#A37E56"
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: BatPanelController.toggle()
            }
        }
    }
}
