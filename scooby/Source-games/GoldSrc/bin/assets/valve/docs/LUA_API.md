# Lua UI API

Version **1.0**. `UI_API_VERSION` is `"1.0"`.

This is the portable UI API for Scooby Simple Base. It provides persistent scripts, custom features, tabs, sub-tabs, independent menus, overlays, page replacements, theming, and a curated set of ImGui controls. Game-specific functions are supplied by the project that embeds the UI.

Open **Lua > API docs** for the API browser beside the main GUI. Expand sections and API members to view signatures and code examples. The browser uses the main UI's theme, fonts, spacing and editor colors; explanatory notes and sections containing only notes are omitted. It supports mouse/keyboard navigation, independent resizing, selection/copy and horizontal code scrolling. Use the close button or Escape while focused to dismiss it. The browser loads this reference with the host's game-specific extension; optional `docs/LUA_SNIPPETS.md` adds examples. The preview supports `--page api --no-welcome`.

The source reference is `docs/LUA_API.md`; consumer and preview builds automatically stage it at `assets/docs/LUA_API.md` beside the executable.

## Getting started

1. Open **Lua > Scripts**, select **Custom UI.lua**, and click Run.
2. A **My Tools** tab appears in the sidebar. Its controls edit real registered features.
3. F8 toggles its feature and the example overlay.
4. Run **Standalone Menu.lua** to try an independent menu; F9 toggles its visibility.
5. Use **Stop** next to the editor's script selector to unload that script.

The independent menus are ImGui windows rendered inside the host's viewport. They can run while the main GUI is closed. This API does not create a separate operating-system process or desktop window.

Minimal custom tab:

```lua
local enabled = features.add {
    id = "enabled", label = "My feature", default = false,
    category = "My Tools", description = "My custom feature", key = "F8"
}
local tab = ui.tab("tools", "My Tools")
ui.subtab(tab, "general", "General", function()
    ui.group("Options", function()
        ui.feature(enabled)
    end)
end)
```

## Localization

`ui.tr(english_key)` returns the selected catalog's **logical UTF-8 text**, or the original key when absent. It is available during loading and callbacks. Call it inside a callback when text must follow live language changes.

Built-in Lua text, buttons, groups, sliders, dropdowns, tooltips, input/color labels, window titles and `render.text` translate their visible captions automatically. Widget IDs continue to use the original labels. Keep labels stable; add an entry with that English key to each `languages/<code>.json` catalog to localize a custom script. Player names and arbitrary values are not translation keys.

Format translated templates before drawing; Arabic/Hebrew display shaping happens afterwards:

```lua
ui.subtab("settings", "localized_stats", "Info", function()
    imgui.text(string.format(ui.tr("Speed: %.0f units/s"), 250))
end)
```

Do not cache `ui.tr` results at script load if the text should change with the selected language. Keep `%s`, `%d`, and other format specifiers unchanged in translated templates. Missing keys intentionally fall back to English. The API guide and console/game diagnostics remain developer text.

## Script lifetime and ownership

Each named script has its own Lua state. Top-level code runs once. Local variables captured by callbacks survive between frames. Different scripts have separate global variables.

Running the same script name again stops its previous instance before loading the replacement. Syntax or startup errors leave the replacement stopped. The old instance is not restored. Running another name leaves existing scripts running.

Stopping removes the script's tabs, sub-tabs, windows, overlays, page replacements, themes, visibility overrides and registered features, including their reset defaults. It closes its state after calling shutdown callbacks. Values explicitly written to existing host features with `features.set`, `features.bind`, `features.color` or `base.set` remain changed.

Register features, pages, windows, overlays and event callbacks at the top level. Registration from a frame callback is rejected, preventing callbacks from invalidating UI/feature iteration.

A drawing callback that errors is logged and disabled. A failed event or action callback is disabled too. Other scripts continue. Reload the script after correcting the error.

The script name determines its namespace. The editor uses the selected filename without `.lua`; an unsaved editor uses `Untitled`. The C++ runtime's default name is `editor`. Renaming a file changes its namespace on its next run; stop the old instance if it is still running.

## Features

A registered feature joins the same registry as built-in features. It participates in search, favorites, hotkeys, config values, and the Active Features overlay. A Lua feature supplies state and optional action callbacks; gameplay behavior belongs in a project API or an update callback.

### Register a feature

```lua
local id = features.add {
    id = "example",                 -- required local ID, 1-80 characters
    label = "Example",              -- defaults to local ID
    category = "My Tools / General", -- defaults to "Scripts"
    description = "What this does",
    default = false,                -- initial enabled state
    key = "F8",                     -- optional key, Toggle mode
    active_list = true,             -- include effective toggles in Active Features
    kind = "toggle"                 -- "toggle" or "action"
}
```

The returned ID is `lua.<script name>.<local id>`. Keep and use the returned ID rather than constructing it. Duplicate IDs are rejected.

An action runs once per button/hotkey activation:

```lua
local action = features.add {
    id = "refresh", label = "Refresh", kind = "action",
    on_trigger = function() print("Refresh requested") end
}
```

### Read and change features

| Function | Behavior |
| --- | --- |
| `features.get(id)` | Returns the saved enabled boolean, or nil for an unknown ID. |
| `features.set(id, boolean)` | Changes enabled state; rejects unknown IDs. |
| `features.active(id)` | Returns effective hotkey state, including Hold/Hold Off. |
| `features.trigger(id)` | Activates an action, including its callback and overlay flash. |
| `features.bind(id, key, mode)` | Sets a key and mode. Empty key clears the key. |
| `features.color(id, r, g, b, a)` | Sets RGBA color; components must be 0-1. Alpha defaults to 1. |
| `features.list()` | Returns an array of tables with id, label, category, description, kind, enabled. |
| `ui.feature(id)` | Draws the standard feature row, including applicable gear/color/hotkey controls. |
| `ui.keybind(id [, label])` | Draws shared capture, Clear and activation mode for an existing feature; drawing callbacks only. Label defaults to Key. |

Binding modes are `"always"`, `"toggle"`, `"hold"`, and `"hold_off"`. Key names match the menu's binding names, for example `F8`, `G`, `Mouse 1` and `Insert`. Hotkeys follow the host's focus and text-input rules.

`features.active` should gate behavior. `features.get` intentionally returns saved state and does not resolve Hold modes.

Legacy compatibility: `base.get(id)`, `base.set(id, boolean)`, `base.log(...)` and `print(...)` remain available.

### Independent health overlays

```lua
features.set("esp.health", true)
features.set("esp.health_text", true)
features.bind("esp.health_text", "F7", "toggle")
ui.tab("health_overlays", "Health", function()
    ui.feature("esp.health")
    ui.feature("esp.health_text")
end)
```

`esp.health` is the existing bar; `esp.health_text` is independent HP text using the same config/hotkey services. Both require authoritative host health. Text can render without a maximum; bars require a valid maximum. See [the host health contract](HEALTH_ESP.md).

### Inline key capture

```lua
ui.tab("aim_controls", "Aimbot", function()
    ui.group("Activation", function()
        ui.feature("host.aim")
        ui.keybind("host.aim", "Aim key")
    end)
end)
```

Use an existing registered host feature ID. Release initiating inputs before assigning a key or mouse button; Escape cancels and Delete clears. The control edits the same binding as `features.bind` and Hotkeys. Hosts can opt into separate saved master and transient activation; see [the integration contract](GAME_SIDEBAR.md). Aim behavior modes remain separate from activation modes.

## Tabs and sub-tabs

```lua
local tab = ui.tab("tools", "My Tools")
local subtab = ui.subtab(tab, "display", "Display", function()
    imgui.text("My page")
end)
```

`ui.tab(id, label [, draw])` creates a sidebar entry and returns its opaque ID. An optional draw callback becomes its Overview page. A tab without a draw callback selects its first sub-tab.

`ui.subtab(parent, id, label, draw)` creates a sub-tab and returns its ID. Parent can be a tab ID returned by `ui.tab`, or one of the built-in IDs: `"visuals"`, `"lua"`, `"settings"`.

```lua
ui.subtab("settings", "my_settings", "My Script", function()
    imgui.text("An extra page beside the built-in settings.")
end)
```

IDs must be nonempty and unique across a script's UI registrations. Labels can be changed independently. Custom sidebar entries scroll when they exceed the available height.

## Groups and columns

Scoped helpers always close their native ImGui/group state, including when a nested Lua callback fails. There are no manual Begin/End or Push/Pop pairs to balance.

```lua
ui.columns(3, function()
    ui.group("First", function() imgui.text("First column") end)
    ui.next_column()
    ui.group("Second", function() imgui.text("Second column") end)
    ui.next_column()
    ui.group("Third", function() imgui.text("Third column") end)
end)
```

`ui.group(label, draw)` creates a collapsible Scooby card. `ui.columns(count, draw)` supports 1-5 columns and reflows on narrow windows. `ui.next_column()` advances inside that scope. Nested column layouts are rejected. Use unique group labels or `##suffix` IDs for repeated controls within a callback.

## Independent menus and attached windows

```lua
local window = ui.window("inspector", "My Inspector", {
    width = 360, height = 280,
    menu_only = false,
    attach = "none"
}, function()
    imgui.text("Independent menu")
    if imgui.button("Show main menu") then ui.menu_visible(true) end
end)
```

`ui.window(id, title, options, draw)` registers a persistent window. Width/height are initial physical-pixel dimensions. A free window can be dragged, resized and closed. `menu_only=true` hides it when the main GUI closes.

`attach` accepts `"none"`, `"left"` or `"right"`. Attached windows follow the main menu and match its height; their position is clamped to the viewport, so they may overlap the main menu when the requested side has insufficient room. The built-in API reader additionally reserves space beside the menu on normal-sized viewports.

`ui.window_visible(windowId [, boolean])` gets/sets the visibility of a window owned by the calling script. This can reopen a window after its close button is used.

`ui.menu_visible([boolean])` gets/sets the main GUI's visibility. Independent windows continue drawing when the main GUI is hidden unless `menu_only` is set.

To toggle a standalone window with a hotkey, register a toggle feature and call `ui.window_visible(windowId, features.active(featureId))` from an update callback. See `Standalone Menu.lua`.

For windows constructed dynamically inside a UI/overlay callback, use `imgui.window(title, options, draw)`. Its options are width and height. It is drawn whenever that scope is called; visibility is controlled by the Lua code surrounding the call.

## ImGui controls

`imgui` is a curated immediate-mode binding to the bundled ImGui renderer, not a claim to expose every upstream ImGui function. Call these functions from tab, sub-tab, window, overlay, or page replacement callbacks. Calling drawing functions while loading or from an update event returns a Lua error.

Controls keep values in Lua and return the edited value:

```lua
local amount, enabled, text = 50, false, "Hello"
ui.window("example", "Controls", {}, function()
    local changed
    changed, enabled = imgui.checkbox("Enabled", enabled)
    changed, amount = imgui.slider_float("Amount", amount, 0, 100)
    changed, text = imgui.input_text("Text", text)
end)
```

| Function | Return / behavior |
| --- | --- |
| `imgui.text(text)` | Wrapped text; treats the string as text, not a printf format. |
| `imgui.text_colored(text, rgba)` | Colored text. |
| `imgui.button(label [, width, height])` | Returns true on activation; dimensions default to automatic. |
| `ui.selectable(label, selected [, width, height])` | Plain text row using the host selection highlight. Returns true on mouse/keyboard activation; selection remains caller-owned. Zero dimensions use available width and text height. |
| `imgui.checkbox(label, value)` | Returns changed, boolean. |
| `imgui.slider_float(label, value, min, max)` | Returns changed, number. |
| `imgui.slider_int(label, value, min, max)` | Returns changed, integer-valued number. |
| `imgui.input_text(label, text)` | Returns changed, string; maximum 4095 bytes. |
| `imgui.combo(label, index, items)` | Returns changed, selected index. Indices start at 1; 1-128 items. |
| `imgui.color_edit(label, rgba)` | Returns changed, RGBA table. |
| `imgui.same_line([spacing])` | Places the next item on the same line; default style spacing. |
| `imgui.separator()` | Separator line. |
| `imgui.spacing([height])` | Vertical space; default 4 physical pixels. |
| `imgui.tooltip(text)` | Tooltip when the preceding item is hovered. |
| `imgui.progress(fraction)` | Progress bar; fraction is clamped to 0-1. |
| `imgui.available()` | Returns available content width, height. |
| `imgui.cursor()` | Returns cursor x, y in screen coordinates. |
| `imgui.set_cursor(x, y)` | Sets the next cursor position in window-local coordinates. |
| `imgui.is_item_hovered()` | Returns whether the preceding item is hovered. |
| `imgui.child(id, width, height, draw)` | Scoped scrollable child; 0 uses remaining size. |
| `imgui.disabled(boolean, draw)` | Scoped disabled controls. |
| `imgui.with_style(colors, draw)` | Scoped color overrides, restored even after callback errors. |
| `imgui.window(title, options, draw)` | Scoped independent ImGui window. |

RGBA values use `{r, g, b, a}` with components between 0 and 1. Alpha defaults to 1 when omitted. Use stable `##suffix` labels when controls have duplicate visible names.

Lua local variables are live session state; they are not automatically written to profiles. Registered feature values participate in the existing profile system. Register the scripts before loading a profile containing their feature IDs.

### Selectable catalog rows

```lua
local selected = 1
local catalog = {"Crowbar", "Health kit"}
ui.tab("catalog", "Spawner", function()
    ui.group("Items", function()
        for index, label in ipairs(catalog) do
            if ui.selectable(label .. "##item_" .. index, selected == index) then
                selected = index
            end
        end
        imgui.disabled(true, function()
            ui.selectable("Unavailable item", false)
        end)
    end)
    if ui.button("Spawn item") then
        print("Spawn requested for " .. catalog[selected])
        -- Invoke the host's actual spawn API here.
    end
end)
```

The row has no button border or idle box. `selected` is a required boolean; Lua keeps selection state and changes it only when activation returns true. Arrow keys move focus, Enter/Space activate, and `imgui.disabled` blocks activation. Use stable hidden ID suffixes for repeated labels. Dimensions are optional nonnegative finite physical pixels; 0 fills available width or uses text height. Drawing-context validation is identical to other controls. Selecting a catalog row must not call a spawn API; the separate Spawn item action uses the current selection.

## Overlays and drawing

```lua
ui.overlay("status", function()
    local width, height = engine.viewport()
    render.rect(20, height - 60, 240, 36, {0.05, 0.07, 0.09, 0.9}, true, 4)
    render.text(30, height - 51, "Lua overlay", {0.4, 0.8, 1, 1}, 14)
end)
```

`ui.overlay(id, draw)` invokes draw every frame, including when the main GUI is closed. Render primitives use the foreground draw list in the current host viewport. Coordinates and sizes are physical pixels; text size is rounded to a whole pixel. A script can derive responsive positions from `engine.viewport()`.

| Function | Arguments |
| --- | --- |
| `render.text(x, y, text, rgba [, size])` | Text; size defaults to 13 and is limited to 8-80. |
| `render.line(x1, y1, x2, y2, rgba [, thickness])` | Line; default thickness 1. |
| `render.rect(x, y, width, height, rgba [, filled, rounding])` | Filled or outlined rectangle; default outline, rounding 0. |
| `render.circle(x, y, radius, rgba [, filled, thickness])` | Filled or outlined circle; default outline, thickness 1. |

Custom draw-list overlays do not acquire a built-in drag handle. Use `ui.window` for an interactive draggable overlay, or implement interaction in the project-specific host API.

## Themes and UI overrides

```lua
ui.theme {
    rounding = 5,
    colors = {
        WindowBg = {0.06, 0.07, 0.1, 1},
        Text = {0.9, 0.92, 1, 1},
        CheckMark = {0.75, 0.4, 1, 1},
        SliderGrab = {0.75, 0.4, 1, 1},
        Button = {0.22, 0.15, 0.32, 1},
        ButtonHovered = {0.32, 0.22, 0.45, 1}
    }
}
```

`ui.theme(options)` installs or replaces this script's theme overrides. Color names match ImGui names without `ImGuiCol_`, such as WindowBg, PopupBg, Text, TextDisabled, CheckMark, SliderGrab, FrameBg, FrameBgHovered, Button, Header and Border. Unknown names are rejected. Rounding sets WindowRounding and FrameRounding, from 0 to 24 pixels.

Overrides apply on the next frame after the user's baseline theme. The most recently applied script theme wins for overlapping fields. `ui.reset_theme()` or stopping the script restores the underlying theme. Scoped `imgui.with_style({Text={1,0,0,1}}, draw)` affects only the callback's controls. Some custom card/overlay surfaces have their own drawing colors; this API edits the ImGui palette rather than every game-specific renderer constant.

`ui.feature_visible(featureId, boolean)` hides/shows the standard row and its search results for that script's lifetime. It does not enable/disable the feature's behavior. If multiple scripts hide a feature, all must release the override before it becomes visible.

Replace the contents of a built-in page:

```lua
ui.override("settings/interface", function()
    imgui.text("My replacement settings page")
    if imgui.button("Log") then print("Replacement works") end
end)
```

Supported targets:

- `visuals/esp`, `visuals/radar`
- `lua/scripts`, `lua/editor`, `lua/console`
- `settings/interface`, `settings/config`, `settings/hotkeys`, `settings/overlays`, `settings/links`

The shell, search and navigation remain available. The latest registered replacement wins. Stopping its script reveals the previous replacement or original page. A failed replacement is disabled so the original page can recover on the next frame.

## Events and host information

```lua
events.on("update", function()
    -- Read feature state and call a project-provided API here.
end)
events.on("shutdown", function()
    print("Cleaning up my script")
end)
```

`update` runs once per rendered application frame. `shutdown` runs when the script is stopped or replaced and during application shutdown. Both use protected Lua calls. They cannot draw ImGui widgets; register a UI callback for drawing.

| Function | Return |
| --- | --- |
| `engine.time()` | ImGui elapsed time in seconds. |
| `engine.delta_time()` | Frame delta in seconds. |
| `engine.fps()` | ImGui's smoothed frame rate. |
| `engine.viewport()` | Host viewport width, height. |
| `print(...)`, `base.log(...)` | Write to the shared console. |

Frame updates run before the current frame's hotkey update, so `features.active` inside update sees the last processed hotkey state. Draw callbacks run after hotkeys and see the current state.

## Porting and game-specific APIs

The default API deliberately contains UI and feature-registry behavior. It does not invent game/entity/memory/network APIs. Add the functions appropriate to each project through `Application::scripts().registerHostApi` before running scripts. The UI layer installs its own API separately, so the host hook does not replace it. A host that owns per-script resources can install `removeHostApi(lua_State*)` to release them when a state closes, including stop, reload and failed initial execution. The owner of these hooks must outlive the Application.

A minimal host extension:

```cpp
extern "C" {
#include "lua.h"
#include "lauxlib.h"
}

app.scripts().registerHostApi = [](lua_State* L) {
    lua_newtable(L);
    lua_pushcfunction(L, [](lua_State* state) -> int {
        lua_pushstring(state, "My Game");
        return 1;
    });
    lua_setfield(L, -2, "name");
    lua_setglobal(L, "game");
};
```

Lua can then call `game.name()` from its loading code or callbacks. For real game features, expose validated functions such as entity snapshots, local-player state, permitted actions or typed settings through the same hook. Connect live behavior in an `update` callback or the host feature dispatcher, using `features.active(id)` to honor hold/toggle bindings.

Thread and lifetime rules:

- Construct, run, stop and draw scripts on the application's UI/render thread.
- Do not call ImGui or the Lua state from background threads. Marshal host results to the render thread.
- Register host features before loading profiles. Run scripts before loading profiles containing script-owned IDs.
- A state remains alive until its named script is stopped/replaced or application shutdown. Do not retain it beyond that point.
- Call `app.shutdown()` before destroying ImGui or host objects referenced by callbacks.
- The bundled Lua target is compiled in C++ exception mode with a C-compatible public ABI, so protected errors unwind C++ bindings safely. Preserve that build mode when porting. On MSVC, bindings require `/EHs` with `/EHc-` so C ABI calls may unwind; the CMake target propagates these options.
- Native host calls must validate arguments and manage their own cancellation; Lua's instruction hook cannot preempt a blocking native function.

C++ lifecycle controls:

```cpp
app.scripts().run(source, app.features(), logCallback, "My Script");
auto names = app.scripts().running();
app.scripts().stop("My Script");
app.scripts().stopAll();
app.navigateScript("lua:My Script:tools", "lua:My Script:general");
app.setApiDocsVisible(true, false); // true = attach left, false = attach right
```

`Application` supplies frame dispatch automatically. A core-only host using `ScriptRuntime` directly calls `beginFrame()` and `dispatch("update")` itself. Such a host gets features/events/base APIs; ImGui/UI/render/engine APIs are installed by the UI layer.

## Limits and troubleshooting

The runtime enables Lua base, string, table, math and UTF-8 libraries. OS, file, package, debug, dynamic loading and coroutine libraries are not provided by default.

Limits: 1 MB source per run; 16 MB Lua allocator per state; 16 running scripts; 128 features per script; 128 total UI registrations; 32 callbacks per event per script; 512 drawing API calls per drawing callback. Loading has a 200 ms instruction-hook deadline; callbacks share an 8 ms per-script frame budget. These are responsiveness guards for scripts, not a security boundary for native extensions.

If a script fails, read Lua > Console. Error messages include the script name. Correct the code and rerun it. A drawing function called from top-level loading or `update` is rejected; move it into a registered draw callback. A stopped script's IDs are no longer valid. API registrations must use unique local IDs and happen during loading.

Profiles do not automatically start scripts. Save a script in the browser and run it explicitly. Register it again before loading profiles with its feature values. Arbitrary Lua locals are not persisted across reloads.

Host tabs may specify navigation metadata: `ui.tab("world", "World", {section="Visuals", icon=0xe231})`. With a page callback, pass metadata as argument 4. Default groups are `Visuals` and `Tools`; other group names appear between them. Hosts can arrange sections and built-in/script tab IDs with `Application::setSidebarLayout`. Unlisted script tabs are appended to their declared section, so user pages remain reachable. The L4D host uses Combat, Visuals and Misc. Icons use the bundled Lucide private-use codepoints. Set `hidden=true` in tab metadata to hide its sidebar entry; the host can still open the registered page with `Application::navigateScript`.

## Custom product controls

`ui.slider(label,value,min,max)` and `ui.slider_int(label,value,min,max)` return `changed,value` and use the Lumia track, handle and click-to-edit value control. Signed/zero ranges are supported. `ui.toggle(label,value)` returns `changed,value`; `ui.combo(label,index,items)` returns `changed,index` with a one-based index. `ui.button(label[,width,height])` returns a boolean. These controls follow the active template scale, colors and disabled scope.

The shared UI also routes legacy `imgui.slider_float`, `imgui.slider_int`, `imgui.checkbox`, `imgui.combo` and `imgui.button` through these custom controls for script compatibility. Product pages use the `ui` names. Text/editing/layout still uses the regular Lua API. `AppOptions.footer` lets a host replace the portable-template footer without changing another application's branding.

`ui.multi_combo(label, selected, items)` returns `changed, selected` for 1-128 items. Pass a dense boolean array with one entry per item; the returned array is new and the input is unchanged. Selected rows are highlighted without checkboxes. Clicking an entry toggles only that entry and keeps the dropdown open; click outside or press Escape to close it. Labels and the None/All summary follow the active language. Save selections through feature/config values when persistence is needed.

```lua
local values = {features.get("aim.common"), features.get("aim.special")}
local changed, selected = ui.multi_combo("Targets", values, {"Common infected", "Special infected"})
if changed then
    features.set("aim.common", selected[1])
    features.set("aim.special", selected[2])
end
```

Shared settings and hotkey popups use the same custom buttons and dropdowns. Native hosts can use `ui::beginCombo`, `ui::comboItem` and `ui::endCombo` for dynamic lists. Negative button widths fill the remaining row, matching the existing layout convention.

`ui.columns(count, draw [, compact])` accepts an optional boolean for tighter columns. The default is unchanged; `true` uses a smaller readable minimum width before reflowing on narrow windows.

---

# halflife host API

## halflife.session()

`halflife.session() -> string`

```lua
print(halflife.session())
```

## halflife.entities()

`halflife.entities() -> table`

```lua
for _, entity in ipairs(halflife.entities()) do
    print(entity.index, entity.name, entity.distance, entity.on_screen)
end
```

## halflife.setting(id, field [, value])

`halflife.setting(id, field [, value]) -> number`

```lua
halflife.setting("hl.combat.fov", "distance", 15)
halflife.setting("hl.combat.aim", "style", 0)
halflife.setting("chams.animation", "style", 1)
```

## halflife.campaign.identity()

`halflife.campaign.identity() -> table`

```lua
local i = halflife.campaign.identity()
print(i.game, i.profile, i.platform, i.server_sha256)
```

## halflife.campaign.capabilities()

`halflife.campaign.capabilities() -> table`

```lua
local caps = halflife.campaign.capabilities()
print(caps["player.godmode"].supported, caps["player.godmode"].available)
```

## halflife.campaign.has(name)

`halflife.campaign.has(name) -> boolean`

```lua
print(halflife.campaign.has("player.no_reload"))
```

## halflife.campaign.status()

`halflife.campaign.status() -> table`

```lua
local s = halflife.campaign.status()
print(s.active, s.map, s.health, s.armor, s.clip, s.tracked, s.message)
```

## halflife.campaign.catalog()

`halflife.campaign.catalog() -> table`

```lua
for _, entry in ipairs(halflife.campaign.catalog()) do
    print(entry.id, entry.label, entry.kind)
end
```

## halflife.campaign.spawn(id, count, distance)

`halflife.campaign.spawn(id, count, distance) -> boolean, string`

```lua
local ok, result = halflife.campaign.spawn("crowbar", 1, 128)
print(ok, result)
```

## halflife.combat.capabilities()

`halflife.combat.capabilities() -> table`

```lua
local caps = halflife.combat.capabilities()
print(caps.lock_on.supported, caps.silent.available, caps.psilent.state)
```

## halflife.combat.status()

`halflife.combat.status() -> table`

```lua
local s = halflife.combat.status()
print(s.target, s.trigger_target, s.weapon_ready, s.state)
```

## halflife.movement.capabilities()

`halflife.movement.capabilities() -> table`

```lua
local caps = halflife.movement.capabilities()
print(caps.bunny_hop, caps.auto_strafe)
```

## halflife.view.capabilities()

`halflife.view.capabilities() -> table`

```lua
local caps = halflife.view.capabilities()
print(caps.third_person, caps.fov, caps.model_fov, caps.offsets)
```

## View settings

```lua
halflife.setting("hl.view.fov", "distance", 100)
halflife.setting("hl.view.model_fov", "distance", 110)
halflife.setting("hl.view.x", "distance", 0)
halflife.setting("hl.view.y", "distance", 0)
halflife.setting("hl.view.z", "distance", 0)
```
