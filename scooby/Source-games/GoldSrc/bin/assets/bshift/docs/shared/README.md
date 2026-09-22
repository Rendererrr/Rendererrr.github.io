# Scooby Simple Base

A standalone C++20 UI template with a working desktop preview. The UI, profiles, hotkeys, languages, Lua runtime and ESP drawing are independent of a game SDK and graphics API.

For automatic propagation into consumers, start with [AUTO_SYNC.md](../AUTO_SYNC.md) and the [consumer inventory](docs/CONSUMERS.md). [Porting everything](docs/PORTING_EVERYTHING.md) retains subsystem and destination acceptance checklists.

## Source layout

This project lives in `simple-base/UI/`. The matching launcher is in [../Loader](../Loader/README.md). Both share this project's theme, fonts and Windows/DX11 host; all original menu, Lua, overlay and preview features remain here. Run the commands below from `UI/`.

## Run the preview

1. Open `run-preview.cmd` (it closes this template’s existing preview, incrementally rebuilds and runs the checks before opening the current executable), or run `build/windows/Release/simple_base_preview.exe`.
2. Press **Insert** (or your saved menu key) to open/close the menu. **F11** switches between a normal window and borderless fullscreen.
3. Assign feature keys in **Settings > Hotkeys**. Fresh settings match L4D: **Insert** opens the menu, feature keys start unassigned, and inactive binds are hidden. Existing saved bindings and overlay preferences are preserved.

The background contains five animated demo entities. Box, skeleton, name, health and distance ESP use real world-to-screen projection over that entity data. Closing the menu leaves the demo and overlays visible.

The runtime data folder defaults to `%LOCALAPPDATA%/Scooby/SimpleBase`. Override it with `--data "C:/your/data"`. The preview never reads another process.

## Included

- **Visuals > ESP:** master switch, full/corner boxes and fills, skeletons, names, health, distance and snaplines; gradients, outlines, label/bar placements and feature settings.
- **Settings > Interface:** resolution auto scale, manual UI scale, independent overlay scale, language selection/reload, menu key, welcome screen and layout reset.
- **Settings > Config:** browser, create, rename, load/save, reset/delete, startup default, clipboard import/export and debounced auto-save.
- **Settings > Hotkeys:** key/mouse capture, always/toggle/hold/hold-to-disable modes, search and assigned-only filtering. Capture waits for the activation click to be released; Mouse 1 works.
- **Settings > Overlays:** Watermark, Hotkeys and Active Features, with content/appearance options, effective feature states, action flashes, dragging and saved positions.
- **Visuals > Radar:** dedicated radar sub-tab with background, shape, rotation, range, dots, names, rings, colors, dragging and reset.
- **Settings > Scooby Links:** Website, Discord and GitHub.
- **Lua > Scripts:** the same browser/card layout as Config; create, rename, edit, run, duplicate and delete scripts.
- **Lua > Lua Editor:** syntax highlighting, script selector, per-file drafts, undo/redo, save/save-as, Ctrl+Enter execution and a console.
- **Search and favorites:** search registered features; hover a feature and press **F** to add/remove a favorite.
- **Welcome screen:** first-launch introduction with an optional repeat-on-launch preference.
- **Language files:** 23 UTF-8 catalogs, English fallback, native language names, RTL display preparation and bundled Noto glyph coverage. New untranslated phrases fall back to their source text.

## Build

Windows preview prerequisites: Visual Studio 2022 with Desktop development with C++, Windows SDK, CMake 3.24 or later, and Python 3.9+ for safe asset/document staging. Dependencies are vendored; the build requires no downloads.

```bat
build-preview.cmd
```

Or, from a developer terminal:

```bat
cmake --preset windows
cmake --build --preset preview
ctest --preset tests
```

The solution is generated at `build/windows/ScoobySimpleBase.sln`. Both Debug and Release configurations are available. `build-preview.cmd` locates CMake from PATH or Visual Studio Community's bundled installation.

## Source map

| Folder | Responsibility |
|---|---|
| `include/simple_base/` | Public integration APIs and portable data structures |
| `src/core/` | Features, hotkeys, config serialization, files, localization and Lua |
| `src/ui/` | Shell, theme, reusable widgets, pages, shared file browser and overlays |
| `src/esp/` | Projection, bounds and ImGui draw-list ESP renderer |
| `preview/` | Standalone executable lifecycle and demo entity provider |
| `src/platform/` | Shared Win32/DX11 swapchain, resize and capture host |
| `assets/` | Icon font, language catalogs and sample scripts |
| `examples/` | Compilable embedding example and callback entity source |
| `docs/` | Porting, adding features, data format and verification guides |
| `tests/` | Core regression tests and all-page UI/ESP tests |
| `third_party/` | ImGui and backends, text editor, JSON and Lua sources/licenses |

Start with [PORTING.md](docs/PORTING.md) to embed the UI, [ADDING_FEATURES.md](docs/ADDING_FEATURES.md) to extend it, and [TESTING.md](docs/TESTING.md) to exercise the preview.

## Renderer support

The executable preview uses **DX11**. The core/UI share the same ImGui draw-data interface for every renderer.

| CMake target | Purpose |
|---|---|
| `simple_base_core` | Non-rendering systems and entity math |
| `simple_base_ui` | UI and ESP; link this into your host |
| `simple_base_win32` | Windows input/window integration |
| `simple_base_dx11_host` | Shared Windows/DX11 host used by preview and loader |
| `simple_base_dx11` | DX11 renderer, used by the preview |
| `simple_base_dx12` | DX12 renderer for a host-owned device, queue, descriptors and command list |
| `simple_base_opengl` | OpenGL renderer for a host-owned current context |
| `simple_base_vulkan` | Optional Vulkan renderer; enable `SIMPLE_BASE_VULKAN` with a Vulkan SDK installed |

DX12 and OpenGL backend libraries are included in the normal Windows build. Vulkan is opt-in. Their host applications still own graphics initialization, swapchains, frame synchronization and presentation; see the exact contracts in [PORTING.md](docs/PORTING.md). They are not separate ready-made preview executables.

## Lua

The preview runs Lua 5.4.7 with persistent named scripts. Scripts can register custom features, tabs, sub-tabs, standalone menus, overlays, themes and page replacements through the UI API. Reloading or stopping a script cleans up its registrations. Existing `base.get`, `base.set`, logging and host API extensions remain supported.

Open **Lua > API docs** for the attached left/right reference window. The complete [Lua API guide](docs/LUA_API.md) includes every binding, runnable examples, lifecycle rules and host extension instructions. Try `Custom UI.lua` and `Standalone Menu.lua` from the script browser. Run the preview with `--page api --no-welcome` to open the guide immediately.

## Floating console

Use **Console** under the Lua editor, or **Lua → Console → Windowed console**. It floats inside the host window with a translucent charcoal body, themed title bar and options popup, timestamped severity labels, drag/resize, an arrow to collapse/expand the log area and close. The small window icon (or right-clicking the header) opens Copy all, Clear and Auto-scroll. Scrolling up pauses following new lines while you read.

Launch the preview with `--console --no-welcome` to show it immediately. It renders through the same ImGui backend as the UI, with no separate OS window or renderer dependency. The host can write from background threads using `Application::console().write(message, LogLevel::Info)`; visibility and drawing belong on the UI thread. See [CONSOLE.md](docs/CONSOLE.md).

## Ownership

Use one `Application` per ImGui context, on the render thread. The host owns ImGui context creation/destruction, backend initialization, input, renderer resources and presentation. `Application` owns the UI state and services. Call `shutdown()` before tearing down ImGui to flush pending auto-save. See [THIRD_PARTY.md](THIRD_PARTY.md) for dependency provenance.

The original Scooby UI components, their source mapping, and group/column usage are documented in [UI_COMPONENTS.md](docs/UI_COMPONENTS.md).

## Wine / Proton compatibility builds

Windows x86/x64 preview packages, explicit runner/prefix selection, Unicode/read-only data handling and runtime diagnostics are documented in [docs/LINUX_COMPATIBILITY.md](docs/LINUX_COMPATIBILITY.md) and [linux/README.md](linux/README.md). Native Windows tests pass; actual Linux/Steam Deck acceptance remains unverified.
