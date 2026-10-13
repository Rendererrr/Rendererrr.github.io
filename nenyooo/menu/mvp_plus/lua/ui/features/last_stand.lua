-- Last Stand. Published by wep_last_stand::draw while the feature is enabled.
--   state        0 = ready, 1 = recharging, 2 = fighting for your life
--   left/total   seconds left in the Last Stand (state 2) or until it recharges (state 1)
--   cooldown     0..1 recharge progress
--   result_age   0..1 for two seconds after a Last Stand ends; survived = true if you got the kill
--   indicator    Ready Indicator option

local function vignette(sw, sh, r, g, b, a, depth)
    local d = math.floor(depth)
    draw.rect_gradient(0, 0, sw, d, r, g, b, a, r, g, b, a, r, g, b, 0, r, g, b, 0)
    draw.rect_gradient(0, sh - d, sw, sh, r, g, b, 0, r, g, b, 0, r, g, b, a, r, g, b, a)
    draw.rect_gradient(0, 0, d, sh, r, g, b, a, r, g, b, 0, r, g, b, 0, r, g, b, a)
    draw.rect_gradient(sw - d, 0, sw, sh, r, g, b, 0, r, g, b, a, r, g, b, a, r, g, b, 0)
end

local function ring(cx, cy, r, frac, cr, cg, cb, ca, th)
    local steps = 48
    local n = math.floor(steps * math.max(0, math.min(1, frac)) + 0.5)
    local a0 = -math.pi / 2
    local px, py = cx + math.cos(a0) * r, cy + math.sin(a0) * r
    for k = 1, n do
        local t = a0 + (k / steps) * math.pi * 2
        local nx, ny = cx + math.cos(t) * r, cy + math.sin(t) * r
        draw.line(px, py, nx, ny, cr, cg, cb, ca, th)
        px, py = nx, ny
    end
end

local function centred(fnt, x, y, str, r, g, b, a)
    text.draw(fnt, x - text.width(fnt, str) * 0.5, y, r, g, b, a, str)
end

local function fighting(f, sw, sh, now)
    local left = math.max(0, f.left or 0)
    local total = math.max(1, f.total or 10)
    local urgent = left < 5
    local rate = urgent and 2.6 or 1.3
    local beat = math.max(0, math.sin(now * math.pi * 2 * rate)) ^ 6
    vignette(sw, sh, 160, 0, 0, math.floor(150 + 90 * beat), sh * (0.22 + 0.06 * beat))

    local cx, cy = sw * 0.5, sh * 0.17
    local r = 46
    draw.circle(cx, cy, r + 10, 10, 6, 8, 200)
    draw.circle_outline(cx, cy, r, 80, 20, 20, 220, 6)
    ring(cx, cy, r, left / total, 255, urgent and 40 or 70, 50, 255, 6)
    local num = string.format("%d", math.ceil(left))
    draw.with_scale(cx, cy, 1 + 0.12 * beat, function()
        local th = text.height(font.display)
        centred(font.display, cx, cy - th * 0.5, num, 255, 255, 255, 255)
    end)

    local ty = cy + r + 18
    text.draw_outlined(font.item, cx - text.width(font.item, "LAST STAND") * 0.5, ty, 255, 70, 60, 255, 0, 0, 0, 200, 2.0, "LAST STAND")
    local sub = "GET A KILL TO SURVIVE"
    local blink = urgent and (0.55 + 0.45 * math.sin(now * 16)) or 1
    text.draw_outlined(font.small, cx - text.width(font.small, sub) * 0.5, ty + text.height(font.item) + 4,
        255, 255, 255, math.floor(255 * blink), 0, 0, 0, 180, 1.5, sub)
end

local function result(f, sw, sh)
    local p = f.result_age
    local ok = f.survived
    local r, g, b = 255, 60, 50
    local title, sub = "BLED OUT", "You ran out of time"
    if ok then r, g, b, title, sub = 70, 235, 120, "SECOND WIND", "Back on your feet" end
    local fade = math.min(1, (1 - p) / 0.35)
    if ok then vignette(sw, sh, r, g, b, math.floor(120 * (1 - p)), sh * 0.2) end
    local cx, cy = sw * 0.5, sh * 0.2
    local pop = 1 + 0.4 * math.max(0, 1 - p / 0.1)
    draw.with_scale(cx, cy, pop, function()
        text.draw_outlined(font.display, cx - text.width(font.display, title) * 0.5, cy, r, g, b, math.floor(255 * fade),
            0, 0, 0, math.floor(200 * fade), 2.5, title)
    end)
    centred(font.small, cx, cy + text.height(font.display) + 8, sub, 230, 230, 235, math.floor(230 * fade))
end

local function indicator(f, sw, sh, now)
    local x, y = sw * 0.165, sh * 0.955 - 30
    local ready = f.state == 0
    local label = ready and "LAST STAND READY" or string.format("LAST STAND  %ds", math.ceil(f.left or 0))
    local w = text.width(font.tiny, label) + 46
    local h = 30
    draw.rect(x, y, x + w, y + h, 10, 10, 16, 190, 6)
    local ix, iy = x + 16, y + h * 0.5
    if ready then
        local glow = 0.6 + 0.4 * math.sin(now * 3)
        draw.circle(ix, iy, 9, 255, 70, 60, math.floor(90 * glow))
        draw.circle(ix, iy, 6, 255, 70, 60, 255)
    else
        draw.circle_outline(ix, iy, 8, 70, 70, 82, 220, 3)
        ring(ix, iy, 8, f.cooldown or 0, 255, 120, 100, 255, 3)
    end
    local tr, tg, tb = ready and 255 or 170, ready and 255 or 170, ready and 255 or 185
    text.draw(font.tiny, x + 32, y + (h - text.height(font.tiny)) * 0.5, tr, tg, tb, 255, label)
end

features.on_draw("Last Stand", function(f)
    if not f.active then return end
    local sw, sh = ctx.screen_w(), ctx.screen_h()
    local now = ctx.time()
    if f.state == 2 then
        fighting(f, sw, sh, now)
    elseif f.result_age then
        result(f, sw, sh)
    end
    if f.indicator and f.state ~= 2 then indicator(f, sw, sh, now) end
end)
