features.on_draw("G-Force HUD", function(f)
    if type(f.total) ~= "number" or not __panelkit then return end

    local style = __panelkit.style
    local warning = f.total >= 1.5
    local dot = warning and __panelkit.rgb(f, "warning_", 240, 75, 60) or __panelkit.rgb(f, "accent_", 90, 190, 245)
    local lateral, longitudinal = f.lateral or 0, f.longitudinal or 0

    local total = string.format("%.2f G", f.total)
    local rows = {
        { "", custom = { w = 140, h = 72, draw = function(x, y, w)
            local size = 72
            local gx, gy = x + w * 0.5, y + size * 0.5
            local half = size * 0.5
            local t = style.track
            draw.rect_outline(gx - half, gy - half, gx + half, gy + half, t[1], t[2], t[3], 255, 0, 1)
            draw.line(gx - half, gy, gx + half, gy, t[1], t[2], t[3], 255, 1)
            draw.line(gx, gy - half, gx, gy + half, t[1], t[2], t[3], 255, 1)
            local px = gx + math.max(-2, math.min(2, lateral)) / 2 * half
            local py = gy - math.max(-2, math.min(2, longitudinal)) / 2 * half
            draw.circle(px, py, 4, dot[1], dot[2], dot[3], 255)
        end } },
        { "Total", total, color = warning and dot or nil },
        { "Peak", string.format("%.2f G", f.peak or 0) },
    }
    if f.show_components then
        rows[#rows + 1] = { "Forward", string.format("%+.2f", longitudinal) }
        rows[#rows + 1] = { "Lateral", string.format("%+.2f", lateral) }
        rows[#rows + 1] = { "Vertical", string.format("%+.2f", f.vertical or 0) }
    end
    __panelkit.feature("g_force_hud", "G-Force", rows, 8, 60, { digest = { "", total } })
end)
