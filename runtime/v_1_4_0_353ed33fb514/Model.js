// Pure functions shared by bar, overlay and regression tests.
var MINIMIZED = "special:minimized";
var ORIGIN_PREFIX = "omarchy-minimized-from-";

function validAddress(value) {
    return typeof value === "string" && /^0x[0-9a-fA-F]{1,32}$/.test(value);
}

function validWorkspace(value) {
    return typeof value === "number" && /^[1-9][0-9]{0,5}$/.test(String(value));
}

// Origin of a minimized window from its provenance tags. Missing, malformed or
// ambiguous tags yield null: an origin is never guessed.
function originFromTags(tags) {
    var origin = null;
    var found = false;
    for (var i = 0; i < tags.length; i++) {
        var tag = tags[i];
        if (typeof tag !== "string" || tag.indexOf(ORIGIN_PREFIX) !== 0) continue;
        var suffix = tag.slice(ORIGIN_PREFIX.length);
        if (!/^[1-9][0-9]{0,5}$/.test(suffix)) return null;
        var current = Number(suffix);
        if (found && origin !== current) return null;
        origin = current;
        found = true;
    }
    return origin;
}

// Records from `hyprctl -j clients`. Compositor data is untrusted: invalid
// addresses are dropped and titles stay plain bounded strings.
function normalizeClients(clients) {
    if (!Array.isArray(clients)) return null;
    var result = [];
    var raws = clients.slice(0, 10000);
    for (var i = 0; i < raws.length; i++) {
        var raw = raws[i];
        if (!raw || typeof raw !== "object" || raw.mapped === false || !validAddress(raw.address)) continue;
        var workspace = raw.workspace && typeof raw.workspace === "object" ? raw.workspace : {};
        var workspaceId = typeof workspace.id === "number" ? workspace.id : -1;
        var minimized = workspace.name === MINIMIZED;
        var origin = minimized ? originFromTags(Array.isArray(raw.tags) ? raw.tags : []) : null;
        if (!minimized && Number.isInteger(workspaceId) && workspaceId > 0) origin = workspaceId;
        result.push({
            address: raw.address.toLowerCase(),
            title: String(raw.title || raw.initialTitle || "").slice(0, 4096),
            appId: String(raw["class"] || raw.initialClass || "").slice(0, 512),
            workspaceId: workspaceId,
            origin: origin,
            minimized: minimized,
            focused: raw.focusHistoryID === 0,
            at: pair(raw.at),
            size: pair(raw.size),
            monitorId: Number.isInteger(raw.monitor) ? raw.monitor : -1
        });
    }
    return result;
}

function pair(value) {
    return Array.isArray(value) && value.length === 2 && isFinite(value[0]) && isFinite(value[1])
        ? [Number(value[0]), Number(value[1])] : null;
}

// Blur settings from `hyprctl -j --batch "getoption ...; ..."`, which prints one
// JSON object per option separated by blank lines. Missing values keep the
// defaults of Hyprland; unreadable output means blur is off.
function parseBlur(text) {
    var blur = { enabled: false, size: 8, passes: 1, brightness: 1, contrast: 1 };
    var keys = { "decoration:blur:enabled": "enabled", "decoration:blur:size": "size", "decoration:blur:passes": "passes",
        "decoration:blur:brightness": "brightness", "decoration:blur:contrast": "contrast" };
    String(text || "").split(/\n\s*\n/).forEach(function (chunk) {
        var option;
        try { option = JSON.parse(chunk); } catch (e) { return; }
        var key = option && keys[option.option];
        if (!key) return;
        var value = "bool" in option ? option.bool : "int" in option ? option.int : option.float;
        if (key === "enabled") blur.enabled = value === true || value === 1;
        else if (typeof value === "number" && isFinite(value)) blur[key] = value;
    });
    blur.size = Math.max(1, Math.min(64, blur.size));
    blur.passes = Math.max(1, Math.min(8, Math.round(blur.passes)));
    blur.brightness = Math.max(0, Math.min(2, blur.brightness));
    blur.contrast = Math.max(0, Math.min(2, blur.contrast));
    return blur;
}

// Where the monitor's wallpaper sits relative to a window preview `width` wide,
// in preview pixels, so a transparent window shows what lies behind it on the
// desktop. Null when the window or monitor geometry is unknown.
function backdropGeometry(record, monitor, width) {
    if (!record || !record.at || !record.size || !(record.size[0] > 0) || !(width > 0)) return null;
    if (!monitor || !(monitor.scale > 0) || !(monitor.width > 0) || !(monitor.height > 0)) return null;
    var rotated = Math.abs(monitor.transform || 0) % 2 === 1;
    var scale = width / record.size[0];
    return {
        x: (monitor.x - record.at[0]) * scale,
        y: (monitor.y - record.at[1]) * scale,
        width: (rotated ? monitor.height : monitor.width) / monitor.scale * scale,
        height: (rotated ? monitor.width : monitor.height) / monitor.scale * scale,
        scale: scale
    };
}

// Hyprland's blur radius in logical pixels, mapped to a preview at `scale`.
// Each Kawase pass doubles the reach of the configured size.
function blurRadius(blur, scale) {
    if (!blur || !blur.enabled || !(scale > 0)) return 0;
    return Math.max(1, Math.min(64, Math.round(blur.size * Math.pow(2, blur.passes) * scale)));
}

// A Lua string literal that carries any text as data.
function luaString(value) {
    return '"' + String(value).replace(/[\\"\u0000-\u001f\u007f]/g, function (c) {
        return "\\" + ("00" + c.charCodeAt(0)).slice(-3);
    }) + '"';
}

// The `hyprctl eval` chunk that restores a window inside the compositor, or
// "" when the arguments are not a valid address and workspace.
function restoreChunk(operationsPath, address, workspace) {
    if (!validAddress(address) || !validWorkspace(workspace)) return "";
    return "dofile(" + luaString(operationsPath) + ").execute(\"restore\", "
        + luaString(address.toLowerCase()) + ", " + workspace + ")";
}

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
