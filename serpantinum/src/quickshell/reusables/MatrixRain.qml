import QtQuick

// Matrix rain drawn by the GPU (see MatrixRain.frag). The CPU only bumps a
// counter once per row of fall; every column, gap and character is worked out
// per pixel from that counter and a random start point, so nothing is drawn or
// stored per frame and nothing repeats.
Item {
    id: rain

    property bool running: true

    // Same cell proportions as the old terminal version: JetBrains Mono at 16pt
    // (advance width 0.6em, line height ~1.32em).
    readonly property int fontPixelSize: 22
    readonly property int colWidth: 13
    readonly property int rowHeight: 24

    readonly property string charset: {
        let s = "0123456789";
        for (let c = 0xFF66; c <= 0xFF9D; c++) s += String.fromCharCode(c);
        return s;
    }

    // Random start so each lock/idle begins somewhere different.
    property real tick: Math.floor(Math.random() * 100000)

    // The characters, drawn once side by side into a texture for the shader.
    Row {
        id: glyphRow
        Repeater {
            model: rain.charset.length
            delegate: Item {
                width: rain.colWidth
                height: rain.rowHeight
                clip: true
                Text {
                    text: rain.charset[index]
                    color: "white"
                    font.family: "monospace"
                    font.pixelSize: rain.fontPixelSize
                }
            }
        }
    }

    ShaderEffectSource {
        id: glyphTexture
        sourceItem: glyphRow
        hideSource: true
        live: false
        smooth: false
        visible: false
        Component.onCompleted: scheduleUpdate()
    }

    ShaderEffect {
        anchors.fill: parent
        blending: true
        property real tick: rain.tick
        property size resolution: Qt.size(width, height)
        property size cellSize: Qt.size(rain.colWidth, rain.rowHeight)
        property real glyphCount: rain.charset.length
        property variant atlas: glyphTexture
        fragmentShader: "MatrixRain.frag.qsb"
    }

    // One row per tick, 80ms, matching unimatrix's own timing at speed 92.
    Timer {
        interval: 80
        running: rain.running
        repeat: true
        onTriggered: rain.tick += 1
    }
}
