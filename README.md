# ZoomItMac

`ZoomItMac` is a small macOS menu bar utility inspired by ZoomIt on Windows.

It captures a still image of the current display, lets you pan and zoom that frozen image, then annotate and export it.

## Current feature set

- Global hotkey to start still zoom
- Frozen zoom overlay with mouse-move pan and scroll-wheel zoom
- Two-stage flow:
  - navigate the frozen image
  - left-click to lock it in place and annotate
- Annotation tools:
  - freehand pen
  - `Ctrl`-drag arrow
  - `Cmd`-drag rectangle
  - `Option`-drag circle
- Color shortcuts for red, blue, green, and yellow
- Clear annotations
- Save/export mode:
  - `Ctrl+S` enters save mode
  - `Enter` saves the full current image
  - click-drag-release saves a selected rectangle
  - saved images are also copied to the clipboard
- Configurable save folder
- Menu option to customize shortcuts
- Menu bar icon with quit action

## Requirements

- macOS 14 or later
- Xcode command line tools / Swift toolchain capable of running `swift build`

## Permissions

`ZoomItMac` needs **Screen Recording** permission.

On first launch, macOS should prompt for it. After granting permission, quit and reopen the app once if capture does not work immediately.

If the permission state gets stuck during local development, you can reset it with:

```bash
./scripts/reset-screen-permission.sh
```

Then:

1. Start the already-built app
2. Enable `ZoomItMac` in **System Settings → Privacy & Security → Screen Recording**
3. Quit the app
4. Start it again without rebuilding in between

## Build locally

Build a debug app bundle:

```bash
./scripts/build-app.sh
```

> **Note:** after building the app, you will have to _delete_ Screen Recording permission for `ZoomItMac` in System Settings (use the `-` sign to remove it) and then start the app to trigger the permission prompt again. This is a quirk of local ad hoc builds.

That creates:

```bash
dist/debug/ZoomItMac.app
```

Build a release bundle:

```bash
./scripts/build-app.sh release
```

That creates:

```bash
dist/release/ZoomItMac.app
```

### Stable signing for local builds

By default, the build script uses **ad hoc signing**. That is fine for quick local testing, but macOS may not persist Screen Recording permission across rebuilds.

If you have an Apple Development certificate, you can build with a stable signing identity:

```bash
CODESIGN_IDENTITY="Apple Development: Your Name (TEAMID)" ./scripts/build-app.sh
```

## Run locally

After building the app bundle, run:

```bash
./scripts/run-app.sh
```

`run-app.sh` only launches the existing app bundle. It does **not** rebuild it.

If the app bundle does not exist yet, build it first with:

```bash
./scripts/build-app.sh
```

## Website

This repository also includes a small Astro-based static site in `site/`.

It is intended for GitHub Pages and uses:

- `site/` for the Astro app
- `.github/workflows/pages.yml` for Pages deployment

To run it locally:

```bash
cd site
npm install
npm run dev
```

To build it locally:

```bash
cd site
npm run build
```

## Using the app

### Start still zoom

- Use the menu bar icon and choose `Toggle Still Zoom`
- Or use the configured global shortcut (default: `Ctrl+1`)

### Navigate

- Move the mouse to pan
- Use the mouse wheel to zoom in and out
- Left-click once to lock the current zoom position and enter annotation mode

### Annotate

- Drag to draw freehand
- `Ctrl`-drag for an arrow
- `Cmd`-drag for a rectangle
- `Option`-drag for a circle

Default annotation shortcuts:

- `R` = red
- `B` = blue
- `G` = green
- `Y` = yellow
- `C` = clear annotations
- `Esc` = exit zoom

### Save/export

- Press `Ctrl+S` to enter save mode
- Press `Enter` to save the full current image
- Or click, drag, and release to save a selected rectangle
- The saved image is also copied to the clipboard

By default, images are saved to your Desktop.

To change the save folder, use the menu bar icon and choose:

```text
Choose Save Folder…
```

### Customize shortcuts

Use the menu bar icon and choose:

```text
Customize Shortcuts…
```

You can change:

- the global still-zoom toggle shortcut
- red / blue / green / yellow keys
- clear key
- save key (`Ctrl+<key>`)

## Install from a release

If you are installing from a packaged release:

1. Download the release asset (`ZoomItMac-macOS.zip`)
2. Unzip it if needed
3. Drag `ZoomItMac.app` into `/Applications`
4. Open `ZoomItMac.app`
5. Grant **Screen Recording** permission when prompted
6. Quit and reopen the app once if macOS asks you to relaunch after permission is granted

After that, launch it from `/Applications` like any normal macOS app.

## Notes

- This project is currently focused on **still zoom**, not live zoom
- Local ad hoc builds are best for development/testing
- A fully signed release build is the smoothest path for macOS privacy permissions

## License

This project is licensed under the MIT License. See [`LICENSE`](./LICENSE).
