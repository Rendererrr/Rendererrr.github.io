# blueshift host API

## blueshift.session()

`blueshift.session() -> string`

```lua
print(blueshift.session())
```

## blueshift.entities()

`blueshift.entities() -> table`

```lua
for _, entity in ipairs(blueshift.entities()) do
    print(entity.index, entity.name, entity.distance, entity.on_screen)
end
```

## blueshift.setting(id, field [, value])

`blueshift.setting(id, field [, value]) -> number`

```lua
blueshift.setting("bs.combat.fov", "distance", 15)
blueshift.setting("bs.combat.aim", "style", 0)
blueshift.setting("chams.animation", "style", 1)
```

## blueshift.campaign.identity()

`blueshift.campaign.identity() -> table`

```lua
local i = blueshift.campaign.identity()
print(i.game, i.profile, i.platform, i.server_sha256)
```

## blueshift.campaign.capabilities()

`blueshift.campaign.capabilities() -> table`

```lua
local caps = blueshift.campaign.capabilities()
print(caps["player.godmode"].supported, caps["player.godmode"].available)
```

## blueshift.campaign.has(name)

`blueshift.campaign.has(name) -> boolean`

```lua
print(blueshift.campaign.has("player.no_reload"))
```

## blueshift.campaign.status()

`blueshift.campaign.status() -> table`

```lua
local s = blueshift.campaign.status()
print(s.active, s.map, s.health, s.armor, s.clip, s.tracked, s.message)
```

## blueshift.campaign.catalog()

`blueshift.campaign.catalog() -> table`

```lua
for _, entry in ipairs(blueshift.campaign.catalog()) do
    print(entry.id, entry.label, entry.kind)
end
```

## blueshift.campaign.spawn(id, count, distance)

`blueshift.campaign.spawn(id, count, distance) -> boolean, string`

```lua
local ok, result = blueshift.campaign.spawn("weapon_crowbar", 1, 128)
print(ok, result)
```

## blueshift.combat.capabilities()

`blueshift.combat.capabilities() -> table`

```lua
local caps = blueshift.combat.capabilities()
print(caps.lock_on.supported, caps.silent.available, caps.psilent.state)
```

## blueshift.combat.status()

`blueshift.combat.status() -> table`

```lua
local s = blueshift.combat.status()
print(s.target, s.trigger_target, s.weapon_ready, s.state)
```

## blueshift.movement.capabilities()

`blueshift.movement.capabilities() -> table`

```lua
local caps = blueshift.movement.capabilities()
print(caps.bunny_hop, caps.auto_strafe)
```

## blueshift.view.capabilities()

`blueshift.view.capabilities() -> table`

```lua
local caps = blueshift.view.capabilities()
print(caps.third_person, caps.fov, caps.model_fov, caps.offsets)
```

## View settings

```lua
blueshift.setting("bs.view.fov", "distance", 100)
blueshift.setting("bs.view.model_fov", "distance", 110)
blueshift.setting("bs.view.x", "distance", 0)
blueshift.setting("bs.view.y", "distance", 0)
blueshift.setting("bs.view.z", "distance", 0)
```
