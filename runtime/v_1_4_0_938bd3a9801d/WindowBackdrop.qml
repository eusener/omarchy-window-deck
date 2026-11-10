pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell.Hyprland
import qs.Commons as Commons
import "Model.js" as Model

// What a transparent window shows through itself on the desktop: the part of
// the wallpaper behind it, blurred when Hyprland's blur is on. Opaque windows
// cover it entirely. Without a still wallpaper, the theme background remains.
Item {
    id: root
    property var record: ({})
    clip: true

    readonly property var monitor: {
        var all = Hyprland.monitors.values;
        for (var i = 0; i < all.length; i++) {
            if (all[i].id === root.record.monitorId) {
                var ipc = all[i].lastIpcObject || {};
                return { x: all[i].x, y: all[i].y, width: all[i].width, height: all[i].height,
                         scale: all[i].scale, transform: ipc.transform || 0 };
            }
        }
        return null;
    }
    readonly property var geometry: Model.backdropGeometry(record, monitor, width)
    readonly property var blur: DeckState.blur
    readonly property int radius: geometry ? Model.blurRadius(blur, geometry.scale) : 0
    readonly property string source: DeckState.wallpaperPath && !Commons.Util.isVideoPath(DeckState.wallpaperPath)
        ? Commons.Util.fileUrl(DeckState.wallpaperPath) : ""
    readonly property bool ready: !!geometry && wallpaper.status === Image.Ready

    Item {
        id: desktop
        visible: root.ready
        x: root.geometry ? root.geometry.x : 0
        y: root.geometry ? root.geometry.y : 0
        width: root.geometry ? root.geometry.width : 0
        height: root.geometry ? root.geometry.height : 0

        Image {
            id: wallpaper
            anchors.fill: parent
            source: root.geometry ? root.source : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            // One decode per wallpaper and size, shared by every card.
            sourceSize: Qt.size(1280, 1280)
            visible: root.radius === 0
        }
        MultiEffect {
            anchors.fill: wallpaper
            source: wallpaper
            visible: root.radius > 0
            blurEnabled: true
            blur: 1.0
            blurMax: Math.max(1, root.radius)
            // Hyprland applies brightness and contrast to blurred areas only.
            brightness: root.blur.brightness - 1
            contrast: root.blur.contrast - 1
            autoPaddingEnabled: false
        }
    }
}
