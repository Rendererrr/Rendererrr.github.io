# opposingforce host API

## opposingforce.session()

`opposingforce.session() -> string`

```lua
print(opposingforce.session())
```

## opposingforce.entities()

`opposingforce.entities() -> table`

```lua
for _, entity in ipairs(opposingforce.entities()) do
    print(entity.index, entity.name, entity.distance, entity.on_screen)
end
```

## opposingforce.setting(id, field [, value])

`opposingforce.setting(id, field [, value]) -> number`

```lua
opposingforce.setting("opfor.combat.fov", "distance", 15)
opposingforce.setting("opfor.combat.aim", "style", 0)
opposingforce.setting("chams.animation", "style", 1)
```

## opposingforce.campaign.identity()

`opposingforce.campaign.identity() -> table`

```lua
local i = opposingforce.campaign.identity()
print(i.game, i.profile, i.platform, i.server_sha256)
```

## opposingforce.campaign.capabilities()

`opposingforce.campaign.capabilities() -> table`

```lua
local caps = opposingforce.campaign.capabilities()
print(caps["player.godmode"].supported, caps["player.godmode"].available)
```

## opposingforce.campaign.has(name)

`opposingforce.campaign.has(name) -> boolean`

```lua
print(opposingforce.campaign.has("player.no_reload"))
```

## opposingforce.campaign.status()

`opposingforce.campaign.status() -> table`

```lua
local s = opposingforce.campaign.status()
print(s.active, s.map, s.health, s.armor, s.clip, s.tracked, s.message)
```

## opposingforce.campaign.catalog()

`opposingforce.campaign.catalog() -> table`

```lua
for _, entry in ipairs(opposingforce.campaign.catalog()) do
    print(entry.id, entry.label, entry.kind)
end
```

## opposingforce.campaign.spawn(id, count, distance)

`opposingforce.campaign.spawn(id, count, distance) -> boolean, string`

```lua
local ok, result = opposingforce.campaign.spawn("weapon_crowbar", 1, 128)
print(ok, result)
```

## opposingforce.combat.capabilities()

`opposingforce.combat.capabilities() -> table`

```lua
local caps = opposingforce.combat.capabilities()
print(caps.lock_on.supported, caps.silent.available, caps.psilent.state)
```

## opposingforce.combat.status()

`opposingforce.combat.status() -> table`

```lua
local s = opposingforce.combat.status()
print(s.target, s.trigger_target, s.weapon_ready, s.state)
```

## opposingforce.movement.capabilities()

`opposingforce.movement.capabilities() -> table`

```lua
local caps = opposingforce.movement.capabilities()
print(caps.bunny_hop, caps.auto_strafe)
```

## opposingforce.view.capabilities()

`opposingforce.view.capabilities() -> table`

```lua
local caps = opposingforce.view.capabilities()
print(caps.third_person, caps.fov, caps.model_fov, caps.offsets)
```

## View settings

```lua
opposingforce.setting("opfor.view.fov", "distance", 100)
opposingforce.setting("opfor.view.model_fov", "distance", 110)
opposingforce.setting("opfor.view.x", "distance", 0)
opposingforce.setting("opfor.view.y", "distance", 0)
opposingforce.setting("opfor.view.z", "distance", 0)
```
