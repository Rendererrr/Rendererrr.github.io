features.on_draw("Hunter Mode", function(f)
    if type(f.markers) ~= "string" or f.markers == "" then return end
    local sw, sh = ctx.screen_w(), ctx.screen_h()
    if not sw or not sh or sw < 1 or sh < 1 then return end
    local icon = math.max(4, (f.icon_scale or 25) * 0.35)
    local text_scale = math.max(0.2, f.text_scale or 1)
    for row in string.gmatch(f.markers, "([^\n]+)") do
        local nx, ny, distance, quality, legendary, dead, name =
            string.match(row, "([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t(.*)")
        nx, ny, distance = tonumber(nx), tonumber(ny), tonumber(distance)
        quality, legendary, dead = tonumber(quality), tonumber(legendary), tonumber(dead)
        if nx and ny then
            local x, y = nx * sw, ny * sh
            local r, g, b, a = f.common_r or 255, f.common_g or 255, f.common_b or 255, f.common_a or 255
            if legendary == 1 then
                r, g, b, a = f.legendary_r or 255, f.legendary_g or 215,
                    f.legendary_b or 0, f.legendary_a or 255
            end
            if dead == 1 and f.highlight_dead then
                r, g, b, a = f.carcass_r or 190, f.carcass_g or 90,
                    f.carcass_b or 80, f.carcass_a or 255
            end
            a = math.max(0, math.min(255, a))
            local fill_a = math.floor(a * 65 / 255)
            draw.circle(x, y, icon * 0.48, r, g, b, fill_a)
            draw.circle_outline(x, y, icon * 0.48, r, g, b, a, 2)
            draw.circle(x - icon * 0.18, y - icon * 0.08, icon * 0.08, r, g, b, a)
            draw.circle(x + icon * 0.18, y - icon * 0.08, icon * 0.08, r, g, b, a)
            if f.show_quality then
                for i = 1, math.max(0, quality or 0) do
                    draw.circle(x + (i - 2) * icon * 0.22, y - icon * 0.75, icon * 0.07, r, g, b, a)
                end
            end
            local label = ""
            if f.show_names then label = name ~= "" and name or "Animal" end
            if f.show_distance then
                local range = tostring(math.floor(distance or 0)) .. "m"
                label = label ~= "" and label .. " - " .. range or range
            end
            if dead == 1 and f.highlight_dead and label ~= "" then label = label .. " (Carcass)" end
            if label ~= "" then
                text.draw_scaled(font.small, x + icon * 0.65, y - 6 * text_scale,
                    r, g, b, a, text_scale, label)
            end
        end
    end
end)
