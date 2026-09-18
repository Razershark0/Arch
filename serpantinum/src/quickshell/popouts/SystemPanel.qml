import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../"
import "../reusables"

PanelWindow {
    id: panelWindow
    color: "transparent"
    visible: SystemPanelController.isVisible
    focusable: true

    function s(val) { return Scaler.s(val); }

    function closeAndRun(scriptPath) {
        Quickshell.execDetached(["bash", scriptPath]);
        SystemPanelController.hide();
    }

    WlrLayershell.namespace: "system-panel"
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore

    mask: Region { item: barHole; intersection: Intersection.Xor }

    anchors {
        top: true
        right: true
        bottom: true
        left: true
    }

    Item {
        id: barHole
        x: 0
        y: 0
        width: panelWindow.width
        height: SystemPanelController.topOffset + 6
    }

    MouseArea {
        anchors.fill: parent
        onClicked: SystemPanelController.hide()
    }

    Rectangle {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: s(50)
        anchors.rightMargin: s(10)
        width: content.width + s(24)
        height: content.height + s(24)
        radius: s(10)
        color: "#110915"
        border.width: 0

        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        ColumnLayout {
            id: content
            anchors.centerIn: parent
            width: s(240)
            spacing: s(10)

            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.bottomMargin: s(4)
                text: "Power"
                font.family: ThemeBackend.fontFamily
                font.weight: Font.Bold
                font.pixelSize: s(15)
                color: "#F0E3B6"
            }

            FillButton {
                Layout.fillWidth: true
                Layout.preferredHeight: s(42)
                buttonText: "Lock"
                buttonIcon: ""
                accentColor: "#A37E56"
                baseColor: ThemeBackend.surface0
                textColor: ThemeBackend.text
                onTriggered: panelWindow.closeAndRun(Caching.serpantinumDir + "/scripts/lock.sh")
            }

            FillButton {
                Layout.fillWidth: true
                Layout.preferredHeight: s(42)
                buttonText: "Suspend"
                buttonIcon: "ᶻ 𝗓 𝗓"
                accentColor: ThemeBackend.blue
                baseColor: ThemeBackend.surface0
                textColor: ThemeBackend.text
                onTriggered: panelWindow.closeAndRun(Caching.serpantinumDir + "/scripts/system/suspend.sh")
            }

            FillButton {
                Layout.fillWidth: true
                Layout.preferredHeight: s(42)
                buttonText: "Reboot"
                buttonIcon: "󰑓"
                accentColor: ThemeBackend.blue
                baseColor: ThemeBackend.surface0
                textColor: ThemeBackend.text
                onTriggered: panelWindow.closeAndRun(Caching.serpantinumDir + "/scripts/system/reboot.sh")
            }

            FillButton {
                Layout.fillWidth: true
                Layout.preferredHeight: s(42)
                buttonText: "Power Off"
                buttonIcon: ""
                accentColor: ThemeBackend.red
                baseColor: ThemeBackend.surface0
                textColor: ThemeBackend.text
                onTriggered: panelWindow.closeAndRun(Caching.serpantinumDir + "/scripts/system/poweroff.sh")
            }

            ClickButton {
                Layout.fillWidth: true
                Layout.preferredHeight: s(42)
                buttonText: "Logout"
                buttonIcon: "󰍃"
                accentColor: ThemeBackend.surface2
                textColor: ThemeBackend.text
                onTriggered: panelWindow.closeAndRun(Caching.serpantinumDir + "/scripts/system/exit.sh")
            }
        }
    }
}
