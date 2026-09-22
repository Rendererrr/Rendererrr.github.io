# Shared health bar and HP text contract

`esp.health` remains the health bar with its existing ID, settings and default enabled state. `esp.health_text` is an independent HP Text feature, off by default so older profiles do not gain another label automatically. Both are standard controls under Visuals > ESP, available to configs, favorites, Hotkeys, Lua and Active Features through the existing registry. No config schema or binding enum is changed.

## Authoritative health data

`Entity::health` and `Entity::maxHealth` default to **-1 (unknown)**. An adapter must explicitly provide current, authoritative health each snapshot. Leave unknown values at -1, and clear stale values when telemetry becomes unavailable. Existing adapters that supply both valid values need no source changes. Adapters that set only current health can display HP text, but must supply a verified maximum before drawing a bar. Do not substitute 100, the current value, or a previous entity's maximum.

For existing consumers, the legacy pair `(health=0, maxHealth=0)` is also unknown and renders neither overlay. This prevents a new HP text toggle from exposing fabricated 0 HP in adapters that already use that pair. An authoritative zero with an unknown maximum must be `(0, -1)`; zero with a verified positive maximum remains valid. Positive current health can render text with maxHealth=0 because only the ambiguous zero/zero pair is reserved.

| Data | HP text | Health bar |
| --- | --- | --- |
| Finite health >= 0, finite max > 0 | Current health rounded to whole HP | Ratio clamped to [0, 1] |
| Finite health >= 0, maximum unknown/invalid | Current health | Omitted |
| Unknown/negative/nonfinite health, or legacy (0, 0) | Omitted | Omitted |
| Zero health while the entity remains eligible | 0 HP | Empty bar background/outline |
| Health above maximum | Actual current HP, not clamped | Full bar |

The usual alive, ESP-enabled, range and visibility/projection filters still apply. A dead or unsupported entity is omitted. Zero does not independently declare an entity dead; the host owns that status. Positive numerical values are not proof of authority: the host must verify its engine/entity/session/generation source. The renderer never infers missing health or maximum.

## Appearance and placement

HP text uses the existing color, text size, position, offset, gradient and outline settings. Its default is white, outlined, on the right; the bar retains its left placement. Both can be enabled independently. HP text enters the same per-side label stack as name/distance, with bar width, offset and outline reserved before text placement. Host-supplied names and distance units use that stack too. Separately drawn host overlays must reserve their own space; the renderer cannot detect unrelated draw lists.

`EspStats::healthBars` retains its meaning. New `healthTexts` counts valid HP labels, which are also included in the existing `labels` total. Hosts using aggregate initialization remain source-compatible after rebuilding the canonical dependency.

```lua
features.set("esp.health", true)
features.set("esp.health_text", true)
features.bind("esp.health_text", "F7", "toggle")
ui.tab("health", "Health", function()
    ui.feature("esp.health")
    ui.feature("esp.health_text")
end)
```

Adapters continue to own actual health acquisition and per-title validation. Shared tests and preview values do not certify Half-Life, Opposing Force, Blue Shift, another game, or a Linux runtime. Game-owner integration must test live damage, death, respawn, serial reuse, map/disconnect transitions and missing telemetry without stale or fabricated health.


## Shared validation and handoff

`health_esp` tests independent toggles, actual HP glyphs, bar ratios, unknown/invalid/extreme telemetry, same-side name/distance/bar/text layout, stale-data removal, eligibility, legacy configs, independent appearance/bindings and Lua/hotkeys. The normal viewport matrix also draws both health overlays using explicit demo maxima. `--health-esp-demo` is a native preview fixture with full, damaged, zero, over-max and unknown samples; its diagnostic expects four health bars and four HP labels. It does not sample a game.

The completed shared handoff records exact inputs, x86/x64 test logs and native captures in `build/health-esp-checkpoint.json`. Previous sidebar and selectable manifests remain historical evidence. API revision and config schema remain 1; the changed default makes missing telemetry safely invisible. Hosts must rebuild and validate their own data independently before release.
