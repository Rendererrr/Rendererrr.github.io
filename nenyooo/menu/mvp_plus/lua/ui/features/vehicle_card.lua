
-- Vehicle Card. Published fields: active (bool), age (0..1), make, model, class (strings), top_speed (km/h), seats.
features.on_draw("Vehicle Card", function(f)
    if not f.active then return end

    local sw, sh = ctx.screen_w(), ctx.screen_h()
    local s = sh / 1080
    local age = f.age or 1
    local t = age < 0.1 and age / 0.1 or (age > 0.8 and (1 - age) / 0.2 or 1)
    local a = math.floor(255 * math.max(0, t))
    local ar, ag, ab = theme.accent()
    local fnt = font.display or font.item

    local make = string.upper(f.make or "")
    local model = f.model or ""
    local info = string.format("%s  |  %d seats  |  %d km/h", f.class or "", math.floor(f.seats or 1), math.floor(f.top_speed or 0))

    local pad = 14 * s
    local w = math.max(text.width(fnt, model), text.width(font.small, info), text.width(font.tiny, make)) + pad * 2
    local h = text.height(font.tiny) + text.height(fnt) + text.height(font.small) + pad * 1.6
    local x = sw * 0.5 - w * 0.5
    local y = sh - h - 120 * s + (1 - t) * 16 * s

    draw.rect(x, y, x + w, y + h, 10, 10, 16, math.floor(170 * t), 8 * s)
    draw.rect(x, y + h - 3 * s, x + w, y + h, ar, ag, ab, a, 0)

    local ty = y + pad * 0.6
    if make ~= "" then
        text.draw(font.tiny, x + pad, ty, ar, ag, ab, a, make)
    end
    ty = ty + text.height(font.tiny)
    text.draw(fnt, x + pad, ty, 245, 245, 250, a, model)
    ty = ty + text.height(fnt)
    text.draw(font.small, x + pad, ty, 190, 190, 200, a, info)
end)
