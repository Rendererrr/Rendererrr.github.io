# Lua UI API

Version **1.0**. `UI_API_VERSION` is `"1.0"`.

This is the portable UI API for Scooby Simple Base. It provides persistent scripts, custom features, tabs, sub-tabs, independent menus, overlays, page replacements, theming, and a curated set of ImGui controls. Game-specific functions are supplied by the project that embeds the UI.

Open **Lua > API docs** for the API browser beside the main GUI. Expand sections and API members to view signatures and code examples. The browser uses the main UI's theme, fonts, spacing and editor colors; explanatory notes and sections containing only notes are omitted. It supports mouse navigation, independent resizing, selection/copy and horizontal code scrolling. Use the close button or Escape while focused to dismiss it. The browser loads this reference with the host's game-specific extension; optional `docs/LUA_SNIPPETS.md` adds examples. The preview supports `--page api --no-welcome`.

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
| `ui.selectable(label, selected [, width, height])` | Plain text row using the host selection highlight. Returns true on mouse activation; selection remains caller-owned. Zero dimensions use available width and text height. |
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

The row has no button border or idle box. `selected` is a required boolean; Lua keeps selection state and changes it only when activation returns true. Mouse clicks activate rows; keyboard navigation is disabled, and `imgui.disabled` blocks activation. Use stable hidden ID suffixes for repeated labels. Dimensions are optional nonnegative finite physical pixels; 0 fills available width or uses text height. Drawing-context validation is identical to other controls. Selecting a catalog row must not call a spawn API; the separate Spawn item action uses the current selection.

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

## Entity colors

| Signature | Behavior |
| --- | --- |
| `esp_colors.available()` | Returns whether the host registered classification color support. |
| `esp_colors.categories()` | Returns the 13 stable category IDs in display order. |
| `esp_colors.enabled([boolean])` | Reads or sets the category master. Unsupported hosts return false; writes fail. |
| `esp_colors.get(category)` | Returns enabled, color, second_color and tint_fill; returns nil without host support. |
| `esp_colors.set(category, settings)` | Atomically applies supplied fields. RGBA arrays require exactly four finite numbers from 0 to 1. |
| `esp_colors.reset([category])` | Resets one category, or all categories and the master when omitted. |
| `ui.entity_colors()` | Draws the shared themed editor in a drawing callback; returns false without host support. |

```lua
if esp_colors.available() then
    esp_colors.set("npc_friendly", {
        enabled = true,
        color = {0.2, 0.9, 0.4, 1},
        second_color = {0.1, 0.5, 0.2, 1},
        tint_fill = false
    })
    ui.window("entity_colors", "Entity colors", function()
        ui.entity_colors()
    end)
end
```

The host supplies Entity kind and relationship; scripts edit persisted appearance only. Writes survive script stop. Category colors affect enabled ESP features after the user enables the master, and preserve independent health colors and host-palette precedence. See [entity classification colors](ENTITY_COLORS.md) for the category mapping and profile migration contract.

---

# Scooby Left 4 Dead Lua API 1.0

## L4D quick start

**Lua > API docs** opens a scrollable L4D1/L4D2 snippet guide without toolbar controls. Select code and press Ctrl+C, then paste it into **Lua > Editor**. Each example runs independently. The guide ships as `docs/LUA_SNIPPETS.md`; this full reference remains in `docs/LUA_API.md`.

The `l4d` host API works with the L4D1 and L4D2 game adapters. It supplements the portable UI, rendering, events, hotkeys and feature/config APIs. `L4D_API_VERSION == "1.0"` identifies this host extension; `UI_API_VERSION` identifies the portable UI API separately.

Open **Lua > Scripts**, select an example and run it. Bundled scripts are copied into the active profile's script library on startup without overwriting your edited copies. They do not auto-run. New native APIs require a host built from this source; copying Lua files alone cannot add native functions to an older DLL.

Included examples:

- **L4D Entity Overlay.lua**: separate actor/pickup ESP, optional skeletons, range and category controls using the custom Scooby widgets.
- **L4D Player HUD.lua**: health, movement state, speed, active weapon and reload/clip information.
- **L4D Nearby Threats.lua**: distance warnings for specials and witches.

```lua
assert(L4D_API_VERSION == "1.0", "Update the Scooby L4D host")
l4d.watch {survivors=false, infected=true, pickups=false, range=60}
ui.overlay("specials", function()
    for _, e in ipairs(l4d.entities {special=true}) do
        local p = l4d.world_to_screen(e.position)
        if p and p.on_screen then
            render.text(p.x, p.y, e.name, {1,.4,.3,1})
        end
    end
end)
```

## L4D snapshots and lifetime

The engine thread captures copied data; Lua never dereferences an entity or calls engine interfaces. All callbacks within a UI frame read one pinned snapshot. `sequence` identifies that capture, not an entity's lifetime. A rendered frame can reuse a previous engine capture. Entity indices may be recycled: reacquire entities each callback and do not assume an index identifies the same actor across frames or maps.

Game data follows the host's existing session gate (an allowed local `-insecure` session). On disconnection, map change or a stopped host, `local_player()` and `camera()` return nil, entity queries return empty/nil and projection returns nil after the next capture. `session().allowed` is false in the standalone preview; `data_available` may be true there for explicitly synthetic data. The preview is not live-game validation.

Returned tables are independent copies. Editing them does not change the game or later queries. Read functions work at top level or inside callbacks, but game data may not exist during script loading. Perform ongoing logic in `events.on("update", ...)`; draw only in UI/overlay callbacks.

## L4D session and player

| Function | Return |
| --- | --- |
| `l4d.info()` | `{api_version, game_id, game, map, preview, sequence, engine_time, max_entities}`. `game_id` is `l4d1`, `l4d2`, `preview`, or empty before attachment. Time is engine time in seconds, not wall-clock time. |
| `l4d.session()` | `{allowed, data_available, preview, stopped, insecure, in_game, connected, loopback, demo, local_player, menu_open, reason}`. `local_player` here is a boolean. |
| `l4d.local_player()` | Player table below, or nil. No entity subscription required. |
| `l4d.camera()` | `{position, angles, width, height, sequence}` or nil. Position is the captured local eye position; angles are engine view angles. Projection uses the captured engine world-to-screen matrix, which can differ from the eye in spectator/third-person views. |
| `l4d.status()` | Human-readable host/session status (existing API). |
| `l4d.metrics()` | Three values: horizontal speed in Source units/s, built-in scene entity count, receive-property count (existing API). This entity count is independent of Lua subscriptions. |

Player fields: `index`, `sequence`, `team`, `health`, `flags`, `water_level`, `move_type`, `alive`, `on_ground`, `incapacitated`, `hanging`, `position`, `eye_position`, `velocity`, `view_angles`, `speed`, and optional `weapon`. `speed` is horizontal Source units per second; velocity is Source units per second on each axis. Team numbers are raw engine team IDs (2 survivors, 3 infected).

`weapon` is `{index, class_name, clip?, reloading?}`. It is absent when there is no active weapon. Clip/reload fields are absent if the receive table does not expose them; clip may be -1 for weapons without a magazine. No reserve-ammo value is invented.

## L4D entity subscriptions

`l4d.watch(options)` replaces this script's subscription and returns its normalized options. Options: `survivors=true`, `infected=true`, `pickups=true`, `bones=false`, `range=150`. Range is metres and clamps to 1-300. Unknown keys, non-boolean flags, non-finite values and wrong types produce Lua errors. `l4d.watch(false)` releases the subscription immediately on the UI side.

Subscriptions take effect on the next engine capture, so queries directly after a change may still show the previous capture. They are removed on stop, reload and failed script loading. Requests from running scripts are merged into one native scan; each script's queries still obey its own categories/range/bone flag. The merged scan may collect more data than one script requested. A disabled feature should release its subscription, as shown by the examples.

Collection is independent of built-in ESP, radar and infected/category toggles. It includes at most 512 recognized, non-dormant, non-local survivors/infected/unowned pickups, in engine-index order within the requested range. Known dead actors and held/owned pickups are excluded. It is not an enumeration of all Source classes. Actors without networked health remain available with nil health. Bone capture also enables animated hitbox fitting and costs more than basic snapshots.

| Function | Return |
| --- | --- |
| `l4d.capture()` | `{requested, captured, truncated, sequence, entity_count}`. Requested is this script's options; captured is the merged options used for this snapshot. Count/truncation describe the merged snapshot, not a filtered query. |
| `l4d.entities([filter])` | Dense array of entity tables. No subscription means an empty array. |
| `l4d.entity(index)` | One currently subscribed entity or nil. |
| `l4d.bones(index)` | Array of `{bone, parent, from, to}` segments. Empty if absent, unsubscribed, or bones were not requested/available. Bone and parent are zero-based engine bone indices; the array uses Lua's one-based indexing. |
| `l4d.screen_box(index)` | `{left, top, right, bottom, width, height, fitted}` in pixels, or nil. `fitted` means animated body hitboxes were used; otherwise actor collision hull or pickup world bounds are used. Near-plane clipping and viewport clamping are applied to native snapshot boxes. |

`entities` filter fields are optional and intersect the subscription: `category="all"|"survivor"|"infected"|"pickup"`, `type="tank"` (exact stable type string), `range=300` (metres, clamps 0-300), `special=true|false`. An unknown type returns an empty result. `special=false` includes non-special actors and pickups; combine it with `category="infected"` to get common/uncommon/witch only. Projection and boxes indicate where an entity projects, not whether a wall occludes it; there is no line-of-sight trace API.

Entity fields: `index`, `sequence`, `team`, `category`, `type`, `name`, `class_name`, `model`, `position`, `bounds_min`, `bounds_max`, `distance_m`, `health?`, `max_health?`, `alive`, `incapacitated`, `hanging`, `special`, `bones_available`. Bounds are absolute world AABB corners, not offsets. `name` is a classified display label, not a Steam/player nickname. Survivor max health falls back to 100 when unavailable; infected maximum health is absent when not networked. For pickups, `alive` is a generic active-entity flag, not an actor life state.

| Category | `type` values |
| --- | --- |
| survivor | `survivor` |
| infected | `unknown`, `common`, `uncommon`, `witch`, `smoker`, `boomer`, `hunter`, `spitter`, `jockey`, `charger`, `tank` |
| pickup | `weapons`, `melee`, `throwables`, `medical`, `ammo`, `upgrades`, `carryables` |

`special` includes unknown special infected and smoker/boomer/hunter/spitter/jockey/charger/tank. Witches are separate. Games only return types present in that game/map; L4D2-only types do not appear in stock L4D1. Classification uses the existing class/model classifier and can return `unknown` for custom mods.

## L4D projection and math

Vectors are Lua tables `{x=..., y=..., z=...}` in **Source coordinates and units**, with Z up. Angles use the same table shape: X pitch, Y yaw, Z roll, in degrees. Internal portable renderer coordinate conversion is handled by the host. Distances explicitly named `_m` and subscription/filter ranges are metres. Inputs must be finite numbers of magnitude at most 1e9.

| Function | Return |
| --- | --- |
| `l4d.world_to_screen(position)` | `{x, y, on_screen}` in physical pixels, or nil behind/outside the camera depth range or without game data. An offscreen point can return a table with `on_screen=false`. |
| `l4d.vec.add(a,b)`, `sub(a,b)` | Component sum/difference vector. |
| `l4d.vec.scale(v,n)` | Scaled vector. |
| `l4d.vec.dot(a,b)` | Scalar dot product. |
| `l4d.vec.length(v)`, `distance(a,b)` | Length/distance in the input's units. |
| `l4d.vec.normalize(v)` | Unit vector or nil for near-zero length. |
| `l4d.angle_to(eye,point)` | Source pitch/yaw/roll vector pointing toward a position. |
| `l4d.angle_fov(from,to)` | Angular distance between view-angle vectors in degrees. |
| `l4d.to_metres(units)`, `l4d.to_units(metres)` | Unit conversion; one Source unit is treated as .0254 metres by this project. |

DirectX and OpenGL use the same snapshot and projection APIs. Rendering still uses `render.*` from an overlay/UI callback.

## L4D feature integration

Use `features.add` to register your toggle/hotkey and `features.active` to gate behavior. Registered feature enabled state/hotkeys participate in the existing config system. Plain Lua locals such as the example sliders are per-run and are not automatically persisted. Use `features.list()` to discover actual IDs; `features.set`, `features.bind`, `features.color` and `ui.feature` also work with built-in IDs.

`l4d.setting(id, field [, value])` reads or updates the following numeric built-in properties. It returns the clamped value, truncating style indices to integers. Unknown ID/field pairs error. Non-finite values reset to that property's lower bound, preserving the existing setting API behavior. Changing a numeric property does not automatically enable its feature.

| ID | Field and values |
| --- | --- |
| `chams.visible`, `chams.hidden` | `style`: 0 Lit, 1 Flat, 2 Chrome, 3 Ghost, 4 Additive, 5 Wireframe, 6 Glass, 7 Glow, 8 Fullbright, 9 Chrome wireframe, 10 Ghost wireframe, 11 Neon wireframe |
| `chams.<target>.custom`, `chams.<target>.hidden` | `style`: same material indices; target IDs and pass switches below |
| `chams.enabled` | `style`: legacy alias for `chams.visible` (Players visible material) |
| `chams.selector`, `infected.selector`, `items.box` | `style`: selected category/type/box-style index; clamped to that feature's choices |
| `l4d.items`, `chams.enabled`, `infected.<type>` | `distance`: 1-300 metres |
| `l4d.items` | `textSize`: 10-24 pixels |
| `chams.pulse` | `thickness`: pulse frequency .5-5 Hz |
| `actor.box_padding` | `distance`: 0-10 percent |
| `actor.box_width`, `actor.box_height` | `distance`: legacy scale 25-100 / 50-100 percent |
| `aim.profile`, `aim.mode`, `aim.point` | `style`: profile 0 Legit/1 Rage; mode 0 Camera/1 Silent/2 Packet silent; hitboxes 0 Upper body / 1 Chest / 2 Head / 3 Stomach / 4 Arms / 5 Legs / 6 All |
| `aim.priority` | `style`: 0 Crosshair, 1 Special infected, 2 Survivors, 3 Common infected; reorders eligible candidates without changing FOV/range/visibility |
| `aim.legit`, `aim.rage`, `aim.range` | `distance`: FOV 1-180 degrees / FOV 1-180 degrees / range 1-300 metres |
| `aim.smoothing` | `distance`: 1-30 |
| `trigger.hitbox`, `trigger.rage.hitbox` | `style`: the same 0-6 hitbox choices as `aim.point`; default 6 All |
| `trigger.delay`, `trigger.range`, `trigger.rage.delay`, `trigger.rage.range` | `distance`: 0-500 ms / 1-300 metres |
| `view.thirdperson_distance`, `view.thirdperson_side`, `view.thirdperson_height` | `distance`: 40-200 / -40 to +40 / -30 to +30 Source units; enable with `features.set("view.thirdperson", true)`, no preset shortcut |
| `view.camera_fov`, `view.model_fov`, `view.offset_x`, `view.offset_y`, `view.offset_z` | `distance`: camera/model FOV in degrees or viewmodel offset in Source units, clamped to the feature's menu bounds |

### Anti-aim controls

```lua
-- Explicit opt-in. The normal host session, input and weapon gates still apply.
l4d.setting("antiaim.yaw", "style", 4) -- Spin
l4d.setting("antiaim.pitch", "style", 0) -- Keep view pitch
l4d.setting("antiaim.spin", "distance", 180) -- degrees per second
features.set("antiaim.enabled", true)
-- Stop again:
features.set("antiaim.enabled", false)
```

`antiaim.pitch.style`: 0 View, 1 Down, 2 Up, 3 Zero, 4 Jitter, 5 Custom. `antiaim.yaw.style`: 0 Backwards, 1 Left, 2 Right, 3 Jitter, 4 Spin, 5 Random, 6 Distortion, 7 Switch, 8 View. Numeric `distance` fields are `antiaim.custom_pitch` (-89â€“89), `antiaim.yaw_offset` (-180â€“180), `antiaim.jitter` (0â€“180), and `antiaim.spin` (30â€“1440 degrees/s). `features.set("antiaim.invert", true)` adds 180 degrees to yaw.

`l4d.keybind("antiaim.key", action, value)` uses the existing capture/clear/mode interface. `capture` waits 0.5 seconds; `mode` accepts 0 Always, 1 Toggle, 2 Hold, 3 Hold to disable. The master switch remains independent of its binding.

### Visual utility actions

Use `features.trigger(id)` to run an action once, or `ui.feature(id)` to draw its button and optional shortcut control. These actions have no assigned hotkeys and do not appear in the active-features list. They edit the existing saved feature settings.

| Action ID | Result |
| --- | --- |
| `view.swap_shoulder` | Negates the current shoulder offset; a centered/invalid offset selects +20. Does not enable third person. |
| `view.center_camera` | Sets the shoulder offset to zero. |
| `world.night`, `world.warm`, `world.cool` | Enables coordinated world/prop/sky tint colors. |
| `world.reset` | Disables all three tint overrides so the material controller restores original colors. |
| `chams.copy_pass` | Copies the selected target's Visible color/alpha/material to Invisible. |
| `chams.swap_passes` | Exchanges the selected target's Visible and Invisible color/alpha/material. |

Chams actions preserve target enable state, both pass switches and hotkeys. Set `chams.selector` first when invoking them from a script. Other targets remain unchanged.

The shared `ui.tr` API also works in L4D scripts. Format its logical string before passing it to `imgui.text` or `render.text` so live language selection and right-to-left text work correctly; see the bundled portable localization reference.

### Chams targets and passes

Enable `chams.enabled`, then enable each desired target. Target enable IDs are `chams.survivors` (other survivor players), `chams.self` (your world player model), `chams.arms`, `chams.held` (first-person weapon/held supplies), `chams.weapons` (dropped firearms/melee), `chams.pickups` (dropped items), `chams.world_weapon` (your active held world model), and `chams.common`, `chams.uncommon`, `chams.witch`, `chams.smoker`, `chams.boomer`, `chams.hunter`, `chams.spitter`, `chams.jockey`, `chams.charger`, `chams.tank`, `chams.unknown`. `chams.special` is an additional master switch for Smoker through Unknown special; Witch has its own independent toggle. Self requires the game to draw the local world model, for example with `view.thirdperson`.

Players use `chams.visible` / `chams.hidden` for Visible / Invisible. Every other target uses `<target ID>.custom` / `<target ID>.hidden`. Each pass has an independent enabled state, color (including alpha), hotkey and material. Use `features.set`, `features.color`, `features.bind`, and `l4d.setting(pass_id, "style", material_index)` respectively. Invisible is the ignore-depth pass: hidden surfaces show through geometry. With Visible off, the original model covers unoccluded surfaces. Both passes off leaves the original model underneath any enabled overlay. Arms/Weapon use the game's separate first-person projection, so Invisible may look the same as Visible there.

Every target also supports `<target ID>.overlay`, including `chams.survivors.overlay` for Players. It uses the same `features.set`, `features.color`, `features.bind`, and `l4d.setting(..., "style", 0..26)` controls independently of the base passes. Overlay draws at normal depth after Visible, or after the original model when Visible is off. It defaults off with white Wireframe (5), alpha 0.3, and no key. Missing materials or zero alpha skip this extra draw. `chams.overlay` itself retains its legacy **Keep original model** meaning; it is not the new per-target layer. Host schema 4 saves overlays; older configs reset absent overlay IDs to their disabled defaults without changing explicit overlay entries.

```lua
-- Red players with blue-white lightning over the base.
features.set("chams.enabled", true)
features.set("chams.survivors", true)
features.set("chams.visible", true)
l4d.setting("chams.visible", "style", 1) -- Flat
features.color("chams.visible", 1, 0.1, 0.1, 1)
features.set("chams.survivors.overlay", true)
l4d.setting("chams.survivors.overlay", "style", 15) -- Lightning overlay
features.color("chams.survivors.overlay", 1, 1, 1, 0.8)
```

Every Visible/Invisible/Overlay pass also has `<pass ID>.animation`, `<pass ID>.animation_speed` and `<pass ID>.animation_amount`. Enable the first with `features.set` (or `features.bind` / `ui.keybind`) to override shared effects for that layer. Its `style` is 0 Static color, 1 Color wave, 2 Pulse opacity, 3 Rainbow colors, 4 Shimmer, 5 Ember flicker, 6 Color surge, 7 Color steps. `features.color` on this animation ID sets the Color wave/Color surge/Color steps secondary RGB; secondary alpha is unused. The speed and amount IDs use `l4d.setting(id, "distance", value)` with 0.05â€“3 Hz and 0â€“1 respectively. A disabled override inherits the old shared effects. Static and zero Strength preserve the layer's configured RGBA; scrolling VMT textures retain their preset UV animation. Host schema 5 resets absent layer overrides and the new world-weapon target when loading older profiles, retaining explicit entries.

```lua
-- Independent arms overlay rainbow; Self and Weapon retain their own settings.
features.set("chams.arms.overlay.animation", true)
l4d.setting("chams.arms.overlay.animation", "style", 3)
l4d.setting("chams.arms.overlay.animation_speed", "distance", 0.5)
l4d.setting("chams.arms.overlay.animation_amount", "distance", 0.7)
```

The old `.custom` IDs now represent the **Visible switch**, not a global-appearance inheritance option. Loading an old profile automatically copies inherited global colors/materials into each target, preserves explicit equipment appearances, and turns Visible on where the old Custom appearance switch was off. Old first-person hidden passes remain off. After migration, targets are independent; new profiles retain explicit Visible/Invisible choices. Scripts that used `.custom` to switch inheritance should use the new pass semantics instead. `chams.enabled` remains the overall on/off switch; its old color property is unused. The `style` compatibility alias is provided through `l4d.setting`, not direct access to the feature's legacy style property.

`chams.selector` indices are 0 Players, 1 Arms, 2 Weapon, 3 Dropped weapons, 4 Items, 5 Self, 6 Common, 7 Uncommon, 8 Witch, 9 Smoker, 10 Boomer, 11 Hunter, 12 Spitter, 13 Jockey, 14 Charger, 15 Tank, 16 Unknown special, 17 Held weapon (world). Selection only changes which settings the menu edits; it does not enable or disable targets. The grouped Target / Infected type dropdowns resolve to these same indices; the new menu organization does not renumber configs or script settings.

```lua
features.set("chams.enabled", true)
features.set("chams.tank", true)
features.set("chams.special", true)
features.set("chams.tank.custom", true) -- Visible
features.set("chams.tank.hidden", true) -- Invisible
features.color("chams.tank.custom", 0.3, 0.8, 1, 1)
features.color("chams.tank.hidden", 1, 0.25, 0.3, 0.6)
l4d.setting("chams.tank.custom", "style", 8) -- Fullbright
l4d.setting("chams.tank.hidden", "style", 11) -- Neon wireframe
```

```lua
-- Explicit user action: integrate a built-in view setting into a custom page.
ui.subtab("settings", "my_view", "My view", function()
    ui.feature("view.camera_fov")
    local fov = l4d.setting("view.camera_fov", "distance")
    local changed, value = ui.slider("Camera FOV", fov, 60, 140)
    if changed then l4d.setting("view.camera_fov", "distance", value) end
end)
```

Built-in changes remain after a script stops, as with the portable feature API. If temporarily controlling a feature, save the previous value and restore it in a shutdown callback (avoid overwriting subsequent user/other-script edits). This extension provides snapshots and built-in feature controls; it does not expose raw memory, arbitrary engine commands, game-event subscriptions, entity spawning, command/packet callbacks or arbitrary weapon changes. `update` and `shutdown` remain the supported portable events.

## L4D performance and troubleshooting

Keep ranges modest, request only relevant categories, and leave bones off unless needed. Query once per callback and reuse the result; querying returns new tables. A script has the existing 16 MiB Lua allocator limit, frame callback budget and render-call limit. The examples cap drawn actors/segments to stay within the draw budget.

Empty entities: check `l4d.session()`, register `l4d.watch`, allow an engine capture, check filters/range, and inspect `l4d.capture().truncated`. Bones may be unavailable while a pose is being initialized. Nil health means unavailable, not zero. A missing `l4d`/`L4D_API_VERSION` means the wrong/older host is running. Reload after updating the native host; copying docs or examples only does not update a loaded DLL.

## Aim activation and indicators

`l4d.keybind(id [, action [, mode]])` manages `aim.key` (Legit), `aim.rage.key` (Rage), `trigger.key` (Legit), or `trigger.rage.key` (Rage). It returns `key, mode, capturing, waiting`. Actions are `"capture"` (wait 500 ms, release all keys, then accept a fresh press), `"clear"`, or `"mode"` with 0 Always, 1 Toggle, 2 Hold, 3 Hold to disable. Escape cancels, Delete clears, and losing focus cancels capture. The built-in pages use native `ui.button` and `ui.combo` controls. Bindings persist through the regular config system; scripts can also assign them using `features.bind`.

Aim and trigger keys start unassigned with Hold mode selected. An unassigned key preserves the existing master switch behavior. A bound key is an additional activation condition: it cannot enable a disabled master switch. Aim's Only while firing and Silent/pSilent firing requirements still apply. The 500 ms delay applies to assigning a key, not to firing or aiming.

`aim.rage.circle`, `aim.rage.snapline`, `aim.rage.dot` and the corresponding `aim.legit.*` features have independent switches and RGBA colors. They start off. Enable the main aim switch and select that profile to render its indicators. The FOV circle uses the current camera projection, including zoom and aspect ratio. Its radius represents the configured angular targeting limit; wide cones can extend beyond the viewport, and at 90 degrees or more the boundary is behind the camera. Snapline and dot follow the actual selected aim point only while aim is active; stale, invalid or mismatched-profile targets disappear. They do not depend on ESP being enabled. pSilent retains the most recent shot point during its following packet-flush command without extending the 250 ms expiry.

### Independent combat profiles

Ragebot and Legitbot retain separate enable switches, keys, target filters, modes, aim points, ranges and weapon controls. Viewing a tab does not change the active profile; use its explicit profile button. `aim.profile` remains 0 Legit / 1 Rage. Legacy `aim.enabled`, `aim.mode`, `aim.key`, `aim.point`, `aim.range`, `aim.lock`, `aim.attack`, `aim.visible`, `aim.common`, `aim.special`, `aim.witch`, `aim.survivors` and `weapon.no_recoil` / `weapon.no_spread` now address Legit. The Rage equivalents insert `rage.` after `aim.` or `weapon.`. Angular limits retain `aim.legit` / `aim.rage` for compatibility. Triggerbot has separate `trigger.*` (Legit) and `trigger.rage.*` (Rage) settings, including enable, activation key, delay, range, target filters and hitboxes. Both use the active `aim.profile`; viewing either page does not change it. Each page edits its own profileâ€™s weapon controls. Schema-3 migration copies older shared trigger settings into both profiles and converts Head only into the Head selector.

Old shared configurations are copied into Rage once when loaded; new profiles persist each side independently. Silent and pSilent use exact head/chest hitbox shot angles. Smoothing applies only to Legit Camera mode. Animated aim points do not depend on ESP/skeleton being enabled. Trigger eligibility rejects known-dead entities but does not treat missing common-infected health properties as zero.


### Combat target dropdowns

Ragebot, Legitbot and both Triggerbot pages use a multi-select Targets dropdown. Click Common infected, Special infected, Witch or Survivors to toggle its highlight; the popup stays open for further selections. Clicking outside or pressing Escape closes it. The dropdown edits the existing `common`, `special`, `witch` and `survivors` booleans under `aim.`, `aim.rage.`, `trigger.` or `trigger.rage.`. Existing configs and script-set values carry over, and each profile retains independent selections. The generic Lua control is `ui.multi_combo(label, booleanArray, labels)`.

### Combat hitbox selectors

`l4d.setting(id, "style", selection)` supports `aim.point`, `aim.rage.point`, `trigger.hitbox` and `trigger.rage.hitbox`:

| Value | Selection | Model hitgroups |
| --- | --- | --- |
| 0 | Upper body | Head, chest and stomach |
| 1 | Chest | Chest only |
| 2 | Head | Head only |
| 3 | Stomach | Stomach only |
| 4 | Arms | Left and right arms |
| 5 | Legs | Left and right legs |
| 6 | Nearest (aim) / All (trigger) | All available hitboxes; aim ranks their centers by crosshair angle |

Aim resolves centers from the entityâ€™s current hitbox set and animated bone matrices, then chooses the closest eligible point inside the FOV and range. With Visible only enabled it tries another selected point when the closer point is obstructed. It never substitutes another region when a strict selection is missing. One bone setup is shared by all candidate points for that entity; no limb-specific bone indices are assumed between L4D1/L4D2 models. Lock on keeps the entity while rechecking its selected hitboxes each command.

Triggerbot filters the actual shot trace hitgroup, without moving the crosshair. Changing profile or hitbox selection restarts its reaction delay. The legacy `trigger.head` and `trigger.rage.head` script toggles still override the selector while enabled; explicitly writing the corresponding hitbox selector clears that override.

```lua
l4d.setting("aim.point", "style", 2)             -- Legit: head
l4d.setting("aim.rage.point", "style", 6)        -- Rage: nearest hitbox center to the crosshair
l4d.setting("trigger.hitbox", "style", 1)       -- Legit Triggerbot: chest
l4d.setting("trigger.rage.hitbox", "style", 0)  -- Rage Triggerbot: upper body
```


## World skies and animated chams

All effects below are disabled initially and participate in normal configs and hotkeys.
`aim.point` and `aim.rage.point` style `6` are displayed as **Nearest**: all current hitbox centers ranked by angular distance from the crosshair. Triggerbot retains **All** at the same numeric value; it filters the hitgroup intersected by its firing trace.

| Setting ID | Field | Values |
|---|---|---|
| `world.skybox` | `style` | 0 Galaxy, 1 Blue nebula, 2 Crimson nebula, 3 Dawn, 4 Storm, 5 Aurora, 6 Bloodmoon, 7 Synthwave, 8 Frost, 9 Toxic, 10 Sunset, 11 Noir |
| `world.sky_brightness` | `distance` | 0.1â€“2, default 1 |
| `world.sky_speed` | `distance` | 0.05â€“1 Hz, default 0.1 |
| `world.pulse_speed` | `distance` | 0.05â€“1 Hz, default 0.2 |
| `world.pulse_amount` | `distance` | 0â€“0.8, default 0.2 |
| `chams.animation` | `style` | 0 Color wave, 1 Breathing, 2 Shimmer |
| `chams.animation_speed` | `distance` | 0.05â€“3 Hz, default 0.3 |
| `chams.animation_amount` | `distance` | 0â€“1, default 0.65 |

Toggle `world.skybox`, `world.sky_animation`, `world.pulse` and `chams.animation` with `features.set`. Use `features.color` on `world.sky_animation` or `chams.animation` for the accent color. The color-wave mode blends toward that accent; breathing/shimmer modulate the selected material brightness. Existing opacity and rainbow controls still work.

Chams material indices 0â€“13 are unchanged. **12 Galaxy** uses a galaxy texture; **13 Galaxy flow** scrolls that texture. New presets: **14 Lightning**, **15 Lightning overlay** (additive), **16 Plasma flow**, **17 Aurora**, **18 Molten**. Select each target's visible/invisible material independently. TextureScroll animates the new textures; color-animation speed does not change their preset scroll rates. White pass tint preserves texture colors. Use `features.set("chams.overlay", true)` to show the original model beneath Lightning overlay.

```lua
features.set("world.skybox", true)
l4d.setting("world.skybox", "style", 0)
l4d.setting("world.sky_brightness", "distance", 0.8)
features.set("chams.enabled", true)
features.set("chams.held", true)
features.set("chams.held.custom", true)
l4d.setting("chams.held.custom", "style", 13)
features.color("chams.held.custom", 1, 1, 1, 1)
features.set("chams.animation", true)
l4d.setting("chams.animation", "style", 0)
features.color("chams.animation", 0.3, 0.8, 1, 1)
```

Galaxy assets are supplied under `materials/scooby_l4d_vfx_v1`. The host installs only this namespace into the detected game's material directory. Galaxy skies need a compatible map skybox; indoor maps can hide the sky. LDR, HDR and RGBS sky textures are handled separately. Legacy three-exposure HDR skies are left unchanged. Texture bindings and colors are restored when disabled, on level shutdown and on Stop. World breathing is limited to eight material updates per second; sky-only animation never rewrites unchanged world materials.

```lua
-- Lightning weapon and iridescent arms, independently configured.
features.set("chams.enabled", true)
features.set("chams.held", true)
features.set("chams.held.custom", true)
l4d.setting("chams.held.custom", "style", 14)
features.color("chams.held.custom", 1, 1, 1, 1)
features.set("chams.arms", true)
features.set("chams.arms.custom", true)
l4d.setting("chams.arms.custom", "style", 17)
features.color("chams.arms.custom", 1, 1, 1, 1)
```

### Radar type colors

Visuals > Radar > Type colors edits independent radar dot RGBA for 19 L4D categories. Enable **Use type colors**, choose a type, then enable its **Override color**. Per-type keys use the existing keybind modes. Reset category restores only the selected color/override/binding. These controls do not change ESP colors or visibility filters.

Enable the radar with `features.set("overlay.radar", true)` and type coloring with `features.set("radar.type_colors", true)`. Type IDs are `radar.color.` followed by `survivors`, `common`, `uncommon`, `witch`, `smoker`, `boomer`, `hunter`, `spitter`, `jockey`, `charger`, `tank`, `unknown`, `weapons`, `melee`, `throwables`, `medical`, `ammo`, `upgrades`, or `carryables`. Each supports `features.set`, `features.color` and `features.bind` independently. `l4d.setting("radar.selector", "style", index)` selects the editor only, with indices 0â€“18 in that order.

```lua
features.set("overlay.radar", true)
features.set("radar.type_colors", true)
features.set("radar.color.tank", true)
features.color("radar.color.tank", 1, 0.15, 0.2, 1)
features.color("radar.color.medical", 0.3, 1, 0.5, 0.85)
-- Disabled overrides inherit the native Radar Team/Enemy colors.
features.set("radar.color.common", false)
```

The master defaults off. Host schema 6 saves colors, override states, keys and the selected type. Loading an older/partial profile clears absent radar activation/bindings and restores absent type defaults; explicit radar entries are preserved. The existing survivor/infected/pickup, death, ownership and range checks still decide which contacts exist. The adapter uses its existing verified classification and does not infer relationships from display names. Zero alpha hides that contact, including its dot outline/name. Invalid host colors fall back safely. Settings are shared between L4D1 and L4D2; unavailable types simply produce no contacts.

### Radar portrait icons

`radar.icons` enables framed portraits/type icons instead of dots. It defaults on for new profiles; profiles without this ID retain dots. Eight stock survivors use their matching portrait. Infected, weapons and supplies use their type icon, with a generic survivor icon for unrecognized custom player models. Frames use the existing independent radar color, and its alpha also controls the portrait. Zero alpha still hides the whole contact. Icons remain upright as the radar rotates.

```lua
features.set("radar.icons", true)
l4d.setting("radar.icon_size", "distance", 24) -- 12..40 design pixels
features.color("radar.color.tank", 1, 0.15, 0.2, 1)
-- Revert to the existing dots:
features.set("radar.icons", false)
```

Host schema 7 saves icon mode/size through the ordinary feature config. The controls are in Visuals > Radar > Radar icons. Portrait images are embedded in the module and uploaded with the managed UI texture; no separate image folder, Steam avatar request or per-contact file access is required.

## VFX library and previews

The dedicated **VFX** sidebar page contains **Presets**, **Sky**, **Lighting**, and **Materials**. Existing `world.*` and `chams.*` IDs are retained. Selecting a sky card selects its saved style; **Apply preset** also enables the sky and coordinated world/prop/sky colors. Restore world disables those overrides and both world animations. A material card changes only the selected target/layer's material, preserving switches, colors and bindings.

New appended chams IDs: **19 Dark Matter**, **20 Acid**, **21 Vortex**, **22 Hologram** (additive), **23 Frost**, **24 Inferno**, **25 Circuit** (additive), **26 Pearl**. All use the existing engine TextureScroll proxy. Color-animation speed changes color/opacity animation; texture flow uses its material's fixed scroll rate.

`l4d.vfx_card(kind, style, selected [, width, height, animate, pass_id, caption])` draws an interactive texture card inside a UI drawing callback and returns whether it was clicked. `kind` is `"sky"` (styles 0â€“11) or `"material"` (styles 12â€“26). Width is 16â€“1200 pixels; height is 16â€“800. Optional `caption` adds a label footer and selected-state checkmark inside the clickable card; its height is included in the requested height. Optional `pass_id` applies that layer's color and custom animation to the material preview. The preview is a texture swatch; model UVs, scene lighting and post-processing determine the final game appearance. Do not call from loading or update callbacks. Preview images share the managed font-atlas lifecycle; script shutdown releases their rectangles.

Sky replacement scans once per second for late-loaded map materials, accepts custom material paths and case-insensitive face suffixes, and can derive the face from a texture name. Original material/texture references survive queued restoration. No shader layout is guessed for a custom map: unsupported face names or legacy three-exposure HDR remain unmodified. Maps without visible sky geometry cannot display a skybox override.


## Custom material library

`l4d.user_materials([action])` returns `entries, folder, errors`. Each entry contains `id`, `name`, `animated`, `installed` and `preview`. An omitted action reads the cached library. `refresh` scans files, `open` opens the active materials folder, and `example` copies the bundled example without overwriting user files. These actions return readable errors in the third result.

`l4d.user_material(pass [, id])` reads or selects a custom material for a registered chams layer, such as `chams.held.custom`, `chams.held.hidden` or `chams.held.overlay`. ID 0 restores the built-in material. Unknown imported IDs and invalid layers are rejected. Saved missing selections keep their ID and render with the built-in fallback until the file returns.

`l4d.vfx_card("user", id, selected, width, height, animate [, pass [, caption]])` draws a custom thumbnail inside a UI callback. Matching basename PNG takes priority over GIF; GIF frames use their animation delays when `animate` is true. Without either file, it uses the VTF thumbnail. PNG/GIF artwork is displayed as supplied; VTF swatches can show texture scrolling and layer tint. Refresh invalidates cached images. See `docs/USER_MATERIALS.md` in the source for supported input formats.
