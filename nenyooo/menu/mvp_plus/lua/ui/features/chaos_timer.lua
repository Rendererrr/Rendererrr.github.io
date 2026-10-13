-- Chaos Timer. Published by misc_chaos_timer::draw while the feature is enabled.
--   left / interval        seconds until the next event / the full interval
--   names                  every event name, ";"-separated (for the roulette)
--   event, blurb           the event just triggered; event_age = seconds since (absent after ~4 s)
--   effect                 a timed event still running; effect_left / effect_total in seconds
--   last1, last2, last3    most recent events, newest first

local function centred(fnt, x, y, str, r, g, b, a)
    text.draw(fnt, x - text.width(fnt, str) * 0.5, y, r, g, b, a, str)
end

local function names_of(s)
    local out = {}
    for n in (s or ""):gmatch("([^;]+);") do out[#out + 1] = n end
    return out
end

local function lerp(a, b, t) return a + (b - a) * t end
local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function panel(f, sw, sh, now, ar, ag, ab)
    local w, h = 360, 66
    local x = sw * 0.5 - w * 0.5
    local y = sh * 0.035
    local left = math.max(0, f.left or 0)
    local interval = math.max(1, f.interval or 30)
    local frac = clamp(left / interval, 0, 1)
    local urgent = left <= 3

    local br, bg, bb = ar, ag, ab
    if urgent then
        local t = 1 - left / 3
        br, bg, bb = math.floor(lerp(ar, 255, t)), math.floor(lerp(ag, 60, t)), math.floor(lerp(ab, 50, t))
    end
    local pulse = urgent and (0.65 + 0.35 * math.sin(now * 14)) or 1

    draw.rect(x, y, x + w, y + h, 10, 10, 16, 210, 8)

    draw.circle(x + 16, y + 15, 4, br, bg, bb, math.floor(255 * pulse))
    text.draw(font.tiny, x + 26, y + 8, 165, 165, 180, 255, "CHAOS TIMER")
    local label = "NEXT EVENT"
    text.draw(font.tiny, x + w - 14 - text.width(font.tiny, label), y + 8, 165, 165, 180, 255, label)

    local current = f.effect or f.last1 or "Get ready"
    local sub_r, sub_g, sub_b = 240, 240, 245
    if f.effect then sub_r, sub_g, sub_b = 255, 190, 70 end
    text.draw(font.item, x + 14, y + 26, sub_r, sub_g, sub_b, 255, current)

    local secs = string.format("%.1fs", left)
    local tw = text.width(font.item, secs)
    draw.with_scale(x + w - 14 - tw * 0.5, y + 34, urgent and (1 + 0.12 * pulse) or 1, function()
        text.draw(font.item, x + w - 14 - tw, y + 26, br, bg, bb, 255, secs)
    end)

    local bx1, bx2, by = x + 14, x + w - 14, y + h - 12
    draw.rect(bx1, by, bx2, by + 5, 45, 45, 55, 230, 2)
    draw.rect(bx1, by, bx1 + (bx2 - bx1) * frac, by + 5, br, bg, bb, math.floor(255 * pulse), 2)
    if interval <= 60 then
        for i = 1, math.floor(interval) - 1 do
            local tx = bx1 + (bx2 - bx1) * (i / interval)
            draw.rect(tx, by, tx + 1, by + 5, 10, 10, 16, 160)
        end
    end

    local bottom = y + h
    if f.effect and f.effect_total and f.effect_total > 0 then
        local ef = clamp((f.effect_left or 0) / f.effect_total, 0, 1)
        local ey = bottom + 4
        draw.rect(x, ey, x + w, ey + 24, 10, 10, 16, 190, 6)
        local tag = string.format("%s  %ds", string.upper(f.effect), math.ceil(f.effect_left or 0))
        text.draw(font.tiny, x + 14, ey + 5, 255, 190, 70, 255, tag)
        local ex1 = x + 14 + text.width(font.tiny, tag) + 12
        draw.rect(ex1, ey + 10, x + w - 14, ey + 14, 45, 45, 55, 230, 2)
        draw.rect(ex1, ey + 10, ex1 + (x + w - 14 - ex1) * ef, ey + 14, 255, 190, 70, 255, 2)
        bottom = ey + 24
    end

    if f.last2 then
        local hist = "BEFORE  " .. string.upper(f.last2) .. (f.last3 and ("  /  " .. string.upper(f.last3)) or "")
        centred(font.tiny, sw * 0.5, bottom + 6, hist, 140, 140, 155, 200)
    end
end

local function roulette(f, sw, sh, now, ar, ag, ab)
    local list = names_of(f.names)
    if #list == 0 then return end
    local left = math.max(0, f.left or 0)
    local cx, cy = sw * 0.5, sh * 0.27

    local digit = math.max(1, math.ceil(left))
    local sub = left - math.floor(left)
    local pop = 1 + 0.5 * clamp((sub - 0.75) / 0.25, 0, 1)
    draw.with_scale(cx, cy - 40, pop, function()
        local s = tostring(digit)
        text.draw_outlined(font.display, cx - text.width(font.display, s) * 0.5, cy - 40 - text.height(font.display) * 0.5,
            255, 255, 255, 255, 0, 0, 0, 200, 2.0, s)
    end)

    local rowh = text.height(font.item) + 10
    local w = 300
    local x1, x2 = cx - w * 0.5, cx + w * 0.5
    local y1, y2 = cy, cy + rowh * 3
    draw.rect(x1, y1, x2, y2, 10, 10, 16, 200, 8)
    draw.rect(x1, y1 + rowh, x2, y1 + rowh * 2, ar, ag, ab, 70, 0)
    draw.rect_outline(x1, y1 + rowh, x2, y1 + rowh * 2, ar, ag, ab, 230, 0, 2)

    local speed = 5 + 16 * clamp(left / 3, 0, 1)
    local pos = now * speed
    local base = math.floor(pos)
    local f_off = pos - base
    draw.push_clip(x1, y1, x2, y2)
    for k = -1, 3 do
        local name = list[((base + k) % #list) + 1]
        local ry = y1 + (k - f_off + 1) * rowh - rowh
        local mid = ry + rowh * 0.5
        local d = math.abs(mid - (y1 + rowh * 1.5)) / rowh
        local a = math.floor(255 * clamp(1 - d * 0.6, 0.15, 1))
        centred(font.item, cx, ry + 5, string.upper(name), 240, 240, 245, a)
    end
    draw.pop_clip()
    draw.rect_gradient(x1, y1, x2, y1 + rowh, 10, 10, 16, 220, 10, 10, 16, 220, 10, 10, 16, 0, 10, 10, 16, 0)
    draw.rect_gradient(x1, y2 - rowh, x2, y2, 10, 10, 16, 0, 10, 10, 16, 0, 10, 10, 16, 220, 10, 10, 16, 220)
end

local function reveal(f, sw, sh, now, ar, ag, ab)
    local age = f.event_age or 0
    local fade = clamp((4.0 - age) / 0.6, 0, 1)
    if fade <= 0 then return end
    local a = math.floor(255 * fade)
    local cx = sw * 0.5
    local cy = sh * 0.27 - math.max(0, age - 3.4) * 30

    if age < 0.18 then
        draw.rect(0, 0, sw, sh, 255, 255, 255, math.floor(70 * (1 - age / 0.18)))
    end

    local spread = 220 * clamp(age / 0.35, 0, 1)
    local th = text.height(font.display)
    draw.rect_gradient(cx - spread, cy - 14, cx, cy - 12, ar, ag, ab, 0, ar, ag, ab, a, ar, ag, ab, a, ar, ag, ab, 0)
    draw.rect_gradient(cx, cy - 14, cx + spread, cy - 12, ar, ag, ab, a, ar, ag, ab, 0, ar, ag, ab, 0, ar, ag, ab, a)
    centred(font.tiny, cx, cy - 34, "CHAOS EVENT", ar, ag, ab, a)

    local name = string.upper(f.event or "")
    local pop = 1 + 0.6 * clamp(1 - age / 0.18, 0, 1)
    local shake = age < 0.4 and (math.sin(now * 90) * 4 * (1 - age / 0.4)) or 0
    draw.with_scale(cx, cy + th * 0.5, pop, function()
        text.draw_outlined(font.display, cx - text.width(font.display, name) * 0.5 + shake, cy, 255, 255, 255, a,
            0, 0, 0, math.floor(a * 0.8), 2.0, name)
    end)

    if f.blurb then
        centred(font.item, cx, cy + th + 8, f.blurb, 220, 220, 230, math.floor(a * clamp((age - 0.2) / 0.3, 0, 1)))
    end
    draw.rect_gradient(cx - spread, cy + th + 36, cx, cy + th + 38, ar, ag, ab, 0, ar, ag, ab, a, ar, ag, ab, a, ar, ag, ab, 0)
    draw.rect_gradient(cx, cy + th + 36, cx + spread, cy + th + 38, ar, ag, ab, a, ar, ag, ab, 0, ar, ag, ab, 0, ar, ag, ab, a)
end

features.on_draw("Chaos Timer", function(f)
    if not f.active then return end
    local sw, sh = ctx.screen_w(), ctx.screen_h()
    local now = ctx.time()
    local ar, ag, ab = theme.accent()

    panel(f, sw, sh, now, ar, ag, ab)
    if f.event then
        reveal(f, sw, sh, now, ar, ag, ab)
    elseif (f.left or 99) <= 3 then
        roulette(f, sw, sh, now, ar, ag, ab)
    end
end)
