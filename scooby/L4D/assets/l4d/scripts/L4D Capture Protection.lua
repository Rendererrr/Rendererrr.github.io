-- Capture policy controls feature activation; gate your callbacks with features.active.
local hud = features.add {
    id="hud", label="Compatible HUD", default=true,
    category="Lua / L4D", capture_protection="safe"
}
local effect = features.add {
    id="effect", label="Example blocked toggle", default=false,
    category="Lua / L4D", capture_protection="disable"
}
local strength = 50
ui.subtab("visuals", "lua_capture", "Lua capture", function()
    ui.group("Capture Protection", function()
        ui.feature(hud)
        ui.feature(effect)
        l4d.protected_control(effect, function()
            local changed
            changed, strength = ui.slider("Example strength", strength, 0, 100)
        end)
        imgui.text(capture_protection.status().message)
    end)
end)
ui.overlay("capture_hud", function()
    if not features.active(hud) then return end
    render.text(20, 110, "Lua HUD | "..capture_protection.status().message, {.3,.8,1,1})
end)
events.on("capture_protection_changed", function()
    if capture_protection.enabled() then
        -- Restore any persistent effects your script previously applied.
        -- The L4D host also disables native hooks while protection is enabled.
    end
end)
events.on("update", function()
    if not features.active(effect) then return end
    -- Add supported behavior here. This example does not modify the game.
end)
