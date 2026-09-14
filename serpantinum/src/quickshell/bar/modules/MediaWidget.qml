import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import Quickshell.Services.Mpris
import "../../reusables"
import "../../"

Rectangle {
    id: mediaWidgetRoot

    property var barWindow
    property bool isSolid: false
    property bool distinctPills: barWindow ? (barWindow.distinctPills !== undefined ? barWindow.distinctPills : false) : false
    property var player: MprisController.activePlayer
    property bool isMediaActive: player !== null && player.playbackState !== MprisPlaybackState.Stopped && player.trackTitle !== ""
    property bool moduleActive: isMediaActive
    property bool isGrouped: false
    property bool isCompact: isGrouped || (isSolid && distinctPills)
    property real contentWrapperWidth: 0
    property bool layoutAnimationsEnabled: true

    property real targetX: 0

    x: targetX
    Behavior on x {
        enabled: barWindow ? (barWindow.startupCascadeFinished && !barWindow.positionChanging && layoutAnimationsEnabled) : layoutAnimationsEnabled
        NumberAnimation { duration: 600; easing.type: Easing.OutQuint }
    }

    radius: barWindow ? barWindow.s(isCompact ? 9 : 10) : (isCompact ? 9 : 10)
    border.width: 0
    color: isGrouped ? "transparent" : (isSolid ? (distinctPills ? "#110915" : "transparent") : ThemeBackend.base)
    height: barWindow ? (isGrouped ? barWindow.barHeight - 8 : ((isSolid && distinctPills) ? barWindow.barHeight - 6 : barWindow.barHeight)) : (isGrouped ? 22 : ((isSolid && distinctPills) ? 24 : 30))
    y: barWindow ? barWindow.baseOffsetY + (barWindow.barHeight - height) / 2 : 0
    clip: true
    layer.enabled: true

    property real colWidth: barWindow ? barWindow.s(isCompact ? 144 : 148) : (isCompact ? 144 : 148)
    property real innerSpacing: 0
    property real btnSpacing: barWindow ? barWindow.s(isCompact ? -8 : -7) : (isCompact ? -8 : -7)
    property real sidePadding: barWindow ? barWindow.s(isCompact ? 6 : 8) : (isCompact ? 6 : 8)

    property real targetWidth: {
        if (!moduleActive) return 0;
        let iconW = barWindow ? barWindow.s(isCompact ? 26 : 28) : (isCompact ? 26 : 28);
        let gapInfo = barWindow ? barWindow.s(isCompact ? 8 : 10) : (isCompact ? 8 : 10);
        let btnPillPad = barWindow ? barWindow.s(isCompact ? 0 : 2) : (isCompact ? 0 : 2);
        let btnW = (barWindow ? barWindow.s(isCompact ? 28 : 30) : (isCompact ? 28 : 30)) * 3 + btnSpacing * 2 + btnPillPad;
        let margins = sidePadding * 2;
        return iconW + gapInfo + colWidth + innerSpacing + btnW + margins;
    }

    width: targetWidth
    Behavior on width {
        enabled: barWindow ? (barWindow.startupCascadeFinished && !barWindow.positionChanging && layoutAnimationsEnabled) : layoutAnimationsEnabled
        NumberAnimation { duration: 600; easing.type: Easing.OutQuint }
    }

    opacity: moduleActive ? ((barWindow && barWindow.barOpacity !== undefined) ? barWindow.barOpacity : 1.0) : 0.0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    function formatTime(sec) {
        sec = Math.floor(sec || 0);
        let m = Math.floor(sec / 60), s = sec % 60;
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
    }

    Item {
        id: mediaLayoutContainer
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: mediaWidgetRoot.sidePadding
        anchors.right: parent.right
        anchors.rightMargin: mediaWidgetRoot.sidePadding
        height: parent.height
        clip: true

        Row {
            id: innerMediaLayout
            anchors.verticalCenter: parent.verticalCenter
            spacing: mediaWidgetRoot.innerSpacing

            MouseArea {
                id: mediaInfoMouse
                width: infoLayout.implicitWidth
                height: mediaLayoutContainer.height
                hoverEnabled: true

                Row {
                    id: infoLayout
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: barWindow ? barWindow.s(mediaWidgetRoot.isCompact ? 8 : 10) : (mediaWidgetRoot.isCompact ? 8 : 10)
                    transformOrigin: Item.Left

                    scale: mediaInfoMouse.containsMouse ? 1.01 : 1.0
                    Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }

                    Rectangle {
                        id: mediaThumbBox
                        width: barWindow ? barWindow.s(mediaWidgetRoot.isCompact ? 26 : 28) : (mediaWidgetRoot.isCompact ? 26 : 28)
                        height: barWindow ? barWindow.s(mediaWidgetRoot.isCompact ? 26 : 28) : (mediaWidgetRoot.isCompact ? 26 : 28)
                        radius: barWindow ? barWindow.s(mediaWidgetRoot.isCompact ? 9 : 10) : (mediaWidgetRoot.isCompact ? 9 : 10)
                        color: mediaWidgetRoot.isCompact ? Qt.lighter(ThemeBackend.surface1, 1.1) : ThemeBackend.surface1
                        border.width: 1
                        border.color: (isMediaActive && MprisController.isPlaying) ? ThemeBackend.mauve : (mediaWidgetRoot.isCompact ? ThemeBackend.surface2 : ThemeBackend.surface1)
                        clip: true
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            anchors.centerIn: parent
                            text: "󰎈"
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: barWindow ? barWindow.s(mediaWidgetRoot.isCompact ? 13 : 14) : (mediaWidgetRoot.isCompact ? 13 : 14)
                            color: mediaWidgetRoot.isCompact ? ThemeBackend.text : ThemeBackend.subtext0
                            visible: !isMediaActive || !MprisController.artUrl
                        }

                        Image {
                            id: mediaArtImg
                            anchors.fill: parent
                            source: (isMediaActive && MprisController.artUrl) ? (MprisController.artUrl.startsWith("file://") || MprisController.artUrl.startsWith("http") ? MprisController.artUrl : "file://" + MprisController.artUrl) : ""
                            fillMode: Image.PreserveAspectCrop
                            visible: false
                        }

                        MultiEffect {
                            anchors.fill: mediaArtImg
                            source: mediaArtImg
                            maskEnabled: true
                            maskSource: mediaArtMask
                            visible: isMediaActive && MprisController.artUrl !== "" && mediaArtImg.status === Image.Ready
                        }

                        Item {
                            id: mediaArtMask
                            anchors.fill: parent
                            layer.enabled: true
                            visible: false

                            Rectangle {
                                anchors.fill: parent
                                radius: mediaThumbBox.radius
                                color: "black"
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: ThemeBackend.surface0
                            opacity: 0.15
                            visible: isMediaActive && MprisController.artUrl !== "" && mediaArtImg.status === Image.Ready
                        }
                    }

                    Column {
                        spacing: -2
                        anchors.verticalCenter: parent.verticalCenter
                        width: mediaWidgetRoot.colWidth

                        Item {
                            id: titleClipRect
                            width: parent.width
                            height: titleTextMain.implicitHeight
                            clip: true

                            property int marqueeSpacing: barWindow ? barWindow.s(40) : 40

                            onWidthChanged: {
                                marqueeContainer.x = 0;
                                if (titleTextMain.implicitWidth > width) {
                                    titleAnim.restart();
                                } else {
                                    titleAnim.stop();
                                }
                            }

                            Item {
                                id: marqueeContainer
                                height: parent.height

                                Row {
                                    spacing: titleClipRect.marqueeSpacing
                                    Text {
                                        id: titleTextMain
                                        text: isMediaActive ? (player ? player.trackTitle : "") : I18n.t("music.nothing_playing")
                                        font.family: ThemeBackend.fontFamily
                                        font.weight: Font.Black
                                        font.pixelSize: barWindow ? barWindow.s(mediaWidgetRoot.isCompact ? 11 : 12) : (mediaWidgetRoot.isCompact ? 11 : 12)
                                        color: ThemeBackend.text

                                        onTextChanged: {
                                            marqueeContainer.x = 0;
                                            if (implicitWidth > titleClipRect.width) {
                                                titleAnim.restart();
                                            } else {
                                                titleAnim.stop();
                                            }
                                        }
                                    }

                                    Text {
                                        id: titleTextClone
                                        text: titleTextMain.text
                                        font.family: ThemeBackend.fontFamily
                                        font.weight: Font.Black
                                        font.pixelSize: barWindow ? barWindow.s(mediaWidgetRoot.isCompact ? 11 : 12) : (mediaWidgetRoot.isCompact ? 11 : 12)
                                        color: ThemeBackend.text
                                        visible: titleTextMain.implicitWidth > titleClipRect.width
                                    }
                                }

                                SequentialAnimation on x {
                                    id: titleAnim
                                    loops: Animation.Infinite
                                    running: titleTextMain.implicitWidth > titleClipRect.width

                                    onRunningChanged: {
                                        if (!running) marqueeContainer.x = 0;
                                    }

                                    PauseAnimation { duration: isMediaActive ? 3000 : 6000 }

                                    NumberAnimation {
                                        from: 0
                                        to: -(titleTextMain.implicitWidth + titleClipRect.marqueeSpacing)
                                        duration: (titleTextMain.implicitWidth + titleClipRect.marqueeSpacing) * (isMediaActive ? 25 : 65)
                                    }

                                    PropertyAction { target: marqueeContainer; property: "x"; value: 0 }
                                }
                            }
                        }

                        Text {
                            text: isMediaActive && player ? (mediaWidgetRoot.formatTime(MprisController.livePosition) + " / " + mediaWidgetRoot.formatTime(player.length)) : ""
                            font.family: ThemeBackend.fontFamily
                            font.weight: Font.Black
                            font.pixelSize: barWindow ? barWindow.s(mediaWidgetRoot.isCompact ? 9 : 10) : (mediaWidgetRoot.isCompact ? 9 : 10)
                            color: mediaWidgetRoot.isCompact ? ThemeBackend.overlay2 : ThemeBackend.subtext0
                            width: parent.width
                            elide: Text.ElideRight
                            visible: isMediaActive
                        }
                    }
                }
            }

            Rectangle {
                id: buttonPill
                anchors.verticalCenter: parent.verticalCenter
                height: barWindow ? barWindow.s(mediaWidgetRoot.isCompact ? 28 : 30) : (mediaWidgetRoot.isCompact ? 28 : 30)
                width: buttonRow.width + (barWindow ? barWindow.s(mediaWidgetRoot.isCompact ? 0 : 2) : (mediaWidgetRoot.isCompact ? 0 : 2))
                radius: barWindow ? barWindow.s(mediaWidgetRoot.isCompact ? 9 : 10) : (mediaWidgetRoot.isCompact ? 9 : 10)
                color: "transparent"
                border.width: 0

                Row {
                    id: buttonRow
                    anchors.centerIn: parent
                    spacing: mediaWidgetRoot.btnSpacing

                IconButton {
                    id: prevMediaButton
                    height: barWindow ? barWindow.s(mediaWidgetRoot.isCompact ? 28 : 30) : (mediaWidgetRoot.isCompact ? 28 : 30)
                    width: barWindow ? barWindow.s(mediaWidgetRoot.isCompact ? 28 : 30) : (mediaWidgetRoot.isCompact ? 28 : 30)
                    cornerRadius: barWindow ? barWindow.s(mediaWidgetRoot.isCompact ? 9 : 10) : (mediaWidgetRoot.isCompact ? 9 : 10)
                    buttonIcon: "󰒮"
                    iconFontSize: barWindow ? barWindow.s(mediaWidgetRoot.isCompact ? 19 : 20) : (mediaWidgetRoot.isCompact ? 19 : 20)
                    accentColor: "transparent"
                    textColor: isHoveredOrHighlighted ? ThemeBackend.text : (mediaWidgetRoot.isCompact ? ThemeBackend.subtext0 : ThemeBackend.overlay2)
                    anchors.verticalCenter: parent.verticalCenter
                    onClicked: if (player && player.canGoPrevious) player.previous()
                }

                IconButton {
                    id: playMediaButton
                    height: barWindow ? barWindow.s(mediaWidgetRoot.isCompact ? 28 : 30) : (mediaWidgetRoot.isCompact ? 28 : 30)
                    width: barWindow ? barWindow.s(mediaWidgetRoot.isCompact ? 28 : 30) : (mediaWidgetRoot.isCompact ? 28 : 30)
                    cornerRadius: barWindow ? barWindow.s(mediaWidgetRoot.isCompact ? 9 : 10) : (mediaWidgetRoot.isCompact ? 9 : 10)
                    buttonIcon: (isMediaActive && MprisController.isPlaying) ? "󰏤" : "󰐊"
                    iconFontSize: barWindow ? barWindow.s(mediaWidgetRoot.isCompact ? 22 : 23) : (mediaWidgetRoot.isCompact ? 22 : 23)
                    accentColor: "transparent"
                    textColor: isHoveredOrHighlighted ? "#A37E56" : (mediaWidgetRoot.isCompact ? Qt.lighter(ThemeBackend.text, 1.1) : ThemeBackend.text)
                    anchors.verticalCenter: parent.verticalCenter
                    onClicked: if (player && player.canTogglePlaying) player.togglePlaying()
                }

                IconButton {
                    id: nextMediaButton
                    height: barWindow ? barWindow.s(mediaWidgetRoot.isCompact ? 28 : 30) : (mediaWidgetRoot.isCompact ? 28 : 30)
                    width: barWindow ? barWindow.s(mediaWidgetRoot.isCompact ? 28 : 30) : (mediaWidgetRoot.isCompact ? 28 : 30)
                    cornerRadius: barWindow ? barWindow.s(mediaWidgetRoot.isCompact ? 9 : 10) : (mediaWidgetRoot.isCompact ? 9 : 10)
                    buttonIcon: "󰒭"
                    iconFontSize: barWindow ? barWindow.s(mediaWidgetRoot.isCompact ? 19 : 20) : (mediaWidgetRoot.isCompact ? 19 : 20)
                    accentColor: "transparent"
                    textColor: isHoveredOrHighlighted ? ThemeBackend.text : (mediaWidgetRoot.isCompact ? ThemeBackend.subtext0 : ThemeBackend.overlay2)
                    anchors.verticalCenter: parent.verticalCenter
                    onClicked: if (player && player.canGoNext) player.next()
                }
                }
            }
        }
    }
}
