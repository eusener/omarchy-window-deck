---
version: alpha
name: Window Deck
description: A workspace window carousel that follows the active Omarchy theme and native bar conventions.
omitted:
  - section: colors
    reason: Colors are live references to qs.Commons.Color, not a plugin-owned palette.
typography:
  sans:
    fontFamily: "monospace"
  mono:
    fontFamily: "monospace"
rounded:
  DEFAULT: "10px"
  card: "18px"
  overlay: "26px"
spacing:
  icon-gap: "4px"
  card-inset: "10px"
  panel-inset: "32px"
components:
  card:
    maxWidth: "560px"
  overlay:
    maxWidth: "1280px"
---

# Window Deck design

## Overview

A filmstrip for the windows on the user's current desktop. The central window dominates; lateral cards hint at its neighbors. Designed for frequent keyboard use on an Omarchy desktop. The user requires the active Omarchy theme and native bar icon conventions for visual consistency.

Portuguese Brazilian and English catalogs follow the current Omarchy language with English fallback. Brand and keyboard names remain unchanged. No network resources or extra fonts are downloaded.

Runtime ownership: qs.Commons.Color and Style own colors and fonts. DeckPalette.qml adapts their live roles for DeckView, WindowCard, AppIcon and DeckButton. AppBarIcon.qml extends the native qs.Ui.BarIconButton, and Widget.qml inherits the host bar's foreground, font, geometry and interaction behavior. There is no independent color catalog or CSS.

## Colors

The panel, foreground and scrim follow Color.menu.background, Color.menu.text and Color.menu.scrim. Card surfaces tint the menu background with Color.menu.selectedBackground. Selection uses Color.imagePicker.selectedBorder; minimized labels use Color.menu.selectedText. Borders use Color.popups.border. Muted text derives from the menu foreground at 65% alpha. These bindings update immediately when Omarchy changes themes, including light themes, without a plugin restart.

Foreground and muted text are used on background/surface. The border is decorative; the theme's selected border carries interaction state. Minimized cards retain an explicit text badge. Do not use the muted color for disabled opacity on already dimmed cards.

## Typography

Style.font.menuFamily supplies the interface hierarchy: 22 px workspace title, 15–16 px window title, 12–13 px secondary information. Style.font.family supplies keyboard hints and workspace numbers. Sizes are multiplied by the current Omarchy font base-size relative to 12 px. The system fontconfig alias and Omarchy's menu-font override remain authoritative.

Window titles are untrusted plain text. Two caption lines are allowed on the selected card; neighbors use one line. The installed host tooltip explicitly renders Text.PlainText, so titles pass through literally; an integration assertion guards that contract.

## Layout

The fullscreen overlay occupies no desktop layout space. The panel is at most 88% of the display width, 80% of height and 1280 logical px wide. A central card is flanked by smaller cards with overlap; only nearby cards are loaded and captured. The bar shows at most six individual window icons, followed by a +N overflow action. Each monitor uses its own active workspace.

Stable geometry: missing previews replace the image with an icon and explanation inside the same image area. Asynchronous window metadata cannot move header/footer controls. A carousel uses keyboard navigation rather than a hidden scroll area; there is no independently scrollable surface.

## Elevation & Depth

Layering comes from a restrained shadow, tonal steps, overlap and the selected border. One background scrim separates the user from the desktop without losing context. No floating ornamental elements or perpetual motion. Native Qt rectangles keep the interface operable under software rendering; thumbnail content is inset within the rounded outer frame.

## Shapes

18 px card corners, 26 px panel corners, 10 px overlay button corners. Fine outlines for resting surfaces, 2 px of the active selected-border color for focus. Minimized windows have explicit labels inside the overlay. The bar uses native optical icon bounds and slot sizes, without custom badges, colored underlines or app-image tiles.

## Components

DeckButton owns overlay hover, focus, pressed, busy and accessibility semantics. WindowCard owns its frame, preview, fallback, caption and minimized badge. AppIcon maps an application id to the system's desktop entry for the large cards. AppBarIcon uses Omarchy's native BarIconButton and monochrome application glyphs from the same vocabulary as the native application menus, with a window glyph fallback. It inherits native click forwarding, tooltip registration, optical sizing and press feedback. DeckView owns the visual layout and emits navigation/confirmation requests; Deck.qml owns compositor actions, cancellation and context lifetime. Widget.qml is the bar adapter. DeckState.qml owns shared compositor reads and serialized restore operations.

Empty, disconnected, stale-window, busy and preview-unavailable states are explicit. Retry is available by button or R. Navigation is cyclic; confirmation is Enter or click on the selected card. Escape cancels. No destructive action exists in this interface.

Animations use qs.Commons.Style.duration and OutCubic, up to 140 ms for card movement and 120 ms for dimming. Keyboard opening/closing is immediate; disabled global animations also disable card transitions.

## Do's and Don'ts

- Keep the central window the only strong visual emphasis.
- Preserve the selected address across compositor updates.
- Keep capture scoped to an open selector and visible cards.
- Keep window titles out of shell commands, Lua expressions and rich text.
- Do not temporarily restore hidden windows for a preview, or write thumbnails to disk.
- Do not change the user's wallpaper, system palette, desktop numbering or unrelated shortcuts.
