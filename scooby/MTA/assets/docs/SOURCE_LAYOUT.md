# Simple-base source ownership

V1 (`UI`), V2 (`UI-v2`) and combined (`UI-vboth`) separate feature pages from application infrastructure. The layout follows the feature-oriented organization of `pure-op/games/Base/src` without importing that project's hooks, memory code or native gameplay assumptions.

```text
UI/src/
  core/                         Registry, configs, files, resources, hotkeys, Lua runtime
  esp/                          Shared projection, renderer and model rendering
  platform/                     Platform support
  ui/                           Application shell, navigation, widgets, theme, Lua bindings
  features/
    aimbot/
      aimbot.cpp/.hpp           Registration and page installation
      control.hpp              Shared control descriptor
      lock_on/                 Sub-tab plus individual controls (.cpp/.hpp)
      silent_aim/              Sub-tab plus individual controls (.cpp/.hpp)
      triggerbot/              Sub-tab plus individual controls (.cpp/.hpp)
    visuals/
      visuals.cpp/.hpp          ESP/Radar dispatcher
      esp/
        esp.cpp/.hpp            ESP page
        appearance.cpp/.hpp     Appearance controls and preview editing
        players/               Base ESP feature definitions and defaults
        npcs/                  Independent NPC profile registration
        zombies/               Independent zombie profile registration
        preview/               Preview animation feature definition
      radar/                   Radar page and feature definition
    lua/
      lua.cpp/.hpp              Scripts/Editor/Console dispatcher
      scripts/                 Script browser page
      editor/                  Editor, document tabs, save/run operations
      console/                 Console page
      api/                     Themed API browser
    settings/
      settings.cpp/.hpp         Settings dispatcher
      general/                 V2/combined General page
      interface/               Interface controls
      config/                  Config browser page
      hotkeys/                 Hotkey editor
      overlays/                Overlay controls, rendering and feature definitions
      links/                   Project links
    common/                    File browser shared by scripts and configs
```

V2 and combined have their own `src/features/{visuals,lua,settings,common}` presentation trees. They compile canonical combat and profile definitions directly; do not copy those implementations into each edition. Combined's V1-specific presentations live in each topic's `v1/` folder. Shell and rendering infrastructure remain in `src/ui/v1` where applicable.

## Interfaces

Reusable feature definitions use ordinary `.hpp` interfaces with matching `.cpp` implementations. For example, `aimbot/lock_on/fov.cpp` owns the FOV setting definition, and `visuals/esp/players/health.cpp` owns the Health feature's default appearance. NPC and zombie profiles reuse the base ESP definitions and apply their independent palette instead of duplicating every feature.

Presentation pages retain the existing `Application::Impl` state and methods. Their paired `.hpp` files are private member-declaration fragments included inside `Impl` by `src/ui/internal.h`; they are not standalone public headers. This preserves object layout and avoids exposing UI internals to game adapters. Add page state to the existing private context and declarations to the topic header, rather than introducing global UI state.

Public ports use `simple_base/features/aimbot/aimbot.hpp`. The earlier `simple_base/templates/combat.h` forwards to it. Existing Application, registry, config and scripting interfaces are unchanged. Feature IDs, Lua route IDs, ImGui widget IDs and defaults remain stable.

## Build ownership

Canonical core compiles the ESP/overlay feature definitions without an ImGui dependency. Canonical UI compiles its presentation modules plus shared combat modules. V2/combined replace canonical presentation sources with their own tree while retaining shared combat. CMake distinguishes absolute feature source paths from legacy relative target sources, so game consumers can continue using `add_subdirectory` normally.

Use the root `SimpleBase.sln`, `SimpleBaseV2.sln` or `SimpleBaseBoth.sln`; each includes source `.cpp`, `.h` and `.hpp` files and forwards to the existing build scripts. Reconfigure existing CMake trees after this reorganization. All generated files, binaries, logs and test data remain under each edition's `build/` directory. Consumers that manually reference removed private page `.cpp` paths must use the CMake target or the new feature paths; public include compatibility is retained.

Historical build records keep their original paths. This refactor does not rebuild, resume or publish game projects. Follow [AUTO_SYNC.md](../../AUTO_SYNC.md) when adopting it in a product.
