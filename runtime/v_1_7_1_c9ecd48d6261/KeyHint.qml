pragma ComponentBehavior: Bound
import QtQuick

// A keyboard key drawn as a small outlined chip, as in the launcher footer.
Rectangle {
    id: root
    property string keys: ""
    property color textColor: DeckPalette.muted
    implicitWidth: label.implicitWidth + DeckPalette.px(12)
    implicitHeight: label.implicitHeight + DeckPalette.px(4)
    radius: DeckPalette.px(6)
    color: DeckPalette.chip
    border.width: 1
    border.color: DeckPalette.hairline
    PlainText {
        id: label
        anchors.centerIn: parent
        text: root.keys
        color: root.textColor
        font.family: DeckPalette.monoFamily
        font.pixelSize: DeckPalette.px(11)
    }
}
