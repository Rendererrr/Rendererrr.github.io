# Portable combat and visuals template

V1, V2 and combined standalone previews share `simple_base/features/aimbot/aimbot.hpp` and `UI/src/features/aimbot/aimbot.cpp`. The controls follow GTA4's Lock-on, Silent Aim and Triggerbot page organization. This module registers settings and draws pages; it does not hook a game, select targets, redirect shots or fire weapons.

## Port integration

```cpp
#include "simple_base/features/aimbot/aimbot.hpp"

simple_base::Application app(options);
simple_base::templates::registerCombat(app.features());
app.features().addActorEsp(); // Optional Players / NPCs / Zombies template banks.
app.initialize();            // Loads saved values after registering defaults.
auto result = simple_base::templates::installCombatPages(app);
if (!result) throw std::runtime_error(result.message);
simple_base::templates::configureTemplateNavigation(app); // Optional default layout.
```

Existing products can keep their own sidebar layout. The stable combat route is `lua:template-combat:aimbot`; subroutes are `lua:template-combat:lock-on`, `lua:template-combat:silent` and `lua:template-combat:triggerbot`. The installer chains the current `registerHostApi` callback; register host APIs before installing, or chain this callback when adding further APIs. Install once per application. Stopping the `template-combat` script removes its pages but leaves host-owned settings intact.

Feature families are `aim.*`, `silent.*` and `trigger.*`, following GTA4's setting names. Toggles use `Feature.enabled`, numbers use `Feature.distance` with declared bounds, and bone choices use `Feature.style` (Head, Neck, Chest, Nearest). Existing config serialization, reset, hotkeys and Lua feature access apply. Registration rejects any ID collision before adding features; an existing game must preserve and map its own IDs instead of blindly registering over them.

Masters default off and use independent activation with Mouse 2 / Hold. Native adapters should query `app.hotkeys().active(feature)` together with their own focus, menu, session, lifetime and capability checks. Keep all native execution and restoration in the product. Omit unsupported controls or provide the product's capability handling when adopting these settings. Template availability is not proof of game support.

## Visuals

All three previews expose Visuals > ESP > Players / NPCs / Zombies, with Radar alongside ESP. `addActorEsp()` opts into independent profiles without changing existing consumers. Player IDs remain `esp.*`; teammate, NPC and zombie banks use `esp.teammate.*`, `esp.npc.*` and `esp.zombie.*`. Each bank retains independent appearance, health/text controls, config and activation. Model preview adapters use `selectedEspPrefix()` to edit the selected bank.

Games with existing Players/NPCs/Self/Vehicles/Pickups pages retain those host-owned categories, IDs and verified telemetry. Do not fabricate actor health for objects, assume unknown relationships are hostile, or replace a game's real render adapter with the preview scene.

Preview command-line routes include `--page aimbot`, `--page silent`, `--page triggerbot`, and the existing Visuals/Radar routes. The shared `combat_template` regression tests page rendering, config persistence, collision protection and independent actor registration in each edition.

See [SOURCE_LAYOUT.md](SOURCE_LAYOUT.md) for feature ownership and edition-specific page modules. The previous `simple_base/templates/combat.h` include remains a compatibility forwarder.
