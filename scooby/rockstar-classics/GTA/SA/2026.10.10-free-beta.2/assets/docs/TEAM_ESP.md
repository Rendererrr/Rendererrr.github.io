# Separate enemy and teammate ESP

Hosts opt in by calling FeatureRegistry::addTeamEsp() before loading profiles. The Visuals / ESP page then shows an Enemy / Teammate dropdown. Each relation has its own enable switch, box, name, health bar, HP text, distance, skeleton, snaplines, colors, appearance, range and bindings.

Existing esp.* IDs remain the enemy settings. New teammate IDs use esp.teammate.*. Existing configuration and Lua APIs save and address each feature independently. The selector changes which controls are edited; it does not change an entity's relationship. The host must supply a current, verified Entity::teammate value.

Teammate ESP starts disabled. Hosts that do not call addTeamEsp retain the original behavior: esp.* applies to both relations. No Entity layout or API revision change is required. Radar remains independent and consumes the same scene/team data.

Run the team_esp CTest, which checks legacy behavior, independent rendering/range/health, configuration, Lua, hotkeys, reset and actual dropdown/toggle interaction. Also run the full shared Win32/x64 suite and consumer checks. These fixtures do not establish any game's entity/camera/team binding correctness.
