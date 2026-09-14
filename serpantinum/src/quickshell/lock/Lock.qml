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

                    // Matches JetBrains Mono's real cell proportions at the
                    // 16pt the rest of this desktop uses (advance width is
                    // 0.6em, line height ~1.32em -- measured off the font's
                    // own hhea/hmtx tables, not guessed), so a column reads
                    // as the same size as it did in the old terminal-based
                    // version instead of the smaller square cells before.
                    readonly property int fontPixelSize: 22
                    readonly property int colWidth: 13
                    readonly property int rowHeight: 24

                    readonly property string charset: {
                        let s = "0123456789";
                        for (let c = 0xFF66; c <= 0xFF9D; c++) s += String.fromCharCode(c);
                        return s;
                    }
                    property var columns: []

                    function resetColumns() {
                        let n = Math.ceil(width / colWidth);
                        let arr = [];
                        for (let i = 0; i < n; i++) {
                            arr.push({ y: Math.random() * -40 });
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
                        // QtQuick's Context2D font parser rejects any
                        // quoted/spaced family name outright (confirmed via
                        // direct testing -- "JetBrains Mono" silently fails
                        // every frame regardless of quote style, falling
                        // back to a tiny default), so this has to be a
                        // generic CSS family keyword, not the real font.
                        ctx.font = fontPixelSize + "px monospace";
                        ctx.textBaseline = "top";
                        for (let i = 0; i < columns.length; i++) {
                            let col = columns[i];
                            let ch = charset[Math.floor(Math.random() * charset.length)];
                            ctx.fillStyle = (i % 7 === 0) ? "#e6ccff" : "#9b30ff";
                            ctx.fillText(ch, i * colWidth, col.y * rowHeight);
                            // uniform one-row-per-tick cascade, matching
                            // unimatrix's own default (non-async) timing at
                            // speed 92: (100-92)*10 = 80ms per row.
                            col.y += 1;
                            if (col.y * rowHeight > height && Math.random() > 0.975) {
                                col.y = Math.random() * -20;
                            }
                        }
                    }

                    Timer {
                        interval: 80
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
                            text: "Welcome Raze"
                            font.family: "JetBrains Mono"
                            font.pixelSize: 18
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
