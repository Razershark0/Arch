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

    QtObject {
        id: lockUI
        property bool failed: false
        property bool authenticating: false
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
                    color: "#00000099"
                }

                Canvas {
                    id: matrixCanvas
                    anchors.fill: parent

                    readonly property int charSize: 16
                    readonly property string charset: {
                        let s = "0123456789";
                        for (let c = 0xFF66; c <= 0xFF9D; c++) s += String.fromCharCode(c);
                        return s;
                    }
                    property var columns: []

                    function resetColumns() {
                        let n = Math.ceil(width / charSize);
                        let arr = [];
                        for (let i = 0; i < n; i++) {
                            arr.push({ y: Math.random() * -40, speed: 0.4 + Math.random() * 0.5 });
                        }
                        columns = arr;
                    }

                    Component.onCompleted: resetColumns()
                    onWidthChanged: resetColumns()
                    onHeightChanged: resetColumns()

                    onPaint: {
                        let ctx = getContext("2d");
                        ctx.fillStyle = "rgba(0, 0, 0, 0.12)";
                        ctx.fillRect(0, 0, width, height);
                        ctx.font = charSize + "px 'JetBrains Mono'";
                        ctx.textBaseline = "top";
                        for (let i = 0; i < columns.length; i++) {
                            let col = columns[i];
                            let ch = charset[Math.floor(Math.random() * charset.length)];
                            ctx.fillStyle = (i % 7 === 0) ? "#e6ccff" : "#9b30ff";
                            ctx.fillText(ch, i * charSize, col.y * charSize);
                            col.y += col.speed;
                            if (col.y * charSize > height && Math.random() > 0.975) {
                                col.y = Math.random() * -20;
                                col.speed = 0.4 + Math.random() * 0.5;
                            }
                        }
                    }

                    Timer {
                        interval: 60
                        running: true
                        repeat: true
                        onTriggered: matrixCanvas.requestPaint()
                    }
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

                Connections {
                    target: lockUI
                    function onFailedChanged() {
                        if (lockUI.failed) {
                            passwordInput.clear();
                            passwordInput.triggerShake();
                        }
                    }
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
