features.on_draw("Position HUD", function(f)
    if type(f.x_coord) ~= "number" or type(f.y_coord) ~= "number" or not __panelkit then return end

    local decimals = math.max(0, math.min(3, math.floor(f.decimals or 2)))
    local format = "%0." .. decimals .. "f"
    local target = "Player"
    if f.target_kind == 1 then target = "Mount" end
    if f.target_kind == 2 then target = "Vehicle" end

    local rows = {
        { "Tracking", target },
        { "X", string.format(format, f.x_coord) },
        { "Y", string.format(format, f.y_coord) },
    }
    if f.show_altitude then rows[#rows + 1] = { "Z", string.format(format, f.z_coord or 0) } end
    if f.show_heading then rows[#rows + 1] = { "Heading", string.format("%0.1f°", f.heading or 0) } end
    if f.show_safe_distance and f.safe_position_valid then
        rows[#rows + 1] = { "Safe Position", string.format("%.1f m", math.max(0, f.safe_position_distance or 0)),
            color = __panelkit.style.good }
    end
    __panelkit.feature("position_hud", "Position", rows, 6, 80,
        { digest = { "", string.format("%.0f, %.0f", f.x_coord, f.y_coord) } })
end)
