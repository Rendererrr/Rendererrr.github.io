features.on_draw("Aimbot", function(f)
    if not f.enabled then return end
    local sw, sh = ctx.screen_w(), ctx.screen_h()
    local cx, cy = sw * 0.5, sh * 0.5
    local r, g, b, a = f.r or 255, f.g or 70, f.b or 90, f.a or 230

    if f.show_fov then
        draw.circle_outline(cx, cy, f.fov or 140, r, g, b, f.active and a or math.floor(a * 0.45), 1.2)
    end
    if f.locked and f.show_target then
        local x, y = f.target_x or cx, f.target_y or cy
        draw.circle_outline(x, y, 10, r, g, b, a, 1.5)
        draw.line(x - 15, y, x - 5, y, r, g, b, a, 1.4)
        draw.line(x + 5, y, x + 15, y, r, g, b, a, 1.4)
        draw.line(x, y - 15, x, y - 5, r, g, b, a, 1.4)
        draw.line(x, y + 5, x, y + 15, r, g, b, a, 1.4)
        local label = f.target_name or ""
        if label ~= "" then
            text.draw(font.small, x - text.width(font.small, label) * 0.5, y + 18, r, g, b, a, label)
        end
    end
end)
