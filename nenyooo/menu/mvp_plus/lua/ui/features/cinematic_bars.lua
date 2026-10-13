
-- Cinematic Bars. Published fields: active (bool), size (bar height, % of screen height).
local shown = 0

features.on_draw("Cinematic Bars", function(f)
    local target = f.active and 1 or 0
    shown = shown + (target - shown) * 0.12
    if shown < 0.002 then shown = 0 return end

    local sw, sh = ctx.screen_w(), ctx.screen_h()
    local h = sh * (f.size or 10) / 100 * shown
    draw.rect(0, 0, sw, h, 0, 0, 0, 255, 0)
    draw.rect(0, sh - h, sw, sh, 0, 0, 0, 255, 0)
end)
