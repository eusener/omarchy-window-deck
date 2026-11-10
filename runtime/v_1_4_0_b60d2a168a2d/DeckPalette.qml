pragma ComponentBehavior: Bound
pragma Singleton
import QtQuick
import qs.Commons
import qs.Commons as Commons

QtObject {
    // Bind to the shell's live roles: theme and user shell.toml changes propagate.
    readonly property color background: Commons.Color.background
    readonly property color surface: Qt.tint(Commons.Color.menu.background, Commons.Color.menu.selectedBackground)
    readonly property color foreground: Commons.Color.menu.text
    readonly property color muted: Util.alpha(Commons.Color.menu.text, 0.65)
    readonly property color accent: Commons.Color.imagePicker.selectedBorder
    readonly property color minimized: Commons.Color.menu.selectedText
    readonly property color border: Commons.Color.popups.border
    readonly property color scrim: Commons.Color.menu.scrim
    readonly property color panel: Commons.Color.menu.background
    readonly property color shadow: Util.alpha(Commons.Color.background, 0.3)
    readonly property color pressed: Qt.tint(surface, Util.alpha(foreground, Style.pressedFillAlpha))
    readonly property string fontFamily: Style.font.menuFamily
    readonly property string monoFamily: Style.font.family
    readonly property real fontScale: Math.max(0.85, Style.fontBaseSize / 12)
    // A shadow behind a see-through surface shows through it, so only opaque
    // surfaces cast one, as in Omarchy's own menus.
    readonly property bool panelOpaque: Commons.Color.menu.background.a > 0.99
    readonly property bool surfaceOpaque: surface.a > 0.99
    function px(value) { return Math.round(value * fontScale); }
}
