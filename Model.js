// Pure functions shared by bar, overlay and regression tests.
function windowsFor(records, workspace, minimizedOnly) {
    if (!(workspace > 0)) return [];
    return records.filter(function (row) {
        return row.origin === workspace && (!minimizedOnly || row.minimized);
    });
}

function selectionIndex(records, address, fallback) {
    for (var i = 0; i < records.length; i++) {
        if (records[i].address === address) return i;
    }
    return Math.max(0, Math.min(records.length - 1, fallback || 0));
}

// The installed Omarchy bar explicitly sets Text.PlainText on tooltipLabel.
// Escaping HTML for that sink would show literal &amp; and &lt; in real titles.
function tooltipText(title, appName) {
    return (appName ? String(appName) + "\n" : "") + String(title || "");
}

function shouldRefresh(name) {
    return /^(openwindow|closewindow|movewindow|windowtitle|activewindow|workspace|focusedmon|configreloaded|tagwindow|windowtag|monitor)/.test(String(name || ""));
}

function slot(workspace) {
    return (workspace - 1) % 10 + 1;
}

function barItems(records, limit) {
    var result = records.slice(0, limit);
    if (records.length > limit) result.push({ overflow: records.length - limit });
    return result;
}

// Monochrome Nerd Font symbols used by Omarchy's own application menus.
// Full-color desktop-entry images remain appropriate for the large preview cards.
function barGlyph(appId) {
    var id = String(appId || "").toLowerCase();
    if (/(^|[.\-_])(foot(client|server)?|alacritty|ghostty|kitty|wezterm|konsole|terminal)([.\-_]|$)/.test(id)) return "";
    if (id.indexOf("chromium") !== -1) return "";
    if (id.indexOf("chrome") !== -1) return "󰊯";
    if (id.indexOf("firefox") !== -1) return "";
    if (id.indexOf("brave") !== -1 || id.indexOf("zen") !== -1) return "󰖟";
    if (id.indexOf("edge") !== -1) return "󰇩";
    if (/nautilus|flea|thunar|dolphin|pcmanfm/.test(id)) return "󰉋";
    if (/(^|[.\-_])(code|code-oss|codium)([.\-_]|$)|vscode|visualstudiocode/.test(id)) return "";
    if (/neovim|nvim/.test(id)) return "";
    if (id.indexOf("spotify") !== -1) return "󰓇";
    if (id.indexOf("superwhisper") !== -1) return "";
    return "󰖲";
}
