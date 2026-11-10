pragma ComponentBehavior: Bound
import QtQuick

Text {
    textFormat: Text.PlainText
    color: DeckPalette.foreground
    font.family: DeckPalette.fontFamily
    font.pixelSize: DeckPalette.px(13)
    renderType: Text.QtRendering
}
