pragma ComponentBehavior: Bound
import QtQuick
import qs.Commons as Commons

Item {
    id: root
    property var record: ({})
    property var toplevel: null
    property bool selected: false
    property bool captureEnabled: false
    property bool busy: false
    // Allows a static illustration in the documentation preview, without capture.
    property Component previewDelegate: null
    signal activated()
    readonly property real captionHeight: Math.min(DeckPalette.px(88), Math.max(DeckPalette.px(65), height * 0.3))
    readonly property real inset: DeckPalette.px(10)
    Commons.Translations { id: strings; directory: Qt.resolvedUrl("i18n") }

    Rectangle {
        x: -5; y: 8
        width: parent.width + 10; height: parent.height + 8
        radius: DeckPalette.px(22)
        color: DeckPalette.shadow
    }
    Rectangle {
        anchors.fill: parent
        radius: DeckPalette.px(18)
        color: DeckPalette.surface
        border.width: root.selected ? 2 : 1
        border.color: root.selected ? DeckPalette.accent : button.hovered ? DeckPalette.muted : DeckPalette.border
    }
    Rectangle {
        id: picture
        clip: true
        x: root.inset; y: root.inset
        width: parent.width - root.inset * 2
        height: Math.max(1, parent.height - root.captionHeight - root.inset)
        radius: DeckPalette.px(11)
        color: DeckPalette.background

        Column {
            anchors.centerIn: parent
            spacing: DeckPalette.px(12)
            visible: !root.previewDelegate && (!preview.item || !preview.item.hasContent)
            AppIcon { anchors.horizontalCenter: parent.horizontalCenter; width: DeckPalette.px(52); height: width; appId: root.record.appId || "" }
            PlainText { anchors.horizontalCenter: parent.horizontalCenter; text: strings.t("deck.unavailable"); color: DeckPalette.muted; font.pixelSize: DeckPalette.px(12) }
        }
        Loader {
            id: preview
            anchors.fill: parent
            active: root.captureEnabled && (!!root.previewDelegate || !!root.toplevel)
            property var record: root.record
            sourceComponent: root.previewDelegate || liveCapture
        }
        Component {
            id: liveCapture
            Item {
                readonly property bool hasContent: capture.hasContent
                WindowCapture {
                    id: capture
                    captureSource: root.captureEnabled ? root.toplevel : null
                    live: root.captureEnabled && !root.record.minimized
                    Component.onCompleted: if (!live) captureFrame()
                }
            }
        }
        Rectangle {
            visible: !!root.record.minimized
            anchors.top: parent.top; anchors.right: parent.right
            anchors.margins: DeckPalette.px(12)
            width: badge.implicitWidth + DeckPalette.px(20)
            height: DeckPalette.px(27)
            radius: height / 2
            color: DeckPalette.background
            border.color: DeckPalette.minimized
            border.width: 1
            PlainText {
                id: badge
                anchors.centerIn: parent
                text: strings.t("deck.minimized")
                color: DeckPalette.minimized
                font.pixelSize: DeckPalette.px(11)
            }
        }
    }
    AppIcon {
        id: appIcon
        x: DeckPalette.px(20)
        y: picture.y + picture.height + DeckPalette.px(22)
        width: DeckPalette.px(28); height: width
        appId: root.record.appId || ""
    }
    Column {
        x: appIcon.x + appIcon.width + DeckPalette.px(12)
        y: picture.y + picture.height + DeckPalette.px(16)
        width: root.width - x - DeckPalette.px(20)
        spacing: DeckPalette.px(3)
        PlainText {
            width: parent.width
            text: appIcon.appName || root.record.appId || "Window"
            color: root.selected ? DeckPalette.accent : DeckPalette.muted
            font.pixelSize: DeckPalette.px(11)
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }
        PlainText {
            width: parent.width
            text: root.record.title || root.record.appId || ""
            font.pixelSize: DeckPalette.px(15)
            font.weight: Font.Medium
            maximumLineCount: root.selected && root.height > DeckPalette.px(280) ? 2 : 1
            wrapMode: Text.Wrap
            elide: Text.ElideRight
        }
    }
    DeckButton {
        id: button
        anchors.fill: parent
        busy: root.busy
        accessibleName: (root.record.minimized ? strings.t("deck.restore") : strings.t("deck.focus")) + ": " + (root.record.title || root.record.appId || "")
        // The card owns its chrome; keep pointer and accessibility semantics here.
        chromeless: true
        onActivated: root.activated()
    }
    Rectangle {
        anchors.fill: parent
        radius: DeckPalette.px(18)
        color: "transparent"
        border.width: 2
        border.color: DeckPalette.accent
        visible: button.activeFocus
    }
}
