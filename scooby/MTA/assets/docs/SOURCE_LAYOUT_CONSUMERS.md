# Game consumer source-layout sync — 2026-10-11

This records the initial shared-only rebuild. The subsequent user-requested game-source reorganization is described in [GAME_SOURCE_LAYOUT.md](GAME_SOURCE_LAYOUT.md), with separate build/test evidence under `build/game-source-reorganization/`.

The active consumers below compile canonical `UI-vboth`, including the reorganized `src/features` presentation modules and the canonical feature definitions described in [SOURCE_LAYOUT.md](SOURCE_LAYOUT.md). Both interface editions use the same game registry, configuration and native adapters. No copied presentation sources or new template gameplay controls are installed into the games.

| Consumer | Root solution | Release platform | Validation |
| --- | --- | --- | --- |
| TF2 retail | `source/TF2/TF2-base-game/TF2UIBoth.sln` | x64 | 38/38 CTests |
| TF2 Classified | `source/TF2/TF2-Classified/TF2ClassifiedUIBoth.sln` | x64 | 28/28 CTests |
| L4D1/L4D2 | `source/L4D-Debug/ScoobyL4D.sln` | Win32 | 95/95 CTests |
| GTA4 | `old-rockstar-games/gta/4/ScoobyGTA4.sln` | Win32 | 10/10 CTests |
| GTA SA | `old-rockstar-games/gta/SA/Scooby-SA.sln` | Win32 | 11/11 CTests |
| MTA | `MTA/Scooby-MTA/Scooby-MTA.sln` | Win32 | 9/9 CTests |
| CS2 Simple Base | `CS2/simple-base-cs2/ScoobyCS2.sln` | x64 | V1/V2 startup and menu-input/focus fixtures, 197 WARP overlay checks, 4,692 capture-policy/UI checks |

Paths in the table are relative to the repository root. Each project's `build/source-layout-sync/` owns the build/test logs and artifact evidence. CS2 uses `GameplaySyncEnabled=false`, preserving its separate gameplay sync and the independent normal CS2 v2 product. Its production and capture-fixture link steps report LNK4098 (`LIBCMT` conflicts with other libraries); passing tests do not resolve that warning.

All seven root solutions passed. L4D's first solution check overlapped its preview tests and failed to relink the running `l4d_preview.exe`; `solution-during-tests.log` preserves that failure. The suite completed 95/95, and the solution passed with zero warnings/errors after the preview exited. The aggregate artifact/log manifest is `simple-base/build/source-reorganization/game-sync-validation.json`.

TF2 Classified, GTA4 and CS2 Simple Base had host-specific Aimbot crosshair icon overrides. These now select the shared vector gun (`0x1f52b`). Other navigation entries retain their existing IDs and routes.

The source-path audit found no active consumer build references to the removed loose presentation `.cpp` files. The registered-consumer audit passes. Game-specific feature source organization remains owned by each title; this sync adopts the reorganized shared implementation without moving native hooks or copying another game's feature implementations. MTA remains independent of Rockstar Classics gameplay/Lua sync. Paused and queued projects are not resumed.

These are local builds and owned-host regression results. No release was published or installed into a game. Live gameplay, native input/focus restoration, the reported CS2 Alt-Tab crash and comparable foreground performance remain unverified by this sync.
