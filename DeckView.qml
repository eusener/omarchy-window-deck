pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell.Wayland
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
    // The screen behind the overlay. When set, the picker snapshots it on open
    // and paints the launcher's liquid glass from that snapshot; without it
    // (or until the snapshot arrives) the plain theme panel is used.
    property var backdropScreen: null
    // A static item to use instead of a screen snapshot (documentation preview).
    property Item backdropItem: null
    // Shader effects need the GPU scene graph; software rendering keeps the
    // plain theme panel.
    readonly property bool glass: backdrop.ready && GraphicsInfo.api !== GraphicsInfo.Software
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

    // Hyprland's blur has one global strength and only shows behind pixels
    // above ignore_alpha, so, as the launcher does, the picker snapshots the
    // screen once and blurs that itself. The blur ramps up from zero, which
    // matches the desktop pixel for pixel, so the open is seamless.
    Item {
        id: backdrop
        anchors.fill: parent
        property real amount: 0
        readonly property bool ready: !!shot.item && (root.backdropScreen ? shot.item.hasContent : true)
        onReadyChanged: if (ready) backdropIn.restart(); else amount = 0
        Loader {
            id: shot
            anchors.fill: parent
            active: (!!root.backdropScreen || !!root.backdropItem) && GraphicsInfo.api !== GraphicsInfo.Software
            sourceComponent: root.backdropScreen ? screenShot : itemShot
        }
        Component {
            id: screenShot
            ScreencopyView {
                captureSource: root.backdropScreen
                live: false
                paintCursor: false
            }
        }
        Component {
            id: itemShot
            ShaderEffectSource { sourceItem: root.backdropItem; live: false }
        }
        MultiEffect {
            anchors.fill: parent
            source: shot.item
            visible: root.glass
            autoPaddingEnabled: false
            blurEnabled: true
            blurMax: 32
            blur: backdrop.amount
        }
        Rectangle {
            anchors.fill: parent
            visible: root.glass
            color: Commons.Util.alpha(DeckPalette.background, 0.68)
            opacity: backdrop.amount / 0.4
        }
        // Heavier, desaturated blur that only the glass panel samples.
        MultiEffect {
            id: glassBlur
            anchors.fill: parent
            source: shot.item
            visible: false
            layer.enabled: root.glass
            autoPaddingEnabled: false
            blurEnabled: true
            blurMax: 64
            blur: 1.0
            saturation: 0.35
        }
        NumberAnimation {
            id: backdropIn
            target: backdrop; property: "amount"
            from: 0; to: 0.4; duration: Commons.Style.duration(280); easing.type: Easing.OutCubic
        }
    }
    Rectangle { anchors.fill: parent; color: DeckPalette.scrim; visible: !root.glass }
    MouseArea { anchors.fill: parent; onClicked: root.cancelled() }

    // Soft lift off the desktop, as under the launcher card.
    RectangularShadow {
        anchors.fill: panel
        visible: root.glass
        radius: panel.radius
        offset: Qt.vector2d(0, 10)
        blur: 36
        spread: 2
        color: Commons.Util.alpha("#000000", 0.14)
    }
    // Liquid glass (shaders/glass.frag, shared with the launcher): bends the
    // blurred snapshot through a lens band along the rounded edge, tints it
    // with the menu background and lights the rim.
    ShaderEffect {
        anchors.fill: panel
        visible: root.glass
        readonly property color base: Commons.Color.menu.background
        property var source: glassBlur
        property size itemSize: Qt.size(width, height)
        property rect screenRect: Qt.rect(panel.x, panel.y, panel.width, panel.height)
        property size screenSize: Qt.size(root.width, root.height)
        property real radius: panel.radius
        property real bezel: Commons.Style.space(24)
        property real refraction: Commons.Style.space(22)
        property real dispersion: 0.2
        property vector4d tint: Qt.vector4d(base.r, base.g, base.b, 0.72)
        property real rim: 0.8
        property real lift: 0.015
        property real grain: 0.035
        property real sheen: 0.045
        property real footerTop: panel.height - footer.height
        property real footerShade: 0.12
        fragmentShader: Qt.resolvedUrl("shaders/glass.frag.qsb")
    }

    RectangularShadow {
        anchors.fill: panel
        visible: DeckPalette.panelOpaque && !root.glass
        radius: panel.radius
        offset: Qt.vector2d(0, DeckPalette.px(10))
        blur: DeckPalette.px(36)
        color: DeckPalette.shadow
    }
    Rectangle {
        id: panel
        anchors.centerIn: parent
        width: Math.min(root.width * 0.88, DeckPalette.px(1280))
        height: Math.min(root.height * 0.8, DeckPalette.px(660))
        radius: DeckPalette.px(26)
        // The glass shader paints the fill, rim and footer band when present.
        color: root.glass ? "transparent" : DeckPalette.panel
        border.width: root.glass ? 0 : 1
        border.color: DeckPalette.ring
        clip: true
        MouseArea { anchors.fill: parent; onClicked: root.cancelled() }

        // Fallback glass: a little more light at the top, and a bright top edge.
        Rectangle {
            visible: !root.glass
            anchors.fill: parent
            anchors.margins: 1
            radius: parent.radius - 1
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0.045) }
                GradientStop { position: 0.45; color: Qt.rgba(1, 1, 1, 0) }
                GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.06) }
            }
        }
        Rectangle {
            visible: !root.glass
            x: panel.radius; y: 1
            width: panel.width - panel.radius * 2; height: 1
            color: DeckPalette.edgeLight
        }

        Item {
            id: header
            x: DeckPalette.px(32); y: DeckPalette.px(24)
            width: parent.width - x * 2
            readonly property bool compact: width < DeckPalette.px(670)
            height: DeckPalette.px(compact ? 64 : 56)
            Column {
                spacing: DeckPalette.px(4)
                anchors.verticalCenter: header.compact ? undefined : parent.verticalCenter
                PlainText {
                    visible: !header.compact
                    text: "WINDOW DECK"
                    color: DeckPalette.accent
                    font.pixelSize: DeckPalette.px(11)
                    font.letterSpacing: 0.9
                    font.weight: Font.Medium
                }
                PlainText {
                    text: strings.t("deck.area").arg(Commons.I18n.formatNumber(Model.slot(root.workspaceId)))
                    font.pixelSize: DeckPalette.px(24)
                    font.weight: Font.DemiBold
                }
            }
            // Workspaces of this monitor: the shown one is selected, the active
            // one is marked, empty ones are dimmed. Number keys do the same.
            Rectangle {
                visible: !header.compact
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                width: slots.width + DeckPalette.px(8)
                height: slots.height + DeckPalette.px(8)
                radius: DeckPalette.px(12)
                color: DeckPalette.well
                border.width: 1
                border.color: DeckPalette.ring
                Row {
                    id: slots
                    anchors.centerIn: parent
                    spacing: DeckPalette.px(2)
                    Repeater {
                        model: 10
                        delegate: DeckButton {
                            id: slotButton
                            required property int index
                            readonly property int slot: index + 1
                            readonly property int count: root.slotCounts[index] || 0
                            width: DeckPalette.px(30); height: DeckPalette.px(30)
                            activeFocusOnTab: false
                            chromeless: true
                            selected: Model.slot(root.workspaceId) === slotButton.slot
                            busy: root.busy
                            accessibleName: strings.t("deck.area").arg(Commons.I18n.formatNumber(slot)) + ", "
                                + strings.tn("deck.windows", count).arg(Commons.I18n.formatNumber(count))
                            Rectangle {
                                anchors.fill: parent
                                radius: DeckPalette.px(9)
                                visible: slotButton.selected || slotButton.hovered
                                color: slotButton.selected ? "transparent" : DeckPalette.chip
                                gradient: slotButton.selected ? accentGradient : null
                            }
                            PlainText {
                                anchors.centerIn: parent
                                text: Commons.I18n.formatNumber(slotButton.slot % 10)
                                font.pixelSize: DeckPalette.px(13)
                                font.weight: slotButton.selected ? Font.DemiBold : Font.Medium
                                font.features: { "tnum": 1 }
                                color: slotButton.selected ? DeckPalette.accentInk : slotButton.count ? DeckPalette.foreground : DeckPalette.dimmed
                            }
                            Rectangle {
                                visible: Model.slot(root.activeWorkspace) === slotButton.slot
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: DeckPalette.px(4)
                                width: DeckPalette.px(10); height: 2; radius: 1
                                color: slotButton.selected ? Commons.Util.alpha(DeckPalette.accentInk, 0.55) : DeckPalette.minimized
                            }
                            onActivated: { root.workspaceRequested(slotButton.slot); root.focusPicker(); }
                        }
                    }
                }
            }
            Row {
                x: header.compact ? 0 : header.width - width
                y: header.compact ? DeckPalette.px(40) : (header.height - height) / 2
                spacing: DeckPalette.px(8)
                Rectangle {
                    // The empty state already says there is nothing here.
                    visible: root.windows.length > 0
                    width: windowCount.implicitWidth + DeckPalette.px(22)
                    height: windowCount.implicitHeight + DeckPalette.px(8)
                    radius: height / 2
                    color: "transparent"
                    border.width: 1
                    border.color: DeckPalette.hairline
                    PlainText {
                        id: windowCount
                        anchors.centerIn: parent
                        text: strings.tn("deck.windows", root.windows.length).arg(Commons.I18n.formatNumber(root.windows.length))
                        color: DeckPalette.muted
                        font.pixelSize: DeckPalette.px(12)
                    }
                }
                Rectangle {
                    visible: root.minimizedCount > 0
                    width: minimizedLabel.implicitWidth + DeckPalette.px(22)
                    height: minimizedLabel.implicitHeight + DeckPalette.px(8)
                    radius: height / 2
                    color: Commons.Util.alpha(DeckPalette.minimized, 0.10)
                    border.width: 1
                    border.color: Commons.Util.alpha(DeckPalette.minimized, 0.34)
                    PlainText {
                        id: minimizedLabel
                        anchors.centerIn: parent
                        text: strings.tn("deck.minimizedCount", root.minimizedCount).arg(Commons.I18n.formatNumber(root.minimizedCount))
                        color: DeckPalette.minimized
                        font.pixelSize: DeckPalette.px(12)
                    }
                }
            }
        }

        Rectangle {
            id: headerRule
            y: header.y + header.height + DeckPalette.px(20)
            width: panel.width; height: 1
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 0.12; color: DeckPalette.hairline }
                GradientStop { position: 0.88; color: DeckPalette.hairline }
                GradientStop { position: 1; color: "transparent" }
            }
        }

        Item {
            id: carousel
            x: 0; y: headerRule.y + 1
            width: panel.width
            height: Math.max(60, panel.height - y - footer.height)
            readonly property real indicatorSpace: DeckPalette.px(48)
            readonly property real cardHeight: Math.min(height - indicatorSpace - DeckPalette.px(28), DeckPalette.px(430))
            readonly property real cardWidth: Math.min(width * 0.62, DeckPalette.px(580))
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
                    y: (carousel.height - carousel.indicatorSpace - height) / 2 + DeckPalette.px(6)
                    width: carousel.cardWidth
                    height: carousel.cardHeight
                    scale: distance === 0 ? 1 : Math.abs(distance) === 1 ? 0.77 : 0.6
                    z: 5 - Math.abs(distance)
                    opacity: distance === 0 ? 1 : Math.abs(distance) === 1 ? 0.6 : 0.22
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

            // Position: one dot per window (minimized ones in their color), or
            // the error message after a failed query or action.
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: DeckPalette.px(18)
                spacing: DeckPalette.px(12)
                visible: root.windows.length > 0 || root.error !== ""
                Row {
                    visible: !root.error && root.windows.length > 1 && root.windows.length <= 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: DeckPalette.px(6)
                    Repeater {
                        model: root.windows.length
                        delegate: Rectangle {
                            required property int index
                            readonly property bool current: index === root.selectedIndex
                            width: current ? DeckPalette.px(20) : DeckPalette.px(6)
                            height: DeckPalette.px(6)
                            radius: height / 2
                            color: current ? DeckPalette.accent
                                : (root.windows[index] || {}).minimized ? Commons.Util.alpha(DeckPalette.minimized, 0.55)
                                : Commons.Util.alpha(DeckPalette.foreground, 0.28)
                            Behavior on width { NumberAnimation { duration: Commons.Style.duration(140); easing.type: Easing.OutCubic } }
                        }
                    }
                }
                PlainText {
                    id: position
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.error ? strings.t(root.error === "action" ? "deck.actionError" : "deck.connectionError")
                        : root.windows.length ? strings.t("deck.position").arg(Commons.I18n.formatNumber(root.selectedIndex + 1)).arg(Commons.I18n.formatNumber(root.windows.length)) : ""
                    color: root.error ? DeckPalette.minimized : DeckPalette.muted
                    font.pixelSize: DeckPalette.px(12)
                    font.features: { "tnum": 1 }
                    width: Math.min(implicitWidth, carousel.width - DeckPalette.px(64))
                    elide: Text.ElideRight
                }
            }

            Column {
                id: emptyState
                anchors.centerIn: parent
                spacing: DeckPalette.px(18)
                visible: root.windows.length === 0
                readonly property bool elsewhere: Model.slot(root.activeWorkspace) !== Model.slot(root.workspaceId)
                Item {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: DeckPalette.px(220); height: DeckPalette.px(128)
                    Rectangle {
                        anchors.fill: parent
                        radius: DeckPalette.px(18)
                        color: DeckPalette.chip
                        border.width: 1
                        border.color: DeckPalette.ring
                    }
                    Rectangle {
                        x: DeckPalette.px(22); y: DeckPalette.px(18)
                        width: DeckPalette.px(120); height: DeckPalette.px(76)
                        radius: DeckPalette.px(10)
                        color: "transparent"
                        border.width: 1
                        border.color: DeckPalette.ringHover
                    }
                    Rectangle {
                        x: parent.width - width - DeckPalette.px(22); y: parent.height - height - DeckPalette.px(18)
                        width: DeckPalette.px(120); height: DeckPalette.px(76)
                        radius: DeckPalette.px(10)
                        color: "transparent"
                        border.width: 1
                        border.color: DeckPalette.ringHover
                    }
                    Rectangle {
                        anchors.centerIn: parent
                        width: DeckPalette.px(48); height: width
                        radius: DeckPalette.px(13)
                        gradient: accentGradient
                        // A window glyph drawn with rectangles, in the accent ink.
                        Rectangle {
                            anchors.centerIn: parent
                            width: DeckPalette.px(20); height: DeckPalette.px(16)
                            radius: DeckPalette.px(3)
                            color: "transparent"
                            border.width: Math.max(1.5, DeckPalette.px(2))
                            border.color: DeckPalette.accentInk
                            Rectangle {
                                y: DeckPalette.px(4)
                                width: parent.width; height: parent.border.width
                                color: DeckPalette.accentInk
                            }
                        }
                    }
                }
                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: DeckPalette.px(6)
                    PlainText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: strings.t(root.minimizedOnly ? "deck.emptyMinimized" : "deck.empty")
                        font.pixelSize: DeckPalette.px(20)
                        font.weight: Font.DemiBold
                    }
                    PlainText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Math.min(implicitWidth, carousel.width - DeckPalette.px(64))
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        text: strings.t("deck.emptyHint")
                        color: DeckPalette.muted
                        font.pixelSize: DeckPalette.px(14)
                    }
                }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: DeckPalette.px(10)
                    topPadding: DeckPalette.px(4)
                    DeckButton {
                        id: backButton
                        visible: emptyState.elsewhere && Model.slot(root.activeWorkspace) > 0
                        chromeless: true
                        busy: root.busy
                        activeFocusOnTab: false
                        width: backRow.implicitWidth + DeckPalette.px(32); height: DeckPalette.px(44)
                        accessibleName: backLabel.text
                        Rectangle {
                            anchors.fill: parent
                            radius: DeckPalette.px(12)
                            gradient: Gradient {
                                GradientStop { position: 0; color: DeckPalette.tint(backButton.hovered ? 0.32 : 0.24) }
                                GradientStop { position: 1; color: DeckPalette.tint(backButton.hovered ? 0.22 : 0.14) }
                            }
                            border.width: 1
                            border.color: DeckPalette.tint(0.38)
                        }
                        Row {
                            id: backRow
                            anchors.centerIn: parent
                            spacing: DeckPalette.px(10)
                            PlainText {
                                id: backLabel
                                anchors.verticalCenter: parent.verticalCenter
                                text: strings.t("deck.backTo").arg(Commons.I18n.formatNumber(Model.slot(root.activeWorkspace)))
                                font.pixelSize: DeckPalette.px(14)
                                font.weight: Font.Medium
                            }
                            KeyHint {
                                anchors.verticalCenter: parent.verticalCenter
                                keys: Commons.I18n.formatNumber(Model.slot(root.activeWorkspace) % 10)
                                textColor: DeckPalette.accent
                                border.color: DeckPalette.tint(0.35)
                            }
                        }
                        onActivated: { root.workspaceRequested(Model.slot(root.activeWorkspace)); root.focusPicker(); }
                    }
                    DeckButton {
                        id: closeButton
                        chromeless: true
                        activeFocusOnTab: false
                        width: closeRow.implicitWidth + DeckPalette.px(32); height: DeckPalette.px(44)
                        accessibleName: closeLabel.text
                        Rectangle {
                            anchors.fill: parent
                            radius: DeckPalette.px(12)
                            color: closeButton.hovered ? DeckPalette.ringHover : DeckPalette.chip
                            border.width: 1
                            border.color: DeckPalette.ring
                        }
                        Row {
                            id: closeRow
                            anchors.centerIn: parent
                            spacing: DeckPalette.px(10)
                            PlainText {
                                id: closeLabel
                                anchors.verticalCenter: parent.verticalCenter
                                text: strings.t("deck.close")
                                font.pixelSize: DeckPalette.px(14)
                                font.weight: Font.Medium
                            }
                            KeyHint { anchors.verticalCenter: parent.verticalCenter; keys: "Esc" }
                        }
                        onActivated: root.cancelled()
                    }
                }
            }
        }

        Item {
            id: footer
            anchors.bottom: parent.bottom
            width: parent.width
            height: DeckPalette.px(46)
            clip: true
            // Rounded at the bottom with the panel, straight at the top.
            Rectangle {
                visible: !root.glass
                x: 1; y: -panel.radius
                width: parent.width - 2; height: parent.height + panel.radius - 1
                radius: panel.radius - 1
                color: DeckPalette.well
            }
            Rectangle { width: parent.width; height: 1; color: Commons.Util.alpha("#ffffff", root.glass ? 0.07 : 0); visible: root.glass }
            Rectangle { width: parent.width; height: 1; color: DeckPalette.ring; visible: !root.glass }
            readonly property bool empty: root.windows.length === 0
            Row {
                x: DeckPalette.px(20)
                anchors.verticalCenter: parent.verticalCenter
                spacing: DeckPalette.px(18)
                Repeater {
                    model: (footer.empty ? [] : [{ keys: ["Tab", "← →"], label: "deck.choose" }, { keys: ["↵"], label: "deck.open" }])
                        .concat(header.compact || footer.empty ? [] : [{ keys: ["↑ ↓"], label: "deck.manage" }])
                        .concat(header.compact ? [] : [{ keys: ["1–0"], label: "deck.workspace" }])
                    delegate: Row {
                        id: hint
                        required property var modelData
                        spacing: DeckPalette.px(6)
                        Repeater {
                            model: hint.modelData.keys
                            delegate: KeyHint {
                                required property string modelData
                                anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                                keys: modelData
                            }
                        }
                        PlainText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: strings.t(hint.modelData.label)
                            font.pixelSize: DeckPalette.px(12)
                            color: DeckPalette.muted
                        }
                    }
                }
            }
            Row {
                anchors.right: parent.right
                anchors.rightMargin: DeckPalette.px(20)
                anchors.verticalCenter: parent.verticalCenter
                spacing: DeckPalette.px(14)
                DeckButton {
                    visible: root.error !== ""
                    anchors.verticalCenter: parent.verticalCenter
                    width: retryRow.implicitWidth + DeckPalette.px(16); height: DeckPalette.px(28)
                    accessibleName: strings.t("deck.retry")
                    Row {
                        id: retryRow
                        anchors.centerIn: parent
                        spacing: DeckPalette.px(6)
                        PlainText { anchors.verticalCenter: parent.verticalCenter; text: "↻"; color: DeckPalette.accent }
                        KeyHint { anchors.verticalCenter: parent.verticalCenter; keys: "R" }
                    }
                    onActivated: root.retryRequested()
                }
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: DeckPalette.px(6)
                    KeyHint { anchors.verticalCenter: parent.verticalCenter; keys: "Esc" }
                    PlainText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: strings.t("deck.back")
                        font.pixelSize: DeckPalette.px(12)
                        color: DeckPalette.muted
                    }
                }
            }
        }
    }
    Gradient {
        id: accentGradient
        GradientStop { position: 0; color: DeckPalette.accentTop }
        GradientStop { position: 1; color: DeckPalette.accentBottom }
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
