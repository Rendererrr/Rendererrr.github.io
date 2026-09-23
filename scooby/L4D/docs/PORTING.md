# Porting the base

For the complete no-omissions workflow, source inventory, UI parity checklist and packaging/acceptance requirements, use [PORTING_EVERYTHING.md](PORTING_EVERYTHING.md). This file retains the focused renderer integration reference.

## 1. Add the library

Use the canonical checkout through [AUTO_SYNC.md](../../AUTO_SYNC.md); consumer builds compile shared sources directly. Avoid linking a second copy of Dear ImGui: this UI and its renderer backends must use the same vendored version and compile definitions.

```cmake
set(SIMPLE_BASE_PREVIEW OFF CACHE BOOL "" FORCE)
set(SIMPLE_BASE_TESTS OFF CACHE BOOL "" FORCE)
set(SIMPLE_BASE_DX12 OFF CACHE BOOL "" FORCE)   # enable only what your host needs
set(SIMPLE_BASE_OPENGL OFF CACHE BOOL "" FORCE)
include("${SIMPLE_BASE_UI_ROOT}/cmake/SimpleBaseConsumer.cmake")
simple_base_add_ui(API_REVISION 1)
target_link_libraries(your_app PRIVATE simple_base_ui simple_base_dx11 simple_base_win32)
simple_base_stage_assets(TARGET your_app)
```

Set `SIMPLE_BASE_UI_ROOT` to a repository-relative canonical UI path (or an explicit checkout override). The staging hook refreshes owned assets and shared Markdown on every product build, including asset-only edits. Give every product a separate writable data folder so profiles and scripts do not collide.

## 2. Initialize and draw

The complete DX11 call sequence is in `examples/embed_dx11.cpp`; it is compiled as part of the Windows build. The host already has a window, device, context and render target.

```cpp
ImGui::CreateContext();
ImGui_ImplWin32_Init(hwnd);
ImGui_ImplDX11_Init(device, context);

simple_base::Application ui({assetDirectory, dataDirectory, "MY PROJECT", "DX11", true});
ui.initialize();

// Once per frame, before NewFrame:
ui.prepareFrame({float(clientWidth), float(clientHeight)}, monitorDpiScale);
ImGui_ImplDX11_NewFrame();
ImGui_ImplWin32_NewFrame();
ImGui::NewFrame();

const auto scene = entitySource.sample(seconds, float(clientWidth) / clientHeight);
ui.draw(scene, applicationHasFocus);
ImGui::Render();
// Host binds its current render target here.
ImGui_ImplDX11_RenderDrawData(ImGui::GetDrawData());
// Host presents.
```

Forward Win32 messages to `ImGui_ImplWin32_WndProcHandler`. Other platforms may use an ImGui SDL/GLFW/custom platform backend and feed the same `Application`. Input names come from ImGui rather than Windows virtual-key numbers, so bindings remain portable. The preview's file implementation uses Win32 atomic replacement on Windows and standard filesystem rename on other platforms.

On a full DX11 device recreation, the bundled renderer shutdown also destroys platform viewport data. Reinitialize both the Win32 and DX11 backends, as shown in `preview/main.cpp`; recreating only the DX11 backend leaves stale platform state. A normal swapchain resize only recreates the host render target.

At shutdown: `ui.shutdown()`, renderer backend shutdown, platform backend shutdown, then `ImGui::DestroyContext()`.

## 3. Connect entity data

Implement `simple_base::EntitySource::sample()` or use `examples/callback_entity_source.h`. Return a **snapshot** valid for the duration of the draw call; do not keep pointers into a mutable engine entity list.

- `Camera::viewProjection` is **row-major**; projection multiplies it by a column vector `[x,y,z,1]`.
- Transpose a column-major engine matrix before assigning it.
- `Camera::zeroToOneDepth` is true for a `[0,1]` clip-depth convention and false for `[-1,1]`. Set it from your projection convention, not simply the API name.
- Supply absolute **world-space** AABB corners. Transform local bounds first, and compute an enclosing world AABB if your source is rotated.
- `position`, camera position, AABB and bones use the same units and axes.
- `bones` contains world positions; `bonePairs` contains index pairs. Invalid pairs are skipped.
- Mark dead/despawned entities as `alive=false`, or omit them.
- Health defaults to unknown (-1). Supply authoritative current health >= 0 and an independently verified maxHealth > 0 for bars. HP text works with current health alone. The legacy (0, 0) pair is unknown; use (0, -1) for known zero without a maximum. Clear unavailable telemetry each snapshot; see [HEALTH_ESP.md](HEALTH_ESP.md).
- ESP rejects non-finite values, geometry behind the near plane and fully offscreen bounds. Bounds crossing the near plane are skipped in this basic template rather than stretched across the screen.

Overlay options are plain data in `Preferences::watermark`, `binds` and `radar` (see `core/overlay_settings.h`). They are included in configs and auto-save. The feature registry owns the enable state, bindings and watermark/binds accent colors. The borderless radar has independent background, team, enemy and ring colors. The background color and alpha apply to its square or circular plot.

Provide `Scene::server` and `Scene::pingMs` when the host has real telemetry; the watermark omits them when unavailable. Set `Entity::teammate` for radar colors and `Camera::yawDegrees` for radar rotation. Heading is measured in the radar X/-Z plane: -90 faces world +Z, 0 faces +X. Positions are normalized to the viewport and survive resolution changes without accumulating clamp drift.

The preview radar range slider uses 1–250 world units, suitable for its metre-sized scene. Profiles/API accept 1–50,000; adapt the slider bounds for a host using centimetres or Source units.

The radar assumes X is horizontal and Z is forward; adapt `src/ui/overlays.cpp` for a Z-up host. Distance labels and the distance limit use your world units. Adjust their ranges if you use centimetres rather than metres.

## 4. DX12

Link `simple_base_dx12` and your platform backend. Initialize `ImGui_ImplDX12_InitInfo` from the included header:

- Device, command queue, frames in flight, render-target format and optional depth format.
- A shader-visible SRV descriptor heap.
- `SrvDescriptorAllocFn` / `SrvDescriptorFreeFn` callbacks with enough descriptors for dynamic font textures. A single hard-coded font descriptor is insufficient for this ImGui version.

Call `ImGui_ImplDX12_NewFrame()` before `ImGui::NewFrame()`. On your graphics command list, transition/bind the current render target and bind the supplied SRV heap, then call `ImGui_ImplDX12_RenderDrawData(drawData, commandList)`. The host owns barriers, fences, allocator reuse and presentation. Wait for the GPU before destroying resources or resizing its swapchain.

## 5. OpenGL

Link `simple_base_opengl` and a platform backend. Make your GL context current, then call `ImGui_ImplOpenGL3_Init()` with the GLSL version matching your context (for example `"#version 330 core"`). Call `ImGui_ImplOpenGL3_NewFrame()` before `ImGui::NewFrame()` and `ImGui_ImplOpenGL3_RenderDrawData(drawData)` while the correct framebuffer/context is bound. The host handles buffer swapping and context lifetime.

The bundled loader is internal to the backend. Do not use it as your application's general GL loader.

## 6. Vulkan

Install a Vulkan SDK and configure `-DSIMPLE_BASE_VULKAN=ON`. Link `simple_base_vulkan` plus your platform backend.

Use the included `ImGui_ImplVulkan_InitInfo` definition; this vendored version uses `PipelineInfoMain.RenderPass` and `PipelineInfoMain.MSAASamples` rather than the older top-level fields. Supply the instance, physical/logical devices, queue family/queue, image counts, and either a descriptor pool with free-descriptor support or `DescriptorPoolSize` to let the backend create one.

For dynamic rendering, enable the required device capabilities and fill `PipelineInfoMain.PipelineRenderingCreateInfo`; otherwise supply the render pass. Call `ImGui_ImplVulkan_NewFrame()` before `ImGui::NewFrame()` and `ImGui_ImplVulkan_RenderDrawData(drawData, commandBuffer)` inside your compatible render pass/rendering scope.

The host handles swapchain recreation, fences, image acquisition and presentation. Update minimum image count and pipeline render-pass/format compatibility as necessary. No Vulkan runtime validation was performed without a Vulkan SDK on the template's build machine.

## Resolution, DPI and fonts

Pass actual client dimensions consistently to `prepareFrame()` and to ImGui's platform/backend sizing. Do not pass stale desktop resolution after a window resize. If a host uses logical coordinates with `DisplayFramebufferScale`, keep entity projection and overlay positions in the same logical viewport and let ImGui scale the draw data once.

The UI uses ImGui 1.92's dynamic font textures and requests fonts at their final pixel size. Do not scale finished vertices or use a stretched font atlas. Backend texture updates must remain enabled. Use the bundled renderer backends, which support `ImGuiBackendFlags_RendererHasTextures`.

UI and overlay scaling use a compact 0.75 baseline: 100% now matches the former 75% dimensions. UI scale changes layout and menu fonts. Menu labels keep a 12-pixel minimum, with smaller section captions at 10 pixels; font sizes are rounded to whole pixels before rasterization. Controls and compact columns adapt to those sizes so labels remain readable at reduced scales. Overlay scale changes HUD dimensions and fonts. World-to-screen ESP stays tied to the viewport, so menu scaling cannot move projected entities.

Provide `assets/fonts/ui.ttf`, `heading.ttf` and `code.ttf` to use your own fonts. On Windows, missing files use installed Verdana for UI/ESP/overlays, Segoe UI Semibold for branding, and Consolas for code. Bundled Noto faces provide fallback and merged script coverage, with ImGui's built-in font as the final fallback. Keep all Noto fonts, their manifest and licenses when porting; custom fonts do not replace the fallback assets.

## Host responsibilities

No game hooks, injection, process handles, offsets or engine pointers are embedded in the base. Integrate the draw call into your existing renderer and implement the entity snapshot yourself. Run the systems on the UI thread; synchronize any data obtained from background engine threads before presenting a snapshot.


## Button actions and Hotkeys overlay

Register a `Feature` with `kind = FeatureKind::Action` and an `onActivate` callback, then add it to `Application::features()`. Use `feature.activate()` for host buttons so both button clicks and assigned hotkeys emit the same activation event. An action runs once per press regardless of the binding mode; it never becomes an enabled toggle. The portable radar reset button is a working example.

The Hotkeys overlay shows only labels and assigned keys, sizes itself to that content, and lights up toggle rows while active. Action rows briefly flash for 0.4 seconds and fade back to their inactive color. Activation events and callbacks are runtime state, not config data. Existing `overlay.binds` and `overlays.binds` IDs remain unchanged for profile compatibility.

Drag the borderless radar from anywhere in its plot while the menu is open. Its dark background sits behind the crosshair, optional range rings, entity dots and local direction marker. There is no surrounding card, header or perimeter outline. Change the background color and opacity under Visuals > Radar > Appearance.


## Active Features overlay

`overlay.active_features` shows compact labels for effective toggle/hold states from the feature registry. Its renderer uses only ImGui draw lists and `Preferences::activeFeatures`; it works through the same DX11/DX12/OpenGL/Vulkan integration as the other overlays. Drag any label with the menu open; the whole list moves. Empty lists draw nothing. Long labels clip safely, and oversized lists scroll with the mouse wheel while the menu is open.

Host toggle features appear automatically. Set `Feature::showInActiveList = false` for utility controls. `activeListLabel` optionally supplies a shorter translated label. Set `activeListParent` to a master feature ID to hide an entry whenever that parent is inactive (the built-in ESP entries demonstrate this). Parent gating affects this list only; the host still owns feature execution. Missing/cyclic parents hide the affected entries. This registration metadata is preserved through config loads and is not user profile data. Button actions are excluded.

`Hotkeys::activeFeatures(registry)` exposes the same filtered list for custom host menus. The Settings > Overlays group and feature gear expose text color, text size, spacing, background opacity, accent edge, alignment, width sorting, drag lock and position reset.


## ESP appearance and placement

Each ESP feature has a plain `Feature::esp` (`EspAppearance`, in `core/esp_settings.h`). Its gear popup edits this same data. Primary color, line/bar thickness, text size, full/corner box style and box-fill enable remain in the existing `Feature` fields. The renderer uses public ImGui draw-list vertices for RGBA gradients; no custom shader or renderer-specific code is required. Outlines have independent color and width. Box fills have independent RGBA colors and their own gradient toggle.

`gradientDirection` chooses vertical (top to bottom) or horizontal (left to right). Box and skeleton gradients span the entity bounds; text gradients span each label. Health gradients span the full bar and are clipped at the current health value. Top/bottom health bars fill left to right; left/right bars fill bottom to top. `position` and `offset` place names, distances and health bars around the bounds. Labels share space with the bar and stack without overlap on the same side.

`esp.snaplines` uses the same master ESP toggle, distance filtering, hotkeys, configs and Active Features integration. `snaplineOrigin` selects viewport top-center, bottom-center or center; the endpoint projects `Entity::position` (feet in the demo), falling back to the projected bounds' bottom center. Supply the foot/origin position expected by your project. `EspStats` includes health-bar and snapline counts for host validation.


The Interface Scale group combines UI, Overlays and Text settings. All scale controls, including the individual text roles, update live while dragging. Each slider keeps its original input range for the gesture. UI scaling also retains the original menu bounds as its resize anchor, so resizing and column reflow do not feed back into the slider or recenter the menu. Text and icon rasterization uses cached whole-pixel sizes. Clicking a numeric value supports direct entry; Enter commits it. Escape cancels a drag, restoring the original scale and UI bounds where applicable. Preferences and config fields are unchanged, and host/API changes still apply on the next frame.


## Lua host extensions

The persistent Lua UI API and its project-extension hook are documented in [LUA_API.md](LUA_API.md). Install game-specific functions through `app.scripts().registerHostApi` before running scripts. Link the provided CMake targets to inherit the Lua C++ exception settings, keep state access on the render thread, and call `app.shutdown()` before destroying objects captured by host callbacks. The bundled examples demonstrate custom tabs, features, overlays, themes and independent menus within the host viewport.


## Game sidebar and inline activation

Use [GAME_SIDEBAR.md](GAME_SIDEBAR.md) to map existing pages to Standard, RageLegit or Campaign, put View under Self, retain Lua under Settings, and expose shared inline bindings. Optional independent activation separates a saved master from Hold/Toggle/Always without changing legacy features or persisted enum values. Game mechanics and lifecycle restoration stay in the host.
