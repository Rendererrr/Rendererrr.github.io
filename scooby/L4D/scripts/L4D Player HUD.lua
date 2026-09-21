-- No entity subscription is needed for local player and weapon telemetry.
assert(L4D_API_VERSION == "1.0", "This example needs the updated Scooby L4D host")
local enabled = features.add {id="hud", label="Lua player HUD", category="Lua / L4D", default=true}
ui.subtab("visuals", "lua_player", "Lua player", function() ui.feature(enabled) end)
ui.overlay("player", function()
    if not features.active(enabled) then return end
    local player, game = l4d.local_player(), l4d.info()
    local width, height = engine.viewport()
    local y = math.max(20, height-140)
    render.rect(20, y, 350, 76, {.035,.045,.06,.92}, true, 4)
    render.text(30, y+9, game.preview and "Synthetic player preview" or game.game, {.3,.8,1,1})
    if not player then
        render.text(30, y+30, l4d.status(), {.8,.8,.8,1})
        return
    end
    local movement = player.incapacitated and "Incapacitated" or (player.on_ground and "Grounded" or "Airborne")
    render.text(30, y+30, string.format("HP %d | Speed %.0f u/s | %s", player.health, player.speed, movement), {1,1,1,1})
    local weapon = player.weapon
    local label = weapon and weapon.class_name or "No active weapon"
    if weapon and weapon.clip ~= nil then label = label.." | Clip "..weapon.clip end
    if weapon and weapon.reloading then label = label.." | Reloading" end
    render.text(30, y+51, label, {.7,.85,.9,1})
end)
