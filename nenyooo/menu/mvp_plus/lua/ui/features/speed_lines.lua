
-- Speed Lines. Published fields: active (bool), intensity (0..1, how far past the threshold speed you are).
features.on_draw("Speed Lines", function(f)
    if not f.active then return end

    local sw, sh = ctx.screen_w(), ctx.screen_h()
    local cx, cy = sw * 0.5, sh * 0.5
    local k = f.intensity or 0
    local outer = math.sqrt(cx * cx + cy * cy)
    local inner = outer * (0.62 - 0.14 * k)
    local count = math.floor(12 + 48 * k)

    for _ = 1, count do
        local ang = math.random() * math.pi * 2
        local start = inner + math.random() * outer * 0.2
        local dx, dy = math.cos(ang), math.sin(ang)
        local a = math.floor((40 + math.random() * 110) * k)
        local t = 1 + math.random() * 2.5 * k
        draw.line(cx + dx * start, cy + dy * start, cx + dx * outer, cy + dy * outer, 255, 255, 255, a, t)
    end
end)
