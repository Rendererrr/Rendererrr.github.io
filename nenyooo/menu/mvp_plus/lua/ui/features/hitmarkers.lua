
-- Hitmarkers. Published fields: active, progress (0..1 fade), type (0 hit / 1 headshot / 2 kill),
-- streak, size, streak_on, and per-type colours nr/ng/nb, hr/hg/hb, kr/kg/kb. Draws an X at the
-- crosshair that fades and expands as progress -> 1.
features.on_draw("Hitmarkers", function(f)
    if not f.active then return end
    local prog = f.progress or 0
    local a = math.floor((1.0 - prog) * 255)
    if a <= 0 then return end

    local cx, cy = ctx.screen_w() * 0.5, ctx.screen_h() * 0.5
    local size = (f.size or 15) * (1.0 + prog * 0.4)   -- slight expand while fading
    local gap  = size * 0.35
    local th   = 2.0

    local t = f.type or 0
    local r, g, b
    if t >= 2 then     r, g, b = f.kr or 255, f.kg or 128, f.kb or 0
    elseif t == 1 then r, g, b = f.hr or 255, f.hg or 0,   f.hb or 0
    else               r, g, b = f.nr or 255, f.ng or 255, f.nb or 255 end

    -- four diagonal strokes forming an X with a centre gap
    draw.line(cx - size, cy - size, cx - gap,  cy - gap,  r, g, b, a, th)
    draw.line(cx + gap,  cy + gap,  cx + size, cy + size, r, g, b, a, th)
    draw.line(cx + size, cy - size, cx + gap,  cy - gap,  r, g, b, a, th)
    draw.line(cx - gap,  cy + gap,  cx - size, cy + size, r, g, b, a, th)

    if f.streak_on and (f.streak or 0) > 1 then
        text.draw(font.item, cx + size + 6, cy - 8, r, g, b, a, "x" .. math.floor(f.streak))
    end
end)
