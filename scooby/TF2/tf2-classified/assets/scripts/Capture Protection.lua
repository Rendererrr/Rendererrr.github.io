-- Shared overlay drawing is safe. Host-side world/camera/material changes must opt out.
local overlay = features.add {
    id="overlay", label="Protected Lua overlay", default=true,
    capture_protection="safe", category="Capture Protection / Example"
}
local world = features.add {
    id="world", label="World feature example", default=true,
    capture_protection="disable", category="Capture Protection / Example",
    description="Demonstrates blocking; this example does not modify a game."
}
local strength = 0.5
ui.tab("capture_example", "Capture Protection", function()
    ui.group("Example features", function()
        local state = capture_protection.status()
        imgui.text(state.message)
        ui.feature(overlay)
        ui.feature(world)
        ui.keybind(world)
        imgui.disabled(features.blocked_reason(world) ~= nil, function()
            local changed, value = ui.slider("World strength", strength, 0, 1)
            if changed then strength = value end
        end)
    end)
end)
events.on("capture_protection_changed", function()
    if capture_protection.enabled() then
        -- Restore any native changes your script previously applied here.
        print("Capture Protection enabled: world example disabled")
    else
        print("Capture Protection off: re-enable the world example manually")
    end
end)
events.on("update", function()
    if not features.active(world) then return end
    -- Put host-supported world-feature behavior here, gated by features.active.
end)
ui.overlay("capture_hud", function()
    if features.active(overlay) then
        render.text(25, 90, "Lua overlay: capture safe", {0.2,0.85,1,1}, 17)
    end
end)
