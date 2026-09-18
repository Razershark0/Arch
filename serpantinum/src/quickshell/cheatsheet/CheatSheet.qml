import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../"

PanelWindow {
    id: cheatSheetWindow
    color: "transparent"
    focusable: true

    function s(val) { return Scaler.s(val); }

    WlrLayershell.namespace: "qs-cheatsheet"
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    property var groups: [
        {
            header: "Apps",
            entries: [
                ["Super + Return", "Terminal"],
                ["Super + E", "File manager"],
                ["Super + W", "Browser"],
                ["Super + D", "App launcher"],
                ["Super + C", "Clipboard manager"],
            ]
        },
        {
            header: "Windows",
            entries: [
                ["Super + Q", "Close window"],
                ["Super + F", "Fullscreen"],
                ["Super + V", "Toggle floating"],
                ["Super + Shift + F", "Float + center"],
                ["Super + Arrows", "Move focus"],
                ["Super + Ctrl + Arrows", "Swap window"],
                ["Super + Shift + Arrows", "Resize window"],
            ]
        },
        {
            header: "Workspaces",
            entries: [
                ["Super + 1-0", "Switch workspace"],
                ["Super + Shift + 1-0", "Move window to workspace"],
                ["Super + ]", "Next workspace"],
                ["Super + [", "Previous workspace"],
            ]
        },
        {
            header: "System",
            entries: [
                ["Super + A", "Toggle bar autohide"],
                ["Super + L", "Lock screen"],
                ["Super + R", "Reload shell"],
                ["Super + Space", "Play / pause media"],
                ["F9", "This cheat sheet"],
            ]
        },
        {
            header: "Screenshots",
            entries: [
                ["Print", "Region, copy"],
                ["Shift + Print", "Region, edit"],
                ["Super + Print", "Full screen"],
                ["Super + Shift + Print", "Full screen, edit"],
            ]
        },
    ]

    function closeSheet() {
        CheatSheetController.hide();
    }

    MouseArea {
        anchors.fill: parent
        onClicked: cheatSheetWindow.closeSheet()
    }

    Rectangle {
        anchors.fill: parent
        color: "#000000e6"
    }

    FocusScope {
        anchors.centerIn: parent
        width: card.width
        height: card.height
        focus: true

        Keys.onEscapePressed: function(event) {
            cheatSheetWindow.closeSheet();
            event.accepted = true;
        }

        Rectangle {
            id: card
            width: content.width + s(48)
            height: content.height + s(40)
            radius: s(14)
            color: "#110915"

            MouseArea {
                anchors.fill: parent
                onClicked: {}
            }

            ColumnLayout {
                id: content
                anchors.centerIn: parent
                spacing: s(16)

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Keybinds"
                    font.family: ThemeBackend.fontFamily
                    font.weight: Font.Bold
                    font.pixelSize: s(18)
                    color: "#F0E3B6"
                }

                RowLayout {
                    id: columns
                    spacing: s(40)
                    Layout.alignment: Qt.AlignHCenter

                    Repeater {
                        model: 2

                        ColumnLayout {
                            spacing: s(18)
                            Layout.alignment: Qt.AlignTop

                            Repeater {
                                model: cheatSheetWindow.groups.filter((_, i) => i % 2 === index)

                                ColumnLayout {
                                    spacing: s(6)

                                    Text {
                                        text: modelData.header
                                        font.family: ThemeBackend.fontFamily
                                        font.weight: Font.Bold
                                        font.pixelSize: s(13)
                                        color: ThemeBackend.mauve
                                    }

                                    ColumnLayout {
                                        spacing: s(4)

                                        Repeater {
                                            model: modelData.entries

                                            RowLayout {
                                                spacing: s(16)

                                                Text {
                                                    Layout.preferredWidth: s(190)
                                                    Layout.maximumWidth: s(190)
                                                    elide: Text.ElideRight
                                                    text: modelData[0]
                                                    font.family: ThemeBackend.fontFamily
                                                    font.pixelSize: s(12)
                                                    color: ThemeBackend.peach
                                                }

                                                Text {
                                                    text: modelData[1]
                                                    font.family: ThemeBackend.fontFamily
                                                    font.pixelSize: s(12)
                                                    color: ThemeBackend.subtext0
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
        }
    }
}
