# Adding and organizing features

A stable feature ID connects UI, hotkeys, favorites, configs, Lua and the binds overlay. Keep IDs stable when changing labels or translating them.

```cpp
ui.features().add({
    "player.example", "Example feature", "Player / General",
    "Describe the feature here.", false
});
```

Call this before loading a product-specific config that includes the new feature. Built-in startup-default loading occurs in `initialize()`, so register your features after constructing the application and before calling `initialize()`.

Read the effective state through `ui.hotkeys().active(*ui.features().find("player.example"))`. Reading only `.enabled` bypasses hold-mode overrides. Hold binds do not mutate saved settings. Add game behavior in your host; the registry itself does not invoke engine calls.

To display the existing checkbox/gear/color/bind/favorite row on a page, call `feature("player.example")` from an `Application::Impl` page in `src/ui`. Add its option fields to `Feature` or a separate typed settings object, update config encoding/validation, and make your game code consume those options. Keep reusable widget changes in `widgets.cpp` and product-specific layout in a page file.

`FeatureRegistry::resetValues()` restores registered defaults, including features added by the host. Configuration decoding is transactional: it validates a temporary copy before replacing live state. Unknown feature IDs are ignored, allowing older products to load a shared profile without applying unsupported controls.

## New page

Add a page file under `src/ui/`, declare its drawing method in `internal.h`, add the source to `simple_base_ui`, then add navigation in `application.cpp`. UI state belongs in `Impl`, not in the renderer backend or the entity source.

## New overlay

Draw from the same scene snapshot in `overlays.cpp`. Use `overlayScale` for its layout and text sizes. Keep positions normalized to the viewport when saving them so they survive resolution changes. World ESP should continue to use `drawEsp()` and the unmodified entity projection.

## New language

Copy `assets/languages/en.json` to a new catalog code that is not already present, set its `name`, and translate values inside `strings`. The original English text is the key. Missing or empty translations fall back to English. Reload the selected language from Settings → Interface. Invalid JSON is rejected without discarding the current catalog.

The source includes 23 catalogs and matching fallback fonts. Keep every catalog and the RTL display preparation when porting; newly added phrases still need translation and fall back to their English source text.

## Lua API extension

Use `Application::scripts().registerHostApi` to register C functions or tables on each new Lua state. `base.get`, `base.set`, `base.log` and `print` are already provided. Keep engine calls on the permitted thread and validate arguments at the boundary. States persist until their named script is stopped or replaced. Do not retain a state after that point. See [LUA_API.md](LUA_API.md) for custom UI, lifecycle and game API extension details.

```cpp
ui.scripts().registerHostApi = [](lua_State* L) {
    lua_pushcfunction(L, [](lua_State* state) -> int {
        lua_pushstring(state, "My Project");
        return 1;
    });
    lua_setglobal(L, "project_name");
};
```

Include `lua.h` in an `extern "C"` block for this example. The public core target exports the Lua include directory.
