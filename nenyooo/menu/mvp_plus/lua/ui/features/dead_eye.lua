
-- Dead Eye. Published fields: active (bool), n (mark count), x1..xN / y1..yN (0..1 screen coords
-- of each marked head), hover (0..1 progress of the mark under the crosshair).
features.on_draw("Dead Eye", function(f)
    if not f.active then return end

    local sw, sh = ctx.screen_w(), ctx.screen_h()
    local t = ctx.time and ctx.time() or 0

    draw.rect_gradient(0, 0, sw, sh * 0.18, 60, 30, 10, 90, 60, 30, 10, 90, 60, 30, 10, 0, 60, 30, 10, 0)
    draw.rect_gradient(0, sh * 0.82, sw, sh, 60, 30, 10, 0, 60, 30, 10, 0, 60, 30, 10, 90, 60, 30, 10, 90)

    local n = math.floor(f.n or 0)
    local pulse = 0.5 + 0.5 * math.sin(t * 9)
    for i = 1, n do
        local x, y = (f["x" .. i] or 0) * sw, (f["y" .. i] or 0) * sh
        local s = 7
        draw.line(x - s, y - s, x + s, y + s, 230, 40, 30, 255, 2.5)
        draw.line(x - s, y + s, x + s, y - s, 230, 40, 30, 255, 2.5)
        draw.circle_outline(x, y, 11 + pulse * 3, 230, 40, 30, 150, 1.2)
    end

    local cx, cy = sw * 0.5, sh * 0.5
    local hover = f.hover or 0
    if hover > 0 then
        draw.circle_outline(cx, cy, 16 - 8 * hover, 240, 200, 120, math.floor(120 + 135 * hover), 1.6)
    end

    if n > 0 then
        local label = "DEAD EYE  " .. n
        local w = text.width(font.item, label)
        text.draw(font.item, cx - w * 0.5, sh * 0.86, 240, 200, 120, 255, label)
    end
end)
