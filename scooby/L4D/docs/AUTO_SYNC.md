# Automatic Simple-base UI updates

`simple-base/UI` is the editable shared source. Consumer CMake builds compile it directly; they do not copy C++ into game folders. Editing common source/headers rebuilds the affected library and relinks the consumer on its next build. Embedded fonts, icons, documents and scripts trigger reconfiguration/relinking when their inputs change. Legacy external asset staging still refreshes on every consumer build. Already compiled or running modules do not update themselves: rebuild, repackage and restart/reload through the product's normal workflow.

Coverage and actual validation are recorded in [UI/docs/CONSUMERS.md](UI/docs/CONSUMERS.md). GMod is a separate implementation, not silently covered by these hooks. All Random-games titles except Infinite Warfare are paused. Completed glue and pre-pause evidence are retained; H1Z1 was not validated successfully.

## Boundaries

Edit reusable UI, theme/widgets, fonts/licenses, catalogs, Lua/core services and shared docs in `UI`. Game adapters, feature registration, config IDs/migration hooks, game Lua APIs and product assets remain in their product folders. `AppOptions.assets` points at packaged assets; `AppOptions.data` must point at a separate writable product data directory. Example Lua scripts are embedded inputs; application initialization creates missing examples and upgrades untouched stock versions while preserving user edits. See [the embedded-resource contract](UI/docs/EMBEDDED_RESOURCES.md) for compact packages, language paths and safe script seeding. Asset staging never targets user scripts, settings, profiles or logs.

The L4D/H1Z1 vendor improvements were reconciled into canonical UI before migration: optional FreeType, DX9 scaling, font lifecycle fixes, registry/config improvements, localized Lua controls, host cleanup hooks, sidebar/branding and UI changes. Half-Life's projected geometry, distance unit and returned draw statistics were retained. CoD's footer option is retained. Shared defaults now match the reconciled UI, including Insert as the default menu key; saved preferences still load. [vendor-reconciliation.json](UI/docs/vendor-reconciliation.json) records imported paths and hashes. Historical vendor trees remain intact for review/rollback, but migrated builds ignore them. Edit canonical UI going forward.

## Build and sync

Prerequisites: CMake 3.24+, C++20 toolchain, Python 3.9+, and the selected renderer SDKs. Existing Windows hosts use Visual Studio 2022. Dependencies/fonts remain local; normal builds do not download anything. Python is required for asset staging, not for the shipped game module. If discovery fails, configure with `-DPython3_EXECUTABLE=C:/path/to/python.exe`.

From the repository root, for example:

```powershell
cmake -S source/L4D-Debug -B source/L4D-Debug/build/shared-ui -G "Visual Studio 17 2022" -A Win32
cmake --build source/L4D-Debug/build/shared-ui --config Release
ctest --test-dir source/L4D-Debug/build/shared-ui -C Release --output-on-failure
```

Use x64 for x64 products and separate build directories for architectures. The consumer's `SIMPLE_BASE_UI_ROOT` defaults to a repository-relative canonical path; an explicit override supports another complete checkout. A missing canonical module or incompatible `api-revision.txt` fails configuration. No fallback to an old vendor tree occurs. Reconfigure old build directories after this migration; a fresh directory is recommended because old assets have no ownership manifest.

Asset-only refresh can run without compilation, e.g. `cmake --build <build> --config Release --target l4d_assets`. Default hook names are `<target>_shared_assets`; existing `l4d_assets`, `port_assets`, `bo2_assets`, `h1z1_assets` and `mwr_assets` names are preserved. Hook targets are dependencies of the product, not just `POST_BUILD` commands. This also covers newly added/removed asset and Markdown files without relying on timestamp globs.

Legacy packages use the successfully built asset staging directory and include `.simple-base-assets.json`. Migrated compact packages instead validate the rebuilt module resources and external language catalogs as described in the embedded-resource contract. Rebuild before running existing packaging scripts. A package archive or a separate installed directory is a snapshot; rerun its packaging/install workflow to deliver changes. This mechanism does not watch source files, deploy products or overwrite installed user data.

## Adding a consumer

Set options before adding UI and keep a single matching ImGui implementation in the host. Use the appropriate number of `../` segments for the project's location:

```cmake
set(SIMPLE_BASE_UI_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../../simple-base/UI"
    CACHE PATH "Canonical Simple-base UI checkout")
if(NOT EXISTS "${SIMPLE_BASE_UI_ROOT}/cmake/SimpleBaseConsumer.cmake")
  message(FATAL_ERROR "Missing canonical UI; set SIMPLE_BASE_UI_ROOT")
endif()
include("${SIMPLE_BASE_UI_ROOT}/cmake/SimpleBaseConsumer.cmake")
set(SIMPLE_BASE_PREVIEW OFF CACHE BOOL "" FORCE)
set(SIMPLE_BASE_TESTS OFF CACHE BOOL "" FORCE)
set(SIMPLE_BASE_DX12 OFF CACHE BOOL "" FORCE)
set(SIMPLE_BASE_OPENGL OFF CACHE BOOL "" FORCE)
set(SIMPLE_BASE_VULKAN OFF CACHE BOOL "" FORCE)
simple_base_add_ui(API_REVISION 1)
add_executable(my_host main.cpp)
target_link_libraries(my_host PRIVATE simple_base_ui simple_base_win32 simple_base_dx11)
simple_base_stage_assets(TARGET my_host
  EXTRA_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/assets"
  DOC_EXTENSION "${CMAKE_CURRENT_SOURCE_DIR}/docs/GAME_LUA_API.md")
```

`EXTRA_ROOT`, `DOC_EXTENSION`, `DOC_SNIPPETS`, `LANGUAGE_OVERLAY`, `DESTINATION` and `SYNC_TARGET` are optional. Default destination is `$<TARGET_FILE_DIR:my_host>/assets`. `DOC_SNIPPETS` maps the host's concise guide to `docs/LUA_SNIPPETS.md`. Shared `docs/**/*.md` keep their relative paths under `assets/docs`; root README/notices go under `docs/shared`. `DOC_EXTENSION` is retained in `docs/game/<name>` and appended to `docs/LUA_API.md`. Root `AUTO_SYNC.md` is also packaged. No consumer source documentation is overwritten.

For products that share an output directory, share one compatible sync target or use distinct asset/output directories. Do not attach different game overlays to the same destination. Add the consumer to `UI/docs/consumer-inventory.json` and `CONSUMERS.md`. Increment `api-revision.txt` for incompatible shared C++/adapter changes and deliberately update consumer expectations after migration; this is an integration compatibility revision, separate from the Lua API's version string. Native MSBuild users must integrate the canonical CMake targets or provide an equally complete source/dependency build; importing only assets does not make a UI shared. No source-vendoring/export workflow is provided or required by the migrated CMake hosts.

## Localization and game extensions

Keep product-only keys in the consumer's `assets/languages/<code>.json` (or `LANGUAGE_OVERLAY`). The staged catalog combines:

1. Game catalog `strings` for game-only keys.
2. Canonical `strings` for shared keys, so old full-catalog copies cannot freeze shared translations.
3. An explicit game `overrides` object for intentional replacements of shared keys.

Canonical language metadata takes precedence for existing catalogs. New game-only languages are supported. Example overlay:

```json
{"strings":{"Game status":"Game status"},"overrides":{"Units":"Game units"}}
```

Normal game assets are additive: collisions with shared fonts/scripts/docs fail instead of silently replacing them. Put game-specific Markdown under distinct names or use `DOC_EXTENSION`. Keep fonts and their notices together. Canonical assets also package the shared ImGui, text-editor, Lua and JSON notices under `assets/licenses`; optional host dependencies such as FreeType need their product notices as well. H1Z1 compatibility profile defaults use a separate seed-only helper: fresh outputs receive defaults, existing differing profiles are retained and reported. It neither deletes nor updates existing profiles.

## Ownership, drift and recovery

The stage manifest stores schema/API versions and SHA-256 hashes of owned files. Outputs are deterministic (no timestamps or machine paths in the manifest), atomically replaced per file, and left untouched on a no-op. A lock serializes simultaneous writers to one destination. A sync preflights all conflicts before changing managed files. It removes only obsolete previously owned files whose bytes still match the recorded hash; directories and unrelated files remain. Symlinks/junctions, traversal, protected data roots, case collisions and reserved metadata names are rejected.

A differing unowned output, or a locally edited owned output, fails with the exact path. Preserve it and either move it to a game extension/user-data source or use a new staging directory. Do not delete the manifest to force a refresh. Identical old output files may be adopted; differing old unmanaged files are not safe to overwrite automatically. This is why an existing L4D/Half-Life build can report a collision on its first migration build. Partial interrupted writes are recoverable on rerun when files match either the prior manifest or the desired inputs. `--check` is read-only and should run outside an active build.

```powershell
python simple-base/UI/scripts/audit_consumers.py
python simple-base/UI/scripts/sync_assets.py --ui-root simple-base/UI --destination <build>/Release/assets --extra-root <game>/assets --doc-extension <game>/docs/GAME_LUA_API.md --check
```

Supply exactly the same optional overlay/doc inputs used by that consumer's CMake hook. `--check` returns 0 for current outputs, 1 for stale outputs and 2 for errors/conflicts. The repository audit detects missing/unregistered integrations and changes to retained vendor snapshots. Paused titles and their retained vendor snapshots are skipped unless deliberately included after resume. Snapshot checks normalize line endings, while package hashes cover actual bytes. An old export lacking the API marker is rejected.

Troubleshooting: a missing Python path is a configure-time tool dependency; a missing canonical source needs the complete checkout or explicit root override; an API mismatch needs an adapter migration; a collision needs preservation and a fresh stage; an asset-only edit not appearing needs the product/sync target to be built and its package refreshed. Tests that read source assets directly verify UI contracts, not packaged deployment.

## Validation and rollback

Run the 16-case `python UI/tests/test_sync_assets.py` from `simple-base`, then build and CTest the shared UI and representative consumers. `python UI/tests/test_build_sync.py --cmake <cmake.exe>` verifies source/header dependency rebuilds, asset/docs updates without relinking, no-op stability, scoped removal, preserved user files, adding a second consumer, missing canonical roots and API-change auto-reconfiguration. It uses a temporary canonical fixture with a real shared C++ source and the production CMake/sync helpers. `UI/scripts/check_port_inventory.py` checks the documented source inventory.

Current build/test evidence and limits live in `UI/docs/CONSUMERS.md`; local detailed logs are under `UI/build/consumer-*/`. A successful preview/CTest build does not establish actual game runtime compatibility. Vulkan requires its SDK and is not implied by an OpenGL/DX11 pass.

Rollback a release using its complete previous binary plus matching packaged assets. Preserve user data separately. To roll back source migration, restore only the focused CMake changes and corresponding canonical reconciliation as one reviewed change; retained vendor trees and the import hash ledger aid comparison. Never reset the whole working tree, which contains concurrent product work. Do not mix an older DLL with newer ABI-dependent binaries or assume reverting a manifest reverts file contents.
