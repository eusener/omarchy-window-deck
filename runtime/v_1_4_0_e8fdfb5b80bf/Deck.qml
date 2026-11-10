pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Ui
import "Model.js" as Model

Item {
    id: root
    property var shell: null
    property var manifest: null
    property bool opened: false
    property int workspaceId: -1
    property string monitorName: ""
    property bool minimizedOnly: false
    property int selectedIndex: 0
    property string selectedAddress: ""
    property string previousAddress: ""
    property bool confirming: false
    // A chosen window waiting for the overlay surface to close.
    property string pendingAddress: ""
    property int pendingWorkspace: -1
    property string actionError: ""
    property var windows: []

    function open(payloadJson) {
        if (opened) { view.step(1); return; }
        var payload = {};
        try { payload = JSON.parse(payloadJson || "{}"); } catch (e) { }
        var monitor = Hyprland.focusedMonitor;
        if (payload.monitor) {
            var monitors = Hyprland.monitors.values;
            for (var i = 0; i < monitors.length; i++) if (monitors[i].name === payload.monitor) monitor = monitors[i];
        }
        if (!monitor || !monitor.activeWorkspace || monitor.activeWorkspace.id <= 0) { dismiss(); return; }
        workspaceId = monitor.activeWorkspace.id;
        if (payload.workspace !== undefined && payload.workspace !== workspaceId) { dismiss(); return; }
        monitorName = monitor.name;
        minimizedOnly = payload.minimizedOnly === true;
        previousAddress = "";
        for (var j = 0; j < DeckState.clients.length; j++) {
            if (DeckState.clients[j].focused) previousAddress = DeckState.clients[j].address;
        }
        selectedAddress = previousAddress;
        selectedIndex = 0;
        actionError = "";
        opened = true;
        rebuild();
        DeckState.refresh();
        DeckState.refreshAppearance();
        Qt.callLater(view.focusPicker);
    }
    function close() { opened = false; confirming = false; }
    function dismiss() {
        close();
        if (shell) shell.hide("eusener.window-deck");
    }
    function rebuild() {
        if (!opened) return;
        windows = Model.windowsFor(DeckState.clients, workspaceId, minimizedOnly);
        selectedIndex = Model.selectionIndex(windows, selectedAddress, selectedIndex);
        selectedAddress = windows.length ? windows[selectedIndex].address : "";
    }
    function choose(index) {
        selectedIndex = index;
        selectedAddress = windows.length ? windows[index].address : "";
    }
    function confirm(record) {
        if (DeckState.busy || pendingAddress) return;
        // While the overlay holds exclusive keyboard focus Hyprland ignores the
        // focus request, and on closing it refocuses the window focused before
        // it opened, which then retakes a maximized state over the chosen one.
        // Restore only once the overlay surface is gone.
        pendingAddress = record.address;
        pendingWorkspace = workspaceId;
        dismiss();
        pendingTimer.restart();
    }
    function runPending() {
        if (!pendingAddress) return;
        var address = pendingAddress;
        pendingAddress = "";
        pendingTimer.stop();
        if (DeckState.act("restore", address, pendingWorkspace)) confirming = true;
        else reopenWithError();
    }
    // The overlay is already closed when a restore fails; show the error in it.
    function reopenWithError() {
        actionError = "action";
        opened = true;
        rebuild();
        Qt.callLater(view.focusPicker);
        Qt.callLater(checkContext);
    }
    function cancel() {
        var previous = DeckState.clients.filter(function(w) { return w.address === previousAddress && w.origin === workspaceId && !w.minimized; });
        dismiss();
        if (previous.length) DeckState.act("restore", previousAddress, workspaceId);
    }
    function checkContext() {
        if (!opened) return;
        var all = Hyprland.monitors.values;
        for (var i = 0; i < all.length; i++) {
            if (all[i].name === monitorName) {
                if (!all[i].activeWorkspace || all[i].activeWorkspace.id !== workspaceId) dismiss();
                return;
            }
        }
        dismiss();
    }

    Connections {
        target: DeckState
        function onClientsChanged() { root.rebuild(); }
        function onActionFinished(success) {
            if (!root.confirming) return;
            root.confirming = false;
            if (!success) root.reopenWithError();
        }
    }
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (root.opened) Qt.callLater(root.checkContext);
            // Hyprland has refocused the previous window when it reports this.
            if (root.pendingAddress && event && String(event.name) === "closelayer") Qt.callLater(root.runPending);
        }
    }
    // Fallback when the close event is missed, as when the surface never mapped.
    Timer { id: pendingTimer; interval: 400; onTriggered: root.runPending() }
    Connections {
        target: Quickshell
        function onScreensChanged() { root.checkContext(); }
    }
    OverlayWindow {
        id: overlay
        shown: root.opened
        // Hyprland blurs behind this namespace through the layer rule of the
        // README, which takes effect only while blur is on (the Glassy mode).
        WlrLayershell.namespace: "eusener-window-deck"
        onContentRevealedChanged: if (contentRevealed) view.focusPicker()
        function focusedScreen() {
            for (var i = 0; i < Quickshell.screens.length; i++)
                if (Quickshell.screens[i].name === root.monitorName) return Quickshell.screens[i];
            return null;
        }
        DeckView {
            id: view
            anchors.fill: parent
            workspaceId: root.workspaceId
            windows: root.windows
            selectedIndex: root.selectedIndex
            minimizedOnly: root.minimizedOnly
            busy: DeckState.busy
            error: root.actionError || DeckState.error
            captureEnabled: root.opened
            toplevelLookup: function(address) { return DeckState.toplevelFor(address); }
            onSelectionRequested: function(index) { root.choose(index); }
            onAccepted: function(record) { root.confirm(record); }
            onCancelled: root.cancel()
            onRetryRequested: { root.actionError = ""; DeckState.refresh(); }
        }
    }
}
