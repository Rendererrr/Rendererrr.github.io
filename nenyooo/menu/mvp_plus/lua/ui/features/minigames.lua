features.on_draw("Minigames", function(f)
    if not f.active then return end

    local sw, sh = ctx.screen_w(), ctx.screen_h()
    local ar, ag, ab = theme.accent()

    if (f.countdown or 0) > 0 then
        local value = tostring(math.floor(f.countdown))
        text.draw(font.title, sw * 0.5 - 18, sh * 0.30, ar, ag, ab, 255, value)
        return
    end

    if f.results then
        local title = f.won and "VICTORY" or "GAME OVER"
        local r, g, b = f.won and 70 or 240, f.won and 220 or 65, f.won and 110 or 65
        draw.rect(sw * 0.5 - 170, sh * 0.34, sw * 0.5 + 170, sh * 0.34 + 112, 10, 10, 16, 225, 8)
        draw.rect(sw * 0.5 - 170, sh * 0.34, sw * 0.5 + 170, sh * 0.34 + 4, r, g, b, 255, 4)
        text.draw(font.title, sw * 0.5 - 72, sh * 0.34 + 20, r, g, b, 255, title)
        text.draw(font.item, sw * 0.5 - 80, sh * 0.34 + 58, 235, 235, 240, 255, "Score: " .. math.floor(f.score or 0))
        text.draw(font.item, sw * 0.5 - 80, sh * 0.34 + 80, 175, 175, 185, 255, "Best: " .. math.floor(f.best or 0))
        return
    end

    local x, y, w, h = 24, sh * 0.17, 330, 142
    draw.rect(x, y, x + w, y + h, 10, 10, 16, 218, 7)
    draw.rect(x, y, x + 4, y + h, ar, ag, ab, 255, 4)
    draw.rect(x + 4, y, x + w, y + 3, ar, ag, ab, 210, 2)

    text.draw(font.title, x + 18, y + 14, ar, ag, ab, 255, f.title or "Minigame")
    text.draw(font.item, x + 18, y + 45, 215, 215, 222, 255, f.objective or "")
    text.draw(font.item, x + 18, y + 70, 240, 240, 245, 255, f.status or "")

    local seconds = math.floor((f.time_ms or 0) / 1000)
    local timer = string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
    text.draw(font.item, x + 18, y + 95, 175, 175, 185, 255, timer)
    text.draw(font.item, x + w - 105, y + 95, 235, 235, 240, 255, "Score " .. math.floor(f.score or 0))

    local p = math.max(0, math.min(1, f.progress or 0))
    draw.rect(x + 18, y + 121, x + w - 18, y + 128, 42, 42, 50, 230, 3)
    draw.rect(x + 18, y + 121, x + 18 + (w - 36) * p, y + 128, ar, ag, ab, 245, 3)
end)
