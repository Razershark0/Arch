import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import "../"
import "../reusables"

PanelWindow {
    id: panelWindow
    color: "transparent"
    visible: NotifPanelController.isVisible || slideContainer.animProgress > 0.001
    focusable: NotifPanelController.isVisible

    function s(val) { return Scaler.s(val); }

    WlrLayershell.namespace: "notif-panel"
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore

    mask: Region { item: barHole; intersection: Intersection.Xor }

    anchors {
        top: true
        right: true
        bottom: true
        left: true
    }

    property real boxWidth: Math.max(1, NotifPanelController.panelWidth)
    property real boxHeight: mainColumn.implicitHeight + s(32)
    readonly property real maxListHeight: s(440)
    readonly property int notifCount: NotificationManager.globalNotificationHistory.count

    // Re-evaluated on a timer so the "5m ago" labels stay current while open.
    property real nowMs: Date.now()
    Timer {
        interval: 30000
        repeat: true
        running: panelWindow.visible
        onTriggered: panelWindow.nowMs = Date.now()
    }
    onVisibleChanged: if (visible) nowMs = Date.now()

    function timeAgo(ts) {
        let sec = Math.max(0, Math.round((nowMs - ts) / 1000));
        if (sec < 60) return "now";
        let min = Math.floor(sec / 60);
        if (min < 60) return min + "m ago";
        let h = Math.floor(min / 60);
        if (h < 24) return h + "h ago";
        return Math.floor(h / 24) + "d ago";
    }

    Item {
        id: barHole
        x: 0
        y: 0
        width: panelWindow.width
        height: NotifPanelController.topOffset + 6
    }

    MouseArea {
        anchors.fill: parent
        onClicked: NotifPanelController.hide()
    }

    Item {
        id: slideContainer
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: NotifPanelController.topOffset + 6
        anchors.rightMargin: 6
        width: panelWindow.boxWidth
        height: panelWindow.boxHeight
        clip: true

        property real animProgress: NotifPanelController.isVisible ? 1.0 : 0.0
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
                    text: "Notifications"
                    font.family: ThemeBackend.fontFamily
                    font.weight: Font.Bold
                    font.pixelSize: panelWindow.s(16)
                    color: "#F0E3B6"
                    Layout.fillWidth: true
                }

                ClickButton {
                    visible: panelWindow.notifCount > 0
                    buttonText: "Clear all"
                    textFontSize: panelWindow.s(10)
                    cornerRadius: panelWindow.s(6)
                    height: panelWindow.s(22)
                    accentColor: ThemeBackend.surface0
                    textColor: ThemeBackend.text
                    onClicked: NotificationManager.clearNotifications()
                }

                IconButton {
                    size: panelWindow.s(22)
                    cornerRadius: panelWindow.s(6)
                    buttonIcon: "×"
                    iconFontSize: panelWindow.s(14)
                    accentColor: ThemeBackend.surface0
                    textColor: ThemeBackend.text
                    onClicked: NotifPanelController.hide()
                }
            }

            Text {
                visible: panelWindow.notifCount === 0
                Layout.fillWidth: true
                Layout.topMargin: panelWindow.s(8)
                Layout.bottomMargin: panelWindow.s(12)
                horizontalAlignment: Text.AlignHCenter
                text: "No notifications"
                font.family: ThemeBackend.fontFamily
                font.pixelSize: panelWindow.s(12)
                color: ThemeBackend.subtext0
            }

            ListView {
                id: notifList
                visible: panelWindow.notifCount > 0
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(contentHeight, panelWindow.maxListHeight)
                Layout.bottomMargin: panelWindow.s(4)
                spacing: panelWindow.s(6)
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: NotificationManager.globalNotificationHistory

                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                delegate: Rectangle {
                    id: row
                    width: notifList.width
                    height: rowLayout.implicitHeight + panelWindow.s(16)
                    radius: panelWindow.s(8)
                    color: ThemeBackend.surface0

                    readonly property bool isCritical: model.urgency === 2

                    Rectangle {
                        visible: row.isCritical
                        width: panelWindow.s(3)
                        height: parent.height - panelWindow.s(12)
                        anchors.left: parent.left
                        anchors.leftMargin: panelWindow.s(3)
                        anchors.verticalCenter: parent.verticalCenter
                        radius: width / 2
                        color: ThemeBackend.red
                    }

                    RowLayout {
                        id: rowLayout
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.margins: panelWindow.s(8)
                        spacing: panelWindow.s(10)

                        Rectangle {
                            Layout.alignment: Qt.AlignTop
                            Layout.preferredWidth: panelWindow.s(32)
                            Layout.preferredHeight: panelWindow.s(32)
                            radius: panelWindow.s(8)
                            color: ThemeBackend.surface1
                            clip: true

                            Image {
                                id: rowIcon
                                anchors.fill: parent
                                anchors.margins: panelWindow.s(3)
                                sourceSize: Qt.size(64, 64)
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                visible: source !== "" && status === Image.Ready
                                source: {
                                    let ic = model.image || model.iconPath || "";
                                    if (!ic) return "";
                                    if (ic.startsWith("file://") || ic.startsWith("image://") || ic.startsWith("http://") || ic.startsWith("https://")) return ic;
                                    if (ic.startsWith("/")) return "file://" + ic;
                                    return Quickshell.iconPath(ic, true);
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: !rowIcon.visible
                                text: "󰋽"
                                font.family: "Iosevka Nerd Font Propo"
                                font.pixelSize: panelWindow.s(16)
                                color: ThemeBackend.subtext0
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignTop
                            spacing: panelWindow.s(2)

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: panelWindow.s(6)

                                Rectangle {
                                    visible: !model.read
                                    Layout.preferredWidth: panelWindow.s(6)
                                    Layout.preferredHeight: panelWindow.s(6)
                                    radius: width / 2
                                    color: "#A37E56"
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: (model.appName || "System") + " · " + panelWindow.timeAgo(model.timestamp)
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: panelWindow.s(10)
                                    color: ThemeBackend.subtext0
                                    elide: Text.ElideRight
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: model.summary
                                font.family: ThemeBackend.fontFamily
                                font.weight: Font.Bold
                                font.pixelSize: panelWindow.s(12)
                                color: ThemeBackend.text
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                            }

                            Text {
                                visible: text !== ""
                                Layout.fillWidth: true
                                text: model.body
                                textFormat: Text.StyledText
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: panelWindow.s(11)
                                color: ThemeBackend.subtext0
                                wrapMode: Text.Wrap
                                maximumLineCount: 3
                                elide: Text.ElideRight
                            }
                        }

                        IconButton {
                            Layout.alignment: Qt.AlignTop
                            size: panelWindow.s(20)
                            cornerRadius: panelWindow.s(6)
                            buttonIcon: "×"
                            iconFontSize: panelWindow.s(12)
                            accentColor: ThemeBackend.surface1
                            textColor: ThemeBackend.text
                            onClicked: NotificationManager.dismissNotification(model.uid)
                        }
                    }
                }
            }
        }
    }
}
