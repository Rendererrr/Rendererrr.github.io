
-- Chase Info. Shown only while you are wanted. Published fields: active (bool), stars, seen (bool),
-- searching (bool), escaping (bool), zone_distance (m left before you leave the search area; negative = outside),
-- duration (s since the chase started).
features.on_draw("Chase Info", function(f)
    if not f.active then return end

    local sw, sh = ctx.screen_w(), ctx.screen_h()
    local s = sh / 1080
    local pad = 10 * s
    local w = 230 * s
    local lh = text.height(font.small) + 4 * s
    local h = lh * 3 + pad * 2
    local x = 24 * s
    local y = sh * 0.22

    local status, r, g, b = "SPOTTED", 235, 70, 70
    if f.escaping then status, r, g, b = "LOSING THEM", 90, 220, 120
    elseif f.searching then status, r, g, b = "SEARCHING", 240, 180, 60 end

    draw.rect(x, y, x + w, y + h, 10, 10, 16, 150, 6 * s)

    local stars = math.floor(f.stars or 0)
    local sx = x + pad
    for i = 1, 5 do
        local filled = i <= stars
        local cxs, cys, rad = sx + (i - 1) * 16 * s + 6 * s, y + pad + lh * 0.45, 5 * s
        if filled then draw.circle(cxs, cys, rad, 240, 240, 245, 255)
        else draw.circle_outline(cxs, cys, rad, 240, 240, 245, 120, 1.2) end
    end
    local sl = text.width(font.small, status)
    text.draw(font.small, x + w - pad - sl, y + pad, r, g, b, 255, status)

    local zd = f.zone_distance or 0
    local zone = zd > 0 and string.format("%d m to zone edge", math.floor(zd)) or "Outside search zone"
    text.draw(font.small, x + pad, y + pad + lh, 220, 220, 228, 235, zone)

    local d = math.floor(f.duration or 0)
    text.draw(font.small, x + pad, y + pad + lh * 2, 170, 170, 180, 230, string.format("Chase %d:%02d", math.floor(d / 60), d % 60))
end)
