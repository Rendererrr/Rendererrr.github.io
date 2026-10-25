features.on_draw("Mount Locator", function(f)
    if type(f.distance) ~= "number" or not __panelkit then return end

    local relative = f.relative_bearing or 0
    local direction = "Ahead"
    if relative >= 22.5 and relative < 67.5 then direction = "Ahead Right"
    elseif relative >= 67.5 and relative < 112.5 then direction = "Right"
    elseif relative >= 112.5 and relative < 157.5 then direction = "Behind Right"
    elseif relative >= 157.5 or relative < -157.5 then direction = "Behind"
    elseif relative >= -157.5 and relative < -112.5 then direction = "Behind Left"
    elseif relative >= -112.5 and relative < -67.5 then direction = "Left"
    elseif relative >= -67.5 and relative < -22.5 then direction = "Ahead Left" end

    local distance = f.distance
    local distance_text
    if f.use_miles then
        distance_text = distance >= 160.9344 and string.format("%.2f mi", distance / 1609.344)
            or string.format("%.0f ft", distance * 3.28084)
    else
        distance_text = distance >= 1000 and string.format("%.2f km", distance / 1000)
            or string.format("%.0f m", distance)
    end

    local status = f.dead and "Down" or (f.mounted and "Mounted" or "Separated")
    local rows = {
        { "Status", status, color = f.dead and __panelkit.rgb(f, "warning_", 235, 70, 60) or nil },
        { "Distance", distance_text },
        { "Direction", direction },
    }
    if f.show_bearing then rows[#rows + 1] = { "Bearing", string.format("%.0f°", f.bearing or 0) } end
    if f.show_elevation then
        local elevation = f.elevation or 0
        local amount = math.abs(elevation)
        rows[#rows + 1] = { elevation >= 0 and "Above" or "Below",
            f.use_miles and string.format("%.0f ft", amount * 3.28084) or string.format("%.0f m", amount) }
    end
    __panelkit.feature("mount_locator", "Mount Locator", rows, 30, 82, { digest = { "", distance_text } })
end)
