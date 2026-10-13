-- Lap Timer HUD. Published by veh_lap_timer::draw:
--   running, armed (far enough out that the next crossing finishes the lap), lap (current lap number)
--   elapsed / best / last (s), show_clock, lx/ly (0..1) above the start line, distance (m)
--   result (s) + result_age 0..1 + record + delta (s) while the lap card is showing

local function fmt(t)
    t = math.max(0, t or 0)
    local m = math.floor(t / 60)
    local s = t - m * 60
    return string.format("%d:%06.3f", m, s)
end

local function centered(fnt, cx, y, r, g, b, a, s)
    text.draw(fnt, cx - text.width(fnt, s) * 0.5, y, r, g, b, a, s)
end

local function flag_icon(x, y, a)
    local sq = 4
    for row = 0, 2 do
        for col = 0, 3 do
            local white = (row + col) % 2 == 0
            local c = white and 255 or 20
            draw.rect(x + col * sq, y + row * sq, x + (col + 1) * sq, y + (row + 1) * sq, c, c, c, a, 0)
        end
    end
    draw.line(x, y, x, y + sq * 6, 230, 230, 230, a, 1.5)
end

local function world_label(f, sw, sh, ar, ag, ab, now)
    if not f.lx then return end
    local d = f.distance or 0
    local a = math.max(0, math.min(1, 1.15 - d / 500))
    if a <= 0.02 then return end
    local x, y = f.lx * sw, f.ly * sh
    local alpha = math.floor(240 * a)

    local title = "START / FINISH"
    local sub, sr, sg, sb
    if not f.running then
        sub, sr, sg, sb = "Drive off to start the clock", 220, 220, 230
    elseif f.armed then
        local pulse = 0.7 + 0.3 * math.sin(now * 6)
        sub, sr, sg, sb = "Cross to finish the lap", 70, 235, 110
        alpha = math.floor(alpha * pulse + 40 * (1 - pulse))
    else
        sub, sr, sg, sb = string.format("Lap %d underway", f.lap or 1), 200, 200, 210
    end

    local w = math.max(text.width(font.small, title), text.width(font.tiny, sub)) + 52
    local h = text.height(font.small) + text.height(font.tiny) + 16
    local x1, y1 = x - w * 0.5, y - h
    draw.rect(x1, y1, x1 + w, y1 + h, 10, 10, 16, math.floor(190 * a), 6)
    flag_icon(x1 + 14, y1 + h * 0.5 - 8, alpha)
    text.draw(font.small, x1 + 36, y1 + 6, 255, 255, 255, alpha, title)
    text.draw(font.tiny, x1 + 36, y1 + 8 + text.height(font.small), sr, sg, sb, alpha, sub)
    draw.line(x, y1 + h, x, y1 + h + 14, 255, 255, 255, math.floor(alpha * 0.7), 2)
    centered(font.tiny, x, y1 + h + 16, 220, 220, 230, math.floor(alpha * 0.85), string.format("%d m", math.floor(d + 0.5)))
end

local function lap_clock(f, sw, sh, ar, ag, ab)
    local w, h = 230, 118
    local x1, y1 = sw - w - 28, sh * 0.30
    draw.rect(x1, y1, x1 + w, y1 + h, 10, 10, 16, 200, 8)

    flag_icon(x1 + 14, y1 + 12, 235)
    text.draw(font.small, x1 + 36, y1 + 10, 255, 255, 255, 245, string.format("LAP %d", f.lap or 1))

    local t = fmt(f.elapsed)
    local tr, tg, tb = 255, 255, 255
    if f.best and (f.elapsed or 0) > f.best then tr, tg, tb = 240, 140, 120 end
    draw.with_scale(x1 + 16, y1 + 34, 1.35, function()
        text.draw(font.display, x1 + 16, y1 + 34, tr, tg, tb, 255, t)
    end)

    local row = y1 + h - text.height(font.tiny) * 2 - 12
    local function stat(label, value, ry, r, g, b)
        text.draw(font.tiny, x1 + 16, ry, 160, 160, 170, 235, label)
        text.draw(font.tiny, x1 + w - 16 - text.width(font.tiny, value), ry, r, g, b, 245, value)
    end
    stat("BEST", f.best and fmt(f.best) or "--", row, 255, 200, 60)
    stat("LAST", f.last and fmt(f.last) or "--", row + text.height(font.tiny) + 4, 220, 220, 230)
end

local function lap_card(f, sw, sh, ar, ag, ab, now)
    local age = f.result_age or 1
    local a = math.min(1, age / 0.04, (1 - age) / 0.15)
    if a <= 0 then return end
    local cx = sw * 0.5
    local w, h = 320, 128
    local x1, y1 = cx - w * 0.5, sh * 0.08 - (1 - math.min(1, age / 0.06)) * 18

    local hr, hg, hb = ar, ag, ab
    if f.record then hr, hg, hb = 255, 200, 60 end
    draw.rect(x1, y1, x1 + w, y1 + h, 10, 10, 16, math.floor(210 * a), 8)
    draw.rect(x1, y1, x1 + w, y1 + 3, hr, hg, hb, math.floor(255 * a), 0)

    centered(font.tiny, cx, y1 + 10, 170, 170, 180, math.floor(235 * a), string.format("LAP %d", math.max(1, (f.lap or 2) - 1)))
    draw.with_scale(cx, y1 + 28, 1.7, function()
        centered(font.display, cx, y1 + 28, 255, 255, 255, math.floor(255 * a), fmt(f.result))
    end)

    local line_y = y1 + h - text.height(font.small) - 10
    if f.record then
        local pulse = 0.75 + 0.25 * math.sin(now * 8)
        centered(font.small, cx, line_y, 255, 200, 60, math.floor(255 * a * pulse), "NEW BEST LAP")
    else
        centered(font.small, cx, line_y, 235, 80, 70, math.floor(245 * a),
            string.format("+%.3f s   BEST %s", f.delta or 0, fmt(f.best)))
    end
end

features.on_draw("Lap Timer", function(f)
    if not f.active then return end
    local sw, sh = ctx.screen_w(), ctx.screen_h()
    local ar, ag, ab = theme.accent()
    local now = ctx.time()

    world_label(f, sw, sh, ar, ag, ab, now)
    if f.show_clock and f.running then lap_clock(f, sw, sh, ar, ag, ab) end
    if f.result then lap_card(f, sw, sh, ar, ag, ab, now) end
end)
