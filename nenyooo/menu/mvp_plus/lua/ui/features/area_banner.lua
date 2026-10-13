
-- Area Banner. Published fields: active (bool), age (0 = just entered, 1 = gone), name (area name).
local function fade(age)
    if age < 0.12 then return age / 0.12 end
    if age > 0.75 then return math.max(0, (1 - age) / 0.25) end
    return 1
end

features.on_draw("Area Banner", function(f)
    if not f.active then return end

    local sw, sh = ctx.screen_w(), ctx.screen_h()
    local s = sh / 1080
    local age = f.age or 1
    local a = math.floor(255 * fade(age))
    local name = string.upper(f.name or "")
    local fnt = font.display or font.item
    local tw = text.width(fnt, name)
    local th = text.height(fnt)
    local cx = sw * 0.5
    local y = sh * 0.24 - (1 - fade(age)) * 8 * s
    local ar, ag, ab = theme.accent()

    local spread = (tw * 0.5 + 30 * s) + 90 * s * math.min(1, age * 4)
    draw.rect_gradient(cx - spread, y + th + 8 * s, cx, y + th + 10 * s, ar, ag, ab, 0, ar, ag, ab, a, ar, ag, ab, a, ar, ag, ab, 0)
    draw.rect_gradient(cx, y + th + 8 * s, cx + spread, y + th + 10 * s, ar, ag, ab, a, ar, ag, ab, 0, ar, ag, ab, 0, ar, ag, ab, a)

    text.draw(fnt, cx - tw * 0.5 + 2, y + 2, 0, 0, 0, math.floor(a * 0.6), name)
    text.draw(fnt, cx - tw * 0.5, y, 245, 245, 250, a, name)
end)
