#!/usr/bin/env bash
# Renders the README images (docs/preview.png and docs/empty-preview.png)
# from tests/preview.qml with illustrative windows. Run it inside a graphical
# Omarchy session: the liquid glass needs the GPU scene graph, which the
# offscreen test platform lacks. A preview window shows for a moment.
# ImageMagick, when installed, scales the HiDPI capture to 1440x900.
set -euo pipefail
deck_root=$(cd -- "$(dirname -- "$0")/.." && pwd)
preview_root=$(mktemp -d /tmp/window-deck-docs.XXXXXX)
trap 'rm -rf -- "$preview_root"' EXIT
ln -s "$deck_root" "$preview_root/plugin"
ln -s /usr/share/omarchy/shell/Commons "$preview_root/Commons"
ln -s /usr/share/omarchy/shell/Ui "$preview_root/Ui"
sed 's#import "\.\." as Deck#import "plugin" as Deck#' "$deck_root/tests/preview.qml" > "$preview_root/shell.qml"
render() {
    local output=$1 empty=$2
    DECK_PREVIEW_OUTPUT="$output" DECK_PREVIEW_EMPTY="$empty" \
        timeout 15 quickshell -p "$preview_root/shell.qml" 2>&1 | tee "$preview_root/run.log" >/dev/null
    grep -q 'PREVIEW_SAVED' "$preview_root/run.log"
    if command -v magick >/dev/null; then magick "$output" -resize 1440x900 -strip "$output"; fi
    echo "Rendered ${output#"$deck_root"/}"
}
render "$deck_root/docs/preview.png" ""
render "$deck_root/docs/empty-preview.png" 1
