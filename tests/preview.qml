pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.Commons as Commons
import qs.Ui as Native
import ".." as Deck

ShellRoot {
    id: root
    property int confirmations: 0
    property string lastAddress: ""
    property int previewCreations: 0
    FloatingWindow {
        id: window
        visible: true
        implicitWidth: Number(Quickshell.env("DECK_PREVIEW_WIDTH")) || 1440
        implicitHeight: Quickshell.env("DECK_PREVIEW_BAR_ONLY") ? Commons.Style.bar.sizeHorizontal : Number(Quickshell.env("DECK_PREVIEW_HEIGHT")) || 900
        color: "#080C16"
        Item {
            id: canvas
            anchors.fill: parent
            Rectangle {
                x: -200; y: -330; width: 1400; height: 900
                radius: 450; rotation: -24
                gradient: Gradient {
                    GradientStop { position: 0; color: "#39415C" }
                    GradientStop { position: 1; color: "#121B2C" }
                }
            }
            Rectangle {
                x: 520; y: 380; width: 1250; height: 800
                radius: 400; rotation: -25
                color: "#162A36"
            }
            Rectangle {
                width: parent.width; height: Commons.Style.bar.sizeHorizontal; color: Commons.Color.bar.background
                Row {
                    x: 12; anchors.verticalCenter: parent.verticalCenter; spacing: 0
                    Native.BarIconButton { text: "󰣇"; foreground: Commons.Color.bar.text; height: Commons.Style.bar.sizeHorizontal }
                    Repeater {
                        model: 5
                        Native.WidgetButton {
                            required property int index
                            text: String(index + 1)
                            foreground: Commons.Color.bar.text
                            fixedWidth: Commons.Style.space(20)
                            fixedHeight: Commons.Style.bar.sizeHorizontal
                        }
                    }
                    Item {
                        width: Commons.Style.space(8); height: Commons.Style.bar.sizeHorizontal
                        Rectangle { anchors.centerIn: parent; width: 1; height: parent.height * 0.4; color: Commons.Color.bar.text; opacity: 0.25 }
                    }
                    Deck.AppBarIcon { appId: "foot"; foreground: Commons.Color.bar.text; height: Commons.Style.bar.sizeHorizontal }
                    Deck.AppBarIcon { appId: "chromium"; foreground: Commons.Color.bar.text; height: Commons.Style.bar.sizeHorizontal }
                    Deck.AppBarIcon { appId: "org.gnome.Nautilus"; foreground: Commons.Color.bar.text; height: Commons.Style.bar.sizeHorizontal }
                }
                Deck.PlainText { anchors.centerIn: parent; text: "seg 9 nov   14:32" }
            }

            Deck.DeckView {
                id: view
                anchors.fill: parent
                visible: !Quickshell.env("DECK_PREVIEW_BAR_ONLY")
                workspaceId: 2
                selectedIndex: 1
                windows: [
                    {address: "0x1", appId: "foot", title: "Terminal — omarchy-window-deck", origin: 2, minimized: true},
                    {address: "0x2", appId: "chromium", title: "Uma janela para cada ideia", origin: 2, minimized: false},
                    {address: "0x3", appId: "org.gnome.Nautilus", title: "Projetos", origin: 2, minimized: true}
                ]
                onSelectionRequested: function(index) { selectedIndex = index; }
                onAccepted: function(record) { confirmations++; lastAddress = record.address; }
                toplevelLookup: function(address) { return address; }
                previewDelegate: Component {
                    Item {
                        Component.onCompleted: root.previewCreations++
                        readonly property bool hasContent: true
                        Rectangle { anchors.fill: parent; color: "#101723" }
                        Rectangle {
                            width: parent.width; height: 26; color: "#202B40"
                            Row {
                                x: 12; anchors.verticalCenter: parent.verticalCenter; spacing: 5
                                Repeater {
                                    model: ["#C4B5FD", "#A7D9CD", "#B5BED3"]
                                    Rectangle { required property string modelData; width: 5; height: 5; radius: 3; color: modelData }
                                }
                            }
                        }
                        Column {
                            anchors.centerIn: parent
                            width: parent.width * 0.82
                            spacing: 18
                            Deck.PlainText { width: parent.width; wrapMode: Text.Wrap; text: "O espaço das suas ideias."; font.pixelSize: Math.min(25, parent.width * 0.07); color: "#F4F2FF"; font.weight: Font.Medium }
                            Deck.PlainText { width: parent.width; wrapMode: Text.Wrap; text: "Cada janela no seu lugar."; font.pixelSize: Math.min(14, parent.width * 0.05); color: "#B5BED3" }
                            Row {
                                spacing: 8
                                Repeater {
                                    model: ["#C4B5FD", "#A7D9CD", "#39425C"]
                                    Rectangle { required property string modelData; width: 70; height: 6; radius: 3; color: modelData }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    Timer {
        interval: 1600
        running: true
        onTriggered: {
            if (Quickshell.env("DECK_PREVIEW_FONT_BASE")) Commons.Style.fontBaseSize = Number(Quickshell.env("DECK_PREVIEW_FONT_BASE"));
            function check(condition, message) {
                if (!condition) { console.error("UI_CHECK_FAILED: " + message); Qt.quit(); return false; }
                return true;
            }
            function hasText(item, text) {
                if (item.text !== undefined && item.text === text) return true;
                var children = item.children || [];
                for (var child of children) if (hasText(child, text)) return true;
                return false;
            }
            function cardFor(item, address) {
                if (item.record && item.record.address === address && item.toplevel !== undefined) return item;
                var children = item.children || [];
                for (var child of children) {
                    var card = cardFor(child, address);
                    if (card) return card;
                }
                return null;
            }
            var previousWindows = view.windows;
            var previousCreations = root.previewCreations;
            view.windows = previousWindows.map(function(row) {
                return Object.assign({}, row, {title: "Progress " + row.address});
            });
            if (!check(previousCreations > 0 && root.previewCreations === previousCreations, "metadata updates preserve running previews")) return;
            if (!check(hasText(view, "Progress 0x2"), "metadata updates refresh visible captions")) return;
            view.windows = previousWindows.map(function(row) {
                return row.address === "0x2" ? Object.assign({}, row, {address: "0x9", title: "Replacement"}) : row;
            });
            var replacement = cardFor(view, "0x9");
            if (!check(replacement && replacement.toplevel === "0x9" && hasText(view, "Replacement")
                && root.previewCreations > previousCreations, "window identity changes create a fresh capture")) return;
            view.windows = previousWindows;
            var originalTheme = Commons.Color.shellValues;
            var originalPanel = Deck.DeckPalette.panel;
            Commons.Color.shellValues = {
                "menu.background": "#f6f0e6", "menu.text": "#202020",
                "menu.selected-background": "#202020", "menu.selected-background-alpha": "0.08",
                "menu.selected-text": "#7c3820", "menu.scrim": "#202020", "menu.scrim-alpha": "0.5",
                "image-picker.selected-border": "#7c3820", "popups.border": "#7c3820"
            };
            if (!check(String(Deck.DeckPalette.panel) === "#f6f0e6" && String(Deck.DeckPalette.foreground) === "#202020", "live light theme")) return;
            Commons.Color.shellValues = originalTheme;
            if (!check(String(Deck.DeckPalette.panel) === String(originalPanel), "restore current theme")) return;
            view.step(1);
            if (!check(view.selectedIndex === 2, "next window")) return;
            view.step(1);
            if (!check(view.selectedIndex === 0, "wrap forward")) return;
            view.step(-1);
            if (!check(view.selectedIndex === 2, "wrap backward")) return;
            view.confirm();
            if (!check(confirmations === 1 && lastAddress === "0x3", "confirm specific minimized window")) return;
            view.busy = true;
            view.step(1); view.confirm();
            if (!check(view.selectedIndex === 2 && confirmations === 1, "busy blocks duplicate operations")) return;
            view.busy = false;
            var original = view.windows;
            view.windows = [];
            view.step(1); view.confirm();
            if (!check(confirmations === 1, "empty state does not confirm")) return;
            view.windows = original;
            view.selectedIndex = 1;
            for (var type of ["Widget"]) {
                var component = Qt.createComponent("plugin/" + type + ".qml");
                if (!check(component.status === Component.Ready, type + " loads: " + component.errorString())) return;
                var item = component.createObject(canvas);
                if (!check(item !== null, type + " instantiates")) return;
                item.destroy();
            }
            var buttonComponent = Qt.createComponent("plugin/DeckButton.qml");
            var button = buttonComponent.createObject(canvas);
            var presses = 0;
            button.activated.connect(function() { presses++; });
            if (!check(typeof button.triggerPress === "function", "bar dispatch contract")) return;
            button.triggerPress(Qt.LeftButton);
            button.busy = true;
            button.triggerPress(Qt.LeftButton);
            if (!check(presses === 1 && button.interactive === false, "bar rejects busy operations")) return;
            button.destroy();
            var overlayComponent = Qt.createComponent("plugin/Deck.qml");
            if (overlayComponent.status === Component.Error && overlayComponent.errorString().indexOf("No PanelWindow backend loaded") !== -1)
                console.log("WAYLAND_OVERLAY_CHECK_PENDING: offscreen platform has no layer-shell backend");
            else if (!check(overlayComponent.status === Component.Ready, "Deck loads: " + overlayComponent.errorString())) return;
            console.log("UI_CHECKS_PASSED: 15");
            captureTimer.start();
        }
    }
    Timer {
        id: captureTimer
        interval: 220
        onTriggered: canvas.grabToImage(function(result) {
            if (!result.saveToFile(Quickshell.env("DECK_PREVIEW_OUTPUT") || String(Qt.resolvedUrl("../docs/preview.png")).replace(/^file:\/\//, ""))) {
                console.error("Preview save failed"); Qt.quit(); return;
            }
            console.log("PREVIEW_SAVED");
            Qt.quit();
        })
    }
}
