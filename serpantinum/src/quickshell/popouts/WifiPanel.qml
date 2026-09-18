import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Networking
import "../"
import "../reusables"

PanelWindow {
    id: panelWindow
    color: "transparent"
    visible: WifiPanelController.isVisible || slideContainer.animProgress > 0.001
    focusable: WifiPanelController.isVisible

    function s(val) { return Scaler.s(val); }

    WlrLayershell.namespace: "wifi-panel"
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore

    mask: Region { item: barHole; intersection: Intersection.Xor }

    anchors {
        top: true
        right: true
        bottom: true
        left: true
    }

    property real boxWidth: Math.max(1, WifiPanelController.panelWidth)
    property real boxHeight: boxWidth

    Item {
        id: barHole
        x: 0
        y: 0
        width: panelWindow.width
        height: WifiPanelController.topOffset + 6
    }

    MouseArea {
        anchors.fill: parent
        onClicked: WifiPanelController.hide()
    }

    property bool isWifiOn: Networking.wifiEnabled
    property bool hwEnabled: Networking.wifiHardwareEnabled
    property var wifiDevice: null
    property var pendingPsk: null
    property string pskError: ""
    property string localIp: ""

    Repeater {
        model: Networking.devices
        Item {
            property var device: modelData
            Component.onCompleted: {
                if (device && device.type === DeviceType.Wifi) {
                    panelWindow.wifiDevice = device;
                }
            }
        }
    }

    Process {
        id: ipFetcher
        command: ["nmcli", "-g", "IP4.ADDRESS", "device", "show", panelWindow.wifiDevice ? panelWindow.wifiDevice.name : ""]
        stdout: StdioCollector {
            onStreamFinished: {
                panelWindow.localIp = this.text.trim().split("/")[0].split("\n")[0];
            }
        }
    }

    function refreshIp() {
        if (wifiDevice && wifiDevice.connected) {
            ipFetcher.running = false;
            ipFetcher.running = true;
        } else {
            localIp = "";
        }
    }

    Connections {
        target: wifiDevice
        ignoreUnknownSignals: true
        function onConnectedChanged() { panelWindow.refreshIp(); }
    }

    Binding {
        target: panelWindow.wifiDevice
        property: "scannerEnabled"
        value: panelWindow.visible && panelWindow.isWifiOn
        when: panelWindow.wifiDevice !== null
    }

    Process {
        id: rescanTrigger
        command: ["nmcli", "device", "wifi", "rescan"]
    }

    function requestRescan() {
        if (panelWindow.visible && panelWindow.isWifiOn && panelWindow.wifiDevice) {
            rescanTrigger.running = false;
            rescanTrigger.running = true;
        }
    }

    onIsWifiOnChanged: requestRescan()
    onWifiDeviceChanged: requestRescan()

    onVisibleChanged: {
        if (panelWindow.visible) {
            refreshIp();
            requestRescan();
        }
        if (!WifiPanelController.isVisible) {
            pendingPsk = null;
            pskError = "";
        }
    }

    function attemptConnect(network) {
        if (!network) return;
        if (network.connected) {
            network.disconnect();
            return;
        }
        pskError = "";
        if (network.known || network.security === WifiSecurityType.Open) {
            pendingPsk = null;
            network.connect();
        } else {
            pendingPsk = network;
        }
    }

    Item {
        id: slideContainer
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: WifiPanelController.topOffset + 6
        anchors.rightMargin: 6
        width: panelWindow.boxWidth
        height: panelWindow.boxHeight
        clip: true

        property real animProgress: WifiPanelController.isVisible ? 1.0 : 0.0
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
                    text: "Wifi"
                    font.family: ThemeBackend.fontFamily
                    font.weight: Font.Bold
                    font.pixelSize: panelWindow.s(16)
                    color: "#F0E3B6"
                    Layout.fillWidth: true
                }

                Item {
                    id: wifiToggle
                    width: panelWindow.s(40)
                    height: panelWindow.s(22)
                    property bool checked: panelWindow.isWifiOn
                    enabled: panelWindow.hwEnabled

                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: wifiToggle.checked ? "#A37E56" : ThemeBackend.surface1
                        opacity: wifiToggle.enabled ? 1.0 : 0.5
                        Behavior on color { ColorAnimation { duration: 180 } }

                        Rectangle {
                            width: parent.height - panelWindow.s(4)
                            height: parent.height - panelWindow.s(4)
                            radius: height / 2
                            color: "#ffffff"
                            y: panelWindow.s(2)
                            x: wifiToggle.checked ? (parent.width - width - panelWindow.s(2)) : panelWindow.s(2)
                            Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: wifiToggle.enabled
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Networking.wifiEnabled = !Networking.wifiEnabled
                    }
                }

                IconButton {
                    size: panelWindow.s(22)
                    cornerRadius: panelWindow.s(6)
                    buttonIcon: "×"
                    iconFontSize: panelWindow.s(14)
                    accentColor: ThemeBackend.surface0
                    textColor: ThemeBackend.text
                    onClicked: WifiPanelController.hide()
                }
            }

            Item {
                id: bodyArea
                Layout.fillWidth: true
                Layout.fillHeight: true

                Text {
                    visible: !panelWindow.hwEnabled
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.topMargin: panelWindow.s(20)
                    text: "Wifi hardware is off (check airplane mode / the physical switch)."
                    wrapMode: Text.WordWrap
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: panelWindow.s(12)
                    color: ThemeBackend.subtext0
                }

                Text {
                    visible: panelWindow.hwEnabled && !panelWindow.isWifiOn
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.topMargin: panelWindow.s(20)
                    text: "Wi-Fi is off."
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: panelWindow.s(12)
                    color: ThemeBackend.subtext0
                }

                ScrollView {
                    visible: panelWindow.hwEnabled && panelWindow.isWifiOn
                    anchors.fill: parent
                    clip: true
                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                    ColumnLayout {
                        width: parent.width
                        spacing: panelWindow.s(4)

                    Repeater {
                        model: panelWindow.wifiDevice ? panelWindow.wifiDevice.networks : null

                        delegate: ColumnLayout {
                            id: netDelegate
                            Layout.fillWidth: true
                            spacing: 0
                            property var network: modelData

                            Connections {
                                target: netDelegate.network
                                ignoreUnknownSignals: true
                                function onConnectionFailed(reason) {
                                    panelWindow.pendingPsk = netDelegate.network;
                                    panelWindow.pskError = ConnectionFailReason.toString(reason);
                                    pwField.markError();
                                }
                                function onConnectedChanged() {
                                    if (netDelegate.network && netDelegate.network.connected && panelWindow.pendingPsk === netDelegate.network) {
                                        panelWindow.pendingPsk = null;
                                        panelWindow.pskError = "";
                                    }
                                }
                            }

                            Rectangle {
                                id: netRow
                                Layout.fillWidth: true
                                Layout.preferredHeight: rowH
                                property bool isConnected: netDelegate.network && netDelegate.network.connected
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
                                            text: {
                                                let sig = netDelegate.network ? netDelegate.network.signalStrength : 0;
                                                sig = sig !== undefined ? Math.round(sig * (sig <= 1 ? 100 : 1)) : 0;
                                                if (sig >= 80) return "\u{F0928}";
                                                if (sig >= 60) return "\u{F0925}";
                                                if (sig >= 40) return "\u{F0922}";
                                                if (sig >= 20) return "\u{F091F}";
                                                return "\u{F092F}";
                                            }
                                            font.family: "Iosevka Nerd Font"
                                            font.pixelSize: panelWindow.s(15)
                                            color: ThemeBackend.text
                                        }

                                        Text {
                                            visible: netDelegate.network && netDelegate.network.security !== WifiSecurityType.Open
                                            text: ""
                                            font.family: "Iosevka Nerd Font"
                                            font.pixelSize: panelWindow.s(11)
                                            color: ThemeBackend.subtext0
                                        }

                                        Text {
                                            text: netDelegate.network ? netDelegate.network.name : ""
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                            font.family: ThemeBackend.fontFamily
                                            font.pixelSize: panelWindow.s(12)
                                            color: ThemeBackend.text
                                        }
                                    }

                                    Text {
                                        visible: netDelegate.network && (netDelegate.network.connected || netDelegate.network.stateChanging)
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                        text: {
                                            if (!netDelegate.network) return "";
                                            if (netDelegate.network.connected) {
                                                let base = netDelegate.network.security !== WifiSecurityType.Open ? "Connected, secured" : "Connected";
                                                let ip = panelWindow.localIp;
                                                return ip !== "" ? (base + " · " + ip) : base;
                                            }
                                            return ConnectionState.toString(netDelegate.network.state);
                                        }
                                        font.family: ThemeBackend.fontFamily
                                        font.pixelSize: panelWindow.s(10)
                                        color: "#F0E3B6"
                                    }

                                    RowLayout {
                                        visible: netRow.isConnected
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
                                            onClicked: netDelegate.network.disconnect()
                                        }
                                    }
                                }

                                MouseArea {
                                    id: rowMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: panelWindow.attemptConnect(netDelegate.network)
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.leftMargin: panelWindow.s(10)
                                Layout.rightMargin: panelWindow.s(10)
                                Layout.topMargin: panelWindow.s(4)
                                Layout.bottomMargin: panelWindow.s(8)
                                spacing: panelWindow.s(6)
                                visible: panelWindow.pendingPsk === netDelegate.network

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: panelWindow.s(6)

                                    PasswordInput {
                                        id: pwField
                                        Layout.fillWidth: true
                                        implicitHeight: panelWindow.s(34)
                                        placeholderText: "Password"
                                        showSubmitButton: false
                                        onAccepted: (finalText) => {
                                            if (netDelegate.network) netDelegate.network.connectWithPsk(finalText);
                                        }
                                    }

                                    IconButton {
                                        size: panelWindow.s(34)
                                        cornerRadius: panelWindow.s(8)
                                        buttonIcon: ""
                                        iconFontSize: panelWindow.s(13)
                                        accentColor: "#A37E56"
                                        textColor: ThemeBackend.crust
                                        onClicked: {
                                            if (netDelegate.network) netDelegate.network.connectWithPsk(pwField.text);
                                        }
                                    }
                                }

                                Text {
                                    visible: panelWindow.pskError !== "" && panelWindow.pendingPsk === netDelegate.network
                                    text: panelWindow.pskError
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: panelWindow.s(10)
                                    color: ThemeBackend.red
                                    wrapMode: Text.WordWrap
                                    Layout.fillWidth: true
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
