features.on_draw("Rangefinder HUD", function(f)
    if type(f.distance) ~= "number" or not __panelkit then return end

    local reticle = __panelkit.rgb(f, "reticle_", 105, 235, 125)
    if f.show_reticle then
        local scale = __panelkit.scale()
        local x, y = ctx.screen_w() * 0.5, ctx.screen_h() * 0.5
        local gap, arm = 5 * scale, 11 * scale
        draw.line(x - arm, y, x - gap, y, reticle[1], reticle[2], reticle[3], 255, 1.5 * scale)
        draw.line(x + gap, y, x + arm, y, reticle[1], reticle[2], reticle[3], 255, 1.5 * scale)
    end

    local distance = string.format("%.1f %s", math.max(0, f.distance), f.yards and "yd" or "m")
    local rows = { { "Distance", distance } }
    if f.show_type then
        local types = { [0] = "Surface", [1] = "Ped", [2] = "Vehicle", [3] = "Object" }
        rows[#rows + 1] = { "Target", types[math.floor(f.target_type or 0)] or "Surface", color = reticle }
    end
    if f.show_health and f.health_valid then
        rows[#rows + 1] = { "Health", string.format("%d%%", math.floor(math.max(0, f.health or 0) + 0.5)) }
    end
    if f.show_speed and f.speed_valid then
        rows[#rows + 1] = { "Target Speed", string.format("%.1f KPH", math.max(0, f.speed_kph or 0)) }
    end
    __panelkit.feature("rangefinder_hud", "Rangefinder", rows, 53, 52, { digest = { "", distance } })
end)
