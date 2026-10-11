-- A working crosshair overlay. Run the script, then use its controls or F8.
local enabled = features.add {
    id="enabled", label="Lua crosshair", category="Tools / Crosshair",
    default=false, key="F8"
}
local gap, length, thickness = 5, 8, 2
ui.tab("tools", "Crosshair", function()
    ui.columns(2, function()
        ui.group("Crosshair", function()
            ui.feature(enabled)
            ui.keybind(enabled, "Crosshair key")
        end)
        ui.next_column()
        ui.group("Shape", function()
            local changed
            changed, gap = imgui.slider_float("Gap", gap, 0, 25)
            changed, length = imgui.slider_float("Length", length, 2, 30)
            changed, thickness = imgui.slider_float("Thickness", thickness, 1, 5)
            if imgui.button("Reset shape") then gap, length, thickness = 5, 8, 2 end
        end)
    end)
end, {section="Tools"})
ui.overlay("crosshair", function()
    if not features.active(enabled) then return end
    local width, height = engine.viewport()
    local x, y = math.floor(width / 2), math.floor(height / 2)
    local color = {0.3, 0.8, 1, 1}
    render.line(x-gap-length, y, x-gap, y, color, thickness)
    render.line(x+gap, y, x+gap+length, y, color, thickness)
    render.line(x, y-gap-length, x, y-gap, color, thickness)
    render.line(x, y+gap, x, y+gap+length, color, thickness)
end)
