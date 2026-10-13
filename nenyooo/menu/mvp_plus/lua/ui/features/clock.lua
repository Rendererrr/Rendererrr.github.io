
-- Clock HUD. Published fields: active (bool), hours, minutes, day (0 = Sunday), fps.
local DAYS = { [0] = "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" }

features.on_draw("Clock", function(f)
    if not f.active then return end

    local sw, sh = ctx.screen_w(), ctx.screen_h()
    local s = sh / 1080
    local ar, ag, ab = theme.accent()

    local time = string.format("%02d:%02d", math.floor(f.hours or 0), math.floor(f.minutes or 0))
    local day = DAYS[math.floor(f.day or 0)] or ""
    local fps = string.format("%d FPS", math.floor((f.fps or 0) + 0.5))

    local tw = text.width(font.item, time)
    local dw = text.width(font.small, day)
    local fw = text.width(font.tiny, fps)
    local pad = 10 * s
    local w = math.max(tw + dw + pad, fw) + pad * 2
    local h = text.height(font.item) + text.height(font.tiny) + pad * 1.5
    local x = sw - w - 18 * s
    local y = 18 * s

    draw.rect(x, y, x + w, y + h, 10, 10, 16, 150, 6 * s)

    local ty = y + pad * 0.5
    text.draw(font.item, x + pad, ty, 240, 240, 245, 255, time)
    text.draw(font.small, x + pad + tw + pad, ty + 2 * s, ar, ag, ab, 255, day)

    local fv = f.fps or 0
    local r, g, b = 120, 220, 140
    if fv < 30 then r, g, b = 235, 80, 80 elseif fv < 50 then r, g, b = 240, 180, 60 end
    text.draw(font.tiny, x + pad, ty + text.height(font.item) + 2 * s, r, g, b, 230, fps)
end)
