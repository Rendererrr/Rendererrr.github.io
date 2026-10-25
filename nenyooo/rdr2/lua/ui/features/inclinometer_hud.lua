features.on_draw("Inclinometer HUD", function(f)
    if type(f.pitch) ~= "number" or type(f.roll) ~= "number" or not __panelkit then return end

    local style = __panelkit.style
    local threshold = f.warning_threshold or 25
    local warning = math.abs(f.pitch) >= threshold or math.abs(f.roll) >= threshold
    local line = warning and __panelkit.rgb(f, "warning_", 240, 75, 60) or __panelkit.rgb(f, "level_", 90, 220, 120)
    local pitch, roll = f.pitch, f.roll

    local rows = {
        { "", custom = { w = 160, h = 44, draw = function(x, y, w)
            local cx, cy = x + w * 0.5, y + 22
            local mark = style.label_c
            draw.line(x, cy, x + w, cy, style.track[1], style.track[2], style.track[3], 255, 1)
            local horizon_y = cy + math.max(-45, math.min(45, pitch)) / 45 * 18
            local angle = -roll * math.pi / 180
            local half = math.min(72, w * 0.45)
            local dx, dy = math.cos(angle) * half, math.sin(angle) * half
            draw.line(cx - dx, horizon_y - dy, cx + dx, horizon_y + dy, line[1], line[2], line[3], 255, 2)
            draw.line(cx - 7, cy, cx + 7, cy, mark[1], mark[2], mark[3], 255, 1.5)
            draw.line(cx, cy - 7, cx, cy + 7, mark[1], mark[2], mark[3], 255, 1.5)
        end } },
    }
    local pitch_text = string.format("%+.1f°", pitch)
    local roll_text = string.format("%+.1f°", roll)
    if f.show_angles then
        rows[#rows + 1] = { "Pitch", pitch_text, color = warning and line or nil }
        rows[#rows + 1] = { "Roll", roll_text, color = warning and line or nil }
    end
    __panelkit.feature("inclinometer_hud", "Inclinometer", rows, 44, 68,
        { digest = { "", pitch_text .. "  " .. roll_text } })
end)
