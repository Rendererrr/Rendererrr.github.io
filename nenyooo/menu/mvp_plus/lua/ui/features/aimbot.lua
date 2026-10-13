features.on_draw("Aimbot", function(f)
    if not f.enabled then return end
    local sw, sh = ctx.screen_w(), ctx.screen_h()
    local cx, cy = sw * 0.5, sh * 0.5
    local r, g, b, a = f.r or 255, f.g or 70, f.b or 90, f.a or 230
    local fov = f.fov or 140
    if f.screen_width and f.screen_width > 0 then fov = fov * sw / f.screen_width end
    if f.show_fov then
        if f.fill_fov then draw.circle(cx, cy, fov, r, g, b, math.floor(a * 0.10)) end
        draw.circle_outline(cx, cy, fov, r, g, b, math.floor(a * 0.75), 1.3)
    end
    if not f.locked then return end
    local x, y = (f.target_x or 0.5) * sw, (f.target_y or 0.5) * sh
    if f.show_line then draw.line(cx, cy, x, y, r, g, b, math.floor(a * 0.65), 1.2) end
    if f.show_marker then
        draw.circle_outline(x, y, 9, r, g, b, a, 1.8)
        draw.circle(x, y, 2.5, r, g, b, a)
    end
    if f.show_name and f.target_name and f.target_name ~= "" then
        text.draw(font.small, x - text.width(font.small, f.target_name) * 0.5, y - 27, 255, 255, 255, a, f.target_name)
    end
end)
