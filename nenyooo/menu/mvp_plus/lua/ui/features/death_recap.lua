
-- Death Recap. Shown while you are dead. Published fields: active (bool), killer, cause (strings),
-- distance (m), survived (s alive before this death), deaths (count since enabled).
local t = 0

features.on_draw("Death Recap", function(f)
    if not f.active then t = 0 return end
    t = math.min(1, t + 0.04)

    local sw, sh = ctx.screen_w(), ctx.screen_h()
    local s = sh / 1080
    local a = math.floor(255 * t)
    local fnt = font.display or font.item
    local pad = 16 * s

    local survived = math.floor(f.survived or 0)
    local rows = {
        { "Weapon", f.cause or "" },
        { "Distance", string.format("%d m", math.floor(f.distance or 0)) },
        { "Survived", string.format("%d:%02d", math.floor(survived / 60), survived % 60) },
        { "Deaths", tostring(math.floor(f.deaths or 0)) },
    }

    local killer = f.killer or ""
    local w = math.max(320 * s, text.width(fnt, killer) + pad * 2)
    local lh = text.height(font.small) + 6 * s
    local h = text.height(font.tiny) + text.height(fnt) + lh * #rows + pad * 2
    local x = sw * 0.5 - w * 0.5
    local y = sh * 0.62 + (1 - t) * 20 * s

    draw.rect(x, y, x + w, y + h, 12, 8, 10, math.floor(200 * t), 8 * s)
    draw.rect(x, y, x + w, y + 3 * s, 200, 40, 40, a, 0)

    local ty = y + pad
    text.draw(font.tiny, x + pad, ty, 200, 60, 60, a, "KILLED BY")
    ty = ty + text.height(font.tiny)
    text.draw(fnt, x + pad, ty, 245, 245, 250, a, killer)
    ty = ty + text.height(fnt) + 4 * s
    for _, row in ipairs(rows) do
        text.draw(font.small, x + pad, ty, 160, 160, 170, a, row[1])
        local vw = text.width(font.small, row[2])
        text.draw(font.small, x + w - pad - vw, ty, 235, 235, 240, a, row[2])
        ty = ty + lh
    end
end)
