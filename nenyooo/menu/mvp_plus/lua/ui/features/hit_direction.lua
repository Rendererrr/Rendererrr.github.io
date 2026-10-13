
-- Hit Direction. Published fields: active (bool), count, angleN (deg clockwise from straight ahead),
-- ageN (0 = just hit, 1 = about to disappear).
features.on_draw("Hit Direction", function(f)
    if not f.active then return end

    local sw, sh = ctx.screen_w(), ctx.screen_h()
    local s = sh / 1080
    local cx, cy = sw * 0.5, sh * 0.5
    local radius = 150 * s

    for i = 1, math.floor(f.count or 0) do
        local ang = math.rad(f["angle" .. i] or 0)
        local a = math.floor(230 * (1 - (f["age" .. i] or 0)))
        if a > 0 then
            local dx, dy = math.sin(ang), -math.cos(ang)
            local px, py = -dy, dx
            local tipx, tipy = cx + dx * (radius + 26 * s), cy + dy * (radius + 26 * s)
            local bx, by = cx + dx * radius, cy + dy * radius
            local wing = 22 * s
            for k = -2, 2 do
                local o = k * 3 * s
                draw.line(bx + px * (wing + o * 0.3) + dx * o * 0.2, by + py * (wing + o * 0.3) + dy * o * 0.2, tipx, tipy, 220, 30, 30, a, 3 * s)
                draw.line(bx - px * (wing + o * 0.3) + dx * o * 0.2, by - py * (wing + o * 0.3) + dy * o * 0.2, tipx, tipy, 220, 30, 30, a, 3 * s)
            end
            draw.line(bx + px * wing, by + py * wing, bx - px * wing, by - py * wing, 220, 30, 30, a, 4 * s)
        end
    end
end)
