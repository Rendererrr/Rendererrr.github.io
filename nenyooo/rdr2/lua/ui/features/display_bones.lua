features.on_draw("Display Bones", function(f)
    if type(f.points) ~= "string" or f.points == "" then return end
    local sw, sh = ctx.screen_w(), ctx.screen_h()
    if not sw or not sh or sw < 1 or sh < 1 then return end

    local rect_size = math.max(1, f.rect_scale or 6)
    local text_scale = math.max(0.1, f.text_scale or 1)
    for line in string.gmatch(f.points, "([^\n]+)") do
        local nx, ny, name = string.match(line, "([^\t]+)\t([^\t]+)\t(.+)")
        nx, ny = tonumber(nx), tonumber(ny)
        if nx and ny then
            local x, y = nx * sw, ny * sh
            if f.draw_rects then
                local half = rect_size * 0.5
                local angle = math.rad(f.rotation or 0)
                local cs, sn = math.cos(angle), math.sin(angle)
                local ax, ay = x + half * (-cs + sn), y - half * (sn + cs)
                local bx, by = x + half * (cs + sn), y + half * (sn - cs)
                local cx, cy = x + half * (cs - sn), y + half * (sn + cs)
                local dx, dy = x - half * (cs + sn), y + half * (cs - sn)
                local r, g, b, a = f.rect_r or 255, f.rect_g or 255,
                    f.rect_b or 255, f.rect_a or 255
                draw.line(ax, ay, bx, by, r, g, b, a, 1)
                draw.line(bx, by, cx, cy, r, g, b, a, 1)
                draw.line(cx, cy, dx, dy, r, g, b, a, 1)
                draw.line(dx, dy, ax, ay, r, g, b, a, 1)
            end
            if f.draw_names and name then
                local width = text.width(font.small, name)
                text.draw_scaled(font.small, x - width * 0.5, y + rect_size * 0.5 + 2,
                    f.name_r or 255, f.name_g or 255, f.name_b or 255,
                    f.name_a or 255, text_scale, name)
            end
        end
    end
end)
