# Runtime data

The host supplies the data root. The preview defaults to `%LOCALAPPDATA%/Scooby/SimpleBase`.

```text
configs/          JSON profiles
scripts/          Editable .lua files
  Welcome.lua
  Custom UI.lua
  Standalone Menu.lua  Bundled samples copied when absent; existing edits are preserved
default.txt       Name of the startup profile
welcome-seen.txt  "hide" or "show" for the welcome screen
```

Config `schema` is currently `1`. `features` maps stable IDs to enabled/favorite state, bind key/mode, RGBA color and feature options. `interface` stores scale preferences, language, menu key, auto-save and radar position. The optional `overlays` object stores watermark content, binds visibility/dragging/position and radar appearance/behavior. Profiles written before this object existed still load. Missing optional fields retain their current/default values. Modes serialize as `0 = Always`, `1 = Toggle`, `2 = Hold`, `3 = Hold to disable`.

The config loader rejects unsupported versions, malformed types and non-finite values, clamps numeric ranges, and applies changes only after all fields validate. Files are limited to 2 MB. Lua execution accepts at most 1 MB of source. Names are restricted to safe filenames and device names/path traversal are rejected.

Writes go to a sibling temporary file and atomically replace the destination. Failed writes leave the previous file intact. Auto-save starts only with an active profile, waits 750 ms after the last change, and flushes on menu close and application shutdown. A write error is shown and retried after another change or an explicit save; deleting the active profile stops auto-save from recreating it.

A profile becomes active after Create, Load or Save. **Set as default** controls which profile loads next launch. These are separate actions. Renaming updates active/default references. Import validates clipboard JSON and creates a new file; it does not silently apply it. Export copies the selected profile to the clipboard.

Hotkey hold states are transient and never serialized as permanent feature settings. Lua drafts are retained while switching files/tabs during the session; save the script to keep edits after exit. Closing the window flushes configs when auto-save is enabled, but does not silently save Lua drafts.


## Interface and overlay preferences

The existing schema-1 `interface` object also stores `text_scale`, `tab_text_scale`, `subtab_text_scale`, `heading_text_scale` (0.75–2.0), `custom_accent`, `accent` (RGBA) and `descriptions`. The UI renders the accent opaque so controls stay visible. Missing fields preserve current/default values. Malformed types/shapes and non-finite settings reject the entire load without partial changes; bounded finite color/numeric values are clamped.

`overlays.watermark` stores `draggable` and a normalized `[x, y]` `position`. A negative x restores the top-right default. Watermark, hotkeys and radar are draggable by default while the menu is open; saved lock preferences remain respected. Positions are clamped for the current viewport without rewriting them during a resize.

UI and overlay scale values remain 0.25–2.0 but now multiply a 0.75 design baseline. The text multipliers affect ordinary labels, sidebar tabs, sub-tabs and headings separately; they do not alter Lua syntax text or world-space ESP.


`overlays.active_features` stores `draggable`, `sort_by_width`, `accent_bar`, `alignment` (0 left, 1 right), `text_size` (10–24), `spacing` (0–12), `background_opacity` (0–1), and normalized `position`. Negative x selects bottom-left automatic placement. Enable state, color and binding belong to `features["overlay.active_features"]`. These optional fields retain schema-1 compatibility and participate in profile saving and auto-save.


ESP feature entries have an optional `appearance` object: `gradient`, `gradient_color` (RGBA), `gradient_direction` (0 vertical, 1 horizontal), `outline`, `outline_color`, `outline_thickness` (0.5–3), `fill_color`, `fill_gradient`, `fill_gradient_color`, `bar_background`, `position` (0 top, 1 bottom, 2 left, 3 right), `offset` (0–30), and `snapline_origin` (0 top, 1 bottom, 2 center). All color components are bounded to 0–1; malformed color values, invalid types, non-finite numbers and invalid appearance enums reject the complete load; bounded finite numeric components are clamped. Existing `filled`, `style`, `thickness`, `text_size` and primary `color` fields remain compatible. Legacy box profiles without `appearance` derive their fill from the primary color at the original 12% opacity. Default name/distance/health placements remain top/bottom/left.
