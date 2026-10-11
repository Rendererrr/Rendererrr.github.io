# Shared game navigation and inline activation

The canonical API revision remains **1**. These additive interfaces live in `include/simple_base/ui/sidebar.h`, `ui/application.h`, `ui/widgets.h` and `core/hotkeys.h`. Game adapters own capability and feature registration, settings storage and engine behavior. See the repository [sidebar specification](../../../docs/GAME_SIDEBAR_LAYOUT.md) and [combat settings](../../../docs/SOURCE1_COMBAT_SETTINGS.md).

## Register pages, then choose a layout

Map the opaque IDs returned by the host's existing `ui.tab` registrations. Preserve feature IDs and registration; navigation does not require a second registry.

```cpp
simple_base::GameSidebarPages pages;
pages.aimbot = aimTabId;
pages.triggerbot = triggerTabId;
pages.chams = chamsTabId; // Optional; only assign a registered host Chams page.
pages.world = worldTabId;
pages.spawner = spawnerTabId;
pages.self = selfTabId;
pages.movement = movementTabId;
pages.misc = miscTabId;
// ESP defaults to "visuals". Assign the host ESP tab ID if it has one.
app.configureSidebar(simple_base::makeGameSidebar(
    simple_base::GameSidebarPreset::Standard, pages));
```

| Preset | Combat pages |
| --- | --- |
| `Standard` | Aimbot, Triggerbot |
| `RageLegit` | Rage, Legit, then supplied Aimbot/Triggerbot and additional combat pages |
| `Campaign` | None; supplied combat routes are excluded from navigation |

Set `pages.rage` and `pages.legit` for hosts with those pages. `pages.additionalCombat` accepts `SidebarPage{id, label, target, icon}` entries. Choosing a layout does not activate or change an aim profile. Empty slots and missing or script-hidden targets produce no row or empty heading. Portal/Portal 2 hosts must also omit combat feature/tab registration; the preset does not disable or unregister gameplay features.

All presets then use Visuals (ESP, World), Misc (Spawner, Self, Movement, Misc), and Other (Settings). Section names are muted headings. Each named page is a full sidebar entry. Self and Spawner are independent pages; View is a sub-tab of Self.

`SidebarLayout` supports explicit ordered `sections`, host-selected labels/icons in `pages`, and `omittedTargets`. Aliases require unique, nonempty IDs, labels and targets. Built-in IDs (`visuals`, `lua`, `settings`) retain their meaning. Use a distinct alias such as `esp` when mapping a host route. Routes are deduplicated, so the same target is not drawn twice. Do not list built-in tools in `omittedTargets`.

Presets put Lua under Settings. Scripts, Editor, Console and API docs retain their routes and theme. When a host supplies its own ESP page, generic Visuals and its Lua extensions also move under Settings. Unlisted third-party script tabs remain reachable under Other. Search, favorites, configs, Hotkeys and feature IDs remain available.

`app.sidebarNavigation()` returns resolved groups. `app.navigateSidebar("self")` follows the semantic alias and returns false when unavailable. Existing `navigate(Page::...)` and `navigateScript(tabId, subtabId)` remain valid. Existing `setSidebarLayout(...)` restores its legacy behavior, including default Visuals/Tools when passed an empty list.

## Self > View

Register View under the existing Self page:

```lua
local self = ui.tab("self", "Self")
ui.subtab(self, "view", "View", function()
    ui.group("Camera", function()
        ui.feature("host.third_person")
        -- Draw the host camera FOV control and its override here.
    end)
    ui.group("Viewmodel", function()
        -- Draw distinct Model FOV and local viewmodel X/Y/Z controls here.
        ui.feature("host.reset_view")
    end)
end)
```

Replace example IDs with actual registered host IDs. Camera FOV, viewmodel projection FOV and local viewmodel position offsets are separate contracts. Keep host-valid ranges, defaults, zero offsets and override-off restoration. Retain implemented shoulder/distance/height options. Validate camera collision, zoom, weapon/spectator transitions and engine restoration in each supported title.

`preview/sidebar_demo.cpp` is a synthetic layout fixture. Its values drive only preview controls. Its host API registration and numeric defaults are not a game adapter template.

## Inline bindings

Draw the binding for an existing feature with either API:

```cpp
simple_base::ui::keybind(*app.features().find("host.aim"), app.hotkeys(), "Aim key");
```

```lua
ui.group("Activation", function()
    ui.feature("host.aim")
    ui.keybind("host.aim", "Aim key")
end)
```

`ui.keybind(id[, label])` is valid only inside drawing callbacks. It edits the same `Feature::binding` used by the gear, Hotkeys manager, config and Lua binding APIs. The current-binding button starts canonical capture. Release initiating inputs, then press a supported keyboard key or mouse button. Escape cancels, Delete clears, and Clear clears directly. Capture does not activate the feature. Persisted modes remain Always=0, Toggle=1, Hold=2, Hold to disable=3. Aim behavior such as Lock-on/Silent/pSilent remains a distinct host setting.

## Spawner catalog rows

Use `ui.selectable(label, selected [, width, height]) -> activated` for plain catalog text. It uses host Text/Header colors without a button-style border or idle box. Caller-owned `selected` is a required boolean. Optional nonnegative finite dimensions are physical pixels; width 0 uses remaining space and height 0 uses text height. IDs retain the original label across localization; add `##stable_id` for duplicate visible names. Clipping and `imgui.disabled` apply. Select rows with the mouse; navigation keys do not focus or activate them.

Only update the selection when the row returns true. Keep the actual host spawn call in a separate `Spawn item` action. The equivalent C++ control is `simple_base::ui::selectable(label, selected, ImVec2 size = {})`. See [the Lua catalog example](LUA_API.md#selectable-catalog-rows). Existing `ui.columns(2, draw)` is sufficient for two-column combat pages; the game adapter chooses which groups belong in each column.

## Optional independent master and activation

Existing features retain established input semantics. Hosts requiring separate combat master-enable and activation can opt in through registration metadata:

```cpp
auto *aim = app.features().find("host.aim");
aim->independentActivation = true;
// Retain existing enabled state, binding and compatible saved mode.
const bool active = app.hotkeys().active(*aim);
```

With that opt-in, a disabled master is always inactive. Hold requires the bound input down; Toggle flips a transient latch once per press edge without changing the saved master; Always requires no binding. Unbound Hold/Toggle is inactive. Compatible Hold to disable remains available. Lua `features.active(id)` reports this effective state; `features.get(id)` reports saved master state.

The metadata and Toggle latch are not profile fields. Config loads preserve host registration metadata. Separate aim/trigger features have independent bindings and latches. Binding or mode changes, disable, capture, focus loss, text entry, mouse capture and UI capture clear transient activation. Application supplies `InputFrame::uiCaptured` from ImGui keyboard/mouse capture. Hosts calling `Hotkeys::update` directly must supply accurate focus/capture flags.

Call `app.hotkeys().resetActivation()` on map/disconnect/stop, profile switches or other lifecycle boundaries; an optional feature ID clears one latch. The host still clears target, timing and owned input state, checks runtime/weapon eligibility, and restores camera/viewmodel state. This contract does not implement aim selection, hitboxes, FOV circle, snapline or trigger firing. Aiming Nearest selects an eligible anatomical hitbox by angle; trigger All is a traced-hitgroup filter. These remain game-owner responsibilities.

## Additional menu key

Hosts may set `AppOptions::alternateMenuKey = "F2"` before constructing the application. This optional fallback preserves the configured menu key and Insert; it is not overwritten by a saved profile. Function keys remain usable while editing text, and focus loss or key capture suppresses menu toggling. The Interface page and bindings overlay show the extra key. Other hosts retain their existing behavior when the option is empty.

## Validation

`sidebar_presets`, `inline_keybind` and `independent_activation` exercise the presets, absent Campaign combat, retained Lua/addon routes, actual mouse sidebar navigation and rejection of keyboard navigation, scale/viewport changes, keyboard/mouse capture, cancel/clear/rebind, persisted modes and master/latch lifecycle. They complement existing core/UI/Lua/docs/ESP/asset/compatibility tests.

From the UI directory:

```powershell
python -X utf8 tests/capture_sidebar.py --exe build/sidebar-x64/Release/simple_base_preview.exe --output build/sidebar-qa
```

The script uses isolated per-fixture data and hidden native Windows DX11/WARP rendering. It captures Standard, RageLegit, Campaign, compact, large-text and Settings/Lua and records PNG/executable hashes. Manual flags include `--sidebar-demo standard|rage-legit|campaign`, `--page self|aimbot|editor` and `--text-scale 2`. Missing routes are not synthesized.

On 2026-09-22, Win32 and x64 Release each passed all 11 shared CTest suites. All six native WARP captures succeeded and were visually inspected. Exact shared inputs/artifacts and logs are recorded in `build/sidebar-checkpoint.json`. This is shared UI evidence; final game integrations, physical in-game input and Linux/Wine/Proton acceptance remain separate.


The subsequent selectable-row checkpoint is recorded separately in `build/selectable-checkpoint.json`; `build/sidebar-checkpoint.json` remains the historical sidebar/input checkpoint. The focused `selectable_rows` suite exercises caller-owned selection and the separate action, mouse activation, rejected keyboard activation, disabled rows, stable IDs, host highlight/no idle box, argument validation and draw-context rules. The spawner preview is synthetic and uses an action counter, never a game spawn.
