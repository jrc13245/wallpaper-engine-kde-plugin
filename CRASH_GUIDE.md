# Crash Guide — Wallpaper Engine KDE Plugin

## Why do some wallpapers crash KDE plasmashell?

### Root cause: in-process rendering

The **scene (2D) backend** renders using a Vulkan/OpenGL pipeline that runs **inside** the `plasmashell` process. If the renderer encounters a fatal error (GPU fault, Vulkan validation failure, unhandled exception), the entire plasmashell process dies.

Video and web wallpapers are much safer: they run through GStreamer / QtWebEngine which are more isolated.

---

## Crash categories

### 1. Unsupported wallpaper features (most common)

The scene renderer is a partial reimplementation of Wallpaper Engine. Features marked as **not implemented** in the README can silently produce undefined GPU behaviour:

| Feature | Status | Risk |
|---------|--------|------|
| 3D models | ❌ Not supported | GPU crash if wallpaper relies on it |
| Timeline animations | ❌ Not supported | Corrupted frame timing |
| Scenescript | ❌ Not supported | Runtime error in shader |
| User Properties | ❌ Not supported | Shader variable mismatch |
| Global bloom | ❌ Not supported | Pass reference error |
| Audio visualisation | ❌ Not supported | Buffer overread |

**How to tell**: Open the wallpaper's `project.json` and look at the `type` and feature flags. Workshop wallpapers using any of the above are likely to crash.

---

### 2. Vulkan driver problems

The scene backend requires **Vulkan 1.1** and the **OpenGL External Memory Object** extension. Not all GPU+driver combinations support this correctly:

| GPU | Recommended driver | Notes |
|-----|-------------------|-------|
| AMD | **RADV** (Mesa) | AMDGPU PRO may crash |
| NVIDIA | **Nouveau** or proprietary ≥ 520 | Older proprietary drivers have Vulkan bugs |
| Intel | Mesa **ANV** | Generally stable |

Check your Vulkan driver:
```sh
vulkaninfo | grep -E "driverName|apiVersion"
```

If you get `SIGSEGV` with AMD, switch to RADV:
```sh
# Arch
sudo pacman -S vulkan-radeon
# Then set (in /etc/environment or shell profile):
export DISABLE_LAYER_AMD_SWITCHABLE_GRAPHICS_1=1
```

---

### 3. Missing Wallpaper Engine assets

Scene wallpapers load shaders and textures from the Wallpaper Engine installation under:
```
<steamlibrary>/steamapps/common/wallpaper_engine/assets/
```

If Wallpaper Engine is not installed or the Steam library path is wrong, the shader compiler cannot find its includes, causing a **Vulkan pipeline creation failure** that propagates as a crash.

**Fix**: Ensure Wallpaper Engine is installed on Steam *and* the plugin's Steam Library Path points to the same library that contains it.

---

### 4. Shader compilation failure

Some wallpapers use GLSL shader constructs that the `glslang` compiler (used internally) rejects or miscompiles. This produces a Vulkan validation error or invalid SPIR-V, which crashes the GPU command buffer.

**Workaround**: Enable Vulkan validation layers to see shader errors before they crash the system:
```sh
sudo pacman -S vulkan-validation-layers   # Arch
export VK_INSTANCE_LAYERS=VK_LAYER_KHRONOS_validation
systemctl --user restart plasma-plasmashell.service
# Then check: journalctl --user -u plasma-plasmashell -f
```

---

### 5. Race condition on startup (partially fixed)

The original code had a race where `autoPause()` and `lauchPauseTimer` could call `.play()` / `.pause()` on a backend item that was still null. This could cause a null-pointer dereference in C++. **This has been fixed** in this patched version.

---

## Recovery after a crash

If plasmashell has crashed and will not start due to a bad wallpaper setting:

```sh
# Remove the saved wallpaper source (works for all KDE versions)
kwriteconfig6 --file plasma-org.kde.plasma.desktop-appletsrc \
  --group "Containments" --group "1" \
  --group "Wallpaper" --group "org.kde.wallpaper-engine" \
  --group "General" --key "WallpaperSource" ""

# Or, if you know which screen's config is broken:
sed -i '/^WallpaperSource=/d' ~/.config/plasma-org.kde.plasma.desktop-appletsrc

# Then restart plasmashell
systemctl --user restart plasma-plasmashell.service
# or re-login if the above doesn't work
```

---

## Safe wallpaper types (least to most risky)

1. **Video** (`.mp4`, `.webm`) via QtMultimedia — safest, no GPU pipeline
2. **Video** via Mpv — very stable, isolated renderer
3. **Web** (HTML/JS) — safe but WebGL wallpapers won't render
4. **Scene** with only image/composition layers and basic effects — usually stable
5. **Scene** with particles, parallax effects — moderate risk
6. **Scene** with audio visualisation, 3D, or timeline — high crash risk

---

## Permanently disable scene wallpapers (if crashes persist)

If scene wallpapers consistently crash your system, switch to a video or web wallpaper. You can also rebuild the plugin without scene support by not initialising the submodule:

```sh
# Build with only video+web support (no scene/Vulkan)
git submodule deinit src/backend_scene
cmake -B build -S . -G Ninja -DUSE_PLASMAPKG=ON
cmake --build build && sudo cmake --install build
cmake --build build --target install_pkg
```

The plugin will still work for video and web wallpapers; scene wallpapers will show the error info screen instead of crashing.
