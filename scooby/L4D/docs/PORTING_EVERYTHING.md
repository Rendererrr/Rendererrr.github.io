# Complete Base/UI porting guide

Use this document when moving **all of Scooby Simple Base** into another project or game. Preserve the existing behavior, appearance, assets, configuration compatibility, Lua API and development tools. Add the destination project's data and behavior through adapters.

This guide was audited against the local source on **2026-09-21**, including the persistent Lua UI API and live scaling changes. The audit included modified and newly created files in the working tree. A checkout of an older commit is not an equivalent copy.

A port is complete only when the file inventory, functionality checklist and destination-host checks all pass. A menu that merely looks similar does not establish that profiles, hotkeys, scripts, fonts or renderer recovery work.

The repository now contains sibling `UI/` and `Loader/` projects. All paths in this guide and its inventory are relative to **UI/**. Run UI build commands from that folder. Canonical dependency and automatic staging instructions are in [AUTO_SYNC.md](../../AUTO_SYNC.md). To transfer the launcher as well, keep both siblings and follow [Loader integration](../../Loader/docs/INTEGRATION.md). Do not reuse build caches from the former root layout.

## Contents

1. [Porting workflow](#1-porting-workflow)
2. [Source and ownership verification](#2-source-and-ownership-verification)
3. [Build and dependency integration](#3-build-and-dependency-integration)
4. [Application lifecycle and host responsibilities](#4-application-lifecycle-and-host-responsibilities)
5. [Connect game data and features](#5-connect-game-data-and-features)
6. [Every subsystem and its source](#6-every-subsystem-and-its-source)
7. [Preserve every UI behavior](#7-preserve-every-ui-behavior)
8. [Profiles, settings and runtime data](#8-profiles-settings-and-runtime-data)
9. [Fonts, languages, assets and licenses](#9-fonts-languages-assets-and-licenses)
10. [Port the complete Lua system](#10-port-the-complete-lua-system)
11. [Renderer-specific requirements](#11-renderer-specific-requirements)
12. [Verification and acceptance](#12-verification-and-acceptance)
13. [Troubleshooting](#13-troubleshooting)
14. [Handoff template for a developer or coding agent](#14-handoff-template-for-a-developer-or-coding-agent)
15. [Complete file inventory](#15-complete-file-inventory)

## 1. Porting workflow

1. Identify the actual consumer and its architecture/renderer in [CONSUMERS.md](CONSUMERS.md).
2. Diff any existing vendor copy against canonical UI. Reconcile reusable fixes and preserve host adapters; do not overwrite unexplained changes.
3. Use the canonical source dependency and manifest staging in [AUTO_SYNC.md](../../AUTO_SYNC.md). No new manually maintained source copies are needed.
4. Connect platform/rendering, input, DPI, asset paths and a separate writable product data directory.
5. Preserve Application lifecycle and supply game data through Scene, feature registration and host Lua extensions.
6. Build shared and consumer tests, verify source/header rebuilds and asset/docs-only refresh, then separately validate the real game runtime.
7. Record adaptations, retained vendor baselines, test evidence and any blocked coverage in the consumer inventory.

## 2. Source and ownership verification

Run `python scripts/check_port_inventory.py` from UI to verify the source inventory below, and `python scripts/audit_consumers.py` to discover unregistered consumers or ignored vendor drift. Use `--write` on the inventory checker only after intentional shared source changes. Build/output/data/IDE caches are excluded from source inventory.

The build reads canonical include/src/third_party directly, preserving compiler dependency tracking. Preview/examples/tests remain in canonical UI. Fonts, notices, shared Markdown and samples are automatically staged by the product's asset target. Game overlays remain editable in their own source trees. Generated staged files are not editable sources; keep user settings/profiles/scripts/logs in separate product data directories. See AUTO_SYNC for conflict recovery, deterministic manifests and scoped removal.

## 3. Build and dependency integration

### Recommended: use the supplied CMake targets

The base requires C++20 and CMake 3.24 or newer. The current Windows preset selects Visual Studio 2022, x64. Use a consistent compiler, architecture, runtime library and configuration across the host, Lua, ImGui and UI. Configure another generator explicitly when the preset does not match the destination.

A DX11/Win32 host can embed it as follows. Replace `my_game_host` with the destination's actual CMake target; that target must already exist.

```cmake
set(SIMPLE_BASE_PREVIEW OFF CACHE BOOL "" FORCE)
set(SIMPLE_BASE_TESTS OFF CACHE BOOL "" FORCE)
set(SIMPLE_BASE_DX12 OFF CACHE BOOL "" FORCE)
set(SIMPLE_BASE_OPENGL OFF CACHE BOOL "" FORCE)
set(SIMPLE_BASE_VULKAN OFF CACHE BOOL "" FORCE)
include("${SIMPLE_BASE_UI_ROOT}/cmake/SimpleBaseConsumer.cmake")
simple_base_add_ui(API_REVISION 1)
target_link_libraries(my_game_host PRIVATE simple_base_ui simple_base_win32 simple_base_dx11)

simple_base_stage_assets(TARGET my_game_host
    EXTRA_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/assets")
```

Set SIMPLE_BASE_UI_ROOT to the canonical checkout as described in AUTO_SYNC. Use a dedicated DESTINATION if the host needs another asset path and pass it through AppOptions.assets. Rebuild the product/sync target before packaging; the hook runs even when no C++ target relinks.

| Target | What it brings |
| --- | --- |
| `simple_base_lua` | Bundled Lua implementation and its exception-safe embedding flags. |
| `simple_base_imgui` | Matching ImGui core, draw, tables and widgets implementation. |
| `simple_base_core` | Registry, hotkeys, files, configs, localization/RTL, logging, Lua runtime and projection; links Lua and threads. |
| `simple_base_ui` | Application, pages, widgets, fonts, overlays, console, Lua UI/docs, ESP renderer and text editor; links core and ImGui. |
| `simple_base_win32` | Win32 platform backend and its system dependencies. |
| `simple_base_dx11`, `simple_base_dx12`, `simple_base_opengl`, `simple_base_vulkan` | Corresponding bundled renderer and required SDK/system libraries. |
| `simple_base_dx11_host` | Shared Win32/DX11 swapchain, resize/recovery and PNG capture host used by preview and loader. |
| `simple_base_preview` | Complete standalone Win32/DX11 preview and demo host; optional product executable. |
| `simple_base_embed_example` | Compile-checked Windows embedding example; enabled with tests. |
| `simple_base_tests`, `simple_base_ui_tests`, `simple_base_esp_tests`, `simple_base_lua_api_tests` | The four regression executables. |

Disable unused renderer options if their SDK/libraries are not installed. Preserve their source for future ports. The portable core/UI can be built without the Windows preview; only the Win32 platform backend is bundled, so another platform needs a compatible platform backend or equivalent host input implementation.

### Existing ImGui or a different build system

- Keep **one matching ImGui implementation** in the final host. The bundled version is `1.92.7 WIP`, `IMGUI_VERSION_NUM=19262`; local widgets use internal APIs and the dynamic-font interface.
- An existing host's older ImGui cannot simply replace these headers. Either use this consistent set throughout the host, or perform an explicit compatibility port and rerun all UI/backend checks.
- Keep `imconfig.h`, internal headers, stb headers, core `.cpp` files and backend headers/sources together. Match definitions that affect ImGui structures across all translation units.
- Use `CMakeLists.txt` as the exact compiled-source and system-library manifest. Header-only UI components and `LuaSyntax.h` still need to be copied.
- Compile `third_party/lua/*.c` as **C++**, exclude `lua.c`, `luac.c` and `onelua.c` from the library target, and force-include `src/core/lua_cpp.h`. Some excluded entry-point files may not be present in this snapshot; do not add the amalgamation alongside separate Lua sources.
- Preserve the C-compatible public Lua declarations and C++ exception unwinding. On MSVC use `/EHs /EHc-` for Lua **and the C++ code calling its API**. `/EHsc` assumptions about C calls caused an optimized error-path crash; linking the provided target propagates the required options.
- Preserve C++20, UTF-8 compilation, `NOMINMAX`, `WIN32_LEAN_AND_MEAN`, required include paths, thread linkage and relevant platform libraries. Do not compile the same implementation twice.
- The UI uses ImGui internal error recovery for Lua callbacks. Retest it when changing ImGui versions or compile options.

## 4. Application lifecycle and host responsibilities

Read [the public Application API](../include/simple_base/ui/application.h), [the compiled DX11 frame example](../examples/embed_dx11.cpp) and [the preview lifecycle](../preview/main.cpp) together.

### Initialization order

1. Obtain a valid host window/platform surface and graphics resources.
2. Establish the ImGui context and initialize the chosen platform/renderer backends once.
3. Construct one `Application` for that context with absolute/resolved asset and writable data paths, title, renderer name, welcome preference and optional `openLink` callback.
4. Register C++ host features **before `initialize()`** if they must receive startup-default profile values.
5. Install `scripts().registerHostApi` before running any script. This hook is separate from the UI's built-in registration hook.
6. Call `initialize()` once, before the first renderer `NewFrame()`. It initializes fonts, style, widgets, sample files, the radar reset action, editor, startup profile, language and welcome state.
7. Run desired Lua scripts explicitly after initialization. Script-owned IDs must exist before loading profile values for them; see the Lua startup ordering below.

`initialize()` sets keyboard navigation, the global style/default font, and `io.IniFilename = nullptr`. If sharing a context with an existing host UI, account for those changes deliberately. Do not assume the host's old style, font or automatic `.ini` layout persistence remains untouched. Select the correct context before every application/backend call.

### Frame order

The host owns the following sequence. The names for the window, device and scene provider are supplied by the host, not additional Base/UI APIs.

```cpp
// Skip drawing while the render size is zero or the render target is unavailable.
ui.prepareFrame({clientWidth, clientHeight}, monitorDpiScale);
ImGui_ImplDX11_NewFrame();
ImGui_ImplWin32_NewFrame();
ImGui::NewFrame();

simple_base::Scene snapshot = entitySource.sample(seconds, clientWidth / clientHeight);
ui.draw(snapshot, applicationHasFocus);

ImGui::Render();
// Bind the host's current render target before this call.
ImGui_ImplDX11_RenderDrawData(ImGui::GetDrawData());
// Present through the host's normal frame/synchronization path.
```

Call `Application::draw()` once for every UI frame **even when the main menu is hidden**. It still processes hotkeys, Lua events, ESP, overlays, independent script windows, the floating console and config autosave. Wrapping the entire call in `if (ui.menuVisible())` loses those systems.

`prepareFrame()` runs before ImGui `NewFrame()`. It applies fonts, DPI, live scale, baseline style, custom accent and Lua themes. Do not stretch completed draw vertices or repeatedly clear/rebuild the font atlas while dragging a scale slider.

### Input and OS services

- Feed keyboard, character/IME, mouse movement/buttons/wheel and focus events to ImGui through the chosen platform backend. Forward Win32 messages to `ImGui_ImplWin32_WndProcHandler` in a Windows host.
- Route input between UI and the game using ImGui capture state and the host's input policy. Continue feeding ImGui even when the game is prevented from acting on captured input. Supply the actual foreground/focus state to `draw` so Hold binds do not stick after focus loss.
- Preserve the F2/default configurable menu key and Insert fallback. F11 is the standalone preview's fullscreen behavior; an embedded game must use its own fullscreen/window management.
- Preserve clipboard functionality for config/script import/export, console copy and API-doc copy. Verify the platform backend's clipboard callbacks in the destination.
- Supply `AppOptions.openLink` for external links; without it, the Settings links copy their URL to the clipboard. Product branding and link destinations are separate changes: title/renderer options do not replace hard-coded URLs in `settings_page.cpp` or every branding literal.
- Keep link opening tied to a user click. The welcome card currently has no Website/Discord buttons; those links are on Settings > Scooby Links.

### Data and thread ownership

Use a separate writable data root per product, for example the destination's own app-data directory. The preview default is `%LOCALAPPDATA%/Scooby/SimpleBase`; do not reuse it blindly for every game. Packaged assets may be read-only; profiles and edited Lua files must remain writable.

Create/run/stop Lua, modify the registry/preferences and draw the UI on the render thread. Game data from other threads should enter through an immutable/copy-owned `Scene` snapshot. `LogBuffer::write` supports background producers; other application services do not promise concurrent access. Preserve its 512-row capacity, 4,096-byte row limit and 65,536-byte write limit, severity/timestamps and immutable snapshots. See [CONSOLE.md](CONSOLE.md).

### Shutdown and resource recreation

- Stop/join background producers before destroying anything they use.
- Call `ui.shutdown()` while the ImGui context and objects captured by Lua/action callbacks still exist. Check its returned `Result`. It flushes autosave before unloading script features and runs script shutdown/cleanup.
- Shut down the renderer backend, then the platform backend, then destroy ImGui and the host graphics resources in a GPU-safe order.
- Keep the `Application`/`FontSet` alive until ImGui has finished using its atlas: font byte buffers are owned by the application with `FontDataOwnedByAtlas=false`. Destroy the application after the ImGui context, having already called `shutdown()`.
- A swapchain resize and a complete device loss are different paths. The DX11 preview recreates its render target for an ordinary resize; a complete device recreation shuts down/reinitializes both bundled Win32 and DX11 backends and clears input keys. Preserve equivalent host recovery.
- Avoid reconstructing/reinitializing `Application` every frame or ordinary resize. That would discard scripts/drafts/state and duplicate initialization registrations.

## 5. Connect game data and features

### Scene adapter: every field matters

Implement `EntitySource::sample` or use [CallbackEntitySource](../examples/callback_entity_source.h). Keep the provider independent of UI drawing.

| Data | Contract / consumer |
| --- | --- |
| `Camera.viewProjection` | Row-major 4x4 matrix; projection computes matrix times `[x,y,z,1]`. Convert the source matrix's storage/order explicitly. |
| `Camera.zeroToOneDepth` | True for clip depth `[0,1]`, false for `[-1,1]`. Use the actual projection convention. |
| `Camera.position` | World coordinates; distance and radar reference. |
| `Camera.yawDegrees` | Radar heading in its X/-Z ground plane: -90 faces world +Z, 0 faces +X. |
| `Entity.id`, `name` | Stable identifier and UTF-8 display name. |
| `Entity.position` | World position, used for radar/distance and snapline endpoint. Supply the appropriate feet/origin position. |
| `Entity.minBounds`, `maxBounds` | Absolute world-space AABB corners. Transform local/rotated bounds and form a world AABB first. |
| `Entity.bones`, `bonePairs` | World-space bone positions and index pairs. Invalid indices are skipped. |
| `Entity.health`, `maxHealth` | Health ratio data; verify dead/zero/invalid values in the host. |
| `Entity.alive` | Dead/despawned entities can be marked false or omitted. |
| `Entity.teammate` | Radar team/enemy color classification. |
| `Scene.server`, `pingMs` | Optional watermark telemetry. Empty server or unavailable/negative ping is omitted. |

All world positions, bounds, bones, camera and distance units must agree. The current radar projects X/Z; a Z-up engine needs a deliberate coordinate conversion or radar adapter. Converting the whole snapshot also requires the corresponding camera matrix conversion.

Projection rejects non-finite/behind-camera geometry and fully offscreen bounds. Bounds crossing the near plane are skipped by the current renderer. Preserve this behavior unless intentionally extending it with clipping and new tests.

Radar UI range is currently 1-250 host world units; config validation accepts up to 50,000. Feature distance config validation currently clamps to 1-1,000. For centimetres/Source units or larger worlds, update the **UI ranges, serializer validation, runtime interpretation, descriptions and tests together**. Changing only a slider will make saved values reload incorrectly.

### Feature registry and stable IDs

| Built-in ID | Meaning |
| --- | --- |
| `esp.enabled` | ESP master enable. |
| `esp.box` | Full/corner box and fill. Default hotkey F6. |
| `esp.skeleton` | Bone connections. Default hotkey F7. |
| `esp.name` | Name labels. |
| `esp.health` | Health bars. |
| `esp.distance` | Distance labels. |
| `esp.snaplines` | Lines from top/bottom/center to entity position. |
| `overlay.watermark` | Project/renderer/telemetry watermark. |
| `overlay.binds` | User-visible **Hotkeys** overlay; retain the legacy ID. |
| `overlay.radar` | Radar; its controls are under Visuals > Radar. |
| `overlay.active_features` | Active Features overlay. |
| `radar.reset_position` | Action registered by `Application::initialize()`. |
| `demo.animate` | Animation control retained in the reference preview. |

IDs connect the registry, UI, hotkeys, search/favorites, configs, Lua and overlays. Preserve them when labels are renamed/translated. Do not silently replace `overlay.binds` with `overlay.hotkeys` in a port.

For each new C++ feature: register its unique ID/defaults and metadata; add the appropriate UI row/settings; consume effective state in the game; serialize and validate new options; add translations/description; verify its hotkey, search, favorites, profile and Active Features behavior.

Use `ui.hotkeys().active(feature)` for game behavior. `.enabled` alone bypasses Hold/HoldOff. Actions use `FeatureKind::Action` and `Feature::activate()` so buttons and hotkeys share the callback, activation serial and overlay flash. Avoid retaining feature pointers across registry additions/removals/config replacement.

`showInActiveList`, `activeListLabel` and `activeListParent` are host metadata. Parent gating controls Active Features display; it does not automatically gate arbitrary game behavior. Preserve action exclusion, parent/missing/cycle handling and reset defaults. Removing a Lua feature must remove its stored defaults too.

There is no automatic game SDK, entity access or native game-action implementation in the base. The destination implements these adapters; the existing UI systems remain intact. See [ADDING_FEATURES.md](ADDING_FEATURES.md).

## 6. Every subsystem and its source

The full path inventory is below. This table maps behavior to the files that must move together.

| Subsystem | Main implementation / contracts | Port check |
| --- | --- | --- |
| Shared Windows host | `include/simple_base/platform/dx11_host.h`, `src/platform/dx11_host.cpp` | Retain the reference swapchain/resize/capture implementation; host-owned renderer integrations may adapt it. |
| Application shell/lifecycle | `src/ui/application.cpp`, `src/ui/internal.h`, `include/simple_base/ui/application.h` | One lifecycle, fixed header/actions, scroll body, all pages, docs attachment, script dispatch and teardown. |
| Theme and shared controls | `include/simple_base/ui/theme.h`, `src/ui/theme.cpp`, `src/ui/widgets.cpp`, `src/ui/components/lumia.cpp`, `include/simple_base/ui/widgets.h` | Palette, icons, toggle/slider/color/hotkey/settings controls, groups, responsive columns and distinct ImGui IDs. |
| Fonts | `include/simple_base/ui/font_set.h`, `src/ui/components/font_set.cpp`, `assets/fonts/` | Glyph fallback/merging, language-specific CJK preference, whole-pixel cached fonts and byte-buffer lifetime. |
| Interface settings | `src/ui/interface_page.cpp` | UI/Overlays/Text selector, live drag behavior, accent, language/menu key/welcome/layout controls. |
| Descriptions | `src/ui/description_box.cpp` | Top-of-menu description box and preference. |
| Visuals pages/options | `src/ui/visuals_page.cpp`, `src/ui/esp_settings.cpp`, `include/simple_base/core/esp_settings.h` | ESP options and separate Radar sub-tab remain connected to drawing/config state. |
| ESP/math | `src/esp/projection.cpp`, `src/esp/esp_renderer.cpp`, `include/simple_base/esp/*.h` | Matrix/bounds contract, all drawing modes, outlines/gradients/fills/placement and snaplines. |
| Standard overlays | `src/ui/overlays.cpp`, `src/ui/overlay_settings.cpp`, `include/simple_base/core/overlay_settings.h` | Watermark, Hotkeys, Active Features, radar, positions/settings and effective states. |
| Overlay drawing helpers | `src/ui/components/overlay_panels.h`, `radar_panel.h`, `active_features.h` | FPS graph, action flash, dragging/clamping, compact sizing, radar geometry and active labels. |
| Welcome | `src/ui/components/welcome.h`, application/interface code | First-launch/reopen/repeat state, open-key capture and compact tooltip. |
| Settings/hotkey page/links | `src/ui/settings_page.cpp` | Capture/search/assigned filter, overlays page and click-driven product links. |
| Shared file browser | `src/ui/file_browser.cpp` | Config/script actions, padded list rows, confirmations, clipboard and traditional two-pane layout. |
| Feature model/defaults | `src/core/feature_registry.cpp`, `include/simple_base/core/feature_registry.h`, `color.h` | Stable IDs, actions, defaults, preferences and RGBA values. |
| Hotkey engine | `src/core/hotkeys.cpp`, `include/simple_base/core/hotkeys.h` | Always/Toggle/Hold/HoldOff, capture arming/cancel, mouse/text/focus handling and active list. |
| Profiles/files | `src/core/configs.cpp`, `src/core/files.cpp`, matching public headers | Complete schema, transactional decode, atomic writes, safe names, startup defaults and autosave. |
| Localization | `src/core/localization.cpp`, `localization_rtl.cpp`, public header, `assets/languages/` | English fallback, native names, ordering/reload, RTL display preparation and glyph coverage. |
| Lua core | `src/core/scripts.cpp`, `lua_cpp.h`, `include/simple_base/core/scripts.h`, `third_party/lua/` | Persistent named states, budgets, C++ unwind behavior, events/features and host hook. |
| Lua UI | `src/ui/lua_ui.h/.cpp` | Registration ownership, custom tabs/windows/overlays, widgets, themes, page overrides and error cleanup. |
| Lua editor/browser | `src/ui/lua_page.cpp`, file browser, `third_party/text_editor/` | Lua lexer, per-file drafts, run/stop/save, selector/status/toolbar and console connection. |
| Lua docs | `src/ui/lua_docs.cpp`, `docs/LUA_API.md` | Continuous read-only guide, Lua syntax highlighting, selection/copy and host snippets. |
| Console/logging | `src/core/log_buffer.cpp`, `src/ui/console_window.cpp`, matching public headers | Thread-safe bounded records and both in-page/floating views. |
| Host reference | `preview/main.cpp`, `dx11_host.h/.cpp`, `demo_scene.h/.cpp` | Window/input, DPI, graphics recovery, sample scenes, capture and smoke path. |
| Embedding reference | `examples/embed_dx11.cpp`, `examples/callback_entity_source.h` | Known frame sequence and snapshot adapter. |
| Tests/tooling | `tests/`, root command/CMake files, `scripts/` | Four suites, preview build/run/smoke, font verification and catalog maintenance. |
| Dependencies/notices | `third_party/`, `THIRD_PARTY.md`, font licenses | Consistent implementations and redistribution notices. |

When adding a compiled file in a destination, update its build target. Copying a source file that is never compiled or called does not port its behavior.

## 7. Preserve every UI behavior

Use each row as an acceptance item. Check it in the destination with the actual renderer/input backend. Keep reference screenshots for the same scale/resolution/language.

| Done | Area | Required behavior |
| --- | --- | --- |
| [ ] | Navigation | Visuals, Lua, Settings, all sub-tabs and Lua-added entries; active state and keyboard/click handling work. |
| [ ] | Header | Search is clickable; Favorites star appears only when a feature is favorited; header remains outside the scrolling body. |
| [ ] | Search/favorites | Search source/translated feature labels, categories and matching results; F-hover favorite behavior, color/gear controls and hidden-feature overrides work. Preserve compact padded search without the unwanted accent outline. |
| [ ] | Scrolling | Vertical scrollbar starts beside the content groups below the search/star/header. Resizing reflows groups instead of cutting them off. |
| [ ] | Columns | Per-page layout, up to five logical columns; Interface uses three, with narrow-window reflow. Config/Scripts retain browser plus stacked action cards. One small group does not stretch across a huge page. |
| [ ] | Window borders | Main menu remains draggable/resizable without the unwanted cyan resize-edge/corner highlight. |
| [ ] | Groups | Collapsible cards, consistent arrow sizing when open/closed, preserved IDs/state through reflow. |
| [ ] | Feature controls | Toggles, settings gear, colors, action buttons, hotkey popups and descriptions all change the actual feature state. |
| [ ] | Popups | Compact hotkey mode/set-key controls; feature title below hotkey controls in the gear; removed decorative divider lines; compact color picker without its side scrollbar; RGB/HEX/alpha editing. |
| [ ] | Interface/Scale | One group with UI/Overlays/Text selector; selected controls only. 100% UI/overlay uses the 0.75 compact baseline. |
| [ ] | Live scaling | UI, overlay, normal text and advanced text roles update while dragging; stable value at rest; direction reversal and responsive reflow work; release does not jump; Escape restores the start value/bounds. Docs attachment must not block live menu resizing. |
| [ ] | Text | Normal, sidebar tabs, sub-tabs and headings have separate multipliers; role minimums and whole-pixel font sizes remain readable; Lua syntax and ESP sizes keep their own rules. |
| [ ] | Appearance | Custom accent toggle/picker/reset changes relevant toggles/sliders/etc.; description box appears above UI when enabled. |
| [ ] | Menu key/layout | Key capture, cancel/reset, Insert fallback, Show welcome screen, Show on next launch, Reset window layout. |
| [ ] | Language selector | English first, German second, Spanish next, stable remaining catalog order; reload works and glyphs render. |
| [ ] | Welcome | Get Started, change open key, repeat preference and compact hover; Website/Discord buttons remain absent from this card. |
| [ ] | Config browser | Create, rename, load, save, reset, delete confirmation, set startup default, import/export, refresh and autosave; list text has left padding. |
| [ ] | Hotkey settings | Capture keyboard/mouse, clear, Always/Toggle/Hold/HoldOff, search/assigned-only filtering, focus/text-input suppression. |
| [ ] | Watermark | Title/renderer, custom text, FPS, graph, ping, clock, server options; default dragging, lock and position reset/persistence. |
| [ ] | Hotkeys overlay | Compact content width, white active names/gray inactive names, accented keys, optional inactive rows; no Toggle/ON suffix; action activation briefly flashes. |
| [ ] | Active Features | Effective active toggles, parent filtering, action exclusion, color/size/spacing/background, accent bar, alignment, width sort, drag/lock/reset and long-list behavior. |
| [ ] | Radar | Visuals > Radar sub-tab; square/circular plot, background restored without outer card/outline/header, rotation, crosshair, dots/outlines, team/enemy colors, names, rings, range, sizes, dragging and reset action. |
| [ ] | ESP | Master enable and box/skeleton/name/health/distance/snaplines respond to the shared entity snapshot. |
| [ ] | ESP appearance | Full/corner box; independent fill and fill gradient; color gradients/direction; outlines/colors/thickness; top/bottom/left/right name/distance/bar placements and offsets; same-side label/bar spacing; snapline top/bottom/center origins. |
| [ ] | Lua browser | Create, rename, edit, run, duplicate, delete confirmation, open in editor, import/export and refresh; same padded browser layout as Config. |
| [ ] | Lua editor | Lua syntax/line numbers, drafts, undo/redo, clear, compact selector, Run/Stop/Save/Save as/Console; status inside editor bottom; Ctrl+Enter runs without the removed status hint. Narrow layouts show selector and Stop. |
| [ ] | Lua extensions | Both bundled samples work; real custom features/tabs/sub-tabs/windows/overlays/themes/overrides; unload/reload/error/timeout behavior passes. |
| [ ] | API reader | Lua > API docs; attached continuous reader follows menu geometry; read-only code selection/copy and host snippets. |
| [ ] | Console | In-page and floating views, timestamps/severity, background logging, collapse/expand, drag/resize/close/reopen, Copy all/Clear/Auto-scroll; reading old output is not yanked to the bottom. |
| [ ] | Links | Settings > Scooby Links retains Website/Discord/GitHub actions, or explicitly recorded destination branding replacements, with host opening/clipboard fallback. |
| [ ] | Hidden menu | ESP, overlays, script update/render callbacks, independent script menus, console, hotkeys and autosave still function. |

The UI can be extended, but do not simplify these controls into lookalikes that lose their existing interactions or persistence.

## 8. Profiles, settings and runtime data

### Runtime file layout

```text
<product-data>/
  configs/*.json
  scripts/*.lua
  default.txt
  welcome-seen.txt
```

All bundled Lua samples are copied into the writable script directory during initialization only when the corresponding user file does not already exist. Keep the original assets as installation defaults and the data directory as user-owned content.

Preserve schema **1**, stable IDs, optional-field compatibility and legacy box-fill migration. The loader validates a temporary registry/preferences copy and commits only after successful validation. Unknown feature IDs are ignored; therefore register host/script features before loading their values.

### Every serialized field family

| Location | Fields to retain |
| --- | --- |
| Root | `schema`, `features`, `interface`, optional `overlays`. |
| `features[id]` | `enabled`, `favorite`, `key`, `mode`, `color`, `thickness`, `distance`, `text_size`, `style`, `filled`, `appearance`. |
| `features[id].appearance` | `gradient`, `gradient_color`, `gradient_direction`, `outline`, `outline_color`, `outline_thickness`, `fill_color`, `fill_gradient`, `fill_gradient_color`, `bar_background`, `position`, `offset`, `snapline_origin`. |
| `interface` | `auto_scale`, `ui_scale`, `overlay_auto_scale`, `overlay_scale`, `text_scale`, `tab_text_scale`, `subtab_text_scale`, `heading_text_scale`, `custom_accent`, `accent`, `descriptions`, `auto_save`, `language`, `menu_key`, `radar_position`. |
| `overlays.watermark` | `show_fps`, `fps_graph`, `show_ping`, `show_time`, `show_server`, `custom_text`, `draggable`, `position`. |
| `overlays.binds` | `show_inactive`, `draggable`, `position`. |
| `overlays.active_features` | `draggable`, `sort_by_width`, `accent_bar`, `alignment`, `text_size`, `spacing`, `background_opacity`, `position`. |
| `overlays.radar` | `rotate`, `names`, `crosshair`, `dot_outline`, `draggable`, `range_rings`, `shape`, `ring_count`, `size`, `range`, `dot_size`, `name_size`, `background`, `ring`, `enemy`, `team`. |

Keep numeric enum meanings: BindMode 0 Always / 1 Toggle / 2 Hold / 3 HoldOff; ESP position 0 Top / 1 Bottom / 2 Left / 3 Right; gradient 0 Vertical / 1 Horizontal; snapline 0 Top / 1 Bottom / 2 Center. Radar shape 0 square / 1 circle; active-list alignment 0 left / 1 right.

Validation behavior is defined by `src/core/configs.cpp`: reject malformed types/shapes, unsupported schema, non-finite values and explicitly invalid enums; bounded finite numeric fields are clamped. Preserve the actual implementation instead of broadly rejecting every out-of-range number or applying half a malformed profile.

### Persistence and compatibility checks

- Config/file reads are bounded to 2 MB by the standard file API; Lua execution accepts at most 1 MB of source. Keep filename validation, device-name rejection and path traversal protection.
- Writes use a sibling temporary file and atomic replacement. Preserve the old file when writes fail. Use the native Windows replacement behavior or the applicable filesystem implementation.
- Active profile and startup default are separate. Create/Load/Save make a profile active; Set as default writes the startup selection. Rename/delete update references correctly.
- Autosave requires an active profile, debounces 750 ms after the last change and flushes on normal menu-key close/application shutdown. Programmatic menu visibility changes do not all invoke the normal close-key path; explicitly flush before a host-driven teardown that cannot wait for the next tick.
- Preserve error reporting/retry semantics; deleting an active profile must not let autosave recreate it.
- Import validates and creates a profile without silently applying it. Export copies the selected file.
- `welcome-seen.txt` stores the separate `show`/`hide` preference. It is not a field in profile schema 1.
- Hold state, action callback/activation serial, current navigation/search, drafts, Lua locals and console layout/history are transient. Scripts are not auto-started by profiles. Do not claim these are restored from a profile.
- Overlay positions are normalized and clamped for display without repeatedly rewriting them on resize. Negative-x sentinel positions select automatic placement for watermark/Hotkeys/Active Features. Radar position is stored in `interface.radar_position`.
- Preserve host registration metadata and callbacks through profile decode/reset. Test legacy profiles without `appearance`, text roles or newer overlay objects.

See [DATA_FORMAT.md](DATA_FORMAT.md) and the serializer for detailed limits. When extending the schema, update defaults, encoding, decoding/validation, UI, consuming code, Lua exposure where applicable and tests together.

## 9. Fonts, languages, assets and licenses

### Runtime packaging

```text
<configured-assets>/
  fonts/                 every font, manifest and license in this source
  languages/             all 23 JSON catalogs
  scripts/               Welcome.lua, Custom UI.lua, Standalone Menu.lua
  docs/LUA_API.md         copied from source docs/LUA_API.md during packaging
```

The runtime Lua guide first looks under `assets/docs/LUA_API.md`, then beside the source assets under `docs/LUA_API.md`. The source fallback can hide a packaging omission on a developer machine. Test a package that has no access to the source checkout.

Keep all 12 shipped font files: Lucide plus the 11 Noto faces named in the inventory. The Noto manifest includes pinned URLs, sizes and SHA-256 values. Keep the Lucide license and every Noto OFL license.

`FontSet` loads optional `ui.ttf`, `heading.ttf`, `code.ttf` overrides. On Windows it can use installed Verdana, Segoe UI Semibold and Consolas; bundled Noto and ultimately ImGui fallback cover missing faces. Noto fallback merging supplies broad script coverage, and language-specific CJK faces control regional glyph preference. System font files are not redistributed by this source. Keep bundled fallbacks when supplying overrides.

The renderer must support dynamic texture creation/updates/destruction for ImGui 1.92 fonts (`ImGuiBackendFlags_RendererHasTextures`). Whole-pixel cached sizes and fallback byte-buffer lifetime are part of working live scaling. Setting the backend flag alone is insufficient: the backend must actually process the texture requests.

### Languages

Retain all catalog codes:

`en`, `de`, `es`, `ar`, `fr`, `he`, `hi`, `id`, `it`, `ja`, `ka`, `ko`, `nl`, `pl`, `pt`, `pt-BR`, `ru`, `sr`, `th`, `tr`, `vi`, `zh-CN`, `zh-TW`.

Preserve UTF-8, native display names, English/source-string fallback, reload behavior, English/German/Spanish ordering and `localization_rtl.cpp` display preparation. Arabic/Hebrew support is the bundled implementation, not a promise of a complete general-purpose shaping engine. Verify real mixed-script text in the destination. Catalog existence does not mean every newly added phrase is translated; missing phrases fall back visibly.

Keep translation keys/placeholders compatible, avoid embedded nulls/ImGui `##` IDs in translated labels, and validate UI IDs separately from visible translations. Do not bake language-dependent labels into permanent feature/config IDs.

### Maintenance tools and notices

- `scripts/update_languages.py` updates catalogs offline by default. `--translate` uses a translation service for public UI phrases; `--seed-projects` reads optional sibling projects in the original monorepo. Those sibling projects are **not runtime dependencies**; do not require them in a port.
- `scripts/language_phrases.py` is retained translation tooling/data. Keep it even though it is not linked into the executable.
- `scripts/download_fonts.py` checks/downloads the pinned Noto files and licenses. Normal builds use vendored assets and do not require downloading fonts.
- Retain ImGui, text-editor, JSON and Lua copyright/license text plus `THIRD_PARTY.md`. Keep the local text-editor modifications and Lua lexer rather than replacing them with an unmodified dependency of the same name.

## 10. Port the complete Lua system

The complete callable reference is [LUA_API.md](LUA_API.md). Keep that file, its packaged runtime copy, the editor/browser, interpreter, UI bindings and example scripts as one system.

### API families that must remain available

| Family | Functions / globals |
| --- | --- |
| Compatibility/logging | `base.get`, `base.set`, `base.log`, `print`, `UI_API_VERSION` (`"1.0"`). |
| Features | `features.add`, `get`, `set`, `active`, `trigger`, `list`, `bind`, `color`. |
| UI registration/control | `ui.tab`, `subtab`, `overlay`, `window`, `window_visible`, `override`, `theme`, `reset_theme`, `feature`, `feature_visible`, `menu_visible`. |
| Layout | `ui.group`, `columns`, `next_column`. |
| ImGui controls | `imgui.text`, `text_colored`, `button`, `checkbox`, `slider_float`, `slider_int`, `input_text`, `combo`, `color_edit`, `same_line`, `separator`, `spacing`, `tooltip`, `progress`. |
| ImGui scopes/queries | `imgui.child`, `window`, `disabled`, `with_style`, `available`, `cursor`, `set_cursor`, `is_item_hovered`. |
| Drawing | `render.text`, `line`, `rect`, `circle`. |
| Events/host information | `events.on` for `update` and `shutdown`; `engine.time`, `delta_time`, `fps`, `viewport`. |
| C++ runtime controls | `run`, `running`, `stop`, `stopAll`, `beginFrame`, `dispatch`; `registerHostApi`, `featureActive`; UI-owned registration/removal hooks; static binding helpers `call`, `name`, `loading`, `features`. |
| C++ UI integration | `Application::navigateScript`, `setApiDocsVisible`, menu/console visibility controls and service accessors. |

This is a curated ImGui binding. Independent Lua menus are ImGui windows inside the host viewport, including while the main menu is hidden; they are not separate OS windows/processes. Preserve `attach="left"/"right"/"none"`, menu-only behavior, reopening and viewport clamping. The API reader additionally reserves side space when room permits.

### Ownership, errors and startup

- Named scripts persist across frames. Register features/pages/callbacks at loading time. UI and feature IDs include the script namespace.
- Reloading the same name stops the old instance before loading its replacement. A failed replacement stays stopped; do not silently keep duplicate registrations.
- Stop/reload/startup-error cleanup removes owned tabs, sub-tabs, overlays, windows, overrides, themes, visibility changes and feature reset defaults before closing the state.
- Values written to existing host features intentionally survive script unload. Lua locals/drafts do not become profile settings automatically.
- Preserve protected callbacks, execution budgets, disabled-after-error behavior, scoped ImGui cleanup and C++ exception build mode. An invalid script must report an error rather than crash or corrupt the next frame.
- Limits currently include 16 scripts, 16 MB Lua allocation/state, 1 MB source, 128 features/script, 128 total UI registrations, 32 callbacks/event/script, 512 drawing calls/callback, a 200 ms load deadline and an 8 ms shared callback budget/script/frame.
- Standard libraries are restricted to base/table/string/math/UTF-8. Preserve the current default restrictions; OS/files/package/debug/coroutines are not enabled by default. Native host extensions own their validation and cancellation; the instruction hook cannot interrupt a blocking native call.
- `Application::draw()` dispatches update once per frame before the current hotkey update. Update sees the previous processed hotkey state; drawing sees the current state. A core-only runtime host must call `beginFrame()` and `dispatch("update")` itself.
- `Application::initialize()` loads the startup profile before Lua scripts are started. For script-owned profile values: initialize, run the intended scripts, then explicitly reload the selected profile. Check results and avoid autosaving an incomplete registry over a profile before the required scripts are registered. Automatic script startup is a future host policy, not an existing base feature.

### Add game APIs without replacing UI APIs

Set `app.scripts().registerHostApi` before running scripts. Keep `registerUiApi` and `removeUiApi` owned by the existing UI integration. Add namespaced, validated game/project functions such as snapshots, typed settings and project actions; retain every portable binding.

The host callback, captured game objects and Lua state must remain valid until script cleanup finishes. Schedule cross-thread game work through the host's own thread contract. Register host features before startup config loading; use effective feature state when consuming them.

Run both bundled samples as acceptance checks:

- `Custom UI.lua`: My Tools tab, General sub-tab, Settings extension, registered feature/action, F8, overlay and theme controls.
- `Standalone Menu.lua`: independent controls/window, F9 visibility, feature state and main-menu visibility integration.
- Keep `Welcome.lua` for compatibility and a minimal script example.

## 11. Renderer-specific requirements

Use the headers in the copied tree as the version-specific contract. Do not substitute initialization code from another ImGui version.

| Renderer | Preserve/adapt in the destination |
| --- | --- |
| DX11 | Valid device/context/current render target; Win32 or another platform backend; backend `NewFrame`/render sequence; resize/recreate path. Bind the current target before rendering ImGui. |
| DX12 | `ImGui_ImplDX12_InitInfo`, device/queue/formats/frames-in-flight, shader-visible SRV heap, descriptor allocation/free callbacks for dynamic fonts. The host owns command allocators/lists, barriers, fences and present. One fixed font descriptor is not sufficient. |
| OpenGL3 | A current compatible GL context/framebuffer and GLSL version; backend initialization, per-frame update and draw; host context/swap lifecycle. Keep its internal loader separate from the host's general-purpose loader. |
| Vulkan | SDK/build option, instance/devices/queue family/queue, image counts and descriptor allocation. This header uses `PipelineInfoMain.RenderPass`/`MSAASamples`; set compatible dynamic-rendering info if used. The host owns command buffers, acquire/present, barriers/fences and swapchain updates. |

Follow the detailed renderer notes in [PORTING.md](PORTING.md) and each bundled backend header. Retaining alternative backend source does not claim it has been tested against a particular game's renderer.

Pass actual viewport dimensions consistently into projection, `prepareFrame`, ImGui and overlays. If the host uses logical coordinates with framebuffer scaling, keep UI/entity coordinates in the same space and apply framebuffer scaling only once. Handle minimization/zero size, resize, DPI changes, fullscreen and device/context loss without stale resources or input.

Existing validation establishes the standalone DX11 preview path; DX12/OpenGL backend builds are available, while each destination needs its own runtime validation. Vulkan requires its SDK and its own host validation. Do not mark a backend accepted based only on compilation or another renderer's tests.

## 12. Verification and acceptance

### Baseline build and automated checks

Run from the copied Base/UI root, in a suitable Windows developer terminal with CMake/CTest available:

```bat
cmake --preset windows
cmake --build --preset preview
ctest --preset tests
cmake --build build/windows --config Debug
ctest --test-dir build/windows -C Debug --output-on-failure
```

For a different generator/platform use equivalent configure/build/test commands and disable the Windows preview when needed. Keep assertions/ImGui diagnostics active for the Debug pass.

| CTest name | Required evidence |
| --- | --- |
| `core_systems` | Config round trips/rollback/autosave/defaults, files, hotkeys, Lua errors/budgets, localization and projection. |
| `ui_and_esp` | Every page at small through 8K sizes, actual controls/IDs/popups, overlays and live scale dragging, including with the API guide attached. |
| `esp_appearance` | Actual geometry for gradients, outlines, fills, placements, health ratios, snaplines and invalid scene data. |
| `lua_ui_api` | Persistent state, host hook, interactive controls, custom pages, independent windows, overlays, theme/override cleanup, callback recovery, deadlines, samples and attached guide. |

The UI tests use a simulated texture uploader. They do not replace native renderer/font/input validation.

```bat
build\windows\Release\simple_base_preview.exe --smoke --warp --data build\port-smoke-data
build\windows\Release\simple_base_preview.exe --no-welcome --page api --frames 30 --capture build\port-api.png --data build\port-capture-data
```

The smoke run should exit successfully, report 150 frames and `exit=0` in its data directory's `smoke-result.txt`, and complete resize/fullscreen/minimize/device recreation. Capture success is only an artifact check; inspect the image for clipping, missing fonts and unwanted decoration.

For Lua/backend/lifetime changes, also repeat a memory-sanitized run when supported. Optimized Release testing is essential: an earlier Lua unwinding problem was specific to optimization assumptions. Record the actual compiler/backend/configuration and results rather than assuming one passing configuration covers all others.

### Destination acceptance checklist

- [ ] Original source inventory copied; baseline file hashes verified and intentional changes recorded.
- [ ] All four suites pass in the copied source; Debug and Release results recorded where supported.
- [ ] Actual destination renderer initializes, displays, resizes, minimizes/restores and recovers correctly.
- [ ] Every UI behavior row in section 7 is exercised; no missing tab, popup, overlay, setting or shortcut.
- [ ] Real entity/camera data validates world units, axes, depth/matrix convention, bounds, bones, health, teammate state and telemetry.
- [ ] Toggle/action/Hold/HoldOff work with focus loss, keyboard entry, mouse capture and the menu hidden.
- [ ] Profiles round-trip every field family; default startup, reset, import/export, rename/delete, failed-write handling and autosave are verified in the destination data root.
- [ ] Both Lua UI samples and the compatibility sample run; error/timeout/reload/stop cleanup works; custom game APIs coexist with the portable API.
- [ ] Fonts/icons render for all language families; English/German ordering and RTL display preparation remain intact; text/overlay/UI scaling is live and smooth.
- [ ] API docs, scripts, language catalogs, fonts and all required notices exist in the final package independently of the source checkout.
- [ ] Main UI, hidden-menu rendering, independent Lua windows and floating console survive the destination lifecycle.
- [ ] Shutdown flushes state and stops scripts before host/ImGui teardown; no use-after-free, duplicate-registration or leaked callback behavior.
- [ ] Preview/demo/examples/tests/tools/docs remain available in the source repository as the reference for future ports.
- [ ] Any unavailable capability is explicitly reported with its missing adapter/dependency and remains unfinished; it is not silently counted as complete.

Store a parity record with columns **system/behavior, original file, destination file/adapter, test evidence, status**. Use statuses such as Pending, Ported, Adapted with evidence, or Blocked. Required functionality cannot be marked complete merely because it was removed from the destination menu.

## 13. Troubleshooting

| Symptom | Check first |
| --- | --- |
| Menu works, overlays/hotkeys/Lua stop when closed | Host skipped the complete `Application::draw()` call while hidden. |
| API reader cannot load the guide | Missing packaged `assets/docs/LUA_API.md`; attach/build the product staging hook and check its output directory. |
| Missing icons, boxes instead of CJK/RTL text | Asset path, Lucide/Noto files, font merging/selection, texture uploads and application-owned font-byte lifetime. |
| Scale stutters or only changes on release | Old slider/widgets copied, `prepareFrame` order, font atlas being rebuilt, stale backend texture support or destination reapplying its own style/scale. |
| Cyan resize highlights return / scrollbar starts beside tabs | Old shell/component code replaced the current UI implementation. |
| Config/Scripts become four columns | A global column rule replaced their explicit browser/action layout. |
| Profiles lose script settings | Scripts registered after the only profile load, changed script namespace, or autosave wrote an incomplete registry. |
| Renamed Hotkeys overlay loses settings | Internal `overlay.binds` / `overlays.binds` keys were renamed. |
| Script error crashes optimized host | Lua compiled as C, missing forced header, `/EHsc` C-call assumptions, mismatched Lua library/ABI or old error-recovery binding code. |
| Script reload duplicates tabs/features | Same-name runtime replacement and ownership cleanup were omitted. |
| Script theme does not apply / never resets | Theme application after baseline style or removal on unload is missing. Custom non-ImGui surfaces have their own colors. |
| Hold remains enabled after alt-tab | Incorrect focus/input delivery or game reads `.enabled` instead of effective hotkey state. |
| ESP behind/offscreen, inverted radar or wrong distances | Matrix convention/depth range, bounds transformation, axis mapping, viewport coordinate space and unit conversions. |
| Controls display but never affect the game | No host behavior consuming the feature registry / Lua extension callback. |
| UI corrupts after another menu draws | Multiple mismatched ImGui copies, wrong current context, unbalanced scopes, incompatible styles/fonts or draw order. |
| Crash after device loss or DPI/size change | Stale target/descriptors/texture state, incomplete platform/renderer reinitialization or invalid frame dimensions. |
| Latest assets absent despite a successful incremental build | The product staging hook is missing, a conflict stopped sync, or an old package is still installed. See AUTO_SYNC. |

## 14. Handoff template for a developer or coding agent

Copy this into the destination task with its actual paths and host details:

> Port the complete Base/UI from `<source-root>` into `<destination-root>`, following `docs/PORTING_EVERYTHING.md`. Preserve every existing subsystem, UI behavior, setting, overlay, profile field, hotkey mode, language/font asset, Lua API, example and regression test. Start from the current working tree, including new/uncommitted files, and use the canonical source dependency and managed asset/document staging from AUTO_SYNC.md. Use the existing implementation as the baseline. Keep the preview/demo as a runnable reference. Integrate the destination's renderer, platform/input, scene snapshot, game behavior, product data paths and game-specific Lua functions through explicit adapters. Keep stable IDs and config compatibility. Record each adaptation and its evidence, and report missing dependencies or unavailable functionality as unfinished. Deliver the working port, packaging rules, test results and a completed parity checklist; do not call a visual-only recreation a complete port.

Fill out before integration:

| Item | Destination decision |
| --- | --- |
| Source snapshot path/date/manifest | |
| Destination source path / host target | |
| OS, architecture, compiler/configuration | |
| Renderer + platform backend / existing ImGui version | |
| ImGui context owner and frame entry point | |
| Asset package directory | |
| Writable product data directory / migration plan | |
| Scene provider, world units/axes/depth convention | |
| Game action thread/dispatcher | |
| Host feature registration and profile startup order | |
| Game-specific Lua namespace and lifetime owner | |
| Link/clipboard/branding policy | |
| Native validation environment and acceptance owner | |

When the base gains new files, settings or APIs, update this guide's subsystem/behavior tables and regenerate the inventory. The inventory scan must always use the current source rather than treating this dated inventory as a permanent upper bound.

## 15. Complete file inventory

The following inventory was generated from the current Base/UI tree, including hidden and untracked files, with the generated-file exclusions in section 2. These are source-transfer items, not a requirement to link every backend or ship developer tests in the game executable. `docs/LUA_API.md` also needs the runtime package copy described above.

Run `python scripts/check_port_inventory.py` from `UI/` to check this list against the current working tree. After intentional source additions/removals, use `--write` to refresh it and review the diff.

**Audited transfer inventory: 290 files.**

<!-- PORT-INVENTORY-BEGIN -->

### Root files (12)

- [ ] `.clang-format`
- [ ] `.gitignore`
- [ ] `CMakeLists.txt`
- [ ] `CMakePresets.json`
- [ ] `README.md`
- [ ] `THIRD_PARTY.md`
- [ ] `UPDATING.md`
- [ ] `api-revision.txt`
- [ ] `build-preview.cmd`
- [ ] `languages.json`
- [ ] `run-preview.cmd`
- [ ] `test-preview.cmd`

### assets (58)

- [ ] `assets/fonts/LUCIDE-LICENSE.txt`
- [ ] `assets/fonts/NotoSans.ttf`
- [ ] `assets/fonts/NotoSansArabic.ttf`
- [ ] `assets/fonts/NotoSansDevanagari.ttf`
- [ ] `assets/fonts/NotoSansGeorgian.ttf`
- [ ] `assets/fonts/NotoSansHebrew.ttf`
- [ ] `assets/fonts/NotoSansJP.ttf`
- [ ] `assets/fonts/NotoSansKR.ttf`
- [ ] `assets/fonts/NotoSansMono.ttf`
- [ ] `assets/fonts/NotoSansSC.ttf`
- [ ] `assets/fonts/NotoSansTC.ttf`
- [ ] `assets/fonts/NotoSansThai.ttf`
- [ ] `assets/fonts/licenses/NotoSans-OFL.txt`
- [ ] `assets/fonts/licenses/NotoSansArabic-OFL.txt`
- [ ] `assets/fonts/licenses/NotoSansDevanagari-OFL.txt`
- [ ] `assets/fonts/licenses/NotoSansGeorgian-OFL.txt`
- [ ] `assets/fonts/licenses/NotoSansHebrew-OFL.txt`
- [ ] `assets/fonts/licenses/NotoSansJP-OFL.txt`
- [ ] `assets/fonts/licenses/NotoSansKR-OFL.txt`
- [ ] `assets/fonts/licenses/NotoSansMono-OFL.txt`
- [ ] `assets/fonts/licenses/NotoSansSC-OFL.txt`
- [ ] `assets/fonts/licenses/NotoSansTC-OFL.txt`
- [ ] `assets/fonts/licenses/NotoSansThai-OFL.txt`
- [ ] `assets/fonts/lucide.ttf`
- [ ] `assets/fonts/manifest.json`
- [ ] `assets/languages/ar.json`
- [ ] `assets/languages/de.json`
- [ ] `assets/languages/en.json`
- [ ] `assets/languages/es.json`
- [ ] `assets/languages/fr.json`
- [ ] `assets/languages/he.json`
- [ ] `assets/languages/hi.json`
- [ ] `assets/languages/id.json`
- [ ] `assets/languages/it.json`
- [ ] `assets/languages/ja.json`
- [ ] `assets/languages/ka.json`
- [ ] `assets/languages/ko.json`
- [ ] `assets/languages/nl.json`
- [ ] `assets/languages/pl.json`
- [ ] `assets/languages/pt-BR.json`
- [ ] `assets/languages/pt.json`
- [ ] `assets/languages/ru.json`
- [ ] `assets/languages/sr.json`
- [ ] `assets/languages/th.json`
- [ ] `assets/languages/tr.json`
- [ ] `assets/languages/vi.json`
- [ ] `assets/languages/zh-CN.json`
- [ ] `assets/languages/zh-TW.json`
- [ ] `assets/licenses/Dear-ImGui-LICENSE.txt`
- [ ] `assets/licenses/ImGuiColorTextEdit-LICENSE.txt`
- [ ] `assets/licenses/Lua-LICENSE.txt`
- [ ] `assets/licenses/nlohmann-json-LICENSE.txt`
- [ ] `assets/script_defaults_v0/Custom UI.lua`
- [ ] `assets/script_defaults_v0/Standalone Menu.lua`
- [ ] `assets/script_defaults_v0/Welcome.lua`
- [ ] `assets/scripts/Custom UI.lua`
- [ ] `assets/scripts/Standalone Menu.lua`
- [ ] `assets/scripts/Welcome.lua`

### cmake (1)

- [ ] `cmake/SimpleBaseConsumer.cmake`

### docs (19)

- [ ] `docs/ADDING_FEATURES.md`
- [ ] `docs/CONSOLE.md`
- [ ] `docs/CONSUMERS.md`
- [ ] `docs/DATA_FORMAT.md`
- [ ] `docs/EMBEDDED_RESOURCES.md`
- [ ] `docs/ENTITY_COLORS.md`
- [ ] `docs/GAME_SIDEBAR.md`
- [ ] `docs/HEALTH_ESP.md`
- [ ] `docs/LANGUAGES.md`
- [ ] `docs/LINUX_COMPATIBILITY.md`
- [ ] `docs/LUA_API.md`
- [ ] `docs/PORTING.md`
- [ ] `docs/PORTING_EVERYTHING.md`
- [ ] `docs/TEAM_ESP.md`
- [ ] `docs/TESTING.md`
- [ ] `docs/UI_COMPONENTS.md`
- [ ] `docs/consumer-inventory.json`
- [ ] `docs/sync-validation.json`
- [ ] `docs/vendor-reconciliation.json`

### examples (2)

- [ ] `examples/callback_entity_source.h`
- [ ] `examples/embed_dx11.cpp`

### include (22)

- [ ] `include/simple_base/core/color.h`
- [ ] `include/simple_base/core/configs.h`
- [ ] `include/simple_base/core/entity_colors.h`
- [ ] `include/simple_base/core/environment.h`
- [ ] `include/simple_base/core/esp_settings.h`
- [ ] `include/simple_base/core/feature_registry.h`
- [ ] `include/simple_base/core/files.h`
- [ ] `include/simple_base/core/hotkeys.h`
- [ ] `include/simple_base/core/localization.h`
- [ ] `include/simple_base/core/log_buffer.h`
- [ ] `include/simple_base/core/overlay_settings.h`
- [ ] `include/simple_base/core/resources.h`
- [ ] `include/simple_base/core/scripts.h`
- [ ] `include/simple_base/esp/entity_source.h`
- [ ] `include/simple_base/esp/esp_renderer.h`
- [ ] `include/simple_base/platform/dx11_host.h`
- [ ] `include/simple_base/ui/application.h`
- [ ] `include/simple_base/ui/console_window.h`
- [ ] `include/simple_base/ui/font_set.h`
- [ ] `include/simple_base/ui/sidebar.h`
- [ ] `include/simple_base/ui/theme.h`
- [ ] `include/simple_base/ui/widgets.h`

### linux (6)

- [ ] `linux/README.md`
- [ ] `linux/build.ps1`
- [ ] `linux/launch.py`
- [ ] `linux/launch.sh`
- [ ] `linux/package.py`
- [ ] `linux/runtime_launcher.py`

### preview (5)

- [ ] `preview/demo_scene.cpp`
- [ ] `preview/demo_scene.h`
- [ ] `preview/main.cpp`
- [ ] `preview/sidebar_demo.cpp`
- [ ] `preview/sidebar_demo.h`

### scripts (10)

- [ ] `scripts/audit_consumers.py`
- [ ] `scripts/audit_language_coverage.py`
- [ ] `scripts/check_port_inventory.py`
- [ ] `scripts/download_fonts.py`
- [ ] `scripts/embed_resources.py`
- [ ] `scripts/language_catalogs.py`
- [ ] `scripts/language_phrases.py`
- [ ] `scripts/seed_files.py`
- [ ] `scripts/sync_assets.py`
- [ ] `scripts/update_languages.py`

### src (43)

- [ ] `src/core/configs.cpp`
- [ ] `src/core/entity_colors.cpp`
- [ ] `src/core/environment.cpp`
- [ ] `src/core/feature_registry.cpp`
- [ ] `src/core/files.cpp`
- [ ] `src/core/hotkeys.cpp`
- [ ] `src/core/localization.cpp`
- [ ] `src/core/localization_rtl.cpp`
- [ ] `src/core/log_buffer.cpp`
- [ ] `src/core/lua_cpp.h`
- [ ] `src/core/resources.cpp`
- [ ] `src/core/scripts.cpp`
- [ ] `src/esp/esp_renderer.cpp`
- [ ] `src/esp/projection.cpp`
- [ ] `src/platform/dx11_host.cpp`
- [ ] `src/ui/api_docs_model.cpp`
- [ ] `src/ui/api_docs_model.h`
- [ ] `src/ui/application.cpp`
- [ ] `src/ui/components/active_features.h`
- [ ] `src/ui/components/font_set.cpp`
- [ ] `src/ui/components/lumia.cpp`
- [ ] `src/ui/components/overlay_panels.h`
- [ ] `src/ui/components/radar_panel.h`
- [ ] `src/ui/components/welcome.h`
- [ ] `src/ui/console_window.cpp`
- [ ] `src/ui/description_box.cpp`
- [ ] `src/ui/entity_colors.cpp`
- [ ] `src/ui/esp_settings.cpp`
- [ ] `src/ui/file_browser.cpp`
- [ ] `src/ui/interface_page.cpp`
- [ ] `src/ui/internal.h`
- [ ] `src/ui/keybind.cpp`
- [ ] `src/ui/lua_docs.cpp`
- [ ] `src/ui/lua_page.cpp`
- [ ] `src/ui/lua_ui.cpp`
- [ ] `src/ui/lua_ui.h`
- [ ] `src/ui/overlay_settings.cpp`
- [ ] `src/ui/overlays.cpp`
- [ ] `src/ui/settings_page.cpp`
- [ ] `src/ui/sidebar.cpp`
- [ ] `src/ui/theme.cpp`
- [ ] `src/ui/visuals_page.cpp`
- [ ] `src/ui/widgets.cpp`

### tests (20)

- [ ] `tests/activation_tests.cpp`
- [ ] `tests/api_docs_tests.cpp`
- [ ] `tests/capture_sidebar.py`
- [ ] `tests/compatibility_tests.cpp`
- [ ] `tests/core_tests.cpp`
- [ ] `tests/embedded_resources_tests.cpp`
- [ ] `tests/entity_color_tests.cpp`
- [ ] `tests/esp_tests.cpp`
- [ ] `tests/health_esp_tests.cpp`
- [ ] `tests/keybind_tests.cpp`
- [ ] `tests/lua_api_tests.cpp`
- [ ] `tests/radar_layout_tests.cpp`
- [ ] `tests/selectable_tests.cpp`
- [ ] `tests/sidebar_tests.cpp`
- [ ] `tests/team_esp_tests.cpp`
- [ ] `tests/test_build_sync.py`
- [ ] `tests/test_compatibility_package.py`
- [ ] `tests/test_preview_package.py`
- [ ] `tests/test_sync_assets.py`
- [ ] `tests/ui_tests.cpp`

### third_party (92)

- [ ] `third_party/imgui/LICENSE.txt`
- [ ] `third_party/imgui/backends/imgui_impl_dx11.cpp`
- [ ] `third_party/imgui/backends/imgui_impl_dx11.h`
- [ ] `third_party/imgui/backends/imgui_impl_dx12.cpp`
- [ ] `third_party/imgui/backends/imgui_impl_dx12.h`
- [ ] `third_party/imgui/backends/imgui_impl_dx9.cpp`
- [ ] `third_party/imgui/backends/imgui_impl_dx9.h`
- [ ] `third_party/imgui/backends/imgui_impl_opengl3.cpp`
- [ ] `third_party/imgui/backends/imgui_impl_opengl3.h`
- [ ] `third_party/imgui/backends/imgui_impl_opengl3_loader.h`
- [ ] `third_party/imgui/backends/imgui_impl_vulkan.cpp`
- [ ] `third_party/imgui/backends/imgui_impl_vulkan.h`
- [ ] `third_party/imgui/backends/imgui_impl_win32.cpp`
- [ ] `third_party/imgui/backends/imgui_impl_win32.h`
- [ ] `third_party/imgui/imconfig.h`
- [ ] `third_party/imgui/imgui.cpp`
- [ ] `third_party/imgui/imgui.h`
- [ ] `third_party/imgui/imgui_draw.cpp`
- [ ] `third_party/imgui/imgui_internal.h`
- [ ] `third_party/imgui/imgui_tables.cpp`
- [ ] `third_party/imgui/imgui_widgets.cpp`
- [ ] `third_party/imgui/imstb_rectpack.h`
- [ ] `third_party/imgui/imstb_textedit.h`
- [ ] `third_party/imgui/imstb_truetype.h`
- [ ] `third_party/imgui/misc/freetype/imgui_freetype.cpp`
- [ ] `third_party/imgui/misc/freetype/imgui_freetype.h`
- [ ] `third_party/json/json.hpp`
- [ ] `third_party/lua/lapi.c`
- [ ] `third_party/lua/lapi.h`
- [ ] `third_party/lua/lauxlib.c`
- [ ] `third_party/lua/lauxlib.h`
- [ ] `third_party/lua/lbaselib.c`
- [ ] `third_party/lua/lcode.c`
- [ ] `third_party/lua/lcode.h`
- [ ] `third_party/lua/lcorolib.c`
- [ ] `third_party/lua/lctype.c`
- [ ] `third_party/lua/lctype.h`
- [ ] `third_party/lua/ldblib.c`
- [ ] `third_party/lua/ldebug.c`
- [ ] `third_party/lua/ldebug.h`
- [ ] `third_party/lua/ldo.c`
- [ ] `third_party/lua/ldo.h`
- [ ] `third_party/lua/ldump.c`
- [ ] `third_party/lua/lfunc.c`
- [ ] `third_party/lua/lfunc.h`
- [ ] `third_party/lua/lgc.c`
- [ ] `third_party/lua/lgc.h`
- [ ] `third_party/lua/linit.c`
- [ ] `third_party/lua/liolib.c`
- [ ] `third_party/lua/ljumptab.h`
- [ ] `third_party/lua/llex.c`
- [ ] `third_party/lua/llex.h`
- [ ] `third_party/lua/llimits.h`
- [ ] `third_party/lua/lmathlib.c`
- [ ] `third_party/lua/lmem.c`
- [ ] `third_party/lua/lmem.h`
- [ ] `third_party/lua/loadlib.c`
- [ ] `third_party/lua/lobject.c`
- [ ] `third_party/lua/lobject.h`
- [ ] `third_party/lua/lopcodes.c`
- [ ] `third_party/lua/lopcodes.h`
- [ ] `third_party/lua/lopnames.h`
- [ ] `third_party/lua/loslib.c`
- [ ] `third_party/lua/lparser.c`
- [ ] `third_party/lua/lparser.h`
- [ ] `third_party/lua/lprefix.h`
- [ ] `third_party/lua/lstate.c`
- [ ] `third_party/lua/lstate.h`
- [ ] `third_party/lua/lstring.c`
- [ ] `third_party/lua/lstring.h`
- [ ] `third_party/lua/lstrlib.c`
- [ ] `third_party/lua/ltable.c`
- [ ] `third_party/lua/ltable.h`
- [ ] `third_party/lua/ltablib.c`
- [ ] `third_party/lua/ltm.c`
- [ ] `third_party/lua/ltm.h`
- [ ] `third_party/lua/lua.h`
- [ ] `third_party/lua/luaconf.h`
- [ ] `third_party/lua/lualib.h`
- [ ] `third_party/lua/lundump.c`
- [ ] `third_party/lua/lundump.h`
- [ ] `third_party/lua/lutf8lib.c`
- [ ] `third_party/lua/lvm.c`
- [ ] `third_party/lua/lvm.h`
- [ ] `third_party/lua/lzio.c`
- [ ] `third_party/lua/lzio.h`
- [ ] `third_party/lua/onelua.c`
- [ ] `third_party/text_editor/LICENSE`
- [ ] `third_party/text_editor/LuaSyntax.h`
- [ ] `third_party/text_editor/README.md`
- [ ] `third_party/text_editor/TextEditor.cpp`
- [ ] `third_party/text_editor/TextEditor.h`

<!-- PORT-INVENTORY-END -->
