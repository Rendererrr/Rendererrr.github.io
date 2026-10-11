# Game-owned feature modules

The shared V1/V2 presentation remains in canonical Simple-base. Active games own their feature implementations and native adapters. Game folders follow the feature-oriented layout without importing another title's offsets, hooks, defaults or gameplay.

## TF2 retail and TF2 Classified

Both projects now use `src/features/`:

| Folder | Ownership |
| --- | --- |
| `aimbot/` | Native combat coordinator, profiles/page controls, indicators, targeting, projectile launch/ballistics and history |
| `anti_aim/` | Portable anti-aim processing |
| `self/view/`, `self/movement/` | Native camera and portable movement processing |
| `visuals/esp/players/`, `objects/`, `preview/` | Entity preview controls and model/object rendering |
| `visuals/radar/`, `chams/`, `world/` | Radar, chams controls/native rendering/animation, VFX settings/native integration |
| `visuals/objectives/` | Retail objective snapshots, native adapter and controls |
| `skins/` | Retail skins, inventory and loadout preview |
| `lua/api/` | Each edition's independently owned Lua API |
| `settings/general/` | Capture Protection controls and Lua scope |
| `registration/`, `common/` | Registry initialization and shared feature controls |

Every moved implementation and extracted module has a companion `.hpp`. Existing `include/tf2/*.h` and `include/tf2c/*.h` entry points remain compatible through forwarding headers where implementation ownership moved. Native class declarations and common domain types remain in their stable public interfaces. Feature algorithms are separate compiled translation units; generic vector/entity operations remain in `core.cpp`.

`product_internal.hpp` holds private application state. The small feature page `.hpp` files explicitly marked as member declarations are included **inside** `ProductUi::Impl`; they are not standalone public headers. Their `.cpp` files implement the same existing methods. `ui.cpp` retains host initialization, navigation and frame orchestration. Engine discovery, input, rendering backends and lifecycle hooks remain under `native/`.

## L4D1/L4D2

`src/features/` owns `aimbot/{targeting,triggerbot,indicators}`, `anti_aim`, `self/{view,movement}`, `misc/commands`, `host`, `visuals/{esp,radar,team_hud,chams,world}`, `lua/{api,hooks,controls}`, `settings`, and `registration`.

ESP has dedicated `extras`, `pickups`, `weapons` and `preview` modules. Chams owns the shared pass catalog and material implementations. World owns sky, profiles and studio modules. Settings snapshot conversion and Lua controls are separate from registration. Existing native coordinator/state ownership and public `include/l4d/*.h` includes remain compatible. Source ABI/session discovery, backend lifecycle and application runtime stay outside feature folders.

## GTA4, SA and MTA

GTA4 already has compiled feature modules for Aimbot > Lock-on/Silent Aim/Triggerbot, Visuals and its game-specific pages. That structure remains intact. The remaining source-loader catalog/page and spawner page declarations now have their own companion `.hpp` files; the existing umbrella headers retain include compatibility.

SA and MTA retain their established `features/combat`, `features/local`, `features/spawner` and `features/visuals/esp/{players,npcs,self,vehicles,pickups}` modules. Their CJ preview now lives at `features/visuals/esp/preview/cj.cpp/.hpp`. MTA's resource browser is `features/lua/resources/resources.cpp/.hpp`. Menu orchestration remains in `ui/`. MTA stays independent of Rockstar Classics gameplay/Lua synchronization.

## CS2 Simple Base

Native feature modules remain under `src/cs2/features/` and preserve the existing reviewed gameplay-sync paths. Product page modules remain under `src/GUI/features/`; the normal CS2 v2 UI is independent.

Settings now has `general`, `interface`, `config` and `links` folders. Interface separates appearance, colors/persistence, layout/persistence, images, fonts, effects, border, cursor and scaling. Each compiled settings feature has its own `.hpp`; `settings.h` remains the compatibility umbrella. Capture Protection's UI helper belongs to General. Root project/filter entries, internal includes and affected test scripts follow the new paths. Build with `GameplaySyncEnabled=false` while the existing review gate has unrelated pending differences; this refactor does not reset or acknowledge that gate's baseline.

## Build and preservation contract

Root solutions still delegate to their existing build systems, with all outputs beneath each project's `build/`. Reconfigure after source moves. Public feature IDs, configuration keys, defaults, hotkeys, Lua routes and native function bodies are preserved. Copy the complete project's `src/` and `include/` trees when porting; compatibility headers intentionally refer to their owned feature modules.

Each affected project keeps `build/game-source-reorganization/` with source backups, a move manifest, build/test logs and final artifact hashes. The aggregate preservation audit is `simple-base/build/source-reorganization/game-source-audit.json`. It verifies unchanged bodies for moved implementations and extracted methods; builds and regression suites validate linkage and behavior. Earlier shared-only sync evidence remains under `build/source-layout-sync/`.

Live gameplay, native capture/Alt-Tab behavior and foreground performance still require the title's maintenance procedure. No paused project, game deployment or release publication is included.

## Validation — 2026-10-11

All seven root Release solutions passed. TF2 passed 38/38 CTests, Classified 28/28, GTA4 10/10, SA 11/11 and MTA 9/9. L4D passed 94/95 on the full run: its L4D1/V1/DX9 model preview exceeded the Lua execution-time budget while other validation was active. That exact test then passed 1/1 in isolation without a code change. Both the failure and retry logs are retained; this does not establish a root cause for the timing failure.

CS2 passed appearance migration/round-trip coverage, 12 config-reset checks and 4,692 capture-policy/UI checks. Its obsolete objects for the 14 relocated sources were preserved under `build/game-source-reorganization/obsolete-objects` before production-linked fixture testing, preventing stale duplicate definitions from entering those links. Native gameplay-sync sources and the normal v2 UI were not reorganized.

TF2/Classified retain C4244 conversion warnings from the extracted, unchanged algorithms. CS2 retains D9025 exception-option and LNK4098 CRT-library warnings. L4D, GTA4, SA and MTA final root builds report zero warnings/errors. Exact diagnostics are recorded in each validation manifest.

The preservation audit checks 82 moved implementation bodies, 35 extracted TF2 page methods, 12 extracted TF2 algorithm sections, three extracted L4D functions and three GTA4 implementations. Root build/test logs, selected source input hashes and final DLL hashes are recorded in `simple-base/build/source-reorganization/game-refactor-validation.json` and each project's `build/game-source-reorganization/validation.json`. The canonical consumer audit and whitespace checks also pass.
