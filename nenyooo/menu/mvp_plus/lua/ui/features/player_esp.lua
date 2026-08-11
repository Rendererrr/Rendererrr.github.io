features.on_draw("Player ESP", function(f)
    local blob = f.players or ""
    if blob == "" then return end
    local sw, sh = ctx.screen_w(), ctx.screen_h()

    local function clamp(v)
        if v < 0 then return 0 end
        if v > 1 then return 1 end
        return v
    end

    local function line_between(points, a, b, r, g, bl, alpha)
        local pa, pb = points[a], points[b]
        if pa and pb and pa[3] == 1 and pb[3] == 1 then
            draw.line(pa[1], pa[2], pb[1], pb[2], r, g, bl, alpha, 1.2)
        end
    end

    for row in string.gmatch(blob, "[^\n]+") do
        local name, distance, health, armour, visible, dead, packed =
            string.match(row, "^(.-)|([^|]+)|([^|]+)|([^|]+)|([^|]+)|([^|]+)|(.+)$")
        if packed then
            local values = {}
            for value in string.gmatch(packed, "[^,]+") do values[#values + 1] = tonumber(value) or 0 end
            local points = {}
            for i = 1, 10 do
                local at = (i - 1) * 3 + 1
                points[i] = { values[at], values[at + 1], values[at + 2] }
            end
            if points[1][3] == 1 and points[9][3] == 1 and points[10][3] == 1 then
                local head_x, head_y = points[1][1], points[1][2]
                local feet_x = (points[9][1] + points[10][1]) * 0.5
                local feet_y = math.max(points[9][2], points[10][2])
                local height = math.max(18, feet_y - head_y)
                local width = height * 0.43
                local left, right = feet_x - width * 0.5, feet_x + width * 0.5
                local top, bottom = head_y - height * 0.08, feet_y
                local is_visible = tonumber(visible) == 1
                local r = is_visible and (f.vr or 80) or (f.hr or 255)
                local g = is_visible and (f.vg or 220) or (f.hg or 185)
                local b = is_visible and (f.vb or 120) or (f.hb or 60)
                local a = is_visible and (f.va or 255) or (f.ha or 255)
                if tonumber(dead) == 1 then r, g, b = 145, 145, 150 end

                if f.fill then draw.rect(left, top, right, bottom, f.fr or 12, f.fg or 12, f.fb or 18, f.fa or 70, 0) end
                if f.boxes then draw.rect_outline(left, top, right, bottom, r, g, b, a, 0, 1.2) end
                if f.tracers then draw.line(sw * 0.5, sh - 2, feet_x, bottom, r, g, b, math.floor(a * 0.75), 1.0) end

                if f.skeleton then
                    line_between(points, 1, 2, r, g, b, a)
                    line_between(points, 2, 3, r, g, b, a)
                    line_between(points, 3, 4, r, g, b, a)
                    line_between(points, 3, 5, r, g, b, a)
                    line_between(points, 3, 6, r, g, b, a)
                    line_between(points, 4, 7, r, g, b, a)
                    line_between(points, 4, 8, r, g, b, a)
                    line_between(points, 7, 9, r, g, b, a)
                    line_between(points, 8, 10, r, g, b, a)
                end

                local label = ""
                if f.names then label = name or "" end
                if f.distance then
                    local d = string.format("%.0fm", tonumber(distance) or 0)
                    label = label ~= "" and (label .. "  " .. d) or d
                end
                if label ~= "" then
                    text.draw(font.small, feet_x - text.width(font.small, label) * 0.5, top - text.height(font.small) - 3, r, g, b, a, label)
                end

                if f.health then
                    local hp = clamp(tonumber(health) or 0)
                    draw.rect(left - 7, top, left - 3, bottom, 18, 18, 22, 210, 0)
                    draw.rect(left - 7, bottom - height * hp, left - 3, bottom, 65, 220, 95, 245, 0)
                end
                if f.armour and (tonumber(armour) or 0) > 0 then
                    local ap = clamp(tonumber(armour) or 0)
                    draw.rect(right + 3, top, right + 7, bottom, 18, 18, 22, 210, 0)
                    draw.rect(right + 3, bottom - height * ap, right + 7, bottom, 80, 155, 255, 245, 0)
                end
            end
        end
    end
end)
