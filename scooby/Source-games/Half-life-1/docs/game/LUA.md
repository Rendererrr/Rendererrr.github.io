# Half-Life host API

The portable Lua/UI API remains available. The visual extension is read-only except for bounded feature settings. The versioned campaign extension adds explicit local actions described below.

- `halflife.session()` returns the current gate explanation.
- `halflife.entities()` returns a copied list of current allowed-session entities: index, name, distance in metres and whether bounds could be projected. Off-viewport projected bounds may still report on_screen; this is projection availability, not visibility through geometry. An inactive/remote/demo session returns an empty list.
- `halflife.setting(id, "style" [, value])` gets/sets a bounded registered style.
- `halflife.setting(id, "distance" [, value])` gets/sets the registered numeric range.

No engine pointers, memory access, arbitrary game commands or network operations are exposed.

NPC labels are model-based. The stock network data does not provide reliable NPC health or faction changes; neither is invented. Campaign interactables use the current BSP's inline model/class mapping and only received current client entities.


Animated chams settings: `halflife.setting("chams.animation", "style", 0)` selects Pulse (1 = Color fade, 2 = Rainbow); `chams.animation_speed` uses `distance` in cycles/sec, bounded 0.05–3; `chams.animation_strength` uses `distance`, bounded 0–1. Enable the registered animation/model-material features through the shared feature API. The animation feature color is the fade accent. These settings persist in configs.


## Campaign API 1.0.0

`halflife.campaign.identity()` returns API version, stable game `half_life`, runtime `steam`, engine `goldsrc`, active mode, exact server profile/hash, x86 architecture, OpenGL renderer and Windows/Wine environment. The existing `halflife` namespace remains; this scoped adapter API does not claim complete loader API compatibility.

`halflife.campaign.capabilities()` returns per-capability `supported`, `available`, `state` and `reason`. `has(name)` is true only for recorded acceptance for this exact profile/platform; pending implementation and a detected Wine runtime are not support evidence. Capabilities are `player.godmode`, `player.noclip`, `player.infinite_ammo`, `player.no_reload`, `player.super_run`, `player.jump`, `player.refill`, `spawn.weapon`, `spawn.item`, `spawn.npc`. Unknown names return false. Mode/session availability is separate from completed implementation evidence.

`status()` returns copied session/generation, active weapon, health/armor/clip, prepared-catalog status, tracked count and actual action-result text. It exposes no server pointers or mutable entity handles. `catalog()` returns bounded title-specific IDs/labels/kinds. `spawn(id, quantity, distance)` queues only a catalog entry (quantity 1..8, forward distance 64..512 game units); its boolean means queued, not spawned. Inspect `status()` for the authoritative result. The caller cannot inject arbitrary classnames or commands. Spawning requires the catalog to have been prepared during map loading; after first attach, reload a map or load a saved game once. The verified original server restore callback also prepares the catalog during loading.

The shared feature API controls `hl.campaign.god`, `.noclip`, `.infinite_ammo`, `.no_reload`, `.super_run`, `.jump`, `.refill_health`, `.refill_armor`, `.cleanup`. Run/jump multipliers use the registered `distance` numeric setting, bounded 1..3 and 1..2.5 respectively. Configs and hotkeys preserve independent toggles. Reserve ammo maintains supported owned-weapon pools; no reload maintains a supported active magazine and skips clipless/melee. Existing reloads finish before magazine control begins. Disable restores captured ammo/clip values; run/jump adjust each movement call without changing global cvars. Refill actions are explicit changes to the current player.

Map changes, death/save restoration, disconnect and Stop clear/rebind transient state. Temporary world roots are tracked by map generation, edict serial and object identity. Cleanup touches only those roots; picked-up weapons leave cleanup ownership and remain in the inventory. Temporary world roots are excluded from saves; player/weapon fields are serialized with captured toggle baselines. Ordinary map entities are never selected by cleanup.

`-scooby-campaign-test` is an explicit local acceptance mode with a small file-command allowlist; it is not a public Lua memory/console interface or proof of platform support. Normal launches omit it. Evidence and current acceptance status are in `ports-handoffs/halflife.md`.
