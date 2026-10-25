features.on_draw("Hash Gun", function(f)
    if type(f.x) ~= "number" or type(f.y) ~= "number" then return end
    local sw, sh = ctx.screen_w(), ctx.screen_h()
    if not sw or not sh or sw < 1 or sh < 1 then return end

    local names = {[1] = "Ped", [2] = "Vehicle", [3] = "Object"}
    local rows = {
        "Model: " .. string.format("0x%08X", f.model or 0),
        "Type: " .. (names[f.entity_type] or "Unknown"),
        "Handle: " .. tostring(math.floor(f.entity or 0)),
        "Blip: " .. tostring(math.floor(f.blip or 0))
    }
    local width, line_h, padding = 180, 18, 10
    local height = padding * 2 + #rows * line_h
    local x = math.min(sw - width - 8, math.max(8, f.x * sw + 18))
    local y = math.min(sh - height - 8, math.max(8, f.y * sh - height * 0.5))
    draw.rect(x, y, x + width, y + height, 8, 8, 12, 210, 5)
    draw.rect_outline(x, y, x + width, y + height, 180, 80, 230, 230, 5, 1)
    for i, row in ipairs(rows) do
        text.draw(font.small, x + padding, y + padding + (i - 1) * line_h,
            240, 240, 245, 255, row)
    end
end)
