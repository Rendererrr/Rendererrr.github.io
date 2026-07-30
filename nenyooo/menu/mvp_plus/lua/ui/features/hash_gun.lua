
-- Hash Gun inspector panel. Published: valid, hash_hex, hash_dec, type (1 ped/2 veh/3 obj), name,
-- category, x/y/z, heading, health/maxhealth, dist, extra, on_screen, sx/sy (entity screen pos).
-- The panel anchors on the aimed entity (falls back to the left edge when it's off-screen).
features.on_draw("Hash Gun", function(f)
    if not f.valid then return end

    local sw, sh = ctx.screen_w(), ctx.screen_h()
    local ar, ag, ab = theme.accent()
    local lh = 20

    local tname = ({ [1] = "Ped", [2] = "Vehicle", [3] = "Object" })[math.floor(f.type or 0)] or "Entity"
    local lines = {}
    lines[#lines + 1] = "HASH GUN"
    lines[#lines + 1] = "Name:  " .. (f.name or "Unknown")
    lines[#lines + 1] = "Hash:  " .. (f.hash_dec or "0") .. "   (" .. (f.hash_hex or "0x0") .. ")"
    lines[#lines + 1] = "Type:  " .. tname
    if f.category and #f.category > 0 then lines[#lines + 1] = "Cat:   " .. f.category end
    if f.extra and #f.extra > 0 then lines[#lines + 1] = "Info:  " .. f.extra end
    lines[#lines + 1] = string.format("Pos:   %.1f, %.1f, %.1f", f.x or 0, f.y or 0, f.z or 0)
    lines[#lines + 1] = string.format("Head:  %.1f", f.heading or 0)
    if (f.maxhealth or 0) > 0 then lines[#lines + 1] = string.format("HP:    %.0f / %.0f", f.health or 0, f.maxhealth or 0) end
    lines[#lines + 1] = string.format("Dist:  %.1f m", f.dist or 0)

    local w = 320
    local h = #lines * lh + 16

    -- Anchor the panel on the aimed entity (offset up-right of it), clamped on-screen. Off-screen -> left edge.
    local x, y
    if f.on_screen then
        local ex, ey = (f.sx or 0.5) * sw, (f.sy or 0.5) * sh
        -- marker dot on the entity
        draw.rect(ex - 3, ey - 3, ex + 3, ey + 3, ar, ag, ab, 255, 0)
        x, y = ex + 22, ey - h * 0.5
        if x + w > sw - 8 then x = ex - w - 22 end        -- flip to the left if it would overflow
        if x < 8 then x = 8 end
        if y < 8 then y = 8 elseif y + h > sh - 8 then y = sh - 8 - h end
    else
        x, y = sw * 0.03, sh * 0.28
    end

    draw.rect(x - 10, y - 10, x + w, y + h, 14, 14, 20, 210, 6)   -- panel bg
    draw.rect(x - 10, y - 10, x - 6, y + h, ar, ag, ab, 255, 0)   -- accent bar
    for i, l in ipairs(lines) do
        local col_r, col_g, col_b = 232, 232, 238
        if i == 1 then col_r, col_g, col_b = ar, ag, ab end        -- title in accent
        text.draw(font.item, x, y + (i - 1) * lh, col_r, col_g, col_b, 255, l)
    end
end)
