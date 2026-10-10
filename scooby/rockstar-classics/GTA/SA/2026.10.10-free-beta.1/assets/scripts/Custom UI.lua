-- A working crosshair overlay. Run the script, then use its controls or F8.
local enabled = features.add {
    capture_protection="safe",
    id="enabled", label="Lua crosshair", category="Tools / Crosshair",
    default=false, key="F8"
}
local gap, length, thickness = 5, 8, 2
ui.tab("tools", "Crosshair", function()
    imgui.table("crosshair_columns", 2, {}, function()
        imgui.table_next_column()
        imgui.text("Crosshair")
        local changed, value = imgui.checkbox("Enabled (F8)", features.get(enabled))
        if changed then features.set(enabled, value) end
        imgui.table_next_column()
        imgui.text("Shape")
        imgui.set_next_item_width(140)
        changed, gap = imgui.slider_float("Gap", gap, 0, 25)
        imgui.set_next_item_width(140)
        changed, length = imgui.slider_float("Length", length, 2, 30)
        imgui.set_next_item_width(140)
        changed, thickness = imgui.slider_float("Thickness", thickness, 1, 5)
        if imgui.button("Reset shape") then gap, length, thickness = 5, 8, 2 end
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
