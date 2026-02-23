# Changes — wallpaper-engine-kde-plugin

Changes made to the upstream source to improve stability, usability,
and crash resistance on KDE Plasma 6 / Qt 6.

---

## Bug fixes

### 1. `src/TTYSwitchMonitor.cpp` — qFatal → qWarning (crash fix)

**Problem**
Two `qFatal()` calls in the TTY/sleep monitor would unconditionally
abort the entire `plasmashell` process if either:
- The D-Bus *system* bus was not reachable (containers, some non-standard setups), or
- The `org.freedesktop.login1` PrepareForSleep signal could not be connected.

`qFatal` calls `abort()`, which kills the parent process — plasmashell
in this case — with no recovery possible.

**Fix**
Both `qFatal` calls replaced with `qWarning`. The constructor now returns
early with a warning log message when D-Bus is unavailable. Sleep/wake
detection is disabled for that session; everything else continues normally.

---

### 2. `plugin/contents/ui/main.qml` — null-item crashes (3 fixes)

**Problem A — `autoPause()` null dereference**
`autoPause()` was called by the `okChanged` signal and by `playTimer`
before any backend was loaded. `backendLoader.item` was null at that
point, so `.play()` and `.pause()` caused a null-object access.

**Fix**
Added `if (!backendLoader.item) return;` guard at the top of `autoPause()`.

---

**Problem B — `lauchPauseTimer` null dereference**
Same issue: the launch-pause timer fired 300 ms after startup and called
`backendLoader.item.pause()` without a null check. If the backend had not
finished loading by that point the call crashed.

**Fix**
Added `if (backendLoader.item)` guard before the `.pause()` call.

---

**Problem C — `mouseHooker.destroy` missing parentheses**
When mouse input was disabled, the code read:
```js
this.mouseHooker.destroy;   // no-op — accesses the function but never calls it
```
The MouseGrabber object was never actually destroyed, leaking it and
leaving a dangling reference. Subsequent code set `this.mouseHooker = null`,
making the leak unrecoverable.

**Fix**
Changed to `this.mouseHooker.destroy();`

---

### 3. `plugin/contents/ui/backend/Scene.qml` — premature method calls

**Problem**
`play()`, `pause()`, `getMouseTarget()`, and the `onDisplayModeChanged`
handler all accessed the `player` (SceneViewer) object directly. These
could be triggered by signal bindings before `SceneViewer.Component.onCompleted`
had run, meaning the C++ object was in an uninitialised state.

**Fix**
Added a `playerReady` boolean property (set to `true` inside
`SceneViewer.Component.onCompleted`). Every method and handler that
touches `player` now checks `if (!playerReady) return;` first.
The display-mode initialisation was also moved into `onCompleted`
so it runs exactly once at the right time.

---

### 4. `plugin/contents/ui/page/WallpaperPage.qml` — two JS typos

**Problem A — `reoslve` typo**
Inside `setCurIndex()`, the Promise executor parameter was named `reoslve`
(transposed letters) but the resolve call used `resolve()`. The Promise
was therefore never resolved, causing callers to hang indefinitely.

**Fix**
Renamed the parameter to `resolve`.

---

**Problem B — `this.cofnig.update()`**
Inside `save_changes()`, after a successful `write_wallpaper_config` RPC
call, the code tried to call `this.cofnig.update(...)` — both a spelling
error (`cofnig` instead of `config`) and a non-existent method (QML objects
don't have `.update()`). This threw a runtime TypeError.

**Fix**
Replaced with `Object.assign(this.config, this.config_changes[wid] || {})`,
which correctly merges the saved changes into the local config cache.

---

## New feature: wallpaper compatibility badges

### 5. `plugin/contents/ui/Common.qml` — compatibility field

Added a `compatibility` property to `wpitem_template` (default `"unknown"`).
Added a `CompatibilityLevel` enum with values `Stable`, `Vulkan`, `Unknown`.

---

### 6. `plugin/contents/ui/WallpaperListModel.qml` — compatibility detection

Extended `loadItemFromJson()` to set `compatibility` for each wallpaper
when its `project.json` is read:

| Wallpaper type | `compatibility` value | Meaning |
|----------------|----------------------|---------|
| `video`        | `"stable"`           | Runs through GStreamer/mpv, isolated from plasmashell GPU state |
| `web`          | `"stable"`           | Runs through QtWebEngine, no Vulkan dependency |
| `scene`        | `"vulkan"`           | Requires Vulkan 1.1+, runs in-process, may crash plasmashell |
| anything else  | `"unknown"`          | Cannot determine safety |

---

### 7. `plugin/contents/ui/page/WallpaperPage.qml` — thumbnail badge overlay

Added a small badge in the bottom-left corner of every wallpaper thumbnail
in the grid view. The badge is only visible for wallpapers with
`compatibility !== "stable"`:

- **Orange "VULKAN" pill** — scene wallpapers that require Vulkan and run
  in-process with plasmashell. These *can* crash KDE if the wallpaper uses
  unsupported features or the Vulkan driver is incompatible.
- **Grey "?" pill** — wallpapers of an unknown or unsupported type.

Hovering a badge shows a tooltip with a plain-English explanation.

---

## New files

### `install.sh`

A single-command installer for the plugin. Detects the running Linux
distribution (Arch/CachyOS, Debian/Ubuntu, Fedora, openSUSE, Void) and:

1. Installs build-time dependencies via the native package manager
2. Initialises the `src/backend_scene` Git submodule (the most commonly
   missed step — without it the scene renderer is missing and the build fails)
3. Configures, builds, and installs the native C++ library
4. Installs the KDE plasma package via `kpackagetool`
5. Restarts `plasma-plasmashell.service`

Usage:
```sh
./install.sh              # full install
./install.sh --skip-deps  # skip package manager step (deps already installed)
```

---

### `CRASH_GUIDE.md`

Documents in detail why some wallpapers crash KDE:

- Root cause: scene renderer runs inside plasmashell (no process isolation)
- Unsupported features that trigger GPU faults (3D models, timeline animations,
  scenescript, audio visualisation, global bloom)
- Vulkan driver requirements and AMD RADV recommendation
- Missing Wallpaper Engine assets as a crash trigger
- Shader compilation failures via glslang
- Race condition on startup (fixed, but documented)
- Step-by-step recovery instructions for a crashed session
- Guide to permanently disabling scene support if crashes persist

---

## Minor changes

### `plugin/contents/ui/backend/InfoShow.qml` — improved error display

The original error screen was barely readable (30pt yellow text on plain
black). Replaced with a styled dark panel that:
- Shows a clear header with a warning icon
- Formats the error details in a monospace font
- For scene-type errors, prints the exact `kwriteconfig6` command needed
  to clear the broken wallpaper setting without having to edit config files
  manually

### `plugin/metadata.json` and `plugin/metadata.desktop` — version field

Both metadata files had an empty `Version` field. Set to `0.5.5` to match
`Common.qml`.

---

## What cannot be fixed without major rework

### In-process scene rendering

The scene/Vulkan renderer running inside plasmashell is the root cause of
all scene crash propagation. The README has a TODO item: *"move scene to
separate process"*. Until that is done, a sufficiently broken scene wallpaper
can always kill plasmashell. The compatibility badges added here let users
make an informed choice, but do not eliminate the underlying risk.

The fix requires:
1. A standalone renderer process that receives configuration over IPC
2. Shared-memory or DMA-buf frame transport back to the plasmashell QML item
3. Watchdog logic to restart the renderer and fall back to InfoShow on crash

This is a significant architectural change, not a bug fix.

### WebGL wallpapers

QtWebEngine running inside plasmashell cannot initialise an OpenGL context
(plasmashell owns the only compositor-level GL context). WebGL wallpapers
will never render correctly without running the web backend in a separate
process with its own GL context.
