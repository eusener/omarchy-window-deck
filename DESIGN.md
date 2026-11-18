---
version: alpha
name: Window Deck
description: A workspace window carousel that follows the active Omarchy theme and native bar conventions.
omitted:
  - section: colors
    reason: Colors are live references to qs.Commons.Color, not a plugin-owned palette.
typography:
  sans:
    fontFamily: "Inter, menu font"
  mono:
    fontFamily: "monospace"
rounded:
  DEFAULT: "10px"
  card: "18px"
  chip: "9px"
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

The panel, foreground and scrim follow Color.menu.background, Color.menu.text and Color.menu.scrim. Card surfaces tint the menu background with Color.menu.selectedBackground. Selection uses Color.imagePicker.selectedBorder; minimized labels use Color.menu.selectedText. Resting borders are fine glass edges: the menu foreground at 8% (18% on hover), with a 12% white line along the top edge of the panel and cards. Muted text derives from the menu foreground at 65% alpha. The selected card, the shown workspace and the empty-state symbol use the accent: a soft tint and halo on the card, a light-to-dark accent gradient on chips, with ink chosen by the accent's luminance. These bindings update immediately when Omarchy changes themes, including light themes, without a plugin restart.

Foreground and muted text are used on background/surface. The border is decorative; the theme's selected border carries interaction state. Minimized cards retain an explicit text badge. Do not use the muted color for disabled opacity on already dimmed cards.

## Typography

Interface text uses Inter when it is installed, otherwise Style.font.menuFamily: 24 px workspace title, 16 px selected window title (14 px neighbors), 12–14 px secondary information. Workspace numbers use tabular figures. Style.font.family (mono) appears only inside keyboard keys. Sizes are multiplied by the current Omarchy font base-size relative to 12 px. The system fontconfig alias and Omarchy's menu-font override remain authoritative.

Window titles are untrusted plain text. Two caption lines are allowed on the selected card; neighbors use one line. The installed host tooltip explicitly renders Text.PlainText, so titles pass through literally; an integration assertion guards that contract.

## Layout

The fullscreen overlay occupies no desktop layout space. The panel is at most 88% of the display width, 80% of height and 1280 logical px wide. A central card is flanked by smaller cards with overlap; only nearby cards are loaded and captured. The bar shows at most six individual window icons, followed by a +N overflow action. Each monitor uses its own active workspace.

Stable geometry: missing previews replace the image with an icon and explanation inside the same image area. Asynchronous window metadata cannot move header/footer controls. A carousel uses keyboard navigation rather than a hidden scroll area; there is no independently scrollable surface.

WindowCapture preserves the exported aspect ratio and forces source-over alpha composition over a backdrop. WindowBackdrop shows the part of the current wallpaper that lies behind the window on its monitor, so transparent pixels look as they do on the desktop. It follows Hyprland's `decoration:blur` live (re-read on config reload and on every summon): blurred with the configured size, passes, brightness and contrast when enabled, sharp when disabled. Video or missing wallpapers fall back to the theme background. The blur radius is an approximation of Hyprland's Kawase blur, scaled to the preview. Quickshell imports native capture textures as opaque even when Glassy applications export transparent pixels; without explicit blending the selected card can punch through the overlay and reveal the desktop. This workaround is local to the preview and does not change application transparency.

Metadata snapshots update existing card bindings. They must not reset every delegate and restart live capture sessions when only a title, focus state or other metadata changes. The delegate model changes only when the ordered window addresses change. Structural changes create fresh captures, avoiding reuse of native ScreencopyView instances across window identities: the installed Quickshell retains old source-destruction connections when a capture is retargeted.

## Elevation & Depth

The panel shares the launcher's liquid glass. On open the overlay snapshots its screen once (ScreencopyView, not live), shows it lightly blurred under a 68% background scrim that ramps in with the blur, and paints the panel with `shaders/glass.frag` from a heavier, desaturated blur of the same snapshot: 72% tint of the menu background, a refracting bezel along the rounded edge, a lit rim, top sheen, film grain and a 12% darker footer band. The snapshot is opaque, so Hyprland's own layer blur no longer shows once it arrives. Without a snapshot (capture failure, offscreen tests) or with software rendering, which cannot run shader effects, the plain theme panel with fine light edges is used. The documentation preview passes a static item as the backdrop instead of a screen. The compiled `.qsb` is committed; `shaders/build.sh` rebuilds it with qt6-shadertools.

Layering comes from a restrained shadow, tonal steps, overlap and the selected border. One background scrim separates the user from the desktop without losing context. No floating ornamental elements or perpetual motion. Native Qt rectangles keep the interface operable under software rendering; thumbnail content is inset within the rounded outer frame.

## Shapes

18 px card corners, 26 px panel corners, 9–12 px chips and buttons, pill badges and counters. Fine outlines for resting surfaces; the selected card has a 1 px accent edge and halo; keyboard focus keeps 2 px of the accent. Minimized windows have explicit labels inside the overlay. The bar uses native optical icon bounds and slot sizes, without custom badges, colored underlines or app-image tiles.

## Components

DeckButton owns overlay hover, focus, pressed, busy and accessibility semantics. WindowCard owns its frame, preview, fallback, caption and minimized badge. AppIcon maps an application id to the system's desktop entry for the large cards. AppBarIcon uses Omarchy's native BarIconButton and monochrome application glyphs from the same vocabulary as the native application menus, with a window glyph fallback. It inherits native click forwarding, tooltip registration, optical sizing and press feedback. DeckView owns the visual layout and emits navigation/confirmation requests; Deck.qml owns compositor actions, cancellation and context lifetime. Widget.qml is the bar adapter. DeckState.qml owns shared compositor reads and serialized restore operations.

The header carries a strip of the monitor's ten workspace slots: the shown one uses the selected treatment, the active one has a short underline in the minimized color, empty ones are dimmed. It hides in compact headers, where number keys still work. The selected card shows window controls (minimize, maximize or restore size, restore) as small buttons over the picture's top-left corner, with glyphs drawn from rectangles so no icon font is needed; maximized windows get a badge in the accent color, mirroring the minimized badge.

Empty, disconnected, stale-window, busy and preview-unavailable states are explicit. Retry is available by button or R. Navigation is cyclic; confirmation is Enter or click on the selected card. Escape cancels. No destructive action exists in this interface.

Animations use qs.Commons.Style.duration and OutCubic, up to 140 ms for card movement and 120 ms for dimming. Keyboard opening/closing is immediate; disabled global animations also disable card transitions.

## Do's and Don'ts

- Keep the central window the only strong visual emphasis.
- Preserve the selected address across compositor updates.
- Keep capture scoped to an open selector and visible cards.
- Keep window titles out of shell commands, Lua expressions and rich text.
- Do not temporarily restore hidden windows for a preview, or write thumbnails to disk.
- Do not change the user's wallpaper, system palette, desktop numbering or unrelated shortcuts.
