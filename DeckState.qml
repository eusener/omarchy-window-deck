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
    readonly property bool busy: !!actionProcess && actionProcess.running === true
    // Restores run inside the compositor: hyprctl eval loads this file there.
    readonly property string operationsPath: decodeURIComponent(String(Qt.resolvedUrl("operations.lua")).replace(/^file:\/\//, ""))
    // What a transparent window shows behind it: the current wallpaper, blurred
    // when Hyprland's blur is on (the Glassy toggle), exactly as on the desktop.
    property string wallpaperPath: ""
    property var blur: Model.parseBlur("")
    readonly property string stateHome: Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")
    signal actionFinished(bool success)

    function refreshAppearance() {
        if (!appearanceProcess.running) appearanceProcess.running = true;
    }

    function refresh() {
        if (snapshotProcess.running) { pending = true; return; }
        pending = false;
        snapshotProcess.running = true;
    }

    function act(action, address, workspace) {
        if (busy || action !== "restore") return false;
        // State, origin and existence are validated by the compositor in the
        // same call that moves and focuses the window.
        var chunk = Model.restoreChunk(operationsPath, address, workspace);
        if (!chunk) { error = "action"; return false; }
        actionProcess.command = ["hyprctl", "eval", chunk];
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
        command: ["hyprctl", "-j", "clients"]
        stdout: StdioCollector {
            onStreamFinished: {
                var rows = null;
                try { rows = Model.normalizeClients(JSON.parse(text)); } catch (e) {}
                if (rows) { root.clients = rows; root.error = ""; }
                else root.error = "unavailable";
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

    Process {
        id: appearanceProcess
        command: ["sh", "-c", "printf '%s\\n' \"$(readlink -f -- \"$1\")\"; hyprctl -j --batch \"$2\"", "_",
            root.stateHome + "/omarchy/current/background",
            "getoption decoration:blur:enabled; getoption decoration:blur:size; getoption decoration:blur:passes; "
            + "getoption decoration:blur:brightness; getoption decoration:blur:contrast"]
        stdout: StdioCollector {
            onStreamFinished: {
                var newline = text.indexOf("\n");
                var path = newline < 0 ? "" : text.slice(0, newline).trim();
                if (path !== root.wallpaperPath) root.wallpaperPath = path;
                root.blur = Model.parseBlur(newline < 0 ? "" : text.slice(newline + 1));
            }
        }
    }

    Timer { id: debounce; interval: 90; onTriggered: root.refresh() }
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            var name = event ? String(event.name) : "";
            if (Model.shouldRefresh(name))
                debounce.restart();
            if (name === "configreloaded")
                root.refreshAppearance();
        }
    }
    Component.onCompleted: { refresh(); refreshAppearance(); }
}
