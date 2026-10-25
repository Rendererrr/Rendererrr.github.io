local factory_names = {
    "Document Forgery", "Weed", "Counterfeit Cash", "Meth", "Cocaine", "Bunker", "Acid Lab"
}

local nightclub_names = {
    "Cargo", "Sporting Goods", "Cocaine", "Meth", "Weed", "Documents", "Cash"
}

local function row(x, y, width, label, value, capacity, scale, accent)
    local font_id = font.tiny
    local height = text.height(font_id) + 5 * scale
    local fraction = capacity > 0 and math.max(0, math.min(1, value / capacity)) or 0
    text.draw(font_id, x, y, 220, 220, 228, 240, label)
    local amount = capacity > 0 and string.format("%d/%d", value, capacity) or tostring(value)
    text.draw(font_id, x + width - text.width(font_id, amount), y, 180, 180, 190, 240, amount)
    local bar_y = y + height - 3 * scale
    draw.rect(x, bar_y, x + width, bar_y + 2 * scale, 45, 45, 55, 220, scale)
    if fraction > 0 then
        draw.rect(x, bar_y, x + width * fraction, bar_y + 2 * scale,
            accent[1], accent[2], accent[3], 240, scale)
    end
    return y + height
end

features.on_draw("Business Inventory", function(f)
    if not f.active then return end

    local sw, sh = ctx.screen_w(), ctx.screen_h()
    local scale = (sh / 1080) * (f.scale or 1)
    local width = 310 * scale
    local pad = 11 * scale
    local x = math.max(0, math.min(sw - width, sw * (f.x or 0.73)))
    local y = math.max(0, math.min(sh - 120 * scale, sh * (f.y or 0.12)))
    local start_y = y
    local ar, ag, ab = theme.accent()
    local accent = {ar, ag, ab}

    local visible_factories = 0
    for i = 0, 6 do
        if not f.hide_unowned or f["factory_" .. i .. "_owned"] then visible_factories = visible_factories + 1 end
    end
    local rows = visible_factories + 7 + 5 + 3
    local line = text.height(font.tiny) + 5 * scale
    local height = 42 * scale + rows * line
    draw.rect(x, y, x + width, y + height, 10, 10, 16, 205, 7 * scale)
    draw.rect(x, y, x + width, y + 3 * scale, ar, ag, ab, 245, 2 * scale)
    text.draw(font.item, x + pad, y + 9 * scale, 245, 245, 250, 255, "Business Inventory")
    y = y + 35 * scale

    for i = 0, 6 do
        if not f.hide_unowned or f["factory_" .. i .. "_owned"] then
            y = row(x + pad, y, width - pad * 2, factory_names[i + 1],
                f["factory_" .. i .. "_product"] or 0,
                f["factory_" .. i .. "_capacity"] or 0, scale, accent)
        end
    end
    for i = 0, 6 do
        y = row(x + pad, y, width - pad * 2, "Nightclub: " .. nightclub_names[i + 1],
            f["nightclub_" .. i] or 0, f["nightclub_" .. i .. "_capacity"] or 0, scale, accent)
    end
    for i = 0, 4 do
        y = row(x + pad, y, width - pad * 2, "Office Warehouse " .. tostring(i + 1),
            f["warehouse_" .. i] or 0, f["warehouse_" .. i .. "_capacity"] or 0, scale, accent)
    end
    y = row(x + pad, y, width - pad * 2, "Hangar", f.hangar or 0, f.hangar_capacity or 50, scale, accent)
    y = row(x + pad, y, width - pad * 2, "Nightclub Safe", f.nightclub_safe or 0,
        f.nightclub_safe_capacity or 250000, scale, accent)
    row(x + pad, y, width - pad * 2, "Arcade Safe", f.arcade_safe or 0, 100000, scale, accent)

    return start_y
end)
