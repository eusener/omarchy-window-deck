import QtQuick

// Window-control glyphs drawn with rectangles, so they need no icon font:
// hide (minimize), maximize, unmaximize (restore size) and show (restore).
Item {
    id: root
    property string kind: "hide"
    property color color: "white"
    property real size: 12
    readonly property real stroke: Math.max(1, Math.round(size / 8))
    width: size; height: size

    Rectangle {
        visible: root.kind === "hide"
        anchors.bottom: parent.bottom
        width: parent.width; height: root.stroke
        color: root.color
    }
    Rectangle {
        visible: root.kind === "maximize"
        anchors.fill: parent
        color: "transparent"
        border.color: root.color; border.width: root.stroke
    }
    Item {
        visible: root.kind === "unmaximize" || root.kind === "show"
        anchors.fill: parent
        // Back square, then the front one over it.
        Rectangle {
            x: parent.width * 0.3; y: 0
            width: parent.width * 0.7; height: parent.height * 0.7
            color: "transparent"
            border.color: root.color; border.width: root.stroke
        }
        Rectangle {
            x: 0; y: parent.height * 0.3
            width: parent.width * 0.7; height: parent.height * 0.7
            color: DeckPalette.background
            border.color: root.color; border.width: root.stroke
        }
    }
}
