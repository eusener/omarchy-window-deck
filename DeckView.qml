pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import qs.Commons as Commons
import "Model.js" as Model

Item {
    id: root
    property var windows: []
    property int workspaceId: 1
    property int activeWorkspace: workspaceId
    // Windows per slot (1-10) of the monitor's block.
    property var slotCounts: []
    property int selectedIndex: 0
    property bool minimizedOnly: false
    property bool busy: false
    property string error: ""
    property var toplevelLookup: null
    property Component previewDelegate: null
    property bool captureEnabled: true
    // A stable identity-only model preserves capture sessions through metadata
    // snapshots, but rebuilds them when a source window is replaced or removed.
    readonly property string windowIdentities: windows.map(function(row) { return row.address; }).join(",")
    readonly property var windowSlots: windowIdentities ? windowIdentities.split(",") : []
    signal accepted(var record)
    signal cancelled()
    signal selectionRequested(int index)
    signal retryRequested()
    signal workspaceRequested(int slot)
    signal manageRequested(string action)
    readonly property int minimizedCount: windows.filter(function(w) { return w.minimized; }).length
    Commons.Translations { id: strings; directory: Qt.resolvedUrl("i18n") }

    function step(delta) {
        if (!windows.length || busy) return;
        selectionRequested((selectedIndex + delta + windows.length) % windows.length);
    }
    function confirm() {
        if (windows.length && !busy) accepted(windows[selectedIndex]);
    }
    function focusPicker() { keys.forceActiveFocus(); }
    function manageSelected(direction) {
        if (!windows.length || busy) return;
        var action = Model.ladderAction(windows[selectedIndex], direction);
        if (action) manageRequested(action);
    }

    Rectangle { anchors.fill: parent; color: DeckPalette.scrim }
    MouseArea { anchors.fill: parent; onClicked: root.cancelled() }

    RectangularShadow {
        anchors.fill: panel
        visible: DeckPalette.panelOpaque
        radius: panel.radius
        offset: Qt.vector2d(0, DeckPalette.px(10))
        blur: DeckPalette.px(36)
        color: DeckPalette.shadow
    }
    Rectangle {
        id: panel
        anchors.centerIn: parent
        width: Math.min(root.width * 0.88, DeckPalette.px(1280))
        height: Math.min(root.height * 0.8, DeckPalette.px(650))
        radius: DeckPalette.px(26)
        color: DeckPalette.panel
        border.width: 1
        border.color: DeckPalette.border
        clip: true
        MouseArea { anchors.fill: parent; onClicked: root.cancelled() }

        Item {
            id: header
            x: DeckPalette.px(32); y: DeckPalette.px(25)
            width: parent.width - x * 2
            readonly property bool compact: width < DeckPalette.px(670)
            height: DeckPalette.px(compact ? 60 : 79)
            Column {
                spacing: DeckPalette.px(8)
                PlainText {
                    visible: !header.compact
                    text: "WINDOW DECK"
                    color: DeckPalette.accent
                    font.pixelSize: DeckPalette.px(10)
                    font.letterSpacing: 2.4
                    font.weight: Font.DemiBold
                }
                PlainText {
                    text: strings.t("deck.area").arg(Commons.I18n.formatNumber(Model.slot(root.workspaceId)))
                    font.pixelSize: DeckPalette.px(22)
                    font.weight: Font.Medium
                }
            }
            // Workspaces of this monitor: the shown one is selected, the active
            // one is marked, empty ones are dimmed. Number keys do the same.
            Row {
                id: slots
                visible: !header.compact
                anchors.horizontalCenter: parent.horizontalCenter
                y: (header.height - height) / 2
                spacing: DeckPalette.px(4)
                Repeater {
                    model: 10
                    delegate: DeckButton {
                        id: slotButton
                        required property int index
                        readonly property int slot: index + 1
                        readonly property int count: root.slotCounts[index] || 0
                        width: DeckPalette.px(30); height: DeckPalette.px(30)
                        activeFocusOnTab: false
                        selected: Model.slot(root.workspaceId) === slotButton.slot
                        busy: root.busy
                        accessibleName: strings.t("deck.area").arg(Commons.I18n.formatNumber(slot)) + ", "
                            + strings.tn("deck.windows", count).arg(Commons.I18n.formatNumber(count))
                        PlainText {
                            anchors.centerIn: parent
                            text: Commons.I18n.formatNumber(slotButton.slot % 10)
                            font.family: DeckPalette.monoFamily
                            font.pixelSize: DeckPalette.px(13)
                            font.weight: slotButton.selected ? Font.DemiBold : Font.Normal
                            color: slotButton.selected ? DeckPalette.accent : slotButton.count ? DeckPalette.foreground : DeckPalette.muted
                            opacity: slotButton.count || slotButton.selected ? 1 : 0.55
                        }
                        Rectangle {
                            visible: Model.slot(root.activeWorkspace) === slotButton.slot
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: DeckPalette.px(3)
                            width: DeckPalette.px(12); height: 2; radius: 1
                            color: DeckPalette.minimized
                        }
                        onActivated: { root.workspaceRequested(slotButton.slot); root.focusPicker(); }
                    }
                }
            }
            Row {
                x: header.compact ? 0 : header.width - width
                y: header.compact ? DeckPalette.px(38) : (header.height - height) / 2
                spacing: DeckPalette.px(14)
                PlainText {
                    text: strings.tn("deck.windows", root.windows.length).arg(Commons.I18n.formatNumber(root.windows.length))
                    color: DeckPalette.muted
                }
                Rectangle { width: 1; height: DeckPalette.px(17); color: DeckPalette.border }
                PlainText {
                    text: strings.tn("deck.minimizedCount", root.minimizedCount).arg(Commons.I18n.formatNumber(root.minimizedCount))
                    color: DeckPalette.minimized
                }
            }
        }

        Item {
            id: carousel
            x: 0; y: header.y + header.height
            width: panel.width
            height: Math.max(60, panel.height - y - footer.height - DeckPalette.px(18))
            readonly property real cardHeight: Math.min(height - DeckPalette.px(22), DeckPalette.px(438))
            readonly property real cardWidth: Math.min(width * 0.65, DeckPalette.px(560))
            clip: true

            Repeater {
                model: root.windowSlots
                delegate: Item {
                    id: slot
                    required property int index
                    readonly property var modelData: root.windows[index] || ({})
                    readonly property int distance: index - root.selectedIndex
                    readonly property bool near: Math.abs(distance) <= 2
                    x: (carousel.width - width) / 2 + distance * (width * 0.67)
                    y: (carousel.height - height) / 2
                    width: carousel.cardWidth
                    height: carousel.cardHeight
                    scale: distance === 0 ? 1 : Math.abs(distance) === 1 ? 0.77 : 0.6
                    z: 5 - Math.abs(distance)
                    opacity: distance === 0 ? 1 : Math.abs(distance) === 1 ? 0.58 : 0.22
                    visible: near
                    Behavior on x { NumberAnimation { duration: Commons.Style.duration(140); easing.type: Easing.OutCubic } }
                    Behavior on scale { NumberAnimation { duration: Commons.Style.duration(140); easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: Commons.Style.duration(120); easing.type: Easing.OutCubic } }
                    Loader {
                        anchors.fill: parent
                        active: slot.near && root.captureEnabled
                        sourceComponent: WindowCard {
                            record: slot.modelData
                            selected: slot.distance === 0
                            captureEnabled: root.captureEnabled
                            busy: root.busy
                            previewDelegate: root.previewDelegate
                            toplevel: root.toplevelLookup ? root.toplevelLookup(slot.modelData.address) : null
                            onActivated: {
                                if (slot.distance === 0) root.accepted(slot.modelData);
                                else { root.selectionRequested(slot.index); root.focusPicker(); }
                            }
                            onActionRequested: function(action) { root.manageRequested(action); root.focusPicker(); }
                        }
                    }
                }
            }

            Column {
                anchors.centerIn: parent
                spacing: DeckPalette.px(18)
                visible: root.windows.length === 0
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: DeckPalette.px(62); height: DeckPalette.px(48)
                    radius: DeckPalette.px(10)
                    color: DeckPalette.surface
                    border.color: DeckPalette.border
                    PlainText { anchors.centerIn: parent; text: "—"; color: DeckPalette.accent; font.pixelSize: DeckPalette.px(24) }
                }
                PlainText {
                    text: strings.t(root.minimizedOnly ? "deck.emptyMinimized" : "deck.empty")
                    font.pixelSize: DeckPalette.px(18)
                    color: DeckPalette.muted
                }
            }
        }

        Item {
            id: footer
            x: DeckPalette.px(32)
            width: parent.width - x * 2
            height: DeckPalette.px(header.compact ? 74 : 95)
            anchors.bottom: parent.bottom
            PlainText {
                id: position
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.error ? strings.t(root.error === "action" ? "deck.actionError" : "deck.connectionError")
                    : root.windows.length ? strings.t("deck.position").arg(Commons.I18n.formatNumber(root.selectedIndex + 1)).arg(Commons.I18n.formatNumber(root.windows.length)) : ""
                color: root.error ? DeckPalette.minimized : DeckPalette.muted
                font.pixelSize: DeckPalette.px(12)
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: DeckPalette.px(25)
                spacing: DeckPalette.px(22)
                Repeater {
                    model: [{ keys: "Tab  /  ← →", label: "deck.choose" }, { keys: "Enter", label: "deck.open" }]
                        .concat(header.compact ? [] : [{ keys: "↑ ↓", label: "deck.manage" }, { keys: "1 – 0", label: "deck.workspace" }])
                        .concat([{ keys: "Esc", label: "deck.back" }])
                    delegate: Row {
                        id: hint
                        required property var modelData
                        spacing: DeckPalette.px(8)
                        PlainText { text: hint.modelData.keys; font.family: DeckPalette.monoFamily; font.pixelSize: DeckPalette.px(11); color: DeckPalette.accent }
                        PlainText { text: strings.t(hint.modelData.label); font.pixelSize: DeckPalette.px(11); color: DeckPalette.muted }
                    }
                }
            }
            DeckButton {
                visible: root.error !== ""
                anchors.right: parent.right
                anchors.top: parent.top
                width: DeckPalette.px(26); height: width
                accessibleName: strings.t("deck.retry")
                PlainText { anchors.centerIn: parent; text: "↻"; color: DeckPalette.accent }
                onActivated: root.retryRequested()
            }
        }
    }
    Item {
        id: keys
        focus: true
        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) root.cancelled();
            else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab)
                root.step((event.modifiers & Qt.ShiftModifier) || event.key === Qt.Key_Backtab ? -1 : 1);
            else if (event.key === Qt.Key_Right) root.step(1);
            else if (event.key === Qt.Key_Left) root.step(-1);
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) root.confirm();
            else if (event.key === Qt.Key_Up) root.manageSelected("up");
            else if (event.key === Qt.Key_Down) root.manageSelected("down");
            else if (Model.slotForKey(event.text) > 0 && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)))
                root.workspaceRequested(Model.slotForKey(event.text));
            else if (event.key === Qt.Key_R && root.error) root.retryRequested();
            else return;
            event.accepted = true;
        }
    }
}
