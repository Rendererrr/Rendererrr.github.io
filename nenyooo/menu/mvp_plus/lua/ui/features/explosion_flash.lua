
-- Explosion Flash. Published fields: active (bool), intensity (0..1, fades out after each blast).
features.on_draw("Explosion Flash", function(f)
    if not f.active then return end

    local sw, sh = ctx.screen_w(), ctx.screen_h()
    local k = math.min(1, f.intensity or 0)
    draw.rect(0, 0, sw, sh, 255, 240, 210, math.floor(190 * k * k), 0)

    local ew, eh = sw * 0.3, sh * 0.3
    local a = math.floor(140 * k)
    local r, g, b = 255, 140, 40
    draw.rect_gradient(0, 0, ew, sh, r, g, b, a, r, g, b, 0, r, g, b, 0, r, g, b, a)
    draw.rect_gradient(sw - ew, 0, sw, sh, r, g, b, 0, r, g, b, a, r, g, b, a, r, g, b, 0)
    draw.rect_gradient(0, sh - eh, sw, sh, r, g, b, 0, r, g, b, 0, r, g, b, a, r, g, b, a)
end)
