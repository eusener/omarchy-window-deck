import QtQuick
import Quickshell.Wayland

ScreencopyView {
    // Quickshell imports DMA-BUF textures without TextureHasAlphaChannel.
    // A fully opaque item then replaces the backing surface even when exported
    // pixels have alpha (e.g. Glassy terminals). A sub-1 opacity forces Qt's
    // source-over blending; the <1/255 difference is below one color step.
    opacity: 0.999
    anchors.centerIn: parent
    readonly property real ratio: sourceSize.height > 0 ? sourceSize.width / sourceSize.height : 1.6
    width: Math.min(parent.width, parent.height * ratio)
    height: width / ratio
    constraintSize: Qt.size(parent.width * 2, parent.height * 2)
    paintCursor: false
    visible: hasContent
}
