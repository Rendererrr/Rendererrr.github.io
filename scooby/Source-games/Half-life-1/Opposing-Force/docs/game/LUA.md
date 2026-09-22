# Opposing Force host API

The shared Lua UI/config API is available alongside this game namespace:

- `opposingforce.session()` returns the session gate explanation.
- `opposingforce.entities()` returns copied current entities with `index`, `name`, `distance` in metres and `on_screen` projection availability. Projection does not prove visibility through geometry. Disallowed sessions return an empty list.
- `opposingforce.setting(id, "style" [, value])` reads or changes a bounded style.
- `opposingforce.setting(id, "distance" [, value])` reads or changes a bounded numeric setting.

Game features use `opfor.*`; shared ESP features retain `esp.*`. Read-only assets are staged beside this game's DLL. Writable config/script state is scoped beneath the logged user data root by game directory, engine, operating environment, exact profile and campaign mode. `SCOOBY_PORT_DATA_ROOT` can select an absolute test root; it is never an implicit fallback into another product. No engine pointers, arbitrary game commands, memory access or network API are exposed.

NPC categories describe stock model types. They do not track allegiance changes, health, life state or server-only entities. The shock roach and shock rifle share a model and keep a combined label. CTF flags/device props are identified by model, without claims about capture state, ownership, mission progress or usability.

## Campaign API (runtime acceptance pending)

The local UI host exposes `opposingforce.campaign.identity()`, `status()`, `capabilities()`, `has(name)`, `catalog()` and `spawn(id, count, distance)`. The canonical game ID is `opposing_force`; the existing Lua table remains `opposingforce`. This local host API is separate from the broader Loader Lua contract.

`capabilities()` and `has()` report the same exact-build acceptance bits used by the campaign controls. A catalog entry or successful queue operation does not establish a supported capability or a successful spawn. Inspect `status()` for the resulting message and tracked-world-object count. Current Opposing Force verification bits remain zero while its actual campaign tests are pending. Wine remains unverified.

`spawn()` accepts an audited catalog ID, quantity 1–8 and distance 64–512 game units. Map reload is required to prepare the catalog after attachment. Weapon, pickup and grounded-NPC entries are title-specific; the initial catalog excludes larger/flying/boss/scripted entities and CTF-only objects. Cleanup removes tracked tool-created world objects; picked-up weapons become normal inventory.

Campaign feature IDs use `opfor.campaign.*`: `god`, `noclip`, `infinite_ammo`, `no_reload`, `super_run`, `jump`, `refill_health`, `refill_armor` and `cleanup`. Reserve ammo and magazine refilling are separate settings. Runtime player/entity handles are never stored in presets.
