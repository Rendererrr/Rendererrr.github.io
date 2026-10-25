features.on_draw("Compass", function(f)
    local heading = f.heading
    if type(heading) ~= "number" then return end

    local sw = ctx.screen_w()
    if not sw or sw < 1 then return end
    local cx = sw * 0.5
    local width = math.min(sw * 0.72, 740)
    local half = width * 0.5
    local y = 24

    draw.line(cx - half, y, cx + half, y,
        f.line_r or 235, f.line_g or 235, f.line_b or 235,
        f.line_a or 220, f.line_width or 1)

    for bearing = 0, 345, 15 do
        local relative = ((bearing - heading + 540) % 360) - 180
        if math.abs(relative) <= 90 then
            local x = cx + relative / 90 * half
            local major = bearing % 45 == 0
            local height = major and 12 or 6
            draw.line(x, y, x, y + height,
                f.tick_r or 235, f.tick_g or 235, f.tick_b or 235,
                f.tick_a or 220, f.tick_width or 1)
            if major then
                local names = {"N", "NE", "E", "SE", "S", "SW", "W", "NW"}
                local label = names[math.floor(bearing / 45) + 1]
                text.draw(font.small, x - text.width(font.small, label) * 0.5,
                    y + 15, f.text_r or 245, f.text_g or 245,
                    f.text_b or 245, f.text_a or 255, label)
            end
        end
    end

    local ar, ag, ab, aa = f.arrow_r or 190, f.arrow_g or 80,
        f.arrow_b or 220, f.arrow_a or 255
    draw.line(cx - 7, y - 8, cx, y - 1, ar, ag, ab, aa, 2)
    draw.line(cx + 7, y - 8, cx, y - 1, ar, ag, ab, aa, 2)

    if type(f.markers) == "string" then
        for relative, kind in string.gmatch(f.markers, "([^\t]+)\t([^\n]+)") do
            local angle = tonumber(relative)
            if angle and math.abs(angle) <= 90 then
                local x = cx + angle / 90 * half
                if tonumber(kind) == 1 then
                    local r, g, b, a = f.waypoint_r or 232, f.waypoint_g or 198,
                        f.waypoint_b or 5, f.waypoint_a or 255
                    draw.circle(x, y + 10, 6, r, g, b, a)
                    draw.circle_outline(x, y + 10, 8, r, g, b, a * 0.7, 2)
                else
                    draw.circle(x, y + 10, 5,
                        f.player_r or 48, f.player_g or 87, f.player_b or 107,
                        f.player_a or 255)
                end
            end
        end
    end
end)
