
-- Altimeter. Published fields: active (bool), altitude (m above sea level), ground (m above ground),
-- vertical_speed (m/s, negative = descending), in_aircraft (bool).
features.on_draw("Altimeter", function(f)
    if not f.active then return end

    local sw, sh = ctx.screen_w(), ctx.screen_h()
    local s = sh / 1080
    local ar, ag, ab = theme.accent()
    local agl = f.ground or 0
    local vs = f.vertical_speed or 0
    local danger = agl < 120 and vs < -20

    local lines = {
        { "ALT", string.format("%d m", math.floor(f.altitude or 0)) },
        { "AGL", string.format("%d m", math.floor(agl)) },
        { vs >= 0 and "CLIMB" or "SINK", string.format("%.1f m/s", math.abs(vs)) },
    }

    local pad = 10 * s
    local lh = text.height(font.small) + 4 * s
    local w = 170 * s
    local h = lh * #lines + pad * 2
    local x = 24 * s
    local y = sh * 0.38

    draw.rect(x, y, x + w, y + h, 10, 10, 16, 150, 6 * s)
    if danger then
        draw.rect_outline(x, y, x + w, y + h, 235, 60, 60, 255, 6 * s, 2)
    else
    end

    for i, l in ipairs(lines) do
        local ly = y + pad + (i - 1) * lh
        text.draw(font.tiny, x + pad, ly + 2 * s, 170, 170, 180, 230, l[1])
        local vw = text.width(font.small, l[2])
        local r, g, b = 240, 240, 245
        if danger and i > 1 then r, g, b = 235, 80, 80 end
        text.draw(font.small, x + w - pad - vw, ly, r, g, b, 255, l[2])
    end

    if danger then
        local label = "PULL UP"
        local lw = text.width(font.item, label)
        text.draw(font.item, x + (w - lw) * 0.5, y + h + 6 * s, 235, 60, 60, 255, label)
    end
end)
