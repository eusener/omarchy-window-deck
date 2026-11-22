pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.Commons as Commons
import qs.Ui
import "Model.js" as Model

BarWidget {
    id: root
    moduleName: "eusener.window-deck"
    readonly property var monitor: {
        var host = root.QsWindow.window;
        return host && host.screen ? Hyprland.monitorFor(host.screen) : null;
    }
    readonly property int workspaceId: monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : -1
    readonly property var windows: Model.windowsFor(DeckState.clients, workspaceId, true)
    readonly property var items: Model.barItems(windows, 6)
    readonly property real slotSize: Commons.Style.bar.iconSlot
    readonly property real leadingGap: Commons.Style.space(8)
    visible: items.length > 0
    implicitWidth: !visible ? 0 : vertical ? barSize : leadingGap + items.length * slotSize
    implicitHeight: !visible ? 0 : vertical ? leadingGap + items.length * slotSize : barSize

    Commons.Translations { id: strings; directory: Qt.resolvedUrl("i18n") }

    Rectangle {
        width: root.vertical ? root.barSize * 0.4 : 1
        height: root.vertical ? 1 : root.barSize * 0.4
        x: root.vertical ? (root.width - width) / 2 : 0
        y: root.vertical ? 0 : (root.height - height) / 2
        color: root.bar ? root.bar.barForeground : Commons.Color.bar.text
        opacity: 0.25
    }

    Grid {
        x: root.vertical ? 0 : root.leadingGap
        y: root.vertical ? root.leadingGap : 0
        columns: root.vertical ? 1 : Math.max(1, root.items.length)
        spacing: 0
        Repeater {
            model: root.items
            delegate: AppBarIcon {
                id: button
                required property var modelData
                bar: root.bar
                width: root.vertical ? root.barSize : root.slotSize
                height: root.vertical ? root.slotSize : root.barSize
                appId: modelData.appId || ""
                text: modelData.overflow ? "+" + Commons.I18n.formatNumber(modelData.overflow) : Model.barGlyph(appId)
                interactive: !DeckState.busy
                pressable: interactive
                activeFocusOnTab: true
                readonly property var entry: {
                    var revision = DesktopEntries.applications.values.length;
                    return appId ? DesktopEntries.heuristicLookup(appId) : null;
                }
                readonly property string appName: entry ? entry.name : appId
                readonly property string actionLabel: modelData.overflow
                    ? strings.t("bar.more").arg(Commons.I18n.formatNumber(modelData.overflow))
                    : strings.t("bar.restore").arg(modelData.title || modelData.appId)
                tooltipText: modelData.overflow ? actionLabel : Model.tooltipText(modelData.title, appName)
                Accessible.role: Accessible.Button
                Accessible.name: actionLabel
                Accessible.onPressAction: triggerPress(Qt.LeftButton)
                Keys.onReturnPressed: triggerPress(Qt.LeftButton)
                Keys.onEnterPressed: triggerPress(Qt.LeftButton)
                Keys.onSpacePressed: triggerPress(Qt.LeftButton)
                onPressed: function(mouseButton) {
                    if (mouseButton !== Qt.LeftButton || !interactive) return;
                    if (modelData.overflow) {
                        if (root.bar && root.bar.shell && root.monitor) root.bar.shell.summon(root.moduleName,
                            JSON.stringify({ workspace: root.workspaceId, monitor: root.monitor.name, minimizedOnly: true }));
                    } else DeckState.act("restore", modelData.address, root.workspaceId);
                }
            }
        }
    }
}
