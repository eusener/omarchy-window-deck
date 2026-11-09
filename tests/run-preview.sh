#!/usr/bin/env bash
set -euo pipefail
deck_root=$(cd -- "$(dirname -- "$0")/.." && pwd)
preview_root=$(mktemp -d /tmp/window-deck-preview.XXXXXX)
trap 'rm -rf -- "$preview_root"' EXIT
mkdir -p "$preview_root/runtime" "$preview_root/cache"
chmod 700 "$preview_root/runtime"
ln -s "$deck_root" "$preview_root/plugin"
ln -s /usr/share/omarchy/shell/Commons "$preview_root/Commons"
ln -s /usr/share/omarchy/shell/Ui "$preview_root/Ui"
sed 's#import "\.\." as Deck#import "plugin" as Deck#; s#Qt.resolvedUrl("../docs/preview.png")#Qt.resolvedUrl("plugin/docs/preview.png")#' "$deck_root/tests/preview.qml" > "$preview_root/shell.qml"
env QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME= QT_STYLE_OVERRIDE=Fusion \
    QT_QUICK_CONTROLS_STYLE=Basic QT_QUICK_BACKEND=software \
    XDG_RUNTIME_DIR="$preview_root/runtime" XDG_CACHE_HOME="$preview_root/cache" \
    HYPRLAND_INSTANCE_SIGNATURE= DISPLAY= WAYLAND_DISPLAY= \
    timeout 15 quickshell -p "$preview_root/shell.qml" 2>&1 | tee "$preview_root/run.log"
if rg -q 'UI_CHECK_FAILED|Failed to load configuration|TypeError:|ReferenceError:' "$preview_root/run.log"; then
    exit 1
fi
rg -q 'UI_CHECKS_PASSED: 12' "$preview_root/run.log"
rg -q 'PREVIEW_SAVED' "$preview_root/run.log"
