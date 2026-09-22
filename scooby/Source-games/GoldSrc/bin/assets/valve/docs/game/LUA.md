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
