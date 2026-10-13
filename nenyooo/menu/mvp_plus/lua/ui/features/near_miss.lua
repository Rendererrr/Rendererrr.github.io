-- Near Miss HUD. Published by veh_near_miss::draw:
--   popups = "x,y,progress,points,name;" per miss (x/y 0..1 screen, rising and fading over progress 0..1)
--   combo, combo_points, combo_left 0..1 (time left to land the next miss), best_combo, best_points
--   banner_combo / banner_points / banner_age 0..1 / banner_broken / banner_best after a combo ends

local function commas(n)
    local s = tostring(math.floor(n + 0.5))
    return (s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

local function centered(fnt, cx, y, r, g, b, a, s)
    text.draw(fnt, cx - text.width(fnt, s) * 0.5, y, r, g, b, a, s)
end

local function outlined(fnt, cx, y, r, g, b, a, s)
    text.draw_outlined(fnt, cx - text.width(fnt, s) * 0.5, y, r, g, b, a, 0, 0, 0, math.floor(a * 0.75), 1.5, s)
end

local function popups(f, sw, sh, ar, ag, ab)
    if not f.popups or f.popups == "" then return end
    for xs, ys, ps, pts, name in string.gmatch(f.popups, "([^,]+),([^,]+),([^,]+),([^,]+),([^;]*);") do
        local x, y, p = tonumber(xs) * sw, tonumber(ys) * sh, tonumber(ps)
        local a = math.floor(255 * math.min(1, (1 - p) / 0.35))
        local pop = 1 + 0.3 * math.max(0, 1 - p / 0.12)
        outlined(font.tiny, x, y - 22, 255, 255, 255, a, "NEAR MISS")
        draw.with_scale(x, y - 4, 1.2 * pop, function()
            outlined(font.item, x, y - 4, ar, ag, ab, a, "+" .. commas(tonumber(pts) or 0))
        end)
        if name ~= "" then outlined(font.tiny, x, y + text.height(font.item) * 1.2, 220, 220, 230, math.floor(a * 0.9), name) end
    end
end

local function combo_panel(f, sw, sh, ar, ag, ab, now)
    local combo = math.floor(f.combo or 0)
    if combo < 1 then return end
    local w, h = 210, 104
    local x1, y1 = sw - w - 28, sh * 0.42
    local left = math.max(0, math.min(1, f.combo_left or 0))

    draw.rect(x1, y1, x1 + w, y1 + h, 10, 10, 16, 200, 8)
    text.draw(font.tiny, x1 + 16, y1 + 10, 200, 200, 210, 235, "NEAR MISS COMBO")

    local mult = "x" .. combo
    local pulse = 1 + 0.08 * math.max(0, math.sin(now * 10))
    draw.with_scale(x1 + 16, y1 + 28, 1.5 * pulse, function()
        text.draw(font.display, x1 + 16, y1 + 28, 255, 255, 255, 255, mult)
    end)
    local pts = commas(f.combo_points or 0)
    text.draw(font.small, x1 + w - 16 - text.width(font.small, pts), y1 + 38, ar, ag, ab, 250, pts)

    local by = y1 + h - 16
    local r, g, b = ar, ag, ab
    if left < 0.3 then r, g, b = 255, 90, 60 end
    draw.rect(x1 + 16, by, x1 + w - 16, by + 5, 40, 40, 48, 230, 2)
    draw.rect(x1 + 16, by, x1 + 16 + (w - 32) * left, by + 5, r, g, b, 250, 2)
end

local function banner(f, sw, sh, now)
    local age = f.banner_age or 1
    local a = math.min(1, age / 0.04, (1 - age) / 0.15)
    if a <= 0 then return end
    local cx = sw * 0.5
    local y = sh * 0.14 - (1 - math.min(1, age / 0.06)) * 16
    local pop = 1 + 0.15 * math.max(0, 1 - age / 0.08)

    local title, r, g, b
    if f.banner_broken then
        title, r, g, b = "COMBO BROKEN", 235, 60, 60
    else
        title, r, g, b = string.format("x%d NEAR MISS COMBO", math.floor(f.banner_combo or 0)), 255, 255, 255
        if f.banner_best then r, g, b = 255, 200, 60 end
    end
    draw.with_scale(cx, y, 1.3 * pop, function()
        outlined(font.display, cx, y, r, g, b, math.floor(255 * a), title)
    end)

    local sy = y + text.height(font.display) * 1.3 + 6
    local pts = commas(f.banner_points or 0)
    if f.banner_broken then
        local w = text.width(font.item, pts)
        outlined(font.item, cx, sy, 200, 200, 210, math.floor(240 * a), pts)
        draw.line(cx - w * 0.5 - 4, sy + text.height(font.item) * 0.55, cx + w * 0.5 + 4, sy + text.height(font.item) * 0.55, 235, 60, 60, math.floor(240 * a), 2.5)
        centered(font.small, cx, sy + text.height(font.item) + 6, 235, 140, 130, math.floor(235 * a), "You clipped a car; points lost")
    else
        outlined(font.item, cx, sy, 255, 255, 255, math.floor(250 * a), "+" .. pts)
        if f.banner_best then
            local pulse = 0.75 + 0.25 * math.sin(now * 8)
            centered(font.small, cx, sy + text.height(font.item) + 6, 255, 200, 60, math.floor(255 * a * pulse), "NEW BEST")
        elseif f.best_points then
            centered(font.small, cx, sy + text.height(font.item) + 6, 200, 200, 210, math.floor(230 * a),
                string.format("BEST x%d   %s", math.floor(f.best_combo or 0), commas(f.best_points)))
        end
    end
end

features.on_draw("Near Miss", function(f)
    if not f.active then return end
    local sw, sh = ctx.screen_w(), ctx.screen_h()
    local ar, ag, ab = theme.accent()
    local now = ctx.time()
    popups(f, sw, sh, ar, ag, ab)
    combo_panel(f, sw, sh, ar, ag, ab, now)
    if f.banner_age then banner(f, sw, sh, now) end
end)
