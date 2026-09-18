import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.UPower
import "../"
import "../reusables"

PanelWindow {
    id: panelWindow
    color: "transparent"
    visible: BatPanelController.isVisible || slideContainer.animProgress > 0.001
    focusable: BatPanelController.isVisible

    function s(val) { return Scaler.s(val); }

    WlrLayershell.namespace: "bat-panel"
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore

    mask: Region { item: barHole; intersection: Intersection.Xor }

    anchors {
        top: true
        right: true
        bottom: true
        left: true
    }

    property real boxWidth: Math.max(1, BatPanelController.panelWidth)
    property real boxHeight: mainColumn.implicitHeight + s(32)

    Item {
        id: barHole
        x: BatPanelController.seamlessX
        y: 0
        width: BatPanelController.seamlessWidth
        height: BatPanelController.topOffset + 6
    }

    MouseArea {
        anchors.fill: parent
        onClicked: BatPanelController.hide()
    }

    readonly property var dev: UPower.displayDevice
    readonly property bool devReady: dev && dev.ready
    readonly property real batPercent: devReady ? dev.percentage : 0
    readonly property int state: devReady ? dev.state : UPowerDeviceState.Unknown
    readonly property bool isCharging: state === UPowerDeviceState.Charging
    readonly property bool isFull: state === UPowerDeviceState.FullyCharged
    readonly property real healthPercent: devReady && dev.healthSupported ? dev.healthPercentage : -1

    function formatTime(seconds) {
        if (!seconds || seconds <= 0) return "";
        let totalMin = Math.round(seconds / 60);
        let h = Math.floor(totalMin / 60);
        let m = totalMin % 60;
        if (h > 0) return h + "h " + m + "m";
        return m + "m";
    }

    readonly property string timeLine: {
        if (!devReady) return "";
        if (isCharging) {
            let t = formatTime(dev.timeToFull);
            return t !== "" ? (t + " until full") : "";
        }
        if (!isCharging && !isFull) {
            let t = formatTime(dev.timeToEmpty);
            return t !== "" ? (t + " remaining") : "";
        }
        return "";
    }

    property int cycleCount: -1
    property int startThresh: -1
    property int stopThresh: -1

    Process {
        id: statFetcher
        command: ["bash", "-c", "cat /sys/class/power_supply/BAT1/cycle_count /sys/class/power_supply/BAT1/charge_control_start_threshold /sys/class/power_supply/BAT1/charge_control_end_threshold 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = this.text.trim().split("\n");
                if (lines.length >= 3) {
                    panelWindow.cycleCount = parseInt(lines[0]) || 0;
                    panelWindow.startThresh = parseInt(lines[1]) || 0;
                    panelWindow.stopThresh = parseInt(lines[2]) || 0;
                }
            }
        }
    }

    function refreshStats() {
        statFetcher.running = false;
        statFetcher.running = true;
    }

    onVisibleChanged: if (panelWindow.visible) refreshStats()

    readonly property string activePreset: {
        if (startThresh === 75 && stopThresh === 80) return "longevity";
        if (startThresh === 75 && stopThresh === 90) return "balanced";
        if (stopThresh === 100) return "full";
        return "";
    }

    Process {
        id: actionRunner
        property string pendingAction: ""
        command: ["sudo", "bash", Caching.qsDir + "/../scripts/battery_charge.sh", pendingAction]
        onExited: panelWindow.refreshStats()
    }

    function runAction(action) {
        actionRunner.pendingAction = action;
        actionRunner.running = false;
        actionRunner.running = true;
    }

    Item {
        id: slideContainer
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: BatPanelController.topOffset + 6
        anchors.rightMargin: 6
        width: panelWindow.boxWidth
        height: panelWindow.boxHeight
        clip: true

        property real animProgress: BatPanelController.isVisible ? 1.0 : 0.0
        Behavior on animProgress {
            NumberAnimation { duration: 320; easing.type: Easing.OutQuint }
        }

        transform: Translate { x: panelWindow.boxWidth * (1.0 - slideContainer.animProgress) }

        Rectangle {
            anchors.fill: parent
            radius: panelWindow.s(9)
            color: "#110915"
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        ColumnLayout {
            id: mainColumn
            anchors.fill: parent
            anchors.margins: panelWindow.s(16)
            spacing: panelWindow.s(10)

                RowLayout {
                    Layout.fillWidth: true
                    spacing: panelWindow.s(8)

                    Text {
                        text: "Battery"
                        font.family: ThemeBackend.fontFamily
                        font.weight: Font.Bold
                        font.pixelSize: panelWindow.s(16)
                        color: "#F0E3B6"
                        Layout.fillWidth: true
                    }

                    IconButton {
                        size: panelWindow.s(22)
                        cornerRadius: panelWindow.s(6)
                        buttonIcon: "×"
                        iconFontSize: panelWindow.s(14)
                        accentColor: ThemeBackend.surface0
                        textColor: ThemeBackend.text
                        onClicked: BatPanelController.hide()
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: panelWindow.s(14)
                    radius: height / 2
                    color: ThemeBackend.surface1

                    Rectangle {
                        height: parent.height
                        width: parent.width * Math.max(0, Math.min(1, panelWindow.batPercent))
                        radius: parent.radius
                        color: "#A37E56"
                        Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: Math.round(panelWindow.batPercent * 100) + "%" + (panelWindow.timeLine !== "" ? (" · " + panelWindow.timeLine) : "")
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: panelWindow.s(12)
                    color: ThemeBackend.text
                }

                Text {
                    visible: panelWindow.healthPercent >= 0 || panelWindow.cycleCount >= 0
                    Layout.fillWidth: true
                    text: {
                        let parts = [];
                        if (panelWindow.healthPercent >= 0) parts.push("Health " + Math.round(panelWindow.healthPercent) + "%");
                        if (panelWindow.cycleCount >= 0) parts.push(panelWindow.cycleCount + " cycles");
                        return parts.join(" · ");
                    }
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: panelWindow.s(10)
                    color: ThemeBackend.subtext0
                }

                Text {
                    Layout.fillWidth: true
                    Layout.topMargin: panelWindow.s(6)
                    text: "Charge Limit"
                    font.family: ThemeBackend.fontFamily
                    font.weight: Font.Bold
                    font.pixelSize: panelWindow.s(11)
                    color: ThemeBackend.subtext0
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: panelWindow.s(6)

                    ClickButton {
                        Layout.fillWidth: true
                        buttonText: "Longevity"
                        subText: "80%"
                        textFontSize: panelWindow.s(10)
                        cornerRadius: panelWindow.s(7)
                        height: panelWindow.s(38)
                        accentColor: panelWindow.activePreset === "longevity" ? "#A37E56" : ThemeBackend.surface1
                        textColor: panelWindow.activePreset === "longevity" ? ThemeBackend.crust : ThemeBackend.text
                        onClicked: panelWindow.runAction("longevity")
                    }

                    ClickButton {
                        Layout.fillWidth: true
                        buttonText: "Balanced"
                        subText: "90%"
                        textFontSize: panelWindow.s(10)
                        cornerRadius: panelWindow.s(7)
                        height: panelWindow.s(38)
                        accentColor: panelWindow.activePreset === "balanced" ? "#A37E56" : ThemeBackend.surface1
                        textColor: panelWindow.activePreset === "balanced" ? ThemeBackend.crust : ThemeBackend.text
                        onClicked: panelWindow.runAction("balanced")
                    }

                    ClickButton {
                        Layout.fillWidth: true
                        buttonText: "Full"
                        subText: "100%"
                        textFontSize: panelWindow.s(10)
                        cornerRadius: panelWindow.s(7)
                        height: panelWindow.s(38)
                        accentColor: panelWindow.activePreset === "full" ? "#A37E56" : ThemeBackend.surface1
                        textColor: panelWindow.activePreset === "full" ? ThemeBackend.crust : ThemeBackend.text
                        onClicked: panelWindow.runAction("full")
                    }
                }

                ClickButton {
                    Layout.fillWidth: true
                    Layout.bottomMargin: panelWindow.s(4)
                    buttonText: "Charge to 100% tonight"
                    textFontSize: panelWindow.s(11)
                    cornerRadius: panelWindow.s(7)
                    height: panelWindow.s(32)
                    accentColor: ThemeBackend.surface1
                    textColor: ThemeBackend.text
                    onClicked: panelWindow.runAction("chargeonce")
                }
        }
    }
}
