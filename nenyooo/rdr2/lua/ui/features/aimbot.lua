features.on_draw("Aimbot", function(f)
    local sw, sh = ctx.screen_w(), ctx.screen_h()
    if not sw or not sh or sw < 1 or sh < 1 then return end
    local radius = math.max(0, math.min(100, f.radius or 20)) * sw * 0.005
    if radius < 0.5 then return end
    draw.circle_outline(sw * 0.5, sh * 0.5, radius,
        f.r or 255, f.g or 0, f.b or 0, f.a or 255,
        math.max(0.1, f.depth or 3))
end)
