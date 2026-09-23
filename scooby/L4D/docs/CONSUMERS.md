# Simple-base consumers

Source of truth: `simple-base/UI`. Workflow: [AUTO_SYNC.md](../../AUTO_SYNC.md). Machine-readable inventory and retained snapshot hashes: [consumer-inventory.json](consumer-inventory.json). Build validation is separate from game runtime acceptance. All Random-games titles except Infinite Warfare are now paused; the results below were obtained before those pauses. No paused title is being investigated or rerun.

| Consumer | Build / architecture | Renderer and scope | Migration state |
| --- | --- | --- | --- |
| simple-base/UI preview | CMake, x64 and x86 | DX11 preview; optional DX12/OpenGL/Vulkan backends | Canonical; manifest staging |
| simple-base/Loader | CMake, x64 | DX11 native loader | Direct canonical source and managed shared assets; companion task owns catalog |
| source/L4D-Debug | CMake, Win32 | L4D1/2 DX9 and OpenGL; DX11 reference | Direct canonical sources and manifest stage; vendor retained |
| source/ports | CMake, Win32 | Half-Life GoldSrc OpenGL; subsequent adapter targets | Direct canonical sources; projected geometry/distance/stats retained |
| Random-games/H1Z1 | CMake, x64 | DX11 host/module | Glue written; user paused before successful validation; excluded from further work |
| old-call-of-duty/Black-ops-2 | CMake, Win32 | DX11 diagnostic host | Direct canonical and managed assets (paused) |
| old-call-of-duty/Advanced-Warfare | CMake, x64 | DX11 diagnostic host | Direct canonical and managed assets (paused) |
| old-call-of-duty/Ghosts | CMake, x64 | DX11 diagnostic host | Direct canonical and managed assets (paused) |
| old-call-of-duty/Infinite-Warfare | CMake, x64 | DX11 diagnostic host | Direct canonical and managed assets; active |
| old-call-of-duty/Modern-Warfare-2 | CMake, Win32 | DX11 diagnostic host | Direct canonical and managed assets (paused) |
| old-call-of-duty/Modern-Warfare-3 | CMake, Win32 | DX11 diagnostic host | Direct canonical and managed assets (paused) |
| old-call-of-duty/Modern-Warfare-Remastered | CMake, x64 | DX11 diagnostic host | Direct canonical; assets under build/assets (paused) |
| old-call-of-duty/WWII | CMake, x64 | DX11 diagnostic host | Direct canonical and managed assets; paused; title owner owns packaged runtime lookup |

CoD paths above are under `Random-games/`. These are the actual targets found in build definitions; a diagnostic UI is not a completed injected game port. New Source/GoldSrc adapters use the same `source/ports` dependency and must attach their own staging hook/output location. TF2/CSS references and planned games without a Simple-base build are not marked as migrated.

## Independent and inactive projects

**GMod (`gmod/Scooby-GMOD`) is not a Simple-base consumer.** Its owner confirmed C++20/MSBuild x64, ImGui 1.89.6, Win32/DX9, independent theme/widgets, language/font handling, config services and game Lua integration. Canonical UI uses a newer ImGui with different internal/dynamic-font APIs. Linking both implementations or copying canonical files over GMod would break the shared context/ABI and lose game behavior. A genuine migration requires replacing its UI shell through an adapter, upgrading its renderer/input and ImGui as one compatible set, mapping existing settings/features/hotkeys and game Lua, preserving its LANG_*.json/bundled catalog format, and testing the full product. No automatic asset hook is installed there because its runtime cannot consume canonical assets as a drop-in replacement. The synchronization boundary is explicit; GMod remains a separate migration, not synchronized coverage.

Other MSBuild products (FiveM/RedM/Megabonk and reference Rhino projects) have their own UI/build sources and are not enrolled merely because they use ImGui or share visual styling. Black Ops I currently has no discovered Simple-base target. The separate `Documents/ChatGPT/Random-games` task path contained only Git metadata at inventory time; actual consumer sources are under this repository. Existing vendor trees in L4D, ports, H1Z1, CoD shared and Infinite Warfare are retained historical snapshots. They are not fallback dependencies.

## Reconciliation

L4D and H1Z1's UI trees were identical after normalizing line endings; both contained reusable improvements absent from canonical. Their 41 differing/added paths were reviewed and imported, with Half-Life's five additional API/source changes layered on top. CoD shared's footer delta was already covered; Infinite Warfare's original vendor matched the old canonical UI. The per-file import ledger is [vendor-reconciliation.json](vendor-reconciliation.json). No game adapter implementation was copied into UI. FreeType and DX9 adapter sources/notices remain bundled; product FreeType targets remain product build dependencies.

## Validation record

The shared x64 Release build passed all five CTest suites (core, UI, appearance, Lua API, asset sync). The final Python sync suite passes **16/16**, including concurrent writers, Windows junction rejection, seeded profile preservation, no-op timestamps, stale-owned removal, local-edit conflict protection and catalog/doc merging. The isolated CMake integration proof passes source/header rebuild and relink, asset/docs-only refresh without relinking, new-consumer onboarding, missing canonical roots and automatic rejection after an API revision changes. Build the proof under the workspace: MSBuild excludes the Windows TEMP directory from normal dependency tracking.

| Migration validation snapshot | Build | CTest | Limitation/current state |
| --- | --- | --- | --- |
| L4D Win32 | Passed | 18/18 | Includes standalone DX9/OpenGL/scale/font checks; no game injection from this task |
| Source/GoldSrc Win32 | Passed | 11/11 | Includes projected geometry and material animation tests; adapter work continues separately |
| BO2 Win32 | Passed | 8/8 | Now paused |
| Advanced Warfare x64 | Passed | 2/2 | Diagnostic UI only; now paused |
| Ghosts x64 | Passed | 2/2 | Diagnostic UI only; now paused |
| Infinite Warfare x64 | Passed | 9/9 | Diagnostic host; gameplay/runtime acceptance belongs to its task |
| WWII x64 | Passed | 3/3 | Diagnostic UI only; now paused |
| MW2 Win32 | Passed | 1/2 | UI navigation test failed `Navigate MW2 subpage`; paused before investigation/fix |
| MWR x64 | Passed | 2/3 | Product page-loading test failed `MWR pages load`; paused before resolution |
| MW3 Win32 | Configure failed | Not run | Product UI/test/preview source files were absent at configure time; now paused |
| H1Z1 x64 | Configure passed; build failed | Not run | Paused; no successful migration validation claimed |
| Loader x64 | Companion task reports build passed | 4/4 reported | Catalog, core, UI interactions and native smoke; no games launched |

Machine-readable evidence and migration binary hashes: [sync-validation.json](sync-validation.json). Detailed local build logs are in `UI/build/consumer-*/{configure,build,tests}.log`. The shared x64 build also compiled DX12/OpenGL backend libraries; Vulkan was disabled and is not validated. No Linux build is claimed.

The Half-Life task subsequently reported its own canonical-UI animation build passing 11/11 CTests plus offline runtime checks, with DLL `07baf1168c29ca1272129f8ff305302590252094ddade415e55d6928b9c1fcd7`; see its handoff for that separate evidence. Product tasks can change sources after these snapshots, so preserve exact build/artifact identity when reporting a result. Existing release and runtime-evidence directories were not overwritten by this task.

Loader owner evidence: fresh `Loader/build/catalog-validation` x64 Release passed `loader_catalog_contracts`, `loader_core`, `loader_ui_interactions` and `loader_native_smoke`. Native validation decoded all 74 catalog images, resized and recreated the graphics device. Additional hidden WARP captures passed at 960x650 and 640x480 / 150% scale. These are owner-reported results; its final Lua cleanup hardening was still being rechecked when this result arrived.

The later Wine/Proton implementation and representative consumer regression snapshots are tracked separately in [LINUX_COMPATIBILITY.md](LINUX_COMPATIBILITY.md). Earlier migration results above remain historical evidence.
