# Entity classification colors

Additive API revision 1 contract. Hosts opt in with `FeatureRegistry::enableEntityColors()` before profile loading. The stored master begins off, so registering support does not recolor existing profiles. Existing hosts that do not opt in retain identical feature/team/host-palette behavior. Every consumer must rebuild to receive shared code and embedded API documentation changes.

## Host classification

Append `Entity::kind` (`Unknown`, `Player`, `Npc`, `Item`, `Weapon`, `Prop`) and `Entity::relationship` (`Unknown`, `Normal`, `Neutral`, `Friendly`, `Hostile`) from verified host data each snapshot. Both default to Unknown. Normal is an explicit ordinary NPC classification; it is not an inferred hostile relationship. Unknown, normal, neutral, friendly and hostile NPC colors are independent. Player unknown/normal share the Players category, with separate neutral/friendly/hostile player categories. Items, weapons and props have their own categories. Invalid enum values use Unclassified. No classification is inferred from entity names, models, health or `teammate`.

Team routing remains unchanged: `addTeamEsp()` and `Entity::teammate` choose the existing enemy/teammate feature set before category color resolution. Relationship colors never enable an entity, change range, supply health, or change radar classification.

## Color precedence and appearance

1. A valid existing `Scene::espPalettes` entry with the relevant mask bit retains its original highest-priority solid RGBA override for box, skeleton, name, distance or snapline.
2. If the host opted in, Entity colors is enabled and the resolved category override is enabled, its primary/secondary colors replace those feature RGB colors. Category alpha multiplies each feature endpoint's alpha. Existing feature gradient enable/direction and geometry remain in use.
3. Otherwise use the selected enemy/teammate feature's original color and gradient. Disabled categories fall directly back to feature colors; they never inherit a hostile or normal NPC category.

Health bars, HP text, outline colors and bar backgrounds retain their own feature settings. Box fill colors and fill gradients also remain independent by default. Optional Color box fill applies category RGB/gradient endpoints to the box fill while multiplying its configured alpha; the existing fill enable/gradient flags still control rendering. A host box-palette override bypasses category fill tint too, preserving the previous host-palette contract.

The same per-feature size, position, offset, thickness, full/corner style and label/bar stacking still apply. Categories are a fixed-size settings array, not feature-registry clones. Per-frame active feature pointers and category colors are resolved before entity traversal; per-entity classification and lookup require no registry scan, string construction or allocation.

## Persistence

`entity_colors` is an optional schema-1 config object with `enabled` and a `categories` object keyed by stable string IDs: unclassified, player, player_neutral, player_friendly, player_hostile, npc_unknown, npc_normal, npc_neutral, npc_friendly, npc_hostile, item, weapon, prop. Each category stores enabled, color, second_color and tint_fill. An absent object disables the category master, including when switching from an enabled classified profile to a legacy profile; inactive category edits are retained. In an explicitly present object, omitted fields retain their current values (initially defaults). Unknown future category keys are ignored. Invalid known fields reject the complete profile atomically. A profile cannot enable host support; non-opted-in hosts ignore the optional object.

## UI and Lua

Opted-in hosts get one Entity colors editor with a dropdown starting at **Global**, followed by supported categories. Global edits the existing `esp.*` feature colors and enabled gradient endpoints; it introduces no extra palette or profile schema. Health colors stay independent. Category **Override global** toggles the existing category enable flag. Turning it off inherits the original feature colors. Enabling one override while the saved master is off enables only that category, retaining the other categories' color values without unexpectedly activating them. Reset category preserves its original reset semantics.

`enableEntityColors(categoryMask)` optionally restricts the editor to meaningful host categories. Bits use `1u << EntityColorCategory`; omitting the argument includes all existing categories. The mask is host metadata and survives profile loading and reset. It is never serialized or set by Lua. Global remains available for every opted-in host. Existing category IDs and Lua get/set/reset remain compatible.

The controls use the existing theme, RGBA picker, scale and all23 languages. Custom pages draw the same editor with `ui.entity_colors()`. Category overrides are shared by both team feature sets; per-team feature colors still provide their own fallback/alpha through the existing feature controls.

`esp_colors.available()` reports host support. `esp_colors.enabled([boolean])` reads/sets the user master. `esp_colors.get(category)` returns the category settings; `esp_colors.set(category, table)` atomically applies supported fields. `esp_colors.reset([category])` restores that category or all settings. Changes use the same registry-owned settings as configs and UI; scripts cannot register classification support or modify host Entity samples through this API.

## Validation boundary

Shared renderer/config/UI tests cover classification, explicit fallbacks, palette priority, team and health isolation, gradients/fills/alpha, placement and old profiles. Headless UI and renderer fixtures are synthetic; they do not validate any title's live classification, health, camera or performance. Game owners supply verified classification and retain their own per-title runtime/performance checks. No paused game work is resumed by this contract.

## Integration example

Register support before initialization/profile loading; attach authoritative classifications in the host's existing sample implementation.

```cpp
app.features().enableEntityColors();
app.initialize();
// In EntitySource::sample, after reading verified host state:
entity.kind = simple_base::EntityKind::Npc;
entity.relationship = simple_base::EntityRelationship::Friendly;
```

The classification above is an example, not a rule for identifying friendly NPCs. Leave unavailable fields Unknown. The default master remains off until the user enables it through the UI or script API.

```lua
if esp_colors.available() then
    ui.window("entity_colors", "Entity colors", function()
        ui.entity_colors()
    end)
end
```

## Paused checkpoint scope

ESP classification, themed controls, strict config/Lua editing and all 23 language catalogs are implemented. Dedicated preview captures and per-title adoption/runtime acceptance remain pending. Radar category settings, independent relationship/type dot colors, a host per-entity radar override, radar persistence/reset/Lua/UI and their regressions are **not implemented** in this checkpoint. Radar retains its existing enemy/team behavior. Do not treat this checkpoint as the combined ESP/radar release contract. HLS may retain its previous verified shared checkpoint for release.

## L4D host radar extension (2026-09-23)

A subsequent L4D-only request adds two reusable host seams without resuming the paused all-consumer radar-category rollout:

- `Entity::radarColor` optionally supplies a dot RGBA independently of ESP classification/palettes. Existing alive/projection/range eligibility is unchanged. Absent or non-finite colors retain Radar enemy/team fallback; finite channels are clamped to 0–1. A zero-alpha host override suppresses that contact's dot, outline and name. Fresh snapshots must clear stale overrides when data or settings change.
- `Application::setRadarControls(std::function<void()>)` appends host groups below Labels in Radar column 3, inside the active themed/localized UI scope. Set an empty callback to remove it. Hosts own settings, persistence, localization and captured-state lifetime. Register on the UI thread; no native page replacement is needed.

L4D uses its existing 19 infected/survivor/pickup classes and independent registered feature settings. Hosts leaving both seams unused keep their existing radar appearance. This is not the pending generic relationship/type radar settings API; other products remain unchanged. The earlier frozen ESP-only checkpoint remains historical evidence, not a hash certification of this extension. L4D's `l4d_radar_colors` test exercises rendering and host settings; shared `ui_and_esp` covers unaffected native controls. Live game results remain separate.
