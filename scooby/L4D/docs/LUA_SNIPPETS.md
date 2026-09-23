# L4D1 & L4D2 snippets

Select code and press Ctrl+C. Click a snippet and press Ctrl+A to select it all. Paste into Lua > Editor and run each example separately.

## Game and player HUD

Show the current game, health and movement speed. Player data can be absent while loading.

```lua
ui.overlay("player_hud", function()
  local game = l4d.info()
  render.text(20, 40, game.game, {1,1,1,1})
  local p = l4d.local_player()
  if not p then return end
  local label = string.format(
    "HP %d | Speed %.0f", p.health, p.speed)
  render.text(20, 60, label, {0.4,0.8,1,1})
end)
```

## Custom feature and hotkey

Add a configurable toggle to your own page. Registered features keep their state and hotkey in configs.

```lua
local toggle = features.add {
  id = "example", label = "My feature",
  category = "My tools", default = false,
  key = "F8"
}
local tab = ui.tab("tools", "My tools")
ui.subtab(tab, "main", "General", function()
  ui.group("Options", function()
    ui.feature(toggle)
  end)
end)
ui.overlay("status", function()
  if features.active(toggle) then
    render.text(20, 90, "Enabled", {0,1,0,1})
  end
end)
```

## Player chams overlay

```lua
features.set("chams.enabled", true)
features.set("chams.survivors", true)
features.set("chams.visible", true)
l4d.setting("chams.visible", "style", 1)
features.color("chams.visible", 1, 0.1, 0.1, 1)
features.set("chams.survivors.overlay", true)
l4d.setting("chams.survivors.overlay", "style", 15)
features.color("chams.survivors.overlay", 1, 1, 1, 0.8)
```

## Special infected names

Subscribe only to the data you need. Subscriptions are released when the script stops. Witch is separate from special infected.

```lua
l4d.watch {
  infected = true, survivors = false,
  pickups = false, range = 60
}
ui.overlay("specials", function()
  local targets = l4d.entities {special=true}
  for _, e in ipairs(targets) do
    local p = l4d.world_to_screen(e.position)
    if p and p.on_screen then
      render.text(p.x, p.y, e.name,
        {1,0.4,0.3,1})
    end
  end
end)
```

## Dropped weapons and items

Draw native projected boxes for unowned pickups. Change type to "medical", "ammo" or "melee" to filter the query.

```lua
l4d.watch {
  infected = false, survivors = false,
  pickups = true, range = 40
}
ui.overlay("pickups", function()
  local items = l4d.entities {type="weapons"}
  for _, e in ipairs(items) do
    local b = l4d.screen_box(e.index)
    if b then
      render.rect(b.left, b.top,
        b.width, b.height, {0.3,0.8,1,1})
    end
  end
end)
```

## Skeleton lines

Bone capture costs more than basic entity data. Enable it only in scripts that draw bones.

```lua
l4d.watch {
  infected = true, survivors = false,
  pickups = false, bones = true, range = 30
}
ui.overlay("bones", function()
  for _, e in ipairs(l4d.entities()) do
    for _, bone in ipairs(l4d.bones(e.index)) do
      local a = l4d.world_to_screen(bone.from)
      local b = l4d.world_to_screen(bone.to)
      if a and b and a.on_screen and b.on_screen then
        render.line(a.x, a.y, b.x, b.y,
          {1,1,1,1})
      end
    end
  end
end)
```

## Camera FOV controls

Use the existing feature toggle and a custom Scooby slider. Edits to built-in settings remain after the script stops.

```lua
local tab = ui.tab("camera", "My camera")
ui.subtab(tab, "view", "View", function()
  ui.group("Camera", function()
    ui.feature("view.camera_fov")
    local id = "view.camera_fov"
    local fov = l4d.setting(id, "distance")
    local changed, value = ui.slider(
      "FOV", fov, 60, 140)
    if changed then
      l4d.setting(id, "distance", value)
    end
  end)
end)
```

## Localized text

Translate inside the callback to follow language changes. Add the same key to each languages/<code>.json catalog; missing keys use English.

```lua
ui.subtab("settings", "my_info", "Info",
  function()
    local p = l4d.local_player()
    if not p then return end
    local format = ui.tr("Speed: %.0f units/s")
    imgui.text(string.format(format, p.speed))
  end)
```

## Full reference

The complete function signatures, fields and lifecycle rules are in docs/LUA_API.md beside your assets. Longer working examples are available in Lua > Scripts.
