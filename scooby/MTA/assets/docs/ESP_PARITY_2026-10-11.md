# ESP integration and release validation — 2026-10-11

This document separates source integration, automated validation and live-game acceptance.
Release build receipts remain under the applicable project build directories.
The authorized targets are canonical UI, UI-v2/UI-vboth, GTA IV, GTA SA, TF2,
L4D and GMod. Other paused projects remain paused. No changelog is generated.

## Donor and observed behavior

Use only `FiveM/new` relative to the repository root. The audit inspected
`gui/globals.hpp`, `gui/feature_registry.cpp`, `features/feature_ui.cpp`,
`features/esp/esp.cpp`, `cone_hat.hpp`, `model_preview.cpp`, and `weapon_icons.cpp/.hpp`.
Registration is not proof of a working renderer. The following checklist records
the observed rendering paths and outstanding shared work; host adapters still
need their own complete audit.

| Feature family | Working donor behavior / limits | Shared parity status |
| --- | --- | --- |
| Box | Full/corner, independent fill, stroke/fill gradients and directions, rounding, thickness, outline, pulse, shadow, corner length, pose-fitted width/height/head/XY offsets | Shared renderer supports sizing, offsets, rounding, pulse/shadow, corner length and independent fill direction. Head offset uses verified host anchors and is exposed only for profiles with head support |
| Health | Bar and independent text, four-side placement, gradients, width/background/outline, per-actor smoothing and cleanup | Four-side placement and per-view health smoothing implemented; text remains authoritative |
| Armor | Authoritative current armor with a donor-specific 100 maximum, separate side/width/color/outline, bar reservation | Shared armor bar implemented. GTA IV uses verified armor natives and player maximum; SA uses verified current/max telemetry. No armor control is synthesized for Source hosts |
| Name/distance/HP text | Independent positions/offsets, size/color, text shadow, name/distance backgrounds and gradients, stacking | Shared text backgrounds, shadows and XY offsets implemented; custom host labels retain their own supported controls |
| Weapon | Selected hash read, embedded icon lookup, known-name fallback, unarmed filter, name/icon switches and layout | SA uses its existing weapon ID and verified name map through the shared renderer. Other hosts preserve their existing weapon metadata/icons; no cross-game icon/hash mapping is invented |
| Skeleton | Validated donor bone pairs, color/thickness, outline, per-line gradient, dashed segments, joints, head circle | Dashed skeleton strokes and joint markers added alongside existing bones/gradient/outline |
| Head marker | Filled/outline circle using verified head bone | Shared marker implemented using optional host anchors; GMod retains its native head styles |
| Snaplines | Screen edge/center origins, thickness/color, dashed and gradient lines | Dashed strokes added to the shared baseline |
| Trail | Bounded timed position history, duration/interval/point limit, taper, gradient/fade, outline, head dot; clears absent entities and replaced identities | Bounded per-Application history implemented; absent actors, disabled trails, clock gaps and teleports clear history. GMod uses its native bounded player history; L4D snapshot lifetime keys reset on slot reuse/map transitions |
| Ring | World-plane rings, radius/elevation, segments/count, fill/color/width, pulse | Opt-in canonical implementation and all four shared host adapters integrated; GMod uses independent native geometry. Model previews use explicitly synthetic anchors |
| Cone hat | 72-face world cone, verified head, radius/height/offset, opacity, rim/outline, tip-to-rim gradient, rainbow/spin | Opt-in canonical implementation and all four shared host adapters integrated; GMod uses independent native geometry. Model previews use explicitly synthetic anchors |
| Offscreen | Filled/outline/chevron arrow, size/margin, pulse, outline, distance | Shared three-style arrows implemented. L4D retains its existing arrows IDs with three styles, outline and pulse; GMod retains native arrows with viewport checks and metres |
| Images, footsteps, flags, aim direction | Settings exist but no drawing path found in the donor `esp.cpp` examined | Unfinished donor controls; do not advertise or expose as implemented |

Several fine-grained donor settings are likewise not consumed by its runtime:
hat style, trail style/arrows/smoothing/position, offscreen name/weapon labels,
separate weapon-icon placement/tint/gradient, and some health/skeleton styles.
Complete the per-field registry/persistence audit before claiming full parity.

Donor fresh Players/NPCs defaults use width `.38`, height `1`, head offset `0`,
and green-to-teal health gradients. Its width is applied relative to `.4` after
pose fitting; it is not simply screen box width divided by height. Do not replace
saved host values or host-specific fitted geometry with those raw numbers.

The donor has Players/NPCs/Self banks and category override storage. In the
examined runtime, category selection is `self ? -1 : player ? 0 : 2`; that does
not establish live friendly-category classification. Unknown relationship data
must remain unknown. Shared category *color* overrides are not full profile parity.

The donor's `feature_ui.cpp` stores scalar/color registry values in opaque
`host_state["fivem.port.v1"]`; booleans also synchronize with shared registered
features and their hotkeys. Saving merges recognized values into the previous
payload to preserve unknown historical fields. Missing scalar fields use captured
defaults. Porting must retain each destination's own stable IDs and migration
rules rather than overwrite it with this FiveM payload. The icon cache validates
embedded dimensions, is scoped to the ImGui context and removes registered
textures on shutdown. Each destination needs its own authoritative weapon mapping
and renderer texture lifecycle.

`UI/build/esp-parity-donor-audit.json` records eight donor source hashes and
occurrence counts for 119 directly registered target fields. These counts support
the source audit; they do not certify runtime behavior.

## New shared decoration contract

`FeatureRegistry::addEspDecorations(prefix)` registers disabled `<prefix>hat`
and `<prefix>ring`, `<prefix>head`, `<prefix>trail`, `<prefix>offscreen` features for an existing master. It is idempotent. Register
each supported profile separately after host profile construction, before config
loading. Existing IDs, bindings, profiles and category filters remain in place.
The ordinary registry does not opt an unsupported game into these controls.

`Entity::decorations` is an optional `EspDecorationFrame` containing authoritative
head and feet anchors plus orthogonal right/forward/up vectors, each representing
one metre in the host's world units. The renderer uses `Scene::camera` or an immutable `Scene::projectWorld` snapshot callback.
Missing/nonfinite anchors, invalid bases and clipped geometry are suppressed.
Never infer a game's head index, fabricate telemetry, or supply this frame for a
screen-only adapter with no valid world projection. Such adapters need an explicit
validated projection integration before registration.

Rendering respects the selected profile, its master, hotkeys, life/ESP/range gates
and viewport clipping. Decoration geometry is stateless. Trails and health animation use bounded per-Application `EspRenderState`, without live entity pointers.
Ring tessellation/count and numerical settings are bounded at decode and render.
ImDrawList flags are restored. Existing Lua `features.get/set/active/bind/color`
and `ui.feature` contracts operate through the registered IDs.

The appearance codec persists the additive dimensions, animation, opacity and
tessellation settings. V1, V2 and combined settings pages contain real gears and
rows only for registered features. New language keys have explicit English
fallbacks in all 23 catalogs; translated wording remains pending.

The existing canonical synthetic scene supplies its own explicit metre-scale
anchors. `simple_base_preview.exe --esp-decorations-demo --hidden --warp
--no-welcome --frames 12 --data <isolated-build-data> --capture <build-image>`
exercises visible cone/ring geometry and the actual UI. This is a fixture in the
existing preview, not a new game product or game acceptance.

## Validation and remaining release gates

Fresh canonical builds are under `UI/build/esp-parity-x64` and
`UI/build/esp-parity-x86`. The original sandboxed x64 MSBuild stalled before
compilation; it was cancelled and the unrestricted retry succeeded. Keep both logs.
The new `esp_decorations` suite covers opt-in/idempotency, profile isolation,
settings/hotkey persistence, rendered counts, host-unit scaling, finite output,
missing/bad anchors, behind-camera rejection, master gates and draw-state restoration.

Initial canonical full runs: x64 24/26; Win32 25/26. `ui_and_esp` targeted stale
top-header coordinates for the footer Console tab, then an outdated toggle X
coordinate. The fixture now resolves the exact item IDs in the actual footer and
gear row, retaining its original assertions. `lua_custom_ui` hit its execution
time budget during concurrent compilation and passed in isolation. The execution
budget was not changed.

Final canonical Release builds succeeded; x64 `tests-idle.log` and Win32
`tests-final.log` each pass **26/26**. The combined V1/V2 x64 Release build and
**28/28** tests passed under `UI-vboth/build/esp-parity-x64`. Combined Win32 and
standalone UI-v2 builds have not been run for this checkpoint. The source inventory
matches 470 files. All 23 catalogs validate. The active-consumer audit passed on
unrestricted read-only retry after sandbox discovery encountered an inaccessible
unrelated source folder; paused consumers remain skipped. Preserve initial and
retry evidence rather than overwriting the failures.

The final x64 WARP capture `UI/build/esp-parity-x64/decorations-final.png` was inspected:
cones and filled concentric rings render on the explicit synthetic actors and
the registered settings rows are present. Its FPS counter is not gameplay
performance evidence. Model-mesh previews/picking and native game screenshots
have not been accepted by this checkpoint.

Exact modified-source, evidence and candidate binary hashes are retained in
`UI/build/esp-parity-checkpoint.json`. This manifest is a local build checkpoint,
not a package verification or native gameplay receipt.

## Host integrations and asset sizes

GTA IV and SA register actor-only decorations and armor. GTA IV projects snapshots through
its verified camera data and uses head/foot native bones; SA uses the existing verified
ped bone tags. Both preserve separate player/NPC/self settings and range/master gates.
TF2 uses studio head hitboxes and Source-to-metre conversion; existing class/loadout
labels and icons remain native. L4D uses head hitboxes and collision feet, keeps its
special-infected overrides and existing arrow feature IDs. GMod retains its own native
UI/config/hotkey/renderer architecture; its rolled-back model preview is not restored.

The earlier DLL size table mixed old/development artifacts with production builds.
GTA IV now downloads pinned fonts/languages and Niko/NPC preview meshes/textures.
The model-download candidate is 3,165,696 bytes (3.02 MiB), versus the older
68,367,360-byte embedded-font artifact. Both models load only after pinned hash
verification; the model preview capture was inspected. Packaging rejects a stale
DLL/asset-manifest pairing.
SA now removes the duplicate shared fonts/languages from its embedded resource bundle.
Its authenticated loader already downloads and verifies these beside the DLL, with
cache/repair/cancellation checks. Small scripts, documentation, branding and host preview
resources remain embedded. L4D's production release uses `L4D_DOWNLOAD_ASSETS=ON`;
the 116.95 MiB embedded development build is not the production size.
TF2 already uses downloadable assets. Final per-product sizes must come from the exact
release outputs, not an arbitrary DLL found recursively under build/.

## Current evidence and acceptance boundary

The final shared runs pass 26/26 canonical x64, 26/26 canonical Win32, 28/28
combined V1/V2 and 24/24 standalone V2 tests. Logs are `tests-release-final.log`
in each edition's `build/esp-parity-*` directory. This includes verified-anchor box
head offset and a full appearance-codec round trip. TF2 exposed the original
head-radius clamp bug (6 pixels became 10); head markers now use their own 1..20
bounds, and both TF2 default-profile tests pass after the fix.
GTA IV's release build passes 10/10 tests; the loader distribution suite verifies offline
cache, repair, cancellation and corrupt package rejection, and the backend identity suite
passes for all three pinned executables. These owned fixtures explicitly do not load a game.
The GTA IV native inventory now contains 155 symbols, 147 code guards and 139 registration
records per profile. Armor analysis is retained under its `build/analysis/esp-parity-armor*.json`.

Release candidates are being built with `release.bat -Product gta4,gta-sa,tf2,l4d,gmod
-NoPublish -LocalOnly -KeepStaging`. `-NoPublish` alone still copies to the public checkout;
`-LocalOnly` preserves the candidate boundary. Logs are retained in
`simple-base/UI/build/esp-parity-release-build*.log` and each product's build directory.
The initial Python launcher probe stalled; the retry used a direct Python installation.
The release helper now preserves the launcher's `-3` as an array argument.

Live gameplay, model-preview interaction in the actual games, restoration and comparable
foreground FPS remain separate acceptance requirements. Builds, synthetic previews and
owned DX9 fixtures do not establish those results. The table identifies per-host behavior; inert donor controls remain excluded. No changelog is generated.

SA's compact initial candidate is 5,231,104 bytes (4.99 MiB); its 11/11 project
checks and matching-loader distribution tests passed, including complete assets,
offline cache, repair, cancellation and corrupt/wrong-game rejection. The initial
L4D download candidate is 6,848,000 bytes (6.53 MiB). The root L4D solution now
selects downloads explicitly; `-EmbeddedAssets` is the opt-in development variant.
GMod's full native regression set passed across the retained initial/retry logs,
including actual config save/load/reset of hats, rings and trails. Its feature-browser
and hotkey tests now require the implemented trail control to be discoverable.

Final product rebuild/package/publication receipts and exact artifact hashes should
be read from the release run, after the final shared changes. Source changes and
fixture tests do not certify native-game foreground FPS or live authentication.
