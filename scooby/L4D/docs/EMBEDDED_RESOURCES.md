# Embedded resources and compact distribution

Simple-base links its fonts, icons, font licenses, API reference and starter Lua scripts into each consuming DLL or executable. A fonts directory is no longer a runtime requirement. Windows uses RCDATA; other builds use generated C++ arrays. Both representations are generated from the same source assets. Keep the font sources and licenses in this repository for rebuilding.

## Consumer integration

Link `simple_base_ui` normally to inherit the shared bundle. Embed immutable game pages and examples in a separate scope:

```cmake
simple_base_embed_resources(TARGET my_host SCOPE my_game
  ROOT "${CMAKE_CURRENT_SOURCE_DIR}/assets"
  DOC_EXTENSION "${CMAKE_CURRENT_SOURCE_DIR}/docs/GAME_LUA_API.md"
  DOC_SNIPPETS "${CMAKE_CURRENT_SOURCE_DIR}/docs/LUA_SNIPPETS.md")
```

`ROOT` is required. The two document arguments are optional; `DOCS_ROOT` can embed a directory of Markdown/JSON documents. Language directories named `languages` or `lang` at the root remain external. Scopes must be unique within the final module and contain only ASCII letters, digits, underscore or hyphen. Look up a page with `readBundledAsset("pages/my_game.lua", text, "my_game")` from `simple_base/core/resources.h`.

Set `AppOptions.resourceScope` to the same scope and `AppOptions.languageDirectory` to the installed language directory. Its default remains `assets/languages` for existing consumers. Set `AppOptions.data` to the existing writable per-product data directory; it must not point at the read-only installation directory. API references fall back to the embedded shared guide and append the embedded game extension and snippets. Old full asset staging remains available for unmigrated host adapters and development tools.

Asset additions, edits and removals trigger CMake reconfiguration and resource relinking. The generated `embedded/<target>-<scope>/manifest.json` records original asset sizes and SHA-256 hashes. The same JSON is inside the module as `_bundle.json`; `_index.txt` lists bundled paths. Windows identifiers are `SB_ASSET_` followed by uppercase hexadecimal UTF-8 bytes of `scope/path`, with resource type 10. A verifier can inspect these using data-only resource loading without executing the DLL entry point.

## Scripts created on first use

Application initialization seeds the writable `data/scripts` directory before building the Lua script list. It never automatically executes a script. The included scripts are:

- `Welcome.lua`: Quick Controls for supported ESP and overlay features, health/name preset and an ESP disable action.
- `Custom UI.lua`: adjustable crosshair overlay with an F8 keybind, shape sliders and reset action.
- `Standalone Menu.lua`: floating session stopwatch, optional timer/FPS HUD and F9 window keybind.

The last supplied defaults are recorded in `data/bundled-script-defaults`. An update replaces a script only when it is missing or still matches a recorded stock revision. The previous bundled example revision is also recognized, including CRLF/LF differences. Edited scripts and unrelated user files are preserved. Game-scope `scripts/*.lua` entries can supply additional examples; a same-named game example takes precedence over the shared example. Files in `pages/` are immutable menu definitions, not user scripts.

## Compact packages

A migrated game can ship its DLL/helper, `lang` catalogs, package manifest and one third-party notices file. It need not ship fonts, immutable pages, API docs or starter-script folders. The exact layout and marker are owned by the game's package format. GoldSrc shares one DLL and uses per-edition `lang/valve`, `lang/gearbox` and `lang/bshift` catalogs.

Rebuild the host before making a compact package. Verify its actual embedded hashes, language paths, page registrations, generated scripts and module size limits. Do not remove loose dependencies from an older binary that still uses them. Preserve the previous complete artifact for rollback; a new module requires its own runtime evidence.

## Regression

Build and run the full shared CTest suite on x64 and Win32. `embedded_resources` initializes against a deliberately missing asset folder, checks multilingual fonts and external catalogs, runs the new scripts through the Lua API, checks drawn overlay geometry, opens the API browser and verifies safe script updates. It also compiles and looks up the generated portable C++ representation on Windows. This is not a Linux, Proton or Wine runtime acceptance result.

Then run the consumer's compact UI fixture, verify the real packaged module resource hashes and test loader install/repair. Build artifacts and exact input hashes belong in the current checkpoint record. All consumers must be rebuilt/reloaded to receive shared changes; no running or previously shipped binary updates itself.

## Windows data paths in injected hosts

The shared file layer normalizes Windows paths and uses the extended Unicode namespace for reads, writes, listing, renaming and deletion. It does not depend on the game executable declaring long-path support. Atomic writes use a short temporary sibling, so a valid long destination filename does not grow past the filesystem's component limit. Caller-facing data paths and script/config names remain unchanged. Edited bundled scripts retain the existing ownership/update rules.

`compatibility_paths` exercises bundled script seeding beyond 310 characters, Unicode names, user-edit preservation, read/list/rename/delete, overwrite refusal, near-limit filenames, relative-path normalization and failure to replace a locked target without losing its original contents. Run both Windows architectures and the full shared suite before rebuilding consumers. A local Windows test does not certify a network share or Wine/Proton runtime. See [Microsoft's path rules](https://learn.microsoft.com/en-us/windows/win32/fileio/maximum-file-path-limitation).
