# Updating Half-Life: Blue Shift

Read [unified GoldSrc maintenance](../../goldsrc/UPDATING.md) first. This title is App ID130, `-game bshift`, installed Steam build5424832, Windows x86/OpenGL profile `steam-5424832-win32`. Current unified expanded-feature acceptance is pending; `ports-handoffs/blueshift.md` records exact diagnostic artifacts and completed/remaining checks. No `-insecure` flag is required.

## Independent profile

| Binary | SHA-256 |
| --- | --- |
| hl.exe | be7c061a2d36a3517c98412a06642f98985ab746e3d65c8d105d25b6ac77369c |
| hw.dll | 9ba9a2db5e07598fd59afa35507a98c86162e4e15b3835177b78c11842cd2295 |
| bshift/cl_dlls/client.dll | c91620709567c8bb0764287b79af96d2cbf2d8a1cb26c1650be605f7dab5b90a |
| bshift/dlls/hl.dll | abdd2ffe8690627a4a889b30a3b95f99100c1d6a617e08e4dfb45701529fa1f2 |

Inventory with `python ports/tools/blueshift_inventory.py <Half-Life-root> <new-research-directory>`. Inspect the script's CLI before changing its scope. Native bshift.so/dylib are different unsupported binaries. Copy DLLs into a new research directory before batch IDA analysis; use ida_report.py, ida_server_contract.py, ida_blueshift_contracts.py, ida_combat_callbacks.py and ida_client_view.py as appropriate. Keep exact input hashes, decoded instructions, calling conventions, vtable/callback evidence and readable spans. JSON reports are evidence, not signatures for a newer binary.

`profile.h`, `campaign_profile.h`, `product.cpp`, `catalog.cpp` and `catalog.h` are title data; shared behavior lives in goldsrc. Client API version7 copies135 engine pointers to RVA0xc7d70; studio version1 copies46 pointers to0xdd1e0. Server API140 callback table0xc2140, engine functions0xd9890, globals0xd9b0c. Damage method0x60210 is thiscall with four arguments/retn0x10; precache helper0x8c350. Independently verified item-info slot0xf0 differs from both siblings. Weapon capacities and all constructors/hulls are in research/blueshift. Blue Shift BSP entity text is lump1, unlike HL/OpFor lump0; preserve explicit product.entityLump and bounds validation.

The catalog has14 canonical weapons,11 pickups (including security armorvest/helmet),7 NPCs; weapon rules17 include three aliases. Rosenberg uses the scientist model, so model-only ESP cannot label him independently. Do not add unknown bosses/scripted classes without their own precache, placement and lifecycle evidence.

## Local acceptance

Back up using `python ports/tools/blueshift_save_guard.py backup --game <root>/bshift --backup <new-directory>` and separately copy config.cfg. After owned process exit, run restore and verify with the same baseline and restore config.cfg. Never replace a previous baseline. The guard removes only scb_campaign test saves while preserving unrelated new saves.

Campaign fixture maps are ba_canal1 and ba_yard1. ba_canal1 starts in a cramped area: rejected placement is valid evidence but does not test catalog spawning. Verified diagnostic placement for all32 entries is ba_yard1 starting at (-3128,-3336,-795.969), yaw0, distance128. Use a fresh process and exact unified DLL:

```text
-game bshift -gl -windowed -w 1280 -h 720 -console -scooby-campaign-test +sv_lan 1 +sv_cheats 1 +maxplayers 1 +map ba_yard1
```

Attach with `halflife_attach.exe <owned-PID> --local-module ScoobyGoldSrc.dll`. `blueshift_campaign_probe.py --data <root>/bshift/goldsrc/windows/steam-5424832-win32/campaign --evidence <new-evidence> --yaw 0 --distance 128 <suite>` supports damage, shared_weapons, clipless, catalog, movement, jump, lifecycle and stop among other bounded checks. Its historical ammo suite was copied from an expansion-specific fixture; use shared_weapons for Blue Shift's actual six magazine classes. `blueshift_campaign_ui_probe.py` covers the old compatibility aliases; expanded visible navigation/View/Combat require the current unified checks.

All positive results must be associated with the exact DLL and source/UI inputs. The first Blue Shift candidate passed32 catalog entries, six magazines, eight clipless exclusions and campaign lifecycle/Stop; later diagnostic candidate2 showed actual Lock-on/Silent/trigger hits and distinct View effects. Neither candidate certifies final unified acceptance or Linux. Keep failed UI and focus-blocked movement attempts as failures/boundary evidence. Refer to the shared procedure for the required final all-title regression, expanded controls and package commands.
