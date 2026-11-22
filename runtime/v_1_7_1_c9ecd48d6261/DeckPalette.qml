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

    // Glass finish: fine light edges instead of the theme's strong outline,
    // so the selected card stays the only strong emphasis.
    readonly property color ring: Util.alpha(foreground, 0.08)
    readonly property color ringHover: Util.alpha(foreground, 0.18)
    readonly property color hairline: Util.alpha(foreground, 0.12)
    readonly property color edgeLight: Qt.rgba(1, 1, 1, 0.12)
    readonly property color well: Qt.rgba(0, 0, 0, 0.16)
    readonly property color chip: Util.alpha(foreground, 0.06)
    readonly property color dimmed: Util.alpha(foreground, 0.45)
    // Accent chip: a soft vertical gradient of the theme accent, with ink
    // picked for contrast so light and dark themes both read.
    readonly property color accentTop: Qt.lighter(accent, 1.12)
    readonly property color accentBottom: Qt.darker(accent, 1.06)
    readonly property color accentInk: luminance(accent) > 0.45 ? Qt.darker(accent, 3.2) : "#ffffff"
    function tint(value) { return Util.alpha(accent, value); }
    function luminance(c) { return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b; }

    // A proportional sans reads as interface text; the mono stays on keys.
    // Outfit is used when installed, then Inter, otherwise the user's menu font.
    readonly property var installedFamilies: Qt.fontFamilies()
    readonly property string fontFamily: installedFamilies.indexOf("Outfit") !== -1 ? "Outfit"
        : installedFamilies.indexOf("Inter") !== -1 ? "Inter"
        : installedFamilies.indexOf("Inter Variable") !== -1 ? "Inter Variable" : Style.font.menuFamily
    readonly property string monoFamily: Style.font.family
    readonly property real fontScale: Math.max(0.85, Style.fontBaseSize / 12)
    // A shadow behind a see-through surface shows through it, so only opaque
    // surfaces cast one, as in Omarchy's own menus.
    readonly property bool panelOpaque: Commons.Color.menu.background.a > 0.99
    readonly property bool surfaceOpaque: surface.a > 0.99
    function px(value) { return Math.round(value * fontScale); }
}
