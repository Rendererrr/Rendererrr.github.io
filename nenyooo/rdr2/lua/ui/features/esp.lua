features.on_draw("ESP", function(f)
    if type(f.entries) ~= "string" or f.entries == "" then return end
    local sw, sh = ctx.screen_w(), ctx.screen_h()
    if not sw or not sh or sw < 1 or sh < 1 then return end
    for row in string.gmatch(f.entries, "([^\n]+)") do
        local x, y, w, h, dist, hp, maxhp, model, kind, player, name =
            string.match(row, "([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t(.*)")
        x, y, w, h = tonumber(x), tonumber(y), tonumber(w), tonumber(h)
        dist, hp, maxhp, model = tonumber(dist), tonumber(hp), tonumber(maxhp), tonumber(model)
        kind, player = tonumber(kind), tonumber(player)
        if x and y and w and h then
            local cx, cy, bw, bh = x * sw, y * sh, w * sw, h * sh
            local left, top, right, bottom = cx - bw * 0.5, cy - bh * 0.5, cx + bw * 0.5, cy + bh * 0.5
            if f.boxes then
                draw.rect_outline(left, top, right, bottom, f.box_r or 255, f.box_g or 255,
                    f.box_b or 255, f.box_a or 255, 0, f.box_thickness or 2)
            end
            if f.health and maxhp and maxhp > 0 then
                local ratio = math.max(0, math.min(1, (hp or 0) / maxhp))
                draw.rect(right + 5, top, right + 10, bottom, f.health_bg_r or 150,
                    f.health_bg_g or 150, f.health_bg_b or 150, f.health_bg_a or 255)
                draw.rect(right + 5, bottom - bh * ratio, right + 10, bottom,
                    f.health_r or 0, f.health_g or 150, f.health_b or 0, f.health_a or 255)
            end
            if f.hashes and model then
                local label = string.format("0x%08X", model)
                local scale = math.max(0.2, f.hash_size or 1)
                text.draw_scaled(font.small, cx - text.width(font.small, label) * scale * 0.5,
                    top - 16 * scale, f.text_r or 255, f.text_g or 255, f.text_b or 255,
                    f.text_a or 255, scale, label)
            end
            if f.names then
                local types = {[1] = "Ped", [2] = "Vehicle", [3] = "Object"}
                local label = (player == 1 and name ~= "" and name) or types[kind] or "Entity"
                label = label .. " - " .. tostring(math.floor(dist or 0)) .. "m"
                local scale = math.max(0.2, f.name_size or 1)
                text.draw_scaled(font.small, cx - text.width(font.small, label) * scale * 0.5,
                    bottom + 2, f.text_r or 255, f.text_g or 255, f.text_b or 255,
                    f.text_a or 255, scale, label)
            end
            if f.lines then
                draw.line(sw * 0.5, 0, cx, cy, f.line_r or 255, f.line_g or 255,
                    f.line_b or 255, f.line_a or 255, f.line_thickness or 1)
            end
        end
    end
end)
