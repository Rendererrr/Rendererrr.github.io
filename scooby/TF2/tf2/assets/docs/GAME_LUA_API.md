# TF2 family Lua API

Version **1.0**. `TF2_API_VERSION == "1.0"`. Each independent product owns its implementation in `src/lua_api.cpp`, headers, docs, examples and tests. Both follow the matching 1.0 Lua contract; neither includes code from the other variant. Retail exposes `tf2`; Classified exposes the same `tf2` table and the compatible alias `tf2c`. The existing portable `UI_API_VERSION`, `ui`, `imgui`, `render`, `features`, `events`, `base` and `esp_colors` APIs remain available.

Scripts run from the Lua main tab through Scripts or Lua Editor. Expand API entries in the themed API browser for signatures and examples. Bundled examples do not run automatically. Updating scripts alone cannot add bindings to an older DLL.

## Identity and capabilities

### tf2.info()

```lua
-- -> {api_version, game_id, game, map, preview, sequence, generation,
--     engine_time, tick_interval}
local info=tf2.info()
print(info.game,info.map,info.api_version)
```

`game_id` is `tf2` or `tf2_classified`. Time is engine seconds. Sequence increases per engine capture; generation changes across map/session transitions. Neither value is a persistent entity identifier. Preview reports the actual product identity with `preview=true`.

### tf2.capabilities()

```lua
-- -> {snapshots, projection, settings, shared_ui, four_teams,
--     civilian, mvm, viewmodel_offsets, native_hooks}
local caps=tf2.capabilities()
if caps.civilian then print(tf2.class_name(10)) end
```

Capabilities describe implemented host surfaces, not completed native acceptance. Four teams/Civilian belong to Classified; MvM/viewmodel offsets belong to retail. Raw native hooks are not supplied by this extension. Detect individual built-in settings with `tf2.has_feature(id)`.

### tf2.session()

```lua
-- -> {allowed, data_available, in_game, preview, stopped, menu_open, entity_count}
local state=tf2.session()
if state.data_available then print(state.entity_count) end
```

Game queries use the existing local-session gate. Preview has no live game data. Missing local player, disconnect, an ineligible session or Stop makes entity/player/projection queries empty or nil on the next captured/rendered frame. No engine pointer is exposed.

## Copied game data

All callbacks in one rendered frame read the same pinned immutable engine capture. Returned tables are independent copies; changing them does not change game memory. Ordinary entity IDs are decimal strings containing the full handle including its serial. Retail synthetic objective markers can have opaque string IDs. Reacquire data each callback and discard IDs when `generation` changes; a serial is not a cross-map lifetime guarantee.

### tf2.local_player()

```lua
-- -> {handle, team, class_id, class_name, health, alive, on_ground, flags,
--     position, eye_position, velocity, view_angles, speed, sequence, generation} or nil
local me=tf2.local_player()
if me then print(me.class_name,me.health,me.speed) end
```

Vectors use Source units with Z up. Angles use `{x=pitch,y=yaw,z=roll}` in degrees. Speed is horizontal Source units/second. Unknown weapon, ammo and attribute fields are not synthesized.

### tf2.entities([filter])

```lua
-- filter = {kind='all', relationship='all', max_distance=metres}
for _,entity in ipairs(tf2.entities{kind='player',relationship='enemy',max_distance=150}) do
    print(entity.handle,entity.name,entity.distance_m)
end
```

The list contains recognized, non-dormant entities already collected by the host, independently of the built-in ESP master switch. It is not an enumeration of every Source class. Local player is separate; dead players and unsupported classes are omitted. `kind` is player/npc/item/weapon/prop/unknown. `relationship` is friendly/enemy/neutral/normal/unknown. Unknown kind/relation values return an empty list; unknown filter keys and non-finite/range types error. `max_distance` clamps to 0..1e9 metres.

Entity fields: `handle`, `name`, `kind`, `relationship`, `alive`, `teammate`, `position`, `bounds_min`, `bounds_max`, `distance_m`, `sequence`, `generation`, `bones_available`, optional `health`/`max_health`. Native entities also supply `team`, `class_id`, `class_name`, `network_class`, `type`. Synthetic retail objectives can omit metadata. Bounds are absolute Source-space AABB corners. Names are actual player names or the host's display labels. Classification only promises recognized per-title types.

### tf2.entity(handle)

```lua
-- Decimal string, opaque ID, or unsigned 32-bit full numeric handle -> entity or nil
local list=tf2.entities()
if list[1] then print(tf2.entity(list[1].handle).name) end
```

### tf2.bones(handle)

```lua
-- -> array of {from={x,y,z}, to={x,y,z}}
local entities=tf2.entities{kind='player'}
if entities[1] then print(#tf2.bones(entities[1].handle)) end
```

Bones are available only when the host captured the pose for built-in ESP/aim; a Lua query does not enable expensive bone collection. Segments are copied world positions, not a promise of stable engine bone indices.

### tf2.condition(handle, index)

```lua
-- index 0..159 -> boolean; false for unavailable/non-player data
local entities=tf2.entities{kind='player'}
if entities[1] then print(tf2.condition(entities[1].handle,4)) end
```

Indices address the copied five TF condition bitfields. The meaning of extended conditions can differ by edition; verify title-specific indices before use.

## Camera and projection

### tf2.camera()

```lua
-- -> {position, angles, width, height} or nil
local camera=tf2.camera()
if camera then print(camera.width,camera.height) end
```

Position is the captured eye and angles are the engine view; projection uses the renderer matrix and can differ in spectator views. Screen values use the same client-pixel coordinates as `render.*`, not menu design units.

### tf2.world_to_screen(position)

```lua
-- Source {x,y,z} -> {x,y,on_screen} or nil
ui.overlay('tf2_player_labels',function()
    for _,e in ipairs(tf2.entities{kind='player'}) do
        local p=tf2.world_to_screen(e.position)
        if p and p.on_screen then render.text(p.x,p.y,e.name,{1,1,1,1}) end
    end
end)
```

Behind-camera/depth-invalid input returns nil. Offscreen lateral points can return `on_screen=false`. Projection does not test line-of-sight or wall occlusion.

### tf2.screen_box(handle)

```lua
-- -> {left,top,right,bottom,width,height,fitted} or nil
ui.overlay('tf2_box_example',function()
    for _,e in ipairs(tf2.entities{kind='player',relationship='enemy'}) do
        local b=tf2.screen_box(e.handle)
        if b then render.rect(b.left,b.top,b.width,b.height,{.2,.8,1,1}) end
    end
end)
```

Uses canonical hitbox fitting, near-plane clipping and viewport handling. `fitted=true` means the capture had animated hitbox boxes; otherwise the current bounds fallback is used. Bone/pose availability follows the host capture policy above.

## Settings and input

### tf2.setting(id, field [, value])

```lua
-- field 'style' or 'distance' -> normalized numeric value
local old=tf2.setting('view.camera_fov','distance')
tf2.setting('view.camera_fov','distance',100)
features.set('view.camera_fov',true)
```

Uses the feature's own numeric limits. Style indices are zero-based, clamped, then truncated. Distance is a generic numeric slot: units depend on the ID (degrees for FOV, metres for range, seconds for trigger delay). Changing a value does not enable its feature. Invalid IDs/fields/non-finite input raise Lua errors. Discover IDs through `features.list()` and use portable APIs for enabled state/colors/hotkeys/configuration.

### tf2.has_feature(id)

```lua
-- -> boolean; useful for edition-specific controls
if tf2.has_feature('mvm.wave_panel') then features.set('mvm.wave_panel',true) end
```

### tf2.keybind(id [, action [, mode]])

```lua
-- -> key, mode, capturing, waiting
-- actions: 'capture', 'clear', 'mode'; modes: 0 Hold, 1 Toggle, 2 Always
local key,mode=tf2.keybind('aim.key')
print(key,mode)
```

Only independent combat activation IDs are accepted. Capture waits 500 ms before accepting a key. Clearing/changing modes resets the transient latch. Settings written to existing features remain after stopping a script and participate in normal profile persistence.

### tf2.object_preview(kind, chams)

```lua
-- UI callback only. kind: "weapons", "health", "ammo", "items".
-- false uses the selected object's ESP settings; true uses chams.target.
ui.subtab("visuals", "custom.weapons", "Weapons", function()
    tf2.object_preview("weapons", false)
end)
```

### tf2.model_preview(chams)

```lua
-- UI callback only; draws the product's actual class model preview
local tab=ui.tab('model_inspector','Model inspector')
ui.subtab(tab,'model','Model',function() tf2.model_preview(false) end)
```

Both products provide this host-owned drawing callback. Available class models differ by title. It is a UI preview, not an entity or gameplay API. Classified's Scientist mesh is a preview asset, not a playable class ID.

## Names and math

### tf2.class_name(id), tf2.team_name(id)

```lua
print(tf2.class_name(1),tf2.team_name(2)) -- Scout, RED
```

Classes 1..9 use the Source TF order. Classified additionally maps 10 to Civilian, teams 4/5 to GRN/YLW. Retail maps only RED/BLU. Unsupported IDs return `Unknown`.

### tf2.vec

```lua
local a={x=3,y=4,z=0}
local b={x=1,y=0,z=0}
local sum=tf2.vec.add(a,b)
local difference=tf2.vec.sub(a,b)
local scaled=tf2.vec.scale(a,2)
local dot=tf2.vec.dot(a,b)
local length=tf2.vec.length(a)
local distance=tf2.vec.distance(a,b)
local unit=tf2.vec.normalize(a) -- nil for near-zero length
```

### tf2.angle_to(eye, point), tf2.angle_fov(from, to)

```lua
local angles=tf2.angle_to({x=0,y=0,z=0},{x=100,y=0,z=50})
local degrees=tf2.angle_fov({x=0,y=0,z=0},angles)
```

Coincident positions return nil from `angle_to`. Angular distance uses the two view directions, in degrees. These pure functions do not write game commands.

### tf2.to_metres(units), tf2.to_units(metres)

```lua
local metres=tf2.to_metres(100)
print(metres,tf2.to_units(metres))
```

One Source unit is treated as .0254 metres. Numeric/vector inputs must be finite and within +/-1e9.

## Built-in feature families

| Family | IDs |
| --- | --- |
| Aim profiles | `aim.*`, `aim.rage.*`, `combat.profile` |
| Trigger profiles | `trigger.*`, `trigger.rage.*` |
| Movement/view | `movement.bhop`, `movement.strafe`, `view.camera_fov`, `view.model_fov` |
| Player ESP | `esp.*`, `esp.teammate.*` |
| Item ESP | `esp.world.health.*`, `esp.world.ammo.*`, `esp.world.weapons.*` |
| Chams targets | `chams.players`, `teammates`, `self`, `arms`, `weapon`, `world_weapon`, `buildings`, `items`, `dropped_weapons` |

Every chams target has `.visible`, `.hidden` and `.overlay` features with independent enabled states/colors. Material style: 0 Flat, 1 Lit, 2 Wireframe. Each layer also has `.animation` (0 Static, 1 Pulse, 2 Rainbow), `.speed` and `.strength`. `world_weapon` is the local player's held world model, verified through weapon receive-table ancestry; `dropped_weapons` is separate. Product-only Stop IDs remain `tf2.stop` / `tf2c.stop`. Additional retail world/mode controls remain retail-only.


### Misc controls and player details

`tf2.toggle_control(feature_id)` draws a registered feature checkbox, its label and a keybind/settings gear, without a color picker. Use it inside a UI drawing callback. Classified exposes the same function through `tf2c`.

View and Movement now live under Misc (`misc.view`, `misc.movement`). The original `self/view` and `movement/movement.main` Lua routes remain registered for existing scripts. Existing `view.*` and `movement.*` feature IDs are unchanged. Both editions expose `view.model_offset`, `view.offset_x/y/z` (right/forward/up, -60..60 Source units), and `view.angle_pitch/yaw/roll` (-180..180 degrees). Camera/model overrides update while the menu is open; gameplay input remains captured by the menu.

Additional movement settings: `movement.air_jump` preserves a deliberate Scout release/press in the air; holding jump still performs bunny hop. `movement.strafe_direction.style` is 0 for View/mouse or 1 for Movement keys. These settings retain the existing per-feature keybind/config behavior.

Player ESP supports `class`, `weapon`, `conditions`, `hide_cloaked`, `hide_disguised`, and `details` under both `esp.` and `esp.teammate.`. The `details` feature stores label color and text size; the individual information toggles control visibility. Details obey the corresponding player ESP master and range. Configure them in the player preview settings gear. Entity snapshots optionally include `weapon_item_id` and `weapon_class` when active-weapon telemetry has been requested by either player ESP weapon toggle and the host resolved a valid weapon. Unavailable weapon IDs are omitted.
