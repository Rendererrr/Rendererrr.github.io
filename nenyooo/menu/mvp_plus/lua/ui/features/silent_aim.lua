features.on_draw("Silent Aim", function(f)
    if not f.enabled then return end
    local sw, sh = ctx.screen_w(), ctx.screen_h()
    local cx, cy = sw * 0.5, sh * 0.5
    local r, g, b, a = f.r or 175, f.g or 90, f.b or 255, f.a or 230
    local fov = f.fov or 120
    if f.screen_width and f.screen_width > 0 then fov = fov * sw / f.screen_width end
    if not f.available then
        text.draw(font.small, cx - 80, cy + 35, 255, 95, 95, 240, "Silent Aim unavailable")
        return
    end
    if f.show_fov then draw.circle_outline(cx, cy, fov, r, g, b, math.floor(a * 0.75), 1.3) end
    if f.locked then
        local x, y = (f.target_x or 0.5) * sw, (f.target_y or 0.5) * sh
        if f.show_line then draw.line(cx, cy, x, y, r, g, b, math.floor(a * 0.60), 1.2) end
        if f.show_marker then
            draw.line(x - 8, y, x + 8, y, r, g, b, a, 1.6)
            draw.line(x, y - 8, x, y + 8, r, g, b, a, 1.6)
        end
        if f.show_info then
            local label = (f.target_name or "Target") .. string.format("  %.0fm", f.distance or 0)
            text.draw(font.small, x - text.width(font.small, label) * 0.5, y - 26, 255, 255, 255, a, label)
        end
    end
    if f.show_stats then
        local stats = string.format("Redirects %d  Streak %d", f.redirects or 0, f.headshot_streak or 0)
        text.draw(font.small, cx - text.width(font.small, stats) * 0.5, cy + 22, r, g, b, a, stats)
    end
end)
