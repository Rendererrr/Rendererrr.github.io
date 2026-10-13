-- Launch Timer HUD. Published by veh_launch_timer::draw:
--   staged / running / charging (bool), launch_control / start_lights (bool)
--   charge 0..1 with green_lo..green_hi as the perfect window, lights 0..4 (4 = green)
--   elapsed (s), speed / target (km/h), grade (0 none, 1 poor, 2 good, 3 perfect, 4 jump start)
--   reaction (s, only after a green light), best (s), result (s) + result_age 0..1, new_best, delta (s)

local GRADES = {
    [1] = { "POOR LAUNCH", 170, 170, 180 },
    [2] = { "GOOD LAUNCH", nil },
    [3] = { "PERFECT LAUNCH", 70, 235, 110 },
    [4] = { "JUMP START", 235, 60, 60 },
}

local function panel(x1, y1, x2, y2, a)
    draw.rect(x1, y1, x2, y2, 10, 10, 16, math.floor(200 * a), 8)
    draw.rect_outline(x1, y1, x2, y2, 255, 255, 255, math.floor(22 * a), 8, 1)
end

local function centered(fnt, cx, y, r, g, b, a, s)
    local w = text.width(fnt, s)
    text.draw(fnt, cx - w * 0.5, y, r, g, b, a, s)
end

local function big_number(cx, y, scale, r, g, b, a, s)
    draw.with_scale(cx, y, scale, function()
        centered(font.display, cx, y, r, g, b, a, s)
    end)
end

local function grade_color(grade, ar, ag, ab)
    local g = GRADES[grade]
    if not g then return nil end
    if not g[2] then return g[1], ar, ag, ab end
    return g[1], g[2], g[3], g[4]
end

local function draw_lights(cx, y, lights, now)
    local r, gap = 11, 34
    local x0 = cx - gap * 1.5
    for i = 1, 4 do
        local x = x0 + (i - 1) * gap
        local lit = lights >= i
        local cr, cg, cb = 40, 40, 48
        if lit then
            if i == 4 then cr, cg, cb = 60, 235, 100 else cr, cg, cb = 255, 170, 40 end
            local glow = (i == 4) and (0.6 + 0.4 * math.sin(now * 10)) or 0.7
            draw.circle(x, y, r + 7, cr, cg, cb, math.floor(55 * glow))
        end
        draw.circle(x, y, r, cr, cg, cb, 255)
        draw.circle_outline(x, y, r, 0, 0, 0, 160, 2)
    end
end

local function draw_rev_meter(x, y, w, h, f, ar, ag, ab, now)
    local c = math.max(0, math.min(1, f.charge or 0))
    local lo, hi = f.green_lo or 0.72, f.green_hi or 0.9
    draw.rect(x, y, x + w, y + h, 35, 35, 44, 235, 3)
    draw.rect(x + w * lo, y, x + w * hi, y + h, 60, 235, 100, 70, 0)

    local segments = 24
    local seg_w = w / segments
    for i = 0, segments - 1 do
        local t = (i + 0.5) / segments
        if t <= c then
            local r, g, b = ar, ag, ab
            if t >= lo and t <= hi then r, g, b = 60, 235, 100
            elseif t > hi then r, g, b = 240, 70, 60 end
            draw.rect(x + i * seg_w + 1, y + 2, x + (i + 1) * seg_w - 1, y + h - 2, r, g, b, 240, 1)
        end
    end

    local nx = x + w * c
    local in_green = c >= lo and c <= hi
    draw.line(nx, y - 5, nx, y + h + 5, 255, 255, 255, 255, 2.5)
    if in_green then
        draw.rect_outline(x + w * lo - 2, y - 3, x + w * hi + 2, y + h + 3, 60, 235, 100,
            math.floor(140 + 110 * math.sin(now * 16)), 3, 2)
    end
    text.draw(font.tiny, x, y + h + 6, 150, 150, 160, 220, "RPM")
    local label = string.format("%d%%", math.floor(c * 100 + 0.5))
    text.draw(font.tiny, x + w - text.width(font.tiny, label), y + h + 6, 220, 220, 230, 235, label)
end

local function draw_staged(f, sw, sh, ar, ag, ab, now)
    local w, h = 380, 150
    local cx = sw * 0.5
    local x1, y1 = cx - w * 0.5, sh * 0.70
    panel(x1, y1, x1 + w, y1 + h, 1)
    draw.rect(x1, y1, x1 + w, y1 + 3, ar, ag, ab, 255, 0)

    local title = f.launch_control and "LAUNCH CONTROL" or "STAGED"
    text.draw(font.small, x1 + 16, y1 + 12, 255, 255, 255, 245, title)
    if f.best then
        local b = string.format("BEST %.2f s", f.best)
        text.draw(font.small, x1 + w - 16 - text.width(font.small, b), y1 + 12, ar, ag, ab, 245, b)
    end
    local target = string.format("0 - %d km/h", math.floor(f.target or 100))
    text.draw(font.tiny, x1 + 16, y1 + 12 + text.height(font.small) + 2, 160, 160, 170, 230, target)

    local ly = y1 + 64
    if f.start_lights then draw_lights(cx, ly, f.charging and (f.lights or 0) or 0, now) end

    local hint
    if not f.launch_control then
        hint = "Drive off to start the clock"
    elseif not f.charging then
        hint = "Hold BRAKE + THROTTLE to build revs"
    elseif f.start_lights and (f.lights or 0) < 4 then
        hint = "Hold it... wait for green"
    else
        local c = f.charge or 0
        if c >= (f.green_lo or 0.72) and c <= (f.green_hi or 0.9) then hint = "RELEASE THE BRAKE!"
        else hint = "Release the brake in the green zone" end
    end

    if f.launch_control and f.charging then
        draw_rev_meter(x1 + 24, y1 + 92, w - 48, 14, f, ar, ag, ab, now)
        centered(font.tiny, cx, y1 + h - text.height(font.tiny) - 8, 235, 235, 240, 245, hint)
    else
        centered(font.small, cx, y1 + 100, 220, 220, 230, 235, hint)
    end
end

local function draw_running(f, sw, sh, ar, ag, ab, now)
    local w, h = 300, 112
    local cx = sw * 0.5
    local x1, y1 = cx - w * 0.5, sh * 0.08
    panel(x1, y1, x1 + w, y1 + h, 1)

    big_number(cx, y1 + 10, 1.6, 255, 255, 255, 255, string.format("%.2f", f.elapsed or 0))

    local speed = math.floor(f.speed or 0)
    local target = math.floor(f.target or 100)
    local p = math.max(0, math.min(1, speed / math.max(1, target)))
    local by = y1 + h - 30
    draw.rect(x1 + 18, by, x1 + w - 18, by + 6, 40, 40, 48, 230, 3)
    draw.rect(x1 + 18, by, x1 + 18 + (w - 36) * p, by + 6, ar, ag, ab, 255, 3)
    local label = string.format("%d / %d km/h", speed, target)
    centered(font.tiny, cx, by + 9, 210, 210, 220, 240, label)

    local name, gr, gg, gb = grade_color(f.grade or 0, ar, ag, ab)
    if name and (f.elapsed or 0) < 2.5 then
        local a = math.floor(255 * math.min(1, (2.5 - f.elapsed) / 0.5))
        local tag = name
        if f.reaction then tag = string.format("%s   REACTION %.3f s", name, f.reaction) end
        centered(font.small, cx, y1 + h + 8, gr, gg, gb, a, tag)
    end
end

local function draw_result(f, sw, sh, ar, ag, ab, now)
    local age = f.result_age or 1
    local a = math.min(1, age / 0.04, (1 - age) / 0.15)
    if a <= 0 then return end
    local w, h = 320, 150
    local cx = sw * 0.5
    local slide = (1 - math.min(1, age / 0.06)) * 20
    local x1, y1 = cx - w * 0.5, sh * 0.08 - slide
    panel(x1, y1, x1 + w, y1 + h, a)

    local hr, hg, hb = ar, ag, ab
    if f.new_best then hr, hg, hb = 255, 200, 60 end
    draw.rect(x1, y1, x1 + w, y1 + 3, hr, hg, hb, math.floor(255 * a), 0)

    centered(font.tiny, cx, y1 + 10, 170, 170, 180, math.floor(235 * a),
        string.format("0 - %d km/h", math.floor(f.target or 100)))
    big_number(cx, y1 + 28, 1.8, 255, 255, 255, math.floor(255 * a), string.format("%.2f s", f.result or 0))

    local line_y = y1 + 96
    if f.new_best then
        local pulse = 0.75 + 0.25 * math.sin(now * 8)
        centered(font.small, cx, line_y, 255, 200, 60, math.floor(255 * a * pulse), "NEW BEST")
    else
        local d = f.delta or 0
        centered(font.small, cx, line_y, 235, 80, 70, math.floor(245 * a),
            string.format("+%.2f s   BEST %.2f s", d, f.best or 0))
    end

    local name, gr, gg, gb = grade_color(f.grade or 0, ar, ag, ab)
    if name then
        local tag = name
        if f.reaction then tag = string.format("%s   REACTION %.3f s", name, f.reaction) end
        centered(font.tiny, cx, y1 + h - text.height(font.tiny) - 10, gr, gg, gb, math.floor(230 * a), tag)
    end
end

features.on_draw("Launch Timer", function(f)
    if not f.active then return end
    local sw, sh = ctx.screen_w(), ctx.screen_h()
    local ar, ag, ab = theme.accent()
    local now = ctx.time()

    if f.running then
        draw_running(f, sw, sh, ar, ag, ab, now)
    elseif f.result then
        draw_result(f, sw, sh, ar, ag, ab, now)
    end
    if f.staged then
        draw_staged(f, sw, sh, ar, ag, ab, now)
    end
end)
