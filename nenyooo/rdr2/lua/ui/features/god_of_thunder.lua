features.on_draw("God Of Thunder", function(f)
    if type(f.x) ~= "number" or type(f.y) ~= "number" then return end
    local sw, sh = ctx.screen_w(), ctx.screen_h()
    if not sw or not sh or sw < 1 or sh < 1 then return end
    local x, y = f.x * sw, f.y * sh
    draw.circle_outline(x, y, 8, 235, 240, 255, 225, 2)
    draw.circle(x, y, 2, 120, 175, 255, 255)
end)
