
-- Kill Feed HUD. Published fields: active (bool), duration (s), total, count,
-- victimN / weaponN (strings), ageN (s since the kill), headshotN (bool, only when true). N = 1 is newest.
features.on_draw("Kill Feed", function(f)
    if not f.active then return end

    local sw, sh = ctx.screen_w(), ctx.screen_h()
    local s = sh / 1080
    local ar, ag, ab = theme.accent()
    local duration = f.duration or 6
    local fade = 0.6
    local right = sw - 18 * s
    local y = 96 * s
    local pad = 8 * s
    local lh = text.height(font.small) + pad

    for i = 1, math.floor(f.count or 0) do
        local age = f["age" .. i] or 0
        if age < duration then
            local t = age > duration - fade and (duration - age) / fade or 1
            local slide = age < 0.15 and (1 - age / 0.15) * 40 * s or 0
            local a = math.floor(255 * t)

            local weapon = f["weapon" .. i] or ""
            local victim = f["victim" .. i] or ""
            local hs = f["headshot" .. i]
            local ww = text.width(font.small, weapon)
            local vw = text.width(font.small, victim)
            local hw = hs and (text.width(font.tiny, "HS") + pad) or 0
            local w = ww + vw + hw + pad * 3
            local x = right - w + slide

            draw.rect(x, y, x + w, y + lh, 10, 10, 16, math.floor(150 * t), 5 * s)
            text.draw(font.small, x + pad, y + pad * 0.5, ar, ag, ab, a, weapon)
            text.draw(font.small, x + pad * 2 + ww, y + pad * 0.5, 240, 240, 245, a, victim)
            if hs then
                text.draw(font.tiny, x + pad * 3 + ww + vw, y + pad * 0.5 + 2 * s, 235, 80, 80, a, "HS")
            end
            y = y + lh + 4 * s
        end
    end
end)
