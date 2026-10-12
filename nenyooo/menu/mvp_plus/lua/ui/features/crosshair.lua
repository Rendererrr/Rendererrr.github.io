
-- Custom Crosshair. Published fields: active (bool), style (0 Cross, 1 Cross + Dot, 2 Dot, 3 Circle, 4 T-Shape),
-- size, gap, thickness (px), outline (bool), spread (0..1), r/g/b/a.
local function seg(x1, y1, x2, y2, r, g, b, a, t, outline)
    if outline then draw.line(x1, y1, x2, y2, 0, 0, 0, math.floor(a * 0.8), t + 2) end
    draw.line(x1, y1, x2, y2, r, g, b, a, t)
end

features.on_draw("Crosshair", function(f)
    if not f.active then return end

    local cx, cy = ctx.screen_w() * 0.5, ctx.screen_h() * 0.5
    local style = math.floor(f.style or 0)
    local size = f.size or 10
    local t = f.thickness or 2
    local gap = (f.gap or 4) + (f.spread or 0) * size
    local r, g, b, a = f.r or 0, f.g or 255, f.b or 120, f.a or 255
    local ol = f.outline

    if style == 0 or style == 1 or style == 4 then
        if style ~= 4 then seg(cx, cy - gap, cx, cy - gap - size, r, g, b, a, t, ol) end
        seg(cx, cy + gap, cx, cy + gap + size, r, g, b, a, t, ol)
        seg(cx - gap, cy, cx - gap - size, cy, r, g, b, a, t, ol)
        seg(cx + gap, cy, cx + gap + size, cy, r, g, b, a, t, ol)
    end
    if style == 3 then
        local rad = size * 0.6 + gap
        if ol then draw.circle_outline(cx, cy, rad, 0, 0, 0, math.floor(a * 0.8), t + 2) end
        draw.circle_outline(cx, cy, rad, r, g, b, a, t)
    end
    if style == 1 or style == 2 or style == 3 then
        local dr = math.max(1.5, t)
        if ol then draw.circle(cx, cy, dr + 1, 0, 0, 0, math.floor(a * 0.8)) end
        draw.circle(cx, cy, dr, r, g, b, a)
    end
end)
