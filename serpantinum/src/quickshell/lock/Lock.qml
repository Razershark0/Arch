import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import "../"
import "../reusables"

Scope {
    id: root

    property string currentWallpaperPath: ""
    FileView {
        id: hyprpaperConfWatcher
        path: (Quickshell.env("HOME") ?? "") + "/.config/hypr/hyprpaper.conf"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            let txt = text();
            let m = txt.match(/^\s*path\s*=\s*(.+?)\s*$/m);
            if (m && m[1]) root.currentWallpaperPath = m[1];
        }
    }

    function lock() {
        if (rootLock.locked) return;
        rootLock.locked = true;
        lockUI.failed = false;
        lockUI.authenticating = false;
        pamActionTimer.restart();
    }

    function completeUnlock() {
        rootLock.locked = false;
    }

    Timer {
        id: pamActionTimer
        interval: 350
        onTriggered: {
            if (rootLock.locked) pam.start();
        }
    }

    PamContext {
        id: pam
        onCompleted: (result) => {
            lockUI.authenticating = false;
            if (result === PamResult.Success) {
                root.completeUnlock();
            } else {
                lockUI.failed = true;
                passwordInput.clear();
                passwordInput.triggerShake();
                pamActionTimer.restart();
            }
        }
    }

    IpcHandler {
        target: "lock"
        function activate(): void { root.lock(); }
    }

    WlSessionLock {
        id: rootLock
        locked: false

        surface: Component {
            WlSessionLockSurface {
                id: surface

                Image {
                    anchors.fill: parent
                    source: root.currentWallpaperPath !== "" ? ("file://" + root.currentWallpaperPath) : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }

                Rectangle {
                    anchors.fill: parent
                    color: "#00000055"
                }

                Rectangle {
                    id: box
                    anchors.centerIn: parent
                    width: 320
                    height: content.height + 48
                    radius: 14
                    color: "#110915ee"

                    ColumnLayout {
                        id: content
                        anchors.centerIn: parent
                        width: parent.width - 48
                        spacing: 14

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "󰌾"
                            font.family: "Iosevka Nerd Font"
                            font.pixelSize: 28
                            color: lockUI.failed ? "#f38ba8" : "#A37E56"
                        }

                        PasswordInput {
                            id: passwordInput
                            Layout.fillWidth: true
                            Layout.preferredHeight: 42
                            baseColor: "#1c1220"
                            focusColor: "#1c1220"
                            activeColor: "#1c1220"
                            accentColor: "#A37E56"
                            textColor: "#F0E3B6"
                            errorColor: "#f38ba8"
                            cornerRadius: 9
                            horizontalAlignment: TextInput.AlignHCenter
                            placeholderText: lockUI.failed ? "Wrong password" : "Password"
                            hasError: lockUI.failed
                            isBusy: lockUI.authenticating
                            enabled: !lockUI.authenticating

                            onAccepted: (finalText) => {
                                if (finalText.length > 0 && pam.responseRequired && !lockUI.authenticating) {
                                    lockUI.authenticating = true;
                                    lockUI.failed = false;
                                    pam.respond(finalText);
                                }
                            }

                            onTextEdited: {
                                if (lockUI.failed) lockUI.failed = false;
                            }

                            Component.onCompleted: forceInputFocus()
                        }
                    }
                }

                Item {
                    id: lockUI
                    property bool failed: false
                    property bool authenticating: false
                }

                MouseArea {
                    anchors.fill: parent
                    z: -1
                    onClicked: passwordInput.forceInputFocus()
                }

                Component.onCompleted: passwordInput.forceInputFocus()
            }
        }
    }
}
