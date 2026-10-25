features.on_draw("Cinematic Frame", function(f)
    local sw, sh = ctx.screen_w(), ctx.screen_h()
    if not sw or not sh or sw < 1 or sh < 1 then return end

    local height = sh * math.max(0, math.min(25, f.bar_height or 8)) / 100
    local br, bg, bb, ba = f.bar_r or 0, f.bar_g or 0, f.bar_b or 0, f.bar_a or 255
    if height > 0 then
        draw.rect(0, 0, sw, height, br, bg, bb, ba, 0)
        draw.rect(0, sh - height, sw, sh, br, bg, bb, ba, 0)
    end

    local gr, gg, gb, ga = f.guide_r or 255, f.guide_g or 255,
        f.guide_b or 255, f.guide_a or 110
    if f.safe_area then
        local left, right = sw * 0.05, sw * 0.95
        local top = height + (sh - height * 2) * 0.06
        local bottom = sh - height - (sh - height * 2) * 0.06
        draw.line(left, top, right, top, gr, gg, gb, ga, 1)
        draw.line(right, top, right, bottom, gr, gg, gb, ga, 1)
        draw.line(right, bottom, left, bottom, gr, gg, gb, ga, 1)
        draw.line(left, bottom, left, top, gr, gg, gb, ga, 1)
    end

    if f.center_marker then
        local x, y, size = sw * 0.5, sh * 0.5, math.max(6, sh * 0.008)
        draw.line(x - size, y, x + size, y, gr, gg, gb, ga, 1)
        draw.line(x, y - size, x, y + size, gr, gg, gb, ga, 1)
    end
end)
