# Verification and preview controls

```bat
cmake --build --preset preview
ctest --preset tests
cmake --build build/windows --config Debug
ctest --test-dir build/windows -C Debug --output-on-failure
```

`core_systems` exercises config round trips, malformed-data rollback, autosave, startup defaults, rename/delete, unsafe paths, mouse capture, toggle/hold behavior, focus loss, real Lua execution/errors/budgets, language fallback and projection.

`ui_and_esp` draws every page at 360×280, 640Ã—480, 1280Ã—720, 1920Ã—1080, 3440Ã—1440, 3840Ã—2160 and 7680Ã—4320, and verifies actual box/skeleton/name geometry. It also opens feature/radar gear popups, checks hover IDs, exercises group collapse, and verifies watermark text/graph, inactive binds and radar names/rings affect HUD drawing. It uses a simulated texture uploader; the live DX11 smoke test complements it.

Run the live renderer lifecycle test:

```bat
build\windows\Release\simple_base_preview.exe --smoke --warp --data "build\smoke-data"
```

The smoke run resizes, switches into/out of borderless fullscreen, minimizes/restores, changes independent UI/overlay scales and recreates the DX11 device/backend. It exits after 150 frames and writes `smoke-result.txt` into the chosen data directory. `--warp` uses Microsoft's software DX11 device so the run does not depend on a particular GPU.

## Capture a preview

```bat
build\windows\Release\simple_base_preview.exe --no-welcome --page config --frames 12 --capture "build\config.png"
```

Supported `--page` values: `visuals`, `radar`, `interface`, `config`, `hotkeys`, `overlays`, `scripts`, `editor`, `api`, `links`, `console`. Use `--console` to show the floating console with the main menu hidden. Other options: `--width`, `--height`, `--data`, `--warp`, `--language`, `--ui-scale`. Use `--ui-scale 0.5` to reproduce 50% manual scale (host DPI still applies); `--data` isolates captures from your saved profiles. A capture is taken from the real DX11 backbuffer before presentation; exit code 3 means capture failed.

## Interactive checks

- Create a profile, change a color, save/load it, set it as default, then restart.
- Enable auto-save and change several features; reload the profile.
- Capture Mouse 1 after releasing the activation click; check Toggle, Hold and Hold to disable.
- Type in the Lua editor and search fields; assigned keys must not toggle features during text input.
- Press F over a feature, then open Favorites and change it there.
- Open the gear popup, change box style/fill/thickness, and inspect the background scene with the menu closed.
- Change RGB, HEX and alpha values; save/reload the profile.
- Open Visuals > Radar, drag anywhere in the radar plot, resize the window and change overlay scale. Draggable is enabled by default for every overlay.
- Drag the watermark with the menu open, save/reload its position, then disable Draggable and confirm it stays fixed.
- In Interface, enable Custom accent and choose a color. Change Normal text, then use its gear to change Tabs, Sub-tabs and Headings independently.
- Hover a feature to check the description box above the menu; disable Feature descriptions to hide it.
- Change watermark options and radar appearance through their gears, save the profile and reload it.
- Select Spanish or German, reload the language catalog, and return to English.
- Create/edit/run a Lua script, switch away and back to check draft retention, and inspect console output.
- Resize, minimize, restore and press F11 while the menu is open and closed.

The template does not claim runtime validation for DX12, OpenGL or Vulkan hosts. DX12/OpenGL renderer targets can be compile-checked on Windows; Vulkan requires a Vulkan SDK. Validate each host's synchronization and swapchain lifecycle during integration.

- Assign a key to Reset radar position. Verify both its button and key reset the position, flash its Hotkeys row briefly, and never leave it enabled. Hold the key to verify it runs only once per press.
- Keep an inactive toggle visible in Hotkeys and switch it on/off; its name and key should light up together with no mode or ON/OFF suffix.


Active Features checks cover effective toggle/hold states, master/child filtering, host opt-out, missing/cyclic parents, action exclusion, optional profile fields and atomic rejection, empty-list rendering, dragging/locking, and background opacity. The existing multi-resolution UI pass includes the new overlay and its responsive Settings group.


`esp_appearance` exercises actual draw geometry for RGBA gradients, independent outlines, full/corner box fills, all four label/bar placements and shared-side collision avoidance, horizontal/vertical health ratios, three snapline origins, invalid health and malformed bone pairs. Core checks cover new appearance profile round trips, legacy fill migration and atomic rejection. UI checks click the actual gradient, direction, outline and fill controls, alongside the existing ID-conflict and hotkey-popup checks.


Scale controls share one UI/Overlays/Text selector. The UI regression pass checks live menu resizing during a held UI-scale drag, stable values when the pointer stops, direction reversal through column reflow, release without a jump, and restoration of the original bounds with Escape. It checks rendered watermark text growing during a held overlay-scale drag and returning to its original size on Escape. Text-scale checks verify live whole-pixel font changes, stable input through reflow, cached fonts when the pointer stops, unchanged menu dimensions, release without a jump, Escape restoration, exact numeric entry, and the advanced text-role controls.


`lua_ui_api` verifies persistent script state, host extensions, registered features/actions, custom tabs and sub-tabs, actual checkbox input, overlays, independent windows, page replacements, theme cleanup, failed-load rollback, nested callback error recovery, execution deadlines, and the API reader attached to either side. It loads both bundled Lua UI examples. Use `--page api --no-welcome` to inspect the documentation reader beside the editor.
