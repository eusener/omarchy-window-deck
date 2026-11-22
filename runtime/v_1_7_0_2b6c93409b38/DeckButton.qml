pragma ComponentBehavior: Bound
import QtQuick

FocusScope {
    id: root
    property string accessibleName: ""
    property bool selected: false
    property bool busy: false
    property bool chromeless: false
    property int heldButtons: Qt.NoButton
    readonly property bool interactive: enabled
    readonly property bool tooltipHovered: visible && enabled && mouse.containsMouse
    property alias hovered: mouse.containsMouse
    readonly property bool pressed: mouse.pressed || heldButtons !== Qt.NoButton
    signal activated()
    signal hoverChanged(bool entered)
    implicitWidth: 30
    implicitHeight: 30
    activeFocusOnTab: true
    enabled: !busy
    Accessible.role: Accessible.Button
    Accessible.name: accessibleName
    Accessible.onPressAction: if (enabled) activated()

    // Omarchy's bar places a drag/click handler over widgets and forwards presses.
    function triggerPress(button) {
        if (enabled && button === Qt.LeftButton) activated();
    }

    Rectangle {
        visible: !root.chromeless
        anchors.fill: parent
        radius: Math.min(10, height / 3)
        color: root.pressed ? DeckPalette.pressed
            : mouse.containsMouse || root.activeFocus || root.selected ? DeckPalette.surface : "transparent"
        border.width: root.activeFocus || root.selected ? 2 : 1
        border.color: root.activeFocus || root.selected ? DeckPalette.accent : mouse.containsMouse ? DeckPalette.border : "transparent"
    }
    opacity: enabled ? 1 : 0.45
    Keys.onReturnPressed: activated()
    Keys.onEnterPressed: activated()
    Keys.onSpacePressed: activated()
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.activated()
        onEntered: root.hoverChanged(true)
        onExited: root.hoverChanged(false)
    }
}
