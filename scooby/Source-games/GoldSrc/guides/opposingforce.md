# Updating the Opposing Force port

Current build contract: [unified GoldSrc maintenance](../../goldsrc/UPDATING.md). The present CMake output is one ScoobyGoldSrc.dll for all three titles. Historical acceptance below applies only to its recorded old artifact; final unified Combat/Movement/View acceptance is pending in ports-handoffs/blueshift.md.

Run the commands below from `source/`. This guide covers the Windows x86 Steam Opposing Force product (App ID 50, `-game gearbox`, OpenGL). The current exact profile is `steam-5429885-win32`; the current acceptance status and artifact hashes are recorded in `ports-handoffs/opposingforce.md`. A successful compile or matching manifest build number does not verify a new game binary.

## 1. Preserve the accepted baseline

Keep the previous DLL, whole package, package manifest, SHA-256 sidecar, source revision/input hashes, runtime logs, capture images and save backup together. Use a new research directory for each update. Do not overwrite `ports/research/opposingforce` evidence with output from a different build. Preserve existing user configs and saves; use a separate `SCOOBY_PORT_DATA_ROOT` during testing.

Coordinate with the consolidated GoldSrc owner before changing shared code or running `hl.exe`; the old original/OpFor owners are archived. Only one product test may own the shared runtime at a time. Receive an explicit release and independently check that no `hl.exe` remains. Do not terminate another test's process.

Inventory the actual installation, replacing the example paths/build label as needed:

```powershell
py ports/tools/opposingforce_inventory.py 'R:/SteamLibrary/steamapps/common/Half-Life' ports/research/opposingforce/update-NEWBUILD
Get-FileHash 'R:/SteamLibrary/steamapps/common/Half-Life/hl.exe','R:/SteamLibrary/steamapps/common/Half-Life/hw.dll','R:/SteamLibrary/steamapps/common/Half-Life/gearbox/cl_dlls/client.dll','R:/SteamLibrary/steamapps/common/Half-Life/gearbox/dlls/opfor.dll' -Algorithm SHA256
```

The inventory records the Steam manifest build, PE architecture, exact module hashes, installed models and BSP entity catalogs. Software rendering (`sw.dll`), native Linux executables and unknown hash combinations are not covered. Keep unknown builds rejected until their contracts are independently checked; do not merely replace hash strings to admit an update.

## 2. Re-establish the binary contracts

| Location | Contract to recheck |
| --- | --- |
| `ports/games/opposingforce/profile.h` | Executable/engine/client hashes, App ID, client engine-function table, default studio table and direct draw implementation |
| `ports/games/opposingforce/product.cpp` | Game directory, profile connection, title, Lua host, assets, scoped feature IDs and startup policy |
| `ports/games/opposingforce/campaign_profile.h` | Server hash, callbacks/global tables, player/weapon fields, save descriptors, damage callback, weapon capacities and spawn envelopes |
| `ports/games/opposingforce/catalog.cpp` | Exact model classification and expansion-specific labels |
| `ports/goldsrc/include/goldsrc` and `ports/goldsrc/src` | Shared SDK layout, startup, adapter, movement, campaign lifecycle and UI integration |

Copy binaries to a new research directory before IDA analysis. Use `ports/tools/ida_report.py`, `ida_server_contract.py`, `ida_opfor_trainer.py`, `ida_opfor_weapons.py`, `ida_opfor_spawn_contract.py` and `ida_detail.py` as appropriate; inspect their input conventions before running them. Batch IDA invocations need absolute database/script/log paths. Preserve decoded assembly and input hashes, including when a decompiler is unavailable.

The existing reference reports include `client-ida.json`, `engine-ida.json`, `engine-draw-ida.json`, `server-contract-ida.json`, `server-trainer-ida.json`, `weapon-capacities-ida.json`, `spawn-contract-ida.json`, `player-vtable-ida.json` and `player-damage-ida.json`. The current client has no `HUD_GetStudioModelInterface` export, and the default renderer bypasses the studio draw wrapper. Prove the replacement path again if either module changes. Do not transplant the original Half-Life renderer or server offsets.

Recheck exported constructors, vtables, calling conventions, API versions/table lengths, player readable spans, each saved-field descriptor, active inventory/ammo links and every weapon's `GetItemInfo`. Prove the damage callback through an independently named method/vtable slot. Audit actual Spawn/Precache implementations and hulls for all admitted classes. Centered spore ammo has negative minimum Z; placement must account for its actual lower hull. Keep bosses, oversized/scripted/airborne classes, CTF-only entities and aliases excluded unless separately implemented and tested.

`extract_opfor_capacities.py` and `extract_opfor_spawn_contract.py` decode the current saved reports. Their paths and assembly patterns are build-specific: adapt them to the newly captured reports and independently check changed patterns. Update the profile audit's expected evidence directory and counts when the contract intentionally changes. Reset affected platform verification bits while acceptance is pending. Update profile identifiers and scoped-data guards in the probes when adding a genuinely new profile; retain the old profile's evidence separately.

## 3. Build and audit

Use Visual Studio 2022 C++ tools, CMake, Python and the canonical `simple-base/UI` checkout. The vendored UI snapshot is not the active UI source. Build all products/tests after shared changes, and coordinate the shared owner's Half-Life regression.

```powershell
cmake -S ports -B ports/build/opposingforce-static -G 'Visual Studio 17 2022' -A Win32 '-DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded$<$<CONFIG:Debug>:Debug>'
cmake --build ports/build/opposingforce-static --config Release --parallel 6
ctest --test-dir ports/build/opposingforce-static -C Release --output-on-failure
py ports/tools/verify_opfor_profile.py ports/build/opposingforce-static/Release/opposingforce_tests.exe
```

Record exit codes and logs. Freeze the source inputs, including canonical UI, before compilation; compare their hashes after it completes. Rebuild if inputs changed. The profile audit compares 23 weapon rules, 53 spawn entries, nine save descriptors, the damage callback and NPC bounds against the current independent research. It does not prove live behavior. Preserve failures as well as passing reruns.

## 4. Accept the exact candidate in the game

Back up and verify existing `gearbox/SAVE` files with `ports/tools/opfor_save_guard.py`. That helper pins the current server hash and must be reviewed for a new build. It restores baseline files and removes only newly created `scb_campaign*` probe saves. Never overwrite a pre-existing test save or broad-delete the save directory.

Start the game with OpenGL and a local single-player map, without requiring `-insecure`. The opt-in fixture flags are for acceptance only:

```text
-game gearbox -gl -windowed -w 1280 -h 720 -console -scooby-campaign-test +sv_lan 1 +sv_cheats 1 +maxplayers 1 +map ofboot0
```

Set an absolute, isolated `SCOOBY_PORT_DATA_ROOT` on that game process. The current campaign scope beneath it is `gearbox/goldsrc/windows/steam-5429885-win32/campaign`. Attach the adjacent module from a verified extracted package with `halflife_attach.exe PID --local-module ScoobyGoldSrc.dll`; use the PID of the game you explicitly launched. Record arguments, actual loaded module hashes and startup/session diagnostics. Test a package path containing spaces and non-ASCII characters.

Use `campaign_control.py --data DATA --record NEW_JSON snapshot` and the allowlisted `reload_map` / `equip` operations to prepare fixtures. The initial training script freezes the player; check the authoritative flags before movement or firing. An unowned weapon or frozen player is an invalid fixture, not an implementation pass.

```powershell
py ports/tools/opfor_campaign_probe.py --data DATA --evidence NEW_EVIDENCE --yaw 0 --distance 64 catalog
py ports/tools/opfor_campaign_ui_probe.py --data DATA --evidence NEW_UI_EVIDENCE
```

Run the `damage`, `ammo`, `shared_weapons`, `clipless`, `movement`, `jump`, `transitions`, `lifecycle` and `stop` suites with separate evidence directories as necessary. Stop is last because it disables the session. Choose a clear spawn location and walking direction based on the actual map. Review exact responses and captures, not only script exit codes. Required checks include:

- Actual health/armor damage, protection, refills and toggle restoration.
- Independent reserve and magazine behavior during real firing, weapon switching and disable; no magazine writes to clipless/melee weapons. The `ammo` suite covers the four expansion magazines; `shared_weapons` covers the other six magazines in the actual Opposing Force runtime; `clipless` covers all 13 configured clipless/melee weapons.
- Every admitted spawn class, invalid/bounded requests, actual world counts, owned cleanup, pickup ownership, collision failures and bounded batches. Do not count stock `give` equipment as spawner acceptance.
- Walking and jump changes measured after real client/server physics; record peaks before releasing input, because each input command resets them. Noclip is checked by displacement and movement-mode restoration.
- Save/load excluding temporary overrides and tool-owned entities, actual death/load, map transitions, disconnect and Stop without stale ownership or state.
- Actual player/spawner/API-docs UI rendering, config roundtrip, Lua identity/capabilities and hotkey hold/release. The automatic hotkey probe exercises the manager; it does not establish physical keyboard or Wine input acceptance. Docs must inherit the project theme and omit note-only prose. Product labels must not gain `/ offline`.

Run a fresh visual smoke process on `of4a4` using `-scooby-smoke -scooby-smoke-animation -scooby-smoke-combat`. Validate its log with:

```powershell
py ports/tools/assert_runtime.py RUNTIME_LOG NEW_VISUAL_EVIDENCE --game 'Half-Life: Opposing Force' --map of4a4 --require-animation --require-projectile
```

Inspect real captures for all material/animation modes, ESP/bones, expansion models/projectiles and the theme. Check GL restoration, disable, disconnect and Stop. Recheck wrong product, duplicate attachment and unknown-profile refusal on the final startup code. `test_opfor_refusals.ps1` pins an old visual DLL and includes a historical missing-flag rejection; it is not current final-build acceptance.

Promote only capabilities supported by exact profile/platform evidence, rebuild and retest the resulting final artifact. Close only the process you own, restore/verify the save baseline and explicitly release runtime ownership.

## 5. Package, record and roll back

```powershell
py ports/linux/package.py --product goldsrc --bin ports/build/opposingforce-static/Release --helper ports/build/opposingforce-static/Release/halflife_attach.exe --output ports/build/opposingforce-static/packages/opposingforce-NEWBUILD.zip
py ports/linux/package.py --verify ports/build/opposingforce-static/packages/opposingforce-NEWBUILD.zip
Get-FileHash ports/build/opposingforce-static/packages/opposingforce-NEWBUILD.zip -Algorithm SHA256
```

The package must contain the x86 DLL/helper, staged canonical and product assets, fonts/licenses and exact per-file manifest. All non-system dependencies must be accounted for; this build uses the static MSVC runtime. Do not redistribute copied game binaries, research databases or Windows system DLLs. Extract and verify every file before testing the delivered package. Record package and loaded DLL hashes, source snapshot, test logs, visual captures and remaining limitations in `ports-handoffs/opposingforce.md`.

Linux/Wine/Proton gameplay, graphics, input and lifecycle remain unverified without a real Linux host and the game's exact runner/prefix. Keep `linux_runtime_verified` false; a Windows run or launcher dry-run cannot change that. Native Linux/ELF and Steam Deck/Game Mode are not verified targets. Do not repeatedly install/probe a missing environment as a substitute for acceptance.

For rollback, stop the owned session and restart the game before replacing the pinned module. Restore the entire previous verified package and its matching assets/config scope, then verify its manifest. Keep the new evidence for diagnosis. If the game itself updated, the old package may correctly reject it: leave the feature unavailable until a matching independently checked profile exists. Do not weaken exact-hash checks to force a rollback package to load.
