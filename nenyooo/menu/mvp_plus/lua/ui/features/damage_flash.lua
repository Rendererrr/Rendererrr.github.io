
-- Damage Flash. Published fields: active (bool), intensity (0..1, fades out after each hit).
features.on_draw("Damage Flash", function(f)
    if not f.active then return end

    local sw, sh = ctx.screen_w(), ctx.screen_h()
    local a = math.floor(200 * math.min(1, f.intensity or 0))
    local ew, eh = sw * 0.22, sh * 0.25
    local r, g, b = 200, 20, 20

    draw.rect_gradient(0, 0, ew, sh, r, g, b, a, r, g, b, 0, r, g, b, 0, r, g, b, a)
    draw.rect_gradient(sw - ew, 0, sw, sh, r, g, b, 0, r, g, b, a, r, g, b, a, r, g, b, 0)
    draw.rect_gradient(0, 0, sw, eh, r, g, b, a, r, g, b, a, r, g, b, 0, r, g, b, 0)
    draw.rect_gradient(0, sh - eh, sw, sh, r, g, b, 0, r, g, b, 0, r, g, b, a, r, g, b, a)
end)
