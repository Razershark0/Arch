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

    // Touching the controller here creates it at startup. Singletons are only
    // created on first use, so otherwise it would be created at the moment of
    // locking, and its startup reset of the pointer setting would race the
    // lock's own change.
    Component.onCompleted: IdleController.sessionLocked = false

    // The lock fades in from a snapshot of the screen as it was, so it looks
    // like the desktop turning into the lock screen instead of cutting to it.
    readonly property string snapshotPath: (Quickshell.env("XDG_RUNTIME_DIR") ?? "/tmp") + "/serpantinum/lock-snapshot.ppm"
    property string snapshotUrl: ""

    function lock() {
        if (rootLock.locked || snapshot.running) return;
        // One screen only: grim would give one image spanning all of them.
        if (Quickshell.screens.length === 1) snapshot.running = true;
        else root.engage(false);
    }

    function engage(haveSnapshot) {
        snapshotUrl = haveSnapshot ? "file://" + snapshotPath : "";
        rootLock.locked = true;
        IdleController.sessionLocked = true;
        lockUI.failed = false;
        lockUI.authenticating = false;
        pamActionTimer.restart();
    }

    function completeUnlock() {
        rootLock.locked = false;
        IdleController.sessionLocked = false;
        Quickshell.execDetached(["rm", "-f", snapshotPath]);
    }

    Process {
        id: snapshot
        command: ["grim", "-t", "ppm", root.snapshotPath]
        onExited: (code) => root.engage(code === 0)
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
                color: "black"

                Image {
                    anchors.fill: parent
                    source: IdleController.wallpaperPath !== "" ? ("file://" + IdleController.wallpaperPath) : ""
                    fillMode: IdleController.wallpaperFillMode
                    asynchronous: true
                }

                // Same darkening as the idle screen, so the wallpaper reads the
                // same behind the rain (the terminal's own background opacity).
                Rectangle {
                    anchors.fill: parent
                    color: "black"
                    opacity: IdleController.terminalOpacity
                }

                MatrixRain {
                    anchors.fill: parent
                }

                Rectangle {
                    id: box
                    anchors.centerIn: parent
                    width: 320
                    height: content.height + 48
                    radius: 14
                    color: "#ee110915"   // QML colors are #AARRGGBB, alpha first

                    ColumnLayout {
                        id: content
                        anchors.centerIn: parent
                        width: parent.width - 48
                        spacing: 14

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "Welcome " + (Quickshell.env("USER") ?? "")
                            font.family: "Iosevka Nerd Font"
                            font.pixelSize: 22
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

                // The screen as it was a moment ago, faded out to reveal the
                // lock. Loaded synchronously so the very first frame is already
                // the desktop and nothing flashes.
                Image {
                    anchors.fill: parent
                    z: 100
                    source: root.snapshotUrl
                    fillMode: Image.Stretch
                    asynchronous: false
                    cache: false
                    visible: source != "" && opacity > 0
                    NumberAnimation on opacity {
                        from: 1.0
                        to: 0.0
                        duration: 900
                        easing.type: Easing.InOutSine
                    }
                }

                Component.onCompleted: passwordInput.forceInputFocus()
            }
        }
    }
}
