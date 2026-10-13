
-- Composition Grid. Published fields: active (bool), mode (0 Rule of Thirds, 1 Golden Ratio, 2 Centre Cross, 3 Diagonals).
local PHI = 0.381966

features.on_draw("Composition Grid", function(f)
    if not f.active then return end

    local sw, sh = ctx.screen_w(), ctx.screen_h()
    local mode = math.floor(f.mode or 0)
    local r, g, b, a, t = 255, 255, 255, 110, 1.2

    local function v(x) draw.line(x, 0, x, sh, r, g, b, a, t) end
    local function h(y) draw.line(0, y, sw, y, r, g, b, a, t) end

    if mode == 0 then
        v(sw / 3); v(sw * 2 / 3); h(sh / 3); h(sh * 2 / 3)
    elseif mode == 1 then
        v(sw * PHI); v(sw * (1 - PHI)); h(sh * PHI); h(sh * (1 - PHI))
    elseif mode == 2 then
        local cx, cy, l = sw * 0.5, sh * 0.5, sh * 0.04
        draw.line(cx - l, cy, cx + l, cy, r, g, b, 170, t)
        draw.line(cx, cy - l, cx, cy + l, r, g, b, 170, t)
        draw.rect_outline(sw * 0.1, sh * 0.1, sw * 0.9, sh * 0.9, r, g, b, 70, 0, 1)
    else
        draw.line(0, 0, sw, sh, r, g, b, a, t)
        draw.line(sw, 0, 0, sh, r, g, b, a, t)
        v(sw * 0.5); h(sh * 0.5)
    end
end)
