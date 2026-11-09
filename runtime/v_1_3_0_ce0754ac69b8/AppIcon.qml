pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

Item {
    id: root
    property string appId: ""
    readonly property var entry: {
        var revision = DesktopEntries.applications.values.length;
        return appId ? DesktopEntries.heuristicLookup(appId) : null;
    }
    readonly property string appName: entry ? entry.name : appId
    implicitWidth: 24
    implicitHeight: 24

    Image {
        id: icon
        anchors.fill: parent
        source: root.entry && root.entry.icon ? Quickshell.iconPath(root.entry.icon, true) : ""
        sourceSize.width: width * (root.Window.window ? root.Window.window.devicePixelRatio : 1)
        sourceSize.height: height * (root.Window.window ? root.Window.window.devicePixelRatio : 1)
        fillMode: Image.PreserveAspectFit
        visible: status === Image.Ready
        smooth: true
    }
    Rectangle {
        visible: !icon.visible
        anchors.centerIn: parent
        width: parent.width * 0.82
        height: parent.height * 0.7
        color: DeckPalette.surface
        border.color: DeckPalette.accent
        border.width: 1.5
        radius: width * 0.16
        Rectangle {
            x: parent.width * 0.18
            y: parent.height * 0.22
            width: parent.width * 0.4
            height: Math.max(1, parent.height * 0.08)
            color: DeckPalette.accent
            radius: 1
        }
    }
}
