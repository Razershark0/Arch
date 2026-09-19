import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.Pipewire
import "../reusables"
import "../"

PanelWindow {
    id: root
    color: "transparent"

    WlrLayershell.namespace: "qs-screenshot-overlay"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.isActive ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    exclusionMode: ExclusionMode.Ignore
    focusable: root.isActive
    visible: root.isActive

    property string targetMonitorName: ""

    // Take the shot as soon as the region drag ends, instead of requiring a
    // second click on the toolbar shutter. Off by default.
    property var generalSettings: Config.getSetting("general", { "screenshotCaptureOnRelease": false })
    readonly property bool captureOnRelease: generalSettings && generalSettings.screenshotCaptureOnRelease === true

    Connections {
        target: Config
        function onSettingsLoaded() {
            root.generalSettings = Config.getSetting("general", { "screenshotCaptureOnRelease": false });
        }
    }

    property var targetScreen: {
        if (targetMonitorName !== "") {
            for (let i = 0; i < Quickshell.screens.length; i++) {
                if (Quickshell.screens[i].name === targetMonitorName) {
                    return Quickshell.screens[i];
                }
            }
        }
        return Quickshell.cursorScreen ?? (Quickshell.screens.length > 0 ? Quickshell.screens[0] : null);
    }

    screen: targetScreen

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    property bool isActive: false
    property bool isLoading: false
    property bool animateChanges: false
    property string freezeImg: ""
    property bool isInitialized: false
    property bool isRefreezing: false
    property string videoBackend: "gpu-screen-recorder"

    function s(val) { return Scaler.s(val); }

    property color dimColor: Qt.alpha(ThemeBackend.crust, 0.72)

    property bool isEditMode: false
    property string cachedMode: "false"
    property bool isVideoMode: false

    IpcHandler {
        target: "screenshotOverlay"

        function toggle(img: string, editMode: string, audioPrefs: string, cGeom: string, cGeomVideo: string, cMode: string, cBackend: string, targetMon: string): void {
            if (root.isActive) {
                if (img && img !== "") Quickshell.execDetached(["bash", "-c", "rm -f " + img]);
                root.deactivate();
            } else {
                root.activate(img, editMode, audioPrefs, cGeom, cGeomVideo, cMode, cBackend, targetMon);
            }
        }

        function activate(img: string, editMode: string, audioPrefs: string, cGeom: string, cGeomVideo: string, cMode: string, cBackend: string, targetMon: string): void {
            root.activate(img, editMode, audioPrefs, cGeom, cGeomVideo, cMode, cBackend, targetMon);
        }

        function deactivate(): void {
            root.deactivate();
        }
    }

    onIsActiveChanged: {
        if (!root.isActive) {
            if (root.freezeImg !== "") Quickshell.execDetached(["bash", "-c", "rm -f " + root.freezeImg]);
        }
    }

    Process {
        id: refreezeProcess
        property string targetFile: ""
        command: (root.screen && root.screen.name) ? ["grim", "-o", root.screen.name, "-l", "0", targetFile] : ["grim", "-l", "0", targetFile]
        onExited: (exitCode) => {
            if (exitCode === 0) {
                if (root.freezeImg !== "" && root.freezeImg !== targetFile) {
                    Quickshell.execDetached(["bash", "-c", "rm -f " + root.freezeImg]);
                }
                root.freezeImg = targetFile;
            }
            root.isRefreezing = false;
            Qt.callLater(() => {
                root.animateChanges = true;
            });
        }
    }

    Timer {
        id: refreezeTimer
        interval: 100
        repeat: false
        onTriggered: {
            let nextFreeze = Caching.getRunDir("screenshot") + "/freeze_" + Date.now() + ".png";
            refreezeProcess.targetFile = nextFreeze;
            refreezeProcess.running = true;
        }
    }

    function triggerRefreeze() {
        root.isRefreezing = true;
        refreezeTimer.start();
    }

    property real imgStartX: 0
    property real imgStartY: 0
    property real imgEndX: 0
    property real imgEndY: 0
    property bool imgHasSelection: false

    property real vidStartX: 0
    property real vidStartY: 0
    property real vidEndX: 0
    property real vidEndY: 0
    property bool vidHasSelection: false

    function activate(img, editMode, audioPrefs, cGeom, cGeomVideo, cMode, cBackend, targetMon) {
        root.targetMonitorName = (targetMon !== undefined && targetMon !== null) ? String(targetMon) : "";
        let resolved = null;
        if (root.targetMonitorName !== "") {
            for (let i = 0; i < Quickshell.screens.length; i++) {
                if (Quickshell.screens[i].name === root.targetMonitorName) {
                    resolved = Quickshell.screens[i];
                    break;
                }
            }
        }
        if (!resolved) {
            resolved = Quickshell.cursorScreen ?? (Quickshell.screens.length > 0 ? Quickshell.screens[0] : null);
        }
        root.screen = resolved;

        root.isLoading = true;
        root.animateChanges = false;
        root.isRefreezing = false;
        root.isEditMode = (editMode === "true");

        let aParts = (audioPrefs || "").split(",");
        let dVol = aParts[0] !== undefined && aParts[0] !== "" ? aParts[0] : "1.0";
        let dMute = aParts[1] || "false";
        let mVol = aParts[2] !== undefined && aParts[2] !== "" ? aParts[2] : "1.0";
        let mMute = aParts[3] || "false";
        let mDev = aParts.length > 4 ? aParts.slice(4).join(",") : "";

        root.deskVol = parseFloat(dVol);
        root.deskMute = (dMute === "true");
        root.micVol = parseFloat(mVol);
        root.micMute = (mMute === "true");
        root.micDevice = mDev || "";

        root.cachedMode = "false";
        root.isVideoMode = false;
        root.videoBackend = (cBackend === "wf-recorder") ? "wf-recorder" : "gpu-screen-recorder";

        if (root.isVideoMode) {
            if (img && img !== "") Quickshell.execDetached(["bash", "-c", "rm -f " + img]);
            root.freezeImg = "";
        } else {
            root.freezeImg = img || "";
        }

        let screenW = root.screen ? root.screen.width : root.width;
        let screenH = root.screen ? root.screen.height : root.height;

        let cGeomStr = cGeom || "";
        let imgParts = cGeomStr.trim() !== "" ? cGeomStr.trim().split(",") : [];
        root.imgHasSelection = imgParts.length === 4 && parseFloat(imgParts[2]) > 10;
        if (root.imgHasSelection) {
            root.imgStartX = parseFloat(imgParts[0]);
            root.imgStartY = parseFloat(imgParts[1]);
            root.imgEndX = root.imgStartX + parseFloat(imgParts[2]);
            root.imgEndY = root.imgStartY + parseFloat(imgParts[3]);
        } else {
            root.imgStartX = 0; root.imgStartY = 0; root.imgEndX = 0; root.imgEndY = 0;
        }

        let cVidStr = cGeomVideo || "";
        let vidParts = cVidStr.trim() !== "" ? cVidStr.trim().split(",") : [];
        root.vidHasSelection = vidParts.length === 4 && parseFloat(vidParts[2]) > 10;
        if (root.vidHasSelection) {
            root.vidStartX = parseFloat(vidParts[0]);
            root.vidStartY = parseFloat(vidParts[1]);
            root.vidEndX = root.vidStartX + parseFloat(vidParts[2]);
            root.vidEndY = root.vidStartY + parseFloat(vidParts[3]);
        } else {
            root.vidStartX = 0; root.vidStartY = 0; root.vidEndX = 0; root.vidEndY = 0;
        }

        if (root.isVideoMode) {
            if (root.videoBackend === "gpu-screen-recorder") {
                root.startX = 0; root.startY = 0; root.endX = screenW; root.endY = screenH;
                root.hasSelection = true;
            } else {
                root.startX = root.vidStartX; root.startY = root.vidStartY; root.endX = root.vidEndX; root.endY = root.vidEndY;
                root.hasSelection = root.vidHasSelection;
            }
        } else {
            root.startX = root.imgStartX; root.startY = root.imgStartY; root.endX = root.imgEndX; root.endY = root.imgEndY;
            root.hasSelection = root.imgHasSelection;
        }

        root.preStartX = root.imgStartX;
        root.preStartY = root.imgStartY;
        root.preEndX = root.imgEndX;
        root.preEndY = root.imgEndY;

        root.isActive = true;
        root.isLoading = false;

        Qt.callLater(() => {
            root.animateChanges = true;
        });
    }

    function deactivate() {
        refreezeTimer.stop();
        refreezeProcess.running = false;
        root.isRefreezing = false;
        root.animateChanges = false;
        if (root.freezeImg !== "") Quickshell.execDetached(["bash", "-c", "rm -f " + root.freezeImg]);
        root.freezeImg = "";
        root.isActive = false;
        root.hasSelection = false;
        root.isSelecting = false;
        root.isMaximized = false;
    }

    onIsVideoModeChanged: {
        if (!root.isInitialized || root.isLoading) return;
        Quickshell.execDetached(["bash", "-c", "echo '" + (root.isVideoMode ? "true" : "false") + "' > " + Caching.getCacheDir("screenshot") + "/video_mode"]);

        root.isMaximized = false;
        let screenW = root.screen ? root.screen.width : root.width;
        let screenH = root.screen ? root.screen.height : root.height;

        if (root.isVideoMode) {
            root.preStartX = root.startX;
            root.preStartY = root.startY;
            root.preEndX = root.endX;
            root.preEndY = root.endY;

            if (root.freezeImg !== "") {
                Quickshell.execDetached(["bash", "-c", "rm -f " + root.freezeImg]);
                root.freezeImg = "";
            }

            if (root.videoBackend === "gpu-screen-recorder") {
                root.startX = 0;
                root.startY = 0;
                root.endX = screenW;
                root.endY = screenH;
                root.hasSelection = true;
            } else {
                if (root.vidHasSelection) {
                    root.startX = root.vidStartX;
                    root.startY = root.vidStartY;
                    root.endX = root.vidEndX;
                    root.endY = root.vidEndY;
                    root.hasSelection = true;
                } else {
                    root.startX = 0;
                    root.startY = 0;
                    root.endX = screenW;
                    root.endY = screenH;
                    root.hasSelection = true;
                }
            }
        } else {
            root.animateChanges = false;
            root.isRefreezing = true;

            if (root.videoBackend === "wf-recorder" && root.hasSelection) {
                root.vidStartX = root.selX;
                root.vidStartY = root.selY;
                root.vidEndX = root.selX + root.selW;
                root.vidEndY = root.selY + root.selH;
                root.vidHasSelection = true;
            }

            root.startX = root.preStartX;
            root.startY = root.preStartY;
            root.endX = root.preEndX;
            root.endY = root.preEndY;

            if (Math.abs(root.endX - root.startX) < 10 || Math.abs(root.endY - root.startY) < 10) {
                root.hasSelection = false;
            } else {
                root.hasSelection = true;
            }

            root.triggerRefreeze();
        }
    }

    onVideoBackendChanged: {
        if (!root.isInitialized || root.isLoading) return;
        Quickshell.execDetached(["bash", "-c", "echo '" + root.videoBackend + "' > " + Caching.getCacheDir("screenshot") + "/video_backend"]);
        if (root.isVideoMode) {
            let screenW = root.screen ? root.screen.width : root.width;
            let screenH = root.screen ? root.screen.height : root.height;

            if (root.videoBackend === "gpu-screen-recorder") {
                if (root.hasSelection) {
                    root.vidStartX = root.selX; root.vidStartY = root.selY;
                    root.vidEndX = root.selX + root.selW; root.vidEndY = root.selY + root.selH;
                    root.vidHasSelection = true;
                }

                root.startX = 0; root.startY = 0; root.endX = screenW; root.endY = screenH;
                root.hasSelection = true;
            } else {
                root.startX = root.vidStartX; root.startY = root.vidStartY;
                root.endX = root.vidEndX; root.endY = root.vidEndY;
                root.hasSelection = root.vidHasSelection;
            }
        }
    }

    property real deskVol: 1.0
    property bool deskMute: false
    property real micVol: 1.0
    property bool micMute: false
    property string micDevice: ""
    property bool audioPrefsLoaded: false

    FileView {
        id: audioPrefsFile
        path: Caching.getStateDir("screenshot") + "/audio_prefs"
        printErrors: false

        onLoaded: (data) => {
            let content = data.trim();
            if (content !== "") {
                let parts = content.split(",");
                root.deskVol = parts[0] !== undefined && parts[0] !== "" ? parseFloat(parts[0]) : 1.0;
                root.deskMute = parts[1] === "true";
                root.micVol = parts[2] !== undefined && parts[2] !== "" ? parseFloat(parts[2]) : 1.0;
                root.micMute = parts[3] === "true";
                root.micDevice = parts.length > 4 ? parts.slice(4).join(",") : "";
            }
            root.finishAudioInit();
        }

        onLoadFailed: (error) => {
            root.finishAudioInit();
        }
    }

    function finishAudioInit() {
        root.audioPrefsLoaded = true;
        if (root.micDevice === "" && Audio.inputs.length > 0) {
            root.micDevice = Audio.inputs[0].name;
            root.saveAudioPrefs();
        }
    }

    function saveAudioPrefs() {
        let data = `${root.deskVol},${root.deskMute},${root.micVol},${root.micMute},${root.micDevice}`;
        Quickshell.execDetached(["bash", "-c", `echo '${data}' > ${Caching.getStateDir("screenshot")}/audio_prefs`]);
    }

    Connections {
        target: Audio
        function onInputsChanged() {
            if (!root.audioPrefsLoaded) return;
            if (root.micDevice === "" && Audio.inputs.length > 0) {
                root.micDevice = Audio.inputs[0].name;
                root.saveAudioPrefs();
            }
        }
    }

    Component.onCompleted: {
        root.isInitialized = true;
    }

    property real startX: 0
    property real startY: 0
    property real endX: 0
    property real endY: 0

    Behavior on startX { enabled: root.animateChanges && !root.isSelecting && !root.isRefreezing; NumberAnimation { duration: 350; easing.type: Easing.OutExpo } }
    Behavior on startY { enabled: root.animateChanges && !root.isSelecting && !root.isRefreezing; NumberAnimation { duration: 350; easing.type: Easing.OutExpo } }
    Behavior on endX { enabled: root.animateChanges && !root.isSelecting && !root.isRefreezing; NumberAnimation { duration: 350; easing.type: Easing.OutExpo } }
    Behavior on endY { enabled: root.animateChanges && !root.isSelecting && !root.isRefreezing; NumberAnimation { duration: 350; easing.type: Easing.OutExpo } }

    property bool hasSelection: false
    property bool isSelecting: false
    property bool isMaximized: false
    property real preStartX: 0
    property real preStartY: 0
    property real preEndX: 0
    property real preEndY: 0

    property real selX: Math.min(startX, endX)
    property real selY: Math.min(startY, endY)
    property real selW: Math.abs(endX - startX)
    property real selH: Math.abs(endY - startY)

    property string geometryString: `${Math.round(selX + (screen ? screen.x : 0))},${Math.round(selY + (screen ? screen.y : 0))} ${Math.round(selW)}x${Math.round(selH)}`
    property int interactionMode: 0
    property real anchorX: 0; property real anchorY: 0
    property real initX: 0; property real initY: 0
    property real initW: 0; property real initH: 0

    function saveCache() {
        if (root.hasSelection && (!root.isVideoMode || root.videoBackend === "wf-recorder")) {
            let data = Math.round(root.selX) + "," + Math.round(root.selY) + "," + Math.round(root.selW) + "," + Math.round(root.selH);
            if (root.isVideoMode) {
                root.vidStartX = root.selX;
                root.vidStartY = root.selY;
                root.vidEndX = root.selX + root.selW;
                root.vidEndY = root.selY + root.selH;
                root.vidHasSelection = true;
                Quickshell.execDetached(["bash", "-c", "echo '" + data + "' > " + Caching.getCacheDir("screenshot") + "/geometry_video"]);
            } else {
                root.imgStartX = root.selX;
                root.imgStartY = root.selY;
                root.imgEndX = root.selX + root.selW;
                root.imgEndY = root.selY + root.selH;
                root.imgHasSelection = true;
                Quickshell.execDetached(["bash", "-c", "echo '" + data + "' > " + Caching.getCacheDir("screenshot") + "/geometry"]);
            }
        }
    }

    function toggleMaximize() {
        if (root.isVideoMode) return;
        let screenW = root.screen ? root.screen.width : root.width;
        let screenH = root.screen ? root.screen.height : root.height;
        if (!isMaximized) {
            preStartX = root.startX; preStartY = root.startY;
            preEndX = root.endX; preEndY = root.endY;
            root.startX = 0; root.startY = 0;
            root.endX = screenW; root.endY = screenH;
            isMaximized = true;
        } else {
            root.startX = preStartX; root.startY = preStartY;
            root.endX = preEndX; root.endY = preEndY;
            isMaximized = false;
        }
        root.saveCache();
    }

    Shortcut { sequence: "Escape"; onActivated: root.deactivate() }
    Shortcut { sequence: "Return"; onActivated: { if (root.hasSelection) root.executeCapture(root.isEditMode, false) } }
    Shortcut { sequence: "F11"; onActivated: root.toggleMaximize() }

    component AnimWrap: Item {
        property bool isShown: false
        property real contentWidth: 0
        property real rightPadding: s(6)
        property real targetWidth: contentWidth + rightPadding

        width: isShown ? targetWidth : 0
        height: parent.height
        opacity: isShown ? 1.0 : 0.0
        clip: true

        Behavior on width { enabled: root.animateChanges && !root.isRefreezing; NumberAnimation { duration: 600; easing.type: Easing.OutExpo } }
        Behavior on opacity { enabled: root.animateChanges && !root.isRefreezing; NumberAnimation { duration: 500; easing.type: Easing.OutExpo } }
        visible: width > 0

        default property alias content: internalWrapper.children
        Item { 
            id: internalWrapper
            width: contentWidth 
            height: parent.height 
        }
    }

    Image {
        id: freezeBackground
        z: 0
        anchors.fill: parent
        source: root.freezeImg !== "" ? ("file://" + root.freezeImg) : ""
        asynchronous: false
        cache: false
        fillMode: Image.PreserveAspectCrop

        opacity: (!root.isVideoMode && !root.isRefreezing && root.freezeImg !== "") ? 1.0 : 0.0
        Behavior on opacity {
            enabled: root.animateChanges && !root.isSelecting && !root.isRefreezing
            NumberAnimation { duration: 350; easing.type: Easing.OutCubic }
        }
        visible: opacity > 0
    }

    Item {
        id: overlayContent
        anchors.fill: parent
        opacity: root.isRefreezing ? 0.0 : 1.0
        Behavior on opacity {
            enabled: root.animateChanges && !root.isSelecting && !root.isRefreezing
            NumberAnimation { duration: 350; easing.type: Easing.OutCubic }
        }
        visible: opacity > 0

        Item {
            anchors.fill: parent
            z: 1

            Rectangle {
                anchors.fill: parent
                color: root.dimColor
                opacity: (!root.isSelecting && !root.hasSelection) ? 1.0 : 0.0
                Behavior on opacity { enabled: root.animateChanges && !root.isRefreezing; NumberAnimation { duration: 150 } }
                Text {
                    anchors.centerIn: parent
                    text: root.isVideoMode ? I18n.t("screenshot.video_mode") : I18n.t("screenshot.select_region")
                    font.family: ThemeBackend.fontFamily; font.weight: Font.DemiBold; font.pixelSize: s(24); color: ThemeBackend.text
                }
            }
            Item {
                anchors.fill: parent
                opacity: (root.isSelecting || root.hasSelection) ? 1.0 : 0.0
                Behavior on opacity { enabled: root.animateChanges && !root.isRefreezing; NumberAnimation { duration: 150 } }
                Rectangle { x: 0; y: 0; width: parent.width; height: root.selY; color: root.dimColor } 
                Rectangle { x: 0; y: root.selY + root.selH; width: parent.width; height: parent.height - (root.selY + root.selH); color: root.dimColor }
                Rectangle { x: 0; y: root.selY; width: root.selX; height: root.selH; color: root.dimColor } 
                Rectangle { x: root.selX + root.selW; y: root.selY; width: parent.width - (root.selX + root.selW); height: root.selH; color: root.dimColor } 
            }
        }

        MultiEffect {
            id: structuralGlow
            source: selectionFrame
            anchors.fill: selectionFrame
            opacity: selectionFrame.opacity
            shadowEnabled: true
            shadowColor: "#000000"
            shadowOpacity: root.isSelecting ? 0.75 : 0.55
            shadowBlur: root.isSelecting ? s(2.0) : s(1.4)
            shadowVerticalOffset: s(4)
            z: 5
            Behavior on shadowOpacity { enabled: root.animateChanges && !root.isRefreezing; NumberAnimation { duration: 200 } }
            Behavior on shadowBlur { enabled: root.animateChanges && !root.isRefreezing; NumberAnimation { duration: 200 } }
            visible: opacity > 0
        }

        Rectangle {
            id: selectionFrame
            opacity: (!root.isRefreezing && (root.isSelecting || root.hasSelection)) ? 1.0 : 0.0
            x: root.selX; y: root.selY; width: root.selW; height: root.selH
            color: "transparent"
            border.color: root.isVideoMode ? ThemeBackend.red : ThemeBackend.mauve
            border.width: s(2)
            z: 6
            visible: opacity > 0
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            z: 20

            function getInteractionMode(mx, my, mods) {
                if (!root.hasSelection) return 1;
                if (mods & Qt.ShiftModifier) return 2;
                let margin = s(24);
                let onLeftLine = Math.abs(mx - root.selX) <= margin;
                let onRightLine = Math.abs(mx - (root.selX + root.selW)) <= margin;
                let onTopLine = Math.abs(my - root.selY) <= margin;
                let onBottomLine = Math.abs(my - (root.selY + root.selH)) <= margin;
                let widthCheck = mx >= (root.selX - margin) && mx <= (root.selX + root.selW + margin);
                let heightCheck = my >= (root.selY - margin) && my <= (root.selY + root.selH + margin);

                if (onTopLine && onLeftLine) return 3;
                if (onTopLine && onRightLine) return 5;
                if (onBottomLine && onLeftLine) return 8;
                if (onBottomLine && onRightLine) return 10;
                if (onTopLine && widthCheck) return 4;
                if (onBottomLine && widthCheck) return 9;
                if (onLeftLine && heightCheck) return 6;
                if (onRightLine && heightCheck) return 7;
                return 1;
            }

            onPositionChanged: (mouse) => {
                if (root.isVideoMode && root.videoBackend === "gpu-screen-recorder") { cursorShape = Qt.ArrowCursor; return; }
                let mode = root.isSelecting ? root.interactionMode : getInteractionMode(mouse.x, mouse.y, mouse.modifiers);
                switch(mode) {
                    case 2: cursorShape = Qt.ClosedHandCursor; break;
                    case 3: case 10: cursorShape = Qt.SizeFDiagCursor; break;
                    case 5: case 8: cursorShape = Qt.SizeBDiagCursor; break;
                    case 4: case 9: cursorShape = Qt.SizeVerCursor; break;
                    case 6: case 7: cursorShape = Qt.SizeHorCursor; break;
                    default: cursorShape = Qt.CrossCursor; break;
                }

                if (!root.isSelecting) return;
                let dx = mouse.x - root.anchorX; let dy = mouse.y - root.anchorY;
                let clamp = (val, min, max) => Math.max(min, Math.min(max, val));

                if (root.interactionMode === 1) {
                    root.endX = clamp(mouse.x, 0, root.width); root.endY = clamp(mouse.y, 0, root.height);
                } else if (root.interactionMode === 2) {
                    let targetX = clamp(root.initX + dx, 0, root.width - root.initW); let targetY = clamp(root.initY + dy, 0, root.height - root.initH);
                    root.startX = targetX; root.startY = targetY; root.endX = targetX + root.initW; root.endY = targetY + root.initH;
                } else {
                    let nx = root.initX, ny = root.initY, nw = root.initW, nh = root.initH;
                    if ([3, 6, 8].includes(root.interactionMode)) { nx = clamp(root.initX + dx, 0, root.initX + root.initW - 10); nw = root.initW + (root.initX - nx); }
                    if ([5, 7, 10].includes(root.interactionMode)) { nw = clamp(root.initW + dx, 10, root.width - root.initX); }
                    if ([3, 4, 5].includes(root.interactionMode)) { ny = clamp(root.initY + dy, 0, root.initY + root.initH - 10); nh = root.initH + (root.initY - ny); }
                    if ([8, 9, 10].includes(root.interactionMode)) { nh = clamp(root.initH + dy, 10, root.height - root.initY); }
                    root.startX = nx; root.startY = ny; root.endX = nx + nw; root.endY = ny + nh;
                }
            }

            onPressed: (mouse) => {
                if (mouse.button === Qt.RightButton) { root.deactivate(); return; }
                if (root.isVideoMode && root.videoBackend === "gpu-screen-recorder") return;

                root.interactionMode = getInteractionMode(mouse.x, mouse.y, mouse.modifiers);
                root.isSelecting = true;
                if (root.interactionMode !== 1) root.isMaximized = false;
                root.anchorX = mouse.x; root.anchorY = mouse.y;
                root.initX = root.selX; root.initY = root.selY; root.initW = root.selW; root.initH = root.selH;

                if (root.interactionMode === 1) {
                    let clamp = (val, min, max) => Math.max(min, Math.min(max, val));
                    let clampedX = clamp(mouse.x, 0, root.width); let clampedY = clamp(mouse.y, 0, root.height);
                    root.startX = clampedX; root.startY = clampedY; root.endX = clampedX; root.endY = clampedY;
                    root.hasSelection = false; root.isMaximized = false;
                }
            }

            onReleased: {
                if (root.isSelecting) {
                    root.isSelecting = false;
                    if (root.selW > 10 && root.selH > 10) {
                        root.hasSelection = true;
                        root.saveCache();
                        // Fresh mouse selection -> capture right away on release
                        // instead of waiting for the toolbar shutter button.
                        // interactionMode === 1 means drawing a new rectangle (not
                        // moving/resizing an existing one), and video mode stays
                        // manual because the audio source is still to be picked.
                        if (root.captureOnRelease && root.interactionMode === 1 && !root.isVideoMode) {
                            root.executeCapture(false, false);
                            return;
                        }
                    } else if (root.interactionMode === 1) {
                        let clamp = (val, min, max) => Math.max(min, Math.min(max, val));
                        let left = clamp(root.startX - 20, 0, Math.max(0, root.width - 40));
                        let top = clamp(root.startY - 20, 0, Math.max(0, root.height - 40));
                        root.startX = left;
                        root.startY = top;
                        root.endX = left + 40;
                        root.endY = top + 40;
                        root.hasSelection = true;
                        root.saveCache();
                    } else {
                        root.hasSelection = false;
                    }
                }
            }
        }

        Item {
            id: toolbar
            z: 30

            property real totalHeight: s(120)
            property bool fitsOutsideBottom: (root.selY + root.selH + totalHeight + s(15)) <= root.height

            property bool shouldShow: root.hasSelection && !root.isSelecting
            opacity: (!root.isRefreezing && shouldShow && !root.isSelecting) ? 1.0 : 0.0
            Behavior on opacity {
                enabled: root.animateChanges && !root.isSelecting && !root.isRefreezing
                NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
            }
            visible: opacity > 0

            width: toolbarRow.width + s(20)
            height: totalHeight

            x: Math.max(s(10), Math.min(parent.width - width - s(10), root.selX + (root.selW / 2) - (width / 2)))
            y: fitsOutsideBottom ? (root.selY + root.selH + s(15)) : 
               ((root.selY - height - s(15)) >= 0 ? (root.selY - height - s(15)) : (root.height - height - s(15)))

            Rectangle {
                anchors.fill: parent
                color: ThemeBackend.base
                border.color: Qt.rgba(ThemeBackend.text.r, ThemeBackend.text.g, ThemeBackend.text.b, 0.08)
                border.width: s(1)
                radius: ThemeBackend.borderRadius
            }

            Row {
                id: toolbarRow
                anchors.top: parent.top
                anchors.topMargin: s(10)
                anchors.horizontalCenter: parent.horizontalCenter
                height: root.s(36)
                spacing: 0

                AnimWrap {
                    isShown: true; contentWidth: s(36)
                    IconButton { size: s(36); cornerRadius: ThemeBackend.borderRadius; buttonIcon: "󰏫"; iconFontSize: s(18); accentColor: ThemeBackend.surface0; textColor: ThemeBackend.text; onClicked: root.executeCapture(true, false) }
                }

                AnimWrap {
                    isShown: true; contentWidth: s(36)
                    IconButton { size: s(36); cornerRadius: ThemeBackend.borderRadius; buttonIcon: root.isMaximized ? "" : ""; iconFontSize: s(18); accentColor: ThemeBackend.surface0; textColor: ThemeBackend.text; onClicked: root.toggleMaximize() }
                }

                Item {
                    width: s(36); height: parent.height
                    IconButton { 
                        anchors.verticalCenter: parent.verticalCenter
                        size: s(36); cornerRadius: ThemeBackend.borderRadius; buttonIcon: "󰅖"; iconFontSize: s(18); accentColor: ThemeBackend.red; textColor: ThemeBackend.crust; onClicked: root.deactivate() 
                    }
                }
            }

            Item {
                id: captureSection
                anchors.bottom: parent.bottom
                anchors.bottomMargin: s(12)
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                height: s(56)
                z: 10

                Rectangle {
                    id: leftLineBase
                    height: s(4)
                    radius: s(2)
                    color: Qt.rgba(ThemeBackend.text.r, ThemeBackend.text.g, ThemeBackend.text.b, 0.1)
                    anchors.left: parent.left
                    anchors.leftMargin: s(24)
                    anchors.right: actionBtnContainer.left
                    anchors.rightMargin: s(16)
                    anchors.verticalCenter: parent.verticalCenter
                    clip: true

                    Rectangle {
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: actionArea.containsMouse ? parent.width : 0
                        radius: s(2)
                        Behavior on width { enabled: root.animateChanges && !root.isRefreezing; NumberAnimation { duration: 500; easing.type: Easing.InOutExpo } }

                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: root.isVideoMode ? ThemeBackend.red : ThemeBackend.mauve }
                            GradientStop { position: 1.0; color: "transparent" }
                        }
                    }
                }

                Item {
                    id: actionBtnContainer
                    width: s(56)
                    height: width
                    anchors.centerIn: parent
                    z: 20

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: "transparent"
                        border.color: root.isVideoMode ? Qt.alpha(ThemeBackend.red, 0.4) : Qt.alpha(ThemeBackend.surface1, 0.8)
                        border.width: s(2)
                        Behavior on border.color { enabled: root.animateChanges && !root.isRefreezing; ColorAnimation { duration: 250 } }
                    }

                    Rectangle {
                        width: actionArea.pressed ? s(32) : (actionArea.containsMouse ? s(40) : s(36))
                        height: width
                        radius: width / 2
                        anchors.centerIn: parent
                        color: root.isVideoMode ? ThemeBackend.red : ThemeBackend.mauve
                        Behavior on color { enabled: root.animateChanges && !root.isRefreezing; ColorAnimation { duration: 250 } }
                        Behavior on width { enabled: root.animateChanges && !root.isRefreezing; NumberAnimation { duration: 350; easing.type: Easing.OutBack } }
                    }

                    MouseArea {
                        id: actionArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.executeCapture(false, root.isVideoMode)
                    }
                }

                Rectangle {
                    id: rightLineBase
                    height: s(4)
                    radius: s(2)
                    color: Qt.rgba(ThemeBackend.text.r, ThemeBackend.text.g, ThemeBackend.text.b, 0.1)
                    anchors.right: parent.right
                    anchors.rightMargin: s(24)
                    anchors.left: actionBtnContainer.right
                    anchors.leftMargin: s(16)
                    anchors.verticalCenter: parent.verticalCenter
                    clip: true

                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: actionArea.containsMouse ? parent.width : 0
                        radius: s(2)
                        Behavior on width { enabled: root.animateChanges && !root.isRefreezing; NumberAnimation { duration: 500; easing.type: Easing.InOutExpo } }

                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: "transparent" }
                            GradientStop { position: 1.0; color: root.isVideoMode ? ThemeBackend.red : ThemeBackend.mauve }
                        }
                    }
                }
            }
        }

    }

    Timer {
        id: captureTimer
        property string pendingCmd: ""
        interval: 200
        repeat: false
        onTriggered: {
            Quickshell.execDetached(["bash", "-c", pendingCmd]);
        }
    }

    function executeCapture(openEditor, isRecord) {
        let cmd = `bash ${Caching.serpantinumDir}/scripts/screenshot.sh --geometry "${root.geometryString}"`;
        if (openEditor) cmd += " --edit";

        captureTimer.pendingCmd = cmd;
        root.animateChanges = false;
        captureTimer.start();
        root.deactivate();
    }
}
