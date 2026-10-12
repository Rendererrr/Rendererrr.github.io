
-- Fuel gauge. Published fields: active (bool), fuel (0..1), refuelling (bool).
features.on_draw("Fuel", function(f)
    if not f.active then return end

    local sw, sh = ctx.screen_w(), ctx.screen_h()
    local fuel = math.max(0, math.min(1, f.fuel or 0))
    local w = sw * 0.14
    local h = 8
    local x = sw * 0.015
    local y = sh * 0.785
    local lh = text.height(font.small)

    local r, g, b = 80, 220, 120
    if fuel < 0.05 then
        r, g, b = 235, 60, 60
    elseif fuel < 0.2 then
        r, g, b = 240, 170, 50
    end

    local a = 255
    if f.refuelling then
        local t = ctx.time and ctx.time() or 0
        a = 150 + math.floor(105 * (0.5 + 0.5 * math.sin(t * 6)))
    elseif fuel < 0.05 then
        local t = ctx.time and ctx.time() or 0
        a = 120 + math.floor(135 * (0.5 + 0.5 * math.sin(t * 10)))
    end

    draw.rect(x - 4, y - lh - 8, x + w + 4, y + h + 4, 12, 12, 18, 170, 4)
    text.draw(font.small, x, y - lh - 4, 230, 230, 235, 255, f.refuelling and "FUEL  +" or "FUEL")
    local pct = string.format("%d%%", math.floor(fuel * 100 + 0.5))
    text.draw(font.small, x + w - text.width(font.small, pct), y - lh - 4, r, g, b, a, pct)

    draw.rect(x, y, x + w, y + h, 40, 40, 48, 220, 3)
    if fuel > 0 then
        draw.rect(x, y, x + w * fuel, y + h, r, g, b, a, 3)
    end
end)
