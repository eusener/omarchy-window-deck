pragma ComponentBehavior: Bound
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "Model.js" as Model

Item {
    id: root
    property var clients: []
    property string error: ""
    property bool pending: false
    readonly property bool busy: actionProcess.running
    readonly property string backendPath: decodeURIComponent(String(Qt.resolvedUrl("backend.py")).replace(/^file:\/\//, ""))
    signal actionFinished(bool success)

    function refresh() {
        if (snapshotProcess.running) { pending = true; return; }
        pending = false;
        snapshotProcess.running = true;
    }

    function act(action, address, workspace) {
        if (busy || action !== "restore") return false;
        actionProcess.command = ["python3", backendPath, action, address, String(workspace)];
        actionProcess.running = true;
        return true;
    }

    function toplevelFor(address) {
        var all = Hyprland.toplevels.values;
        for (var i = 0; i < all.length; i++) {
            var candidate = String(all[i].address || "").toLowerCase();
            if (candidate.indexOf("0x") !== 0) candidate = "0x" + candidate;
            if (candidate === address) return all[i].wayland;
        }
        return null;
    }

    Process {
        id: snapshotProcess
        command: ["python3", root.backendPath, "snapshot"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(text);
                    if (Array.isArray(data.clients)) { root.clients = data.clients; root.error = ""; }
                    else root.error = "unavailable";
                } catch (e) { root.error = "unavailable"; }
            }
        }
        onExited: function(exitCode) {
            if (exitCode !== 0) root.error = "unavailable";
            if (root.pending) debounce.restart();
        }
    }

    Process {
        id: actionProcess
        onExited: function(exitCode) {
            if (exitCode !== 0) root.error = "action";
            root.refresh();
            root.actionFinished(exitCode === 0);
        }
    }

    Timer { id: debounce; interval: 90; onTriggered: root.refresh() }
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            var name = event ? String(event.name) : "";
            if (Model.shouldRefresh(name))
                debounce.restart();
        }
    }
    Component.onCompleted: refresh()
}
