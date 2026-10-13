-- Human Slingshot HUD. The game-thread feature publishes charge state and projected arc points.
features.on_draw("Human Slingshot", function(f)
    if not f.active or not f.charging then return end

    local sw, sh = ctx.screen_w(), ctx.screen_h()
    local ar, ag, ab = theme.accent()

    if f.show_trajectory and f.trajectory then
        local previous_x, previous_y = nil, nil
        local last_x, last_y = nil, nil
        for xs, ys, visible in string.gmatch(f.trajectory, "([^,]+),([^,]+),([^;]+);") do
            local x = tonumber(xs) * sw
            local y = tonumber(ys) * sh
            if visible == "1" then
                if previous_x then
                    draw.line(previous_x, previous_y, x, y, ar, ag, ab, 210, 2.0)
                end
                previous_x, previous_y = x, y
                last_x, last_y = x, y
            else
                previous_x, previous_y = nil, nil
            end
        end
        if last_x then
            draw.circle(last_x, last_y, 4, ar, ag, ab, 235)
            draw.circle_outline(last_x, last_y, 9, ar, ag, ab, 190, 1.5)
        end
    end

    if f.show_charge_meter then
        local charge = math.max(0, math.min(1, f.charge or 0))
        local width, height = 220, 10
        local x = sw * 0.5 - width * 0.5
        local y = sh * 0.72
        draw.rect(x - 5, y - 5, x + width + 5, y + height + 25, 12, 12, 18, 205, 5)
        draw.rect(x, y, x + width, y + height, 50, 50, 58, 230, 3)
        draw.rect(x, y, x + width * charge, y + height, ar, ag, ab, 245, 3)

        local label = string.format("HUMAN SLINGSHOT  %d%%", math.floor(charge * 100 + 0.5))
        text.draw(font.small, sw * 0.5 - text.width(font.small, label) * 0.5,
            y + height + 4, 235, 235, 240, 245, label)
    end
end)
