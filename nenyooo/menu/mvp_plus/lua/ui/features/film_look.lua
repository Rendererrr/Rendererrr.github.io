
-- Film Look. Published fields: active (bool), strength (0.25..2).
features.on_draw("Film Look", function(f)
    if not f.active then return end

    local sw, sh = ctx.screen_w(), ctx.screen_h()
    local k = f.strength or 1
    local a = math.min(255, math.floor(150 * k))
    local ew, eh = sw * 0.28, sh * 0.32

    draw.rect_gradient(0, 0, ew, sh, 0, 0, 0, a, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, a)
    draw.rect_gradient(sw - ew, 0, sw, sh, 0, 0, 0, 0, 0, 0, 0, a, 0, 0, 0, a, 0, 0, 0, 0)
    draw.rect_gradient(0, 0, sw, eh, 0, 0, 0, a, 0, 0, 0, a, 0, 0, 0, 0, 0, 0, 0, 0)
    draw.rect_gradient(0, sh - eh, sw, sh, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, a, 0, 0, 0, a)

    local dots = math.floor(220 * k)
    local ga = math.min(255, math.floor(26 * k))
    for _ = 1, dots do
        local x, y = math.random() * sw, math.random() * sh
        local c = math.random() < 0.5 and 0 or 255
        draw.rect(x, y, x + 2, y + 2, c, c, c, ga, 0)
    end
end)
