# Icon assets

This document describes how GenyDL's icon assets are organized and regenerated.

## App icon (colored)

The application icon stays **colored** on every platform. The authoritative
sources remain at the repository root and are used by packaging unchanged:

- `GenyDL.png` — colored master / Linux install icon
- `GenyDL.icns` — macOS `.app` bundle icon
- `GenyDL.ico` — Windows resource icon

Canonical copies are also kept under `resources/icons/app/` for future cleanup.
These are not yet wired into packaging; the root-level files remain authoritative.

## Tray / status-bar icon

Tray icons live under `resources/icons/tray/`:

- `GenyDL.png` — colored tray icon used on **Windows and Linux**.
- `GenyDLTemplate.png` / `@2x` / `@3x` — monochrome **template (mask)** glyphs
  (22, 44, 66 px) used on **macOS**.

On macOS the menu-bar (status-bar) icon must be a *template image*: a
transparent-background, monochrome alpha mask. The code loads the template PNG
and calls `QIcon::setIsMask(true)` so AppKit tints it automatically for light
and dark menu bars. See `src/ui/tray_icon_provider.cpp`
(`genydl::ui::createTrayIcon()`).

## Regenerating icons

All `resources/icons/` assets are derived from the root `GenyDL.png` (the logo
is never redesigned by the script). To regenerate them:

```sh
./scripts/generate-icons.sh
```

Requires ImageMagick (`magick`). The script validates the source files, creates
the destination folders, and prints every file it generates.
