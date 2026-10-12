
-- Stamina & Breath. Published fields: active (bool), stamina (0..1), breath (0..1), underwater (bool).
-- Each bar shows while it is draining or refilling and fades out once full.
local shown = { stamina = 0, breath = 0 }

local function bar(x, y, w, h, frac, r, g, b, a)
    draw.rect(x, y, x + w, y + h, 0, 0, 0, math.floor(a * 0.55), h * 0.5)
    if frac > 0 then draw.rect(x, y, x + w * frac, y + h, r, g, b, a, h * 0.5) end
end

features.on_draw("Vitals", function(f)
    local st = f.stamina or 1
    local br = f.breath or 1
    local want_st = f.active and st < 0.995
    local want_br = f.active and (f.underwater or br < 0.995)
    shown.stamina = shown.stamina + ((want_st and 1 or 0) - shown.stamina) * 0.1
    shown.breath = shown.breath + ((want_br and 1 or 0) - shown.breath) * 0.1
    if shown.stamina < 0.01 and shown.breath < 0.01 then return end

    local sw, sh = ctx.screen_w(), ctx.screen_h()
    local s = sh / 1080
    local w, h = 180 * s, 6 * s
    local x = sw * 0.5 - w * 0.5
    local y = sh - 60 * s

    if shown.breath >= 0.01 then
        local r, g, b = 80, 190, 255
        if br < 0.25 then r, g, b = 235, 70, 70 end
        bar(x, y, w, h, br, r, g, b, math.floor(230 * shown.breath))
        y = y - h - 6 * s
    end
    if shown.stamina >= 0.01 then
        local r, g, b = 250, 210, 70
        if st < 0.2 then r, g, b = 240, 120, 50 end
        bar(x, y, w, h, st, r, g, b, math.floor(230 * shown.stamina))
    end
end)
