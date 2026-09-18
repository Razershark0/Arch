import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Bluetooth
import "../"
import "../reusables"

PanelWindow {
    id: panelWindow
    color: "transparent"
    visible: BtPanelController.isVisible || slideContainer.animProgress > 0.001
    focusable: BtPanelController.isVisible

    function s(val) { return Scaler.s(val); }

    WlrLayershell.namespace: "bt-panel"
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore

    mask: Region { item: barHole; intersection: Intersection.Xor }

    anchors {
        top: true
        right: true
        bottom: true
        left: true
    }

    property real boxWidth: Math.max(1, BtPanelController.panelWidth)
    property real boxHeight: boxWidth

    Item {
        id: barHole
        x: 0
        y: 0
        width: panelWindow.width
        height: BtPanelController.topOffset + 6
    }

    MouseArea {
        anchors.fill: parent
        onClicked: BtPanelController.hide()
    }

    property var adapter: Bluetooth.defaultAdapter
    property bool isBtOn: adapter ? adapter.enabled : false

    Binding {
        target: panelWindow.adapter
        property: "discovering"
        value: panelWindow.visible && panelWindow.isBtOn
        when: panelWindow.adapter !== null
    }

    onVisibleChanged: {
        if (!BtPanelController.isVisible) {
            pendingPair = null;
        }
    }

    property var pendingPair: null

    function deviceIcon(device) {
        if (!device) return "\u{F00AF}";
        let name = (device.name || device.deviceName || "").toLowerCase();
        let iconType = (device.icon || "").toLowerCase();

        if (iconType.indexOf("headset") !== -1 || iconType.indexOf("headphone") !== -1 || name.indexOf("headphone") !== -1 || name.indexOf("buds") !== -1 || name.indexOf("pods") !== -1) return "\u{F02CB}";
        if (iconType.indexOf("audio") !== -1 || iconType.indexOf("speaker") !== -1 || iconType.indexOf("card") !== -1 || name.indexOf("speaker") !== -1) return "\u{F04C3}";
        if (iconType.indexOf("phone") !== -1 || name.indexOf("phone") !== -1 || name.indexOf("android") !== -1) return "\u{F011C}";
        if (iconType.indexOf("mouse") !== -1 || name.indexOf("mouse") !== -1) return "\u{F037D}";
        if (iconType.indexOf("keyboard") !== -1 || name.indexOf("keyboard") !== -1) return "\u{F030C}";
        if (iconType.indexOf("controller") !== -1 || name.indexOf("controller") !== -1) return "\u{F0296}";
        return "\u{F00AF}";
    }

    function attemptConnect(device) {
        if (!device) return;
        if (device.connected) {
            device.disconnect();
            return;
        }
        if (device.paired) {
            device.connect();
        } else {
            pendingPair = device;
            device.pair();
        }
    }

    Item {
        id: slideContainer
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: BtPanelController.topOffset + 6
        anchors.rightMargin: 6
        width: panelWindow.boxWidth
        height: panelWindow.boxHeight
        clip: true

        property real animProgress: BtPanelController.isVisible ? 1.0 : 0.0
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
            anchors.fill: parent
            anchors.margins: panelWindow.s(16)
            spacing: panelWindow.s(10)

            RowLayout {
                Layout.fillWidth: true
                spacing: panelWindow.s(8)

                Text {
                    text: "Bluetooth"
                    font.family: ThemeBackend.fontFamily
                    font.weight: Font.Bold
                    font.pixelSize: panelWindow.s(16)
                    color: "#F0E3B6"
                    Layout.fillWidth: true
                }

                Item {
                    id: btToggle
                    width: panelWindow.s(40)
                    height: panelWindow.s(22)
                    property bool checked: panelWindow.isBtOn

                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: btToggle.checked ? "#A37E56" : ThemeBackend.surface1
                        Behavior on color { ColorAnimation { duration: 180 } }

                        Rectangle {
                            width: parent.height - panelWindow.s(4)
                            height: parent.height - panelWindow.s(4)
                            radius: height / 2
                            color: "#ffffff"
                            y: panelWindow.s(2)
                            x: btToggle.checked ? (parent.width - width - panelWindow.s(2)) : panelWindow.s(2)
                            Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (panelWindow.adapter) panelWindow.adapter.enabled = !panelWindow.adapter.enabled;
                        }
                    }
                }

                IconButton {
                    size: panelWindow.s(22)
                    cornerRadius: panelWindow.s(6)
                    buttonIcon: "×"
                    iconFontSize: panelWindow.s(14)
                    accentColor: ThemeBackend.surface0
                    textColor: ThemeBackend.text
                    onClicked: BtPanelController.hide()
                }
            }

            Item {
                id: bodyArea
                Layout.fillWidth: true
                Layout.fillHeight: true

                Text {
                    visible: !panelWindow.adapter
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.topMargin: panelWindow.s(20)
                    text: "No Bluetooth adapter found."
                    wrapMode: Text.WordWrap
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: panelWindow.s(12)
                    color: ThemeBackend.subtext0
                }

                Text {
                    visible: panelWindow.adapter && !panelWindow.isBtOn
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.topMargin: panelWindow.s(20)
                    text: "Bluetooth is off."
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: panelWindow.s(12)
                    color: ThemeBackend.subtext0
                }

                ScrollView {
                    visible: panelWindow.adapter && panelWindow.isBtOn
                    anchors.fill: parent
                    clip: true
                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                    ColumnLayout {
                        width: parent.width
                        spacing: panelWindow.s(4)

                        Repeater {
                            model: panelWindow.adapter ? panelWindow.adapter.devices : null

                            delegate: ColumnLayout {
                                id: devDelegate
                                Layout.fillWidth: true
                                spacing: 0
                                property var device: modelData

                                Rectangle {
                                    id: devRow
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: rowH
                                    property bool isConnected: devDelegate.device && devDelegate.device.connected
                                    property real rowH: isConnected ? (cardContent.implicitHeight + panelWindow.s(12)) : panelWindow.s(40)
                                    Behavior on rowH { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                    radius: panelWindow.s(9)
                                    clip: true
                                    color: isConnected
                                        ? Qt.alpha("#A37E56", 0.16)
                                        : (rowMa.containsMouse ? ThemeBackend.surface0 : "transparent")

                                    Behavior on color { ColorAnimation { duration: 150 } }

                                    ColumnLayout {
                                        id: cardContent
                                        anchors.fill: parent
                                        anchors.leftMargin: panelWindow.s(10)
                                        anchors.rightMargin: panelWindow.s(10)
                                        anchors.topMargin: panelWindow.s(6)
                                        anchors.bottomMargin: panelWindow.s(6)
                                        spacing: panelWindow.s(2)

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: panelWindow.s(8)

                                            Text {
                                                text: panelWindow.deviceIcon(devDelegate.device)
                                                font.family: "Iosevka Nerd Font"
                                                font.pixelSize: panelWindow.s(14)
                                                color: ThemeBackend.text
                                            }

                                            Text {
                                                text: devDelegate.device ? (devDelegate.device.name || devDelegate.device.deviceName || "") : ""
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                                font.family: ThemeBackend.fontFamily
                                                font.pixelSize: panelWindow.s(12)
                                                color: ThemeBackend.text
                                            }

                                            Text {
                                                visible: devDelegate.device && !devDelegate.device.paired && !devRow.isConnected
                                                text: "Pair"
                                                font.family: ThemeBackend.fontFamily
                                                font.pixelSize: panelWindow.s(10)
                                                color: ThemeBackend.subtext0
                                            }
                                        }

                                        Text {
                                            visible: devDelegate.device && (devDelegate.device.pairing || devDelegate.device.state !== BluetoothDeviceState.Disconnected)
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                            text: {
                                                if (!devDelegate.device) return "";
                                                if (devDelegate.device.connected) {
                                                    let batt = devDelegate.device.batteryAvailable ? (" · " + Math.round(devDelegate.device.battery * 100) + "%") : "";
                                                    return "Connected" + batt;
                                                }
                                                if (devDelegate.device.pairing) return "Pairing…";
                                                return BluetoothDeviceState.toString(devDelegate.device.state);
                                            }
                                            font.family: ThemeBackend.fontFamily
                                            font.pixelSize: panelWindow.s(10)
                                            color: "#A37E56"
                                        }

                                        RowLayout {
                                            visible: devRow.isConnected
                                            Layout.fillWidth: true
                                            Layout.topMargin: panelWindow.s(2)

                                            Item { Layout.fillWidth: true }

                                            ClickButton {
                                                buttonText: "Disconnect"
                                                accentColor: ThemeBackend.surface1
                                                textColor: ThemeBackend.text
                                                horizontalPadding: panelWindow.s(10)
                                                textFontSize: panelWindow.s(10)
                                                cornerRadius: panelWindow.s(7)
                                                height: panelWindow.s(24)
                                                onClicked: devDelegate.device.disconnect()
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: rowMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: panelWindow.attemptConnect(devDelegate.device)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
