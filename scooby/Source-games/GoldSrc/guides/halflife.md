# Updating original Half-Life

Current build contract: [unified GoldSrc maintenance](../../goldsrc/UPDATING.md). The present CMake output is one ScoobyGoldSrc.dll for all three titles. Historical acceptance below applies only to its recorded old artifact; final unified Combat/Movement/View acceptance is pending in ports-handoffs/blueshift.md.

This guide applies to the Windows x86 OpenGL module for original Half-Life (Steam App ID70, `-game valve`). GoldSrc expansions have separate profiles and acceptance. Run commands below from the repository's `source` directory. Preserve the current package and its adjacent assets before changing a supported profile.

## Current accepted installation

Steam build15961492 is installed at `R:/SteamLibrary/steamapps/common/Half-Life` in the recorded acceptance environment. A different install path is fine; binary identities must match.

| Module | SHA-256 |
| --- | --- |
| `hl.exe` | `be7c061a2d36a3517c98412a06642f98985ab746e3d65c8d105d25b6ac77369c` |
| `hw.dll` | `9ba9a2db5e07598fd59afa35507a98c86162e4e15b3835177b78c11842cd2295` |
| `valve/cl_dlls/client.dll` | `e9827e3fe884b72da897c48b9921feb93660f9b0be62bd772e0104ab8c7135f8` |
| `valve/dlls/hl.dll` | `d932d274061ee05bef89ea712f9b32b8f5f742ad0124d5f516c8cca1e421ca24` |

Exact build/artifact/runtime evidence is indexed in `ports-handoffs/halflife.md` and `ports/research/trainer`. Do not replace old evidence with results from a newer DLL. The current module does not require `-insecure`; keep the exact-build, product and local campaign checks.

## When Steam updates the game

1. Close the previously attached game. Its DLL and verified server are pinned until process exit; replacing the file cannot update a running process.
2. Inventory the updated installation without modifying game files. `inventory.py` reads the actual Steam manifest build ID; a missing manifest reports null.

   ```powershell
   python ports/tools/inventory.py 'R:/SteamLibrary/steamapps/common/Half-Life' > ports/research/updated-halflife-inventory.json
   ```

3. Compare the four identities above and the manifest. If binaries are unchanged, retain the existing profile and record the new manifest evidence. If any required binary changes, the module must refuse that identity until verified. Never change only a hash to make an old RVA table load.
4. Copy the updated binaries to a separate ignored research workspace for static analysis. Keep installed binaries and saves intact. Record disassembler version, image base, file SHA-256, RVA, prototype/calling convention, field offsets and the instructions that establish each contract. The prior IDA scripts and JSON are evidence aids, not signatures that establish a new build automatically.

## Source and ABI ownership

| File or directory | What needs verification |
| --- | --- |
| `ports/games/halflife/profile.h` | App ID, executable/engine/client identities, engine/studio tables and their sizes. |
| `ports/games/halflife/product.cpp` | Original product identity, `valve` scope, feature prefix, paths, map fixtures and classification. |
| `ports/games/halflife/campaign_profile.h` | Exact server hash, engine/globals/precache RVAs, private player/weapon spans, saved-field descriptors, weapon IDs/capacities, spawn catalog and native evidence mask. Reset the new profile's `windowsVerified` to0 until its runtime acceptance passes. |
| `ports/goldsrc/src/adapter.cpp` | Verified client callbacks, executable-owned table entries, studio rendering and bounded pre-hook interface readiness. Do not relax a readiness failure into unchecked hooking. |
| `ports/goldsrc/src/campaign.cpp` | Server callback ABI, stock damage method, pre/post-think and client/server movement, temporary field leases, precache loading windows and save/restore/cleanup ownership. |
| `ports/goldsrc/include/goldsrc/server_sdk.h`, `ports/tools/server_layout.cpp` | Native x86 SDK offsets and compile-time layout checks. |
| `ports/goldsrc/src/ui.cpp`, `campaign_ui.cpp` | Feature/config/hotkey/Lua bindings, renderer lifecycle and product capability reporting. |
| `ports/games/halflife/assets`, `LUA.md` | Original title pages, example and scoped API documentation. |
| `../simple-base/UI`, `ports/CMakeLists.txt` | Canonical UI consumer and automatic asset/docs staging. Do not edit the unused legacy UI snapshot. |

The original server's `GetEntityAPI2` version140, `GiveFnptrsToDll`, engine function table, globals pointer, `UTIL_PrecacheOther`, saved `TYPEDESCRIPTION` entries and `CBasePlayer::TakeDamage` calling convention were independently checked. Re-establish them for a changed server. Inspect each weapon's actual item information/capacities and inventory linkage. Do not copy expansion offsets or infer IDs from a different SDK revision. Loading-window precaching is exercised both on world spawn and stock save restore.

## Build and automated verification

Use Visual Studio2022 with the x86 C++ toolchain, CMake and Python3.10+. A fresh ignored build directory prevents changed local assets from masking source updates.

```powershell
cmake -S ports -B ports/build/halflife-update-x86 -G 'Visual Studio 17 2022' -A Win32 '-DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded$<$<CONFIG:Debug>:Debug>'
cmake --build ports/build/halflife-update-x86 --config Release --parallel 4
ctest --test-dir ports/build/halflife-update-x86 -C Release --output-on-failure
```

The accepted revision has17 CTests covering the ports, SDK/layout, catalog, animation, campaign policy, canonical UI/Lua/docs and assets. A green compile or fixture test does not establish a changed game's ABI. Inspect failures rather than weakening assertions. Existing vendor encoding/enum warnings are separate from owned-code errors.

## Installed-game acceptance

Coordinate the shared `hl.exe` runtime with other GoldSrc tasks before launching. Back up original save files using a new backup directory for this update. The guard refuses to replace an existing baseline or a pre-existing test save name.

```powershell
python ports/tools/save_guard.py backup --game 'R:/SteamLibrary/steamapps/common/Half-Life/valve' --backup ports/build/halflife-update-x86/save-backup
```

Use an absolute `SCOOBY_PORT_DATA_ROOT` unique to the run. Logs/configs are further scoped under `valve/goldsrc/windows/<exact-profile>/campaign`. Normal launches omit every `-scooby-*` test flag. Campaign acceptance uses the explicit `-scooby-campaign-test` flag and a local map:

```text
-game valve -gl -windowed -w 1280 -h 720 -console -scooby-campaign-test +sv_lan 1 +sv_cheats 1 +maxplayers 1 +map c1a0
```

Attach the matching x86 DLL with the built `halflife_attach.exe`. `--list` enumerates Windows PIDs and full paths; `<owned-PID> --local-module ScoobyGoldSrc.dll` loads the adjacent module. Inspect the scoped log for actual initialization and exact server attachment. A successful LoadLibrary result alone is not acceptance.

For the existing accepted profile, `halflife_campaign_acceptance.py` takes `--data <scoped campaign directory> --evidence <new evidence directory>` followed by a suite. Run `movement`, `ammo`, `ui`, then `lifecycle` last because its final action is Stop. Evidence outputs refuse replacement. For a newly named profile, update this tool's explicit scope assertion after verifying that profile. Keep fixtures separate from the actual effects they test.

- Exercise all catalog entries and compare actual world class counts before spawn, after spawn and after cleanup. The original31-entry loop is `campaign_runtime.catalog()`; its default data path must be explicitly adjusted for another run. Include a bounded multi-item batch, obstructed placement/rollback, unknown classes and out-of-range requests.
- Verify actual pickup removes cleanup ownership and that cleanup preserves both inventory and ordinary map entities.
- Verify godmode against real stock health/armor damage and disable restoration. Test reserve ammo separately from no reload with actual firing across every magazine class, baseline restoration and clipless/melee exclusions.
- Compare client/server walking and jumping from the same save, then disable and compare the baseline again. Verify actual noclip displacement and safe return to walking.
- Save with active leases and temporary world objects; load with options off. Assert original fields and actual world object exclusion. Spawn again after load. Exercise lethal damage/recovery, map transition, disconnect and Stop.
- Verify config round trips, hold/release hotkey-manager behavior, Lua identity/capabilities and rendered Player/Spawner/docs pages. Programmatic input is not evidence of physical keyboard/mouse behavior.

Once exact native acceptance is complete, promote only those capability bits. Rebuild and run a final visual smoke without campaign test mode:

```text
-game valve -gl -windowed -w 1280 -h 720 -console -scooby-smoke -scooby-smoke-animation +sv_lan 1 +sv_cheats 1 +maxplayers 1 +map c1a0
```

```powershell
python ports/tools/assert_runtime.py '<scoped-data>/halflife.log' ports/research/new-final-animation --map c1a0 --require-animation
```

Inspect `SMOKE_CAMPAIGN_CAPABILITIES PASS test_mode=0`, reviewed frame pairs, all material/animation phases, config/Lua results, no renderer restoration errors, disconnect and input restoration. Record the DLL hash associated with every run.

After the owned game exits, restore and verify the original save hashes. The guard restores originals and removes only uniquely named test saves; it preserves other new saves.

```powershell
python ports/tools/save_guard.py restore --game 'R:/SteamLibrary/steamapps/common/Half-Life/valve' --backup ports/build/halflife-update-x86/save-backup
python ports/tools/save_guard.py verify --game 'R:/SteamLibrary/steamapps/common/Half-Life/valve' --backup ports/build/halflife-update-x86/save-backup
```

## Package, release and rollback

```powershell
python ports/linux/package.py --product goldsrc --bin ports/build/halflife-update-x86/Release --helper ports/build/halflife-update-x86/Release/halflife_attach.exe --output ports/build/packages/halflife-update-x86.zip
python ports/linux/package.py --verify ports/build/packages/halflife-update-x86.zip
```

The package contains the native Windows DLL/helper, canonical fonts/languages/pages/docs/licenses and the shared runner. It verifies file hashes, PE32 architecture, allowed system imports and asset manifests. No game binaries belong in it. Preserve the `.sha256`, source revision/diff, test logs, captures and final handoff. `ports/tests/compatibility_package_tests.py` additionally validates the standard original/OpFor package paths, tampering, traversal and runner fixtures; update explicit fixture paths when using a separate update build.

Rollback means closing the game and restoring the last verified module **with its complete matching assets**. Retain data backups; do not overwrite user saves or force an old module onto newly incompatible game binaries. The adapter should continue refusing an unknown build. Document the regression and keep its new capabilities pending until fixed. Changelogs are updated only when explicitly requested.

## Linux evidence remains separate

The compatibility package targets the Windows x86 game in a deliberately selected Wine/Proton prefix. Native ELF Half-Life is unsupported. This host has no Linux test environment; package/runner fixtures do not establish Linux gameplay support. `linux_runtime_verified` remains false and detected Wine campaign capabilities remain pending. Follow `ports/linux/README.md` and `../docs/LINUX_COMPATIBILITY.md` when a real Linux host is available; record runner/prefix/GPU/display/input, all feature/lifecycle tests and save preservation before promoting that platform.
