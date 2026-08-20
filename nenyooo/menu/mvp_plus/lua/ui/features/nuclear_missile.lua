-- Nuclear missile guidance HUD -- a weapon nose-camera feed, not a set of panels.
--
-- Published by wep_nuclear_missile::draw: flying (bool), phase (0 idle, 1 booster, 2 cruise,
-- 3 impact), speed (m/s), altitude (m), distance (m to target), fuel (0..1), throttle (0..1).
--
-- Identity is a gun-camera viewfinder: hazard-striped phase banner, converging boresight that
-- tightens as the target closes, vertical propellant/throttle columns, a scrolling altitude
-- ladder, and a phosphor palette that shifts amber -> green -> red with the flight phase.

local PI = math.pi
local sin, cos, min, max, floor, abs = math.sin, math.cos, math.min, math.max, math.floor, math.abs

local AMBER_R, AMBER_G, AMBER_B = 255, 176,  40   -- booster ascent
local GREEN_R, GREEN_G, GREEN_B = 130, 255, 160   -- guidance / cruise
local RED_R,   RED_G,   RED_B   = 255,  62,  48   -- terminal / detonation
local WHT_R,   WHT_G,   WHT_B   = 232, 245, 236
local DIM_R,   DIM_G,   DIM_B   =  46,  78,  58

local PHASE_BOOSTER, PHASE_CRUISE, PHASE_IMPACT = 1, 2, 3

local boot_at, was_flying = -1, false
local sm_speed, sm_alt, sm_dist, sm_fuel, sm_thr = 0, 0, 0, 0, 0

local g_fade = 1
local function A(v) return floor(v * g_fade) end

local function approach(cur, target, rate, dt)
    return cur + (target - cur) * min(1, rate * dt)
end

-- Diagonal hazard stripes clipped to a box -- the one motif that says "warhead" on sight.
local function hazard_bar(x1, y1, x2, y2, r, g, b, a, s)
    draw.push_clip(x1, y1, x2, y2)
    local h = y2 - y1
    local step = 15 * s
    local x = x1 - h
    while x < x2 do
        draw.line(x, y2, x + h, y1, r, g, b, a, 6 * s)
        x = x + step
    end
    draw.pop_clip()
end

-- Camera viewfinder corners + edge centre ticks.
local function viewfinder(x1, y1, x2, y2, len, r, g, b, a, th)
    draw.line(x1, y1, x1 + len, y1, r, g, b, a, th); draw.line(x1, y1, x1, y1 + len, r, g, b, a, th)
    draw.line(x2 - len, y1, x2, y1, r, g, b, a, th); draw.line(x2, y1, x2, y1 + len, r, g, b, a, th)
    draw.line(x1, y2 - len, x1, y2, r, g, b, a, th); draw.line(x1, y2, x1 + len, y2, r, g, b, a, th)
    draw.line(x2, y2 - len, x2, y2, r, g, b, a, th); draw.line(x2 - len, y2, x2, y2, r, g, b, a, th)
    local mx, my = (x1 + x2) * 0.5, (y1 + y2) * 0.5
    local t = len * 0.28
    draw.line(mx, y1, mx, y1 + t, r, g, b, a, th); draw.line(mx, y2 - t, mx, y2, r, g, b, a, th)
    draw.line(x1, my, x1 + t, my, r, g, b, a, th); draw.line(x2 - t, my, x2, my, r, g, b, a, th)
end

-- Vertical segmented column, fills bottom-up. Used for propellant and throttle.
local function column(x, y_bot, w, h, segs, value, r, g, b, a)
    local gap = max(1.0, h * 0.008)
    local sh_ = (h - gap * (segs - 1)) / segs
    local lit = max(0, min(1, value)) * segs
    for i = 0, segs - 1 do
        local by = y_bot - (i + 1) * sh_ - i * gap
        local fill = min(1, max(0, lit - i))
        if fill > 0 then
            draw.rect(x, by, x + w, by + sh_, r, g, b, floor(a * (0.45 + 0.55 * fill)), 0)
        else
            draw.rect(x, by, x + w, by + sh_, DIM_R, DIM_G, DIM_B, floor(a * 0.5), 0)
        end
    end
end

local function arc(cx, cy, rad, a0, a1, r, g, b, a, th)
    if a <= 0 or a1 <= a0 then return end
    local steps = max(2, math.ceil((a1 - a0) / 0.10))
    local d = (a1 - a0) / steps
    local px, py = cx + sin(a0) * rad, cy - cos(a0) * rad
    for i = 1, steps do
        local t = a0 + d * i
        local nx, ny = cx + sin(t) * rad, cy - cos(t) * rad
        draw.line(px, py, nx, ny, r, g, b, a, th)
        px, py = nx, ny
    end
end

local function right_text(fnt, x2, y, r, g, b, a, str)
    text.draw(fnt, x2 - text.width(fnt, str), y, r, g, b, a, str)
end

local function centre_spaced(fnt, cx, y, sp, r, g, b, a, str)
    text.draw_spaced(fnt, cx - text.width_spaced(fnt, str, sp) * 0.5, y, r, g, b, a, str, sp)
end

-- Scrolling altitude ladder. Ticks march past a fixed caret; labels on the majors.
local function ladder(x, cy, half, value, step, s, r, g, b, a)
    local per = half / 5.5
    local base = floor(value / step)
    draw.line(x, cy - half, x, cy + half, r, g, b, floor(a * 0.35), 1.2)
    for i = -6, 6 do
        local v = (base + i) * step
        local ty = cy + (value - v) / step * per
        if v >= 0 and ty >= cy - half and ty <= cy + half then
            local major = (i + base) % 5 == 0
            local len = (major and 14 or 7) * s
            local ta = floor(a * (0.35 + 0.65 * (1 - abs(ty - cy) / half)))
            draw.line(x - len, ty, x, ty, r, g, b, major and ta or floor(ta * 0.65), major and 1.5 or 1.0)
            if major then
                local lbl = string.format("%d", v)
                text.draw(font.tiny, x - len - 6 * s - text.width(font.tiny, lbl),
                          ty - text.height(font.tiny) * 0.5, r, g, b, floor(ta * 0.9), lbl)
            end
        end
    end
    draw.line(x, cy - 6 * s, x + 12 * s, cy, r, g, b, a, 1.7)
    draw.line(x, cy + 6 * s, x + 12 * s, cy, r, g, b, a, 1.7)
end

features.on_draw("Nuclear Missile", function(f)
    local now = ctx.time()
    if f.flying and not was_flying then boot_at = now end
    was_flying = f.flying and true or false
    if not f.flying then return end

    local dt = min(0.1, max(0.001, ctx.delta()))
    local boot = boot_at < 0 and 1 or min(1, (now - boot_at) / 0.5)
    g_fade = 1 - (1 - boot) * (1 - boot)

    local sw, sh = ctx.screen_w(), ctx.screen_h()
    local s = max(0.72, min(1.7, sh / 1080))
    local m = 34 * s
    local cx, cy = sw * 0.5, sh * 0.5

    local phase = floor((f.phase or 0) + 0.5)
    local impact = phase == PHASE_IMPACT

    sm_speed = approach(sm_speed, f.speed or 0, 8, dt)
    sm_alt   = approach(sm_alt, f.altitude or 0, 8, dt)
    sm_dist  = approach(sm_dist, f.distance or 0, 8, dt)
    sm_fuel  = approach(sm_fuel, f.fuel or 0, 6, dt)
    sm_thr   = approach(sm_thr, f.throttle or 0, 6, dt)

    -- Phase drives the whole palette: amber on the boost, phosphor green under guidance, red the
    -- moment the warhead is committed.
    local ac_r = impact and RED_R or (phase == PHASE_BOOSTER and AMBER_R or GREEN_R)
    local ac_g = impact and RED_G or (phase == PHASE_BOOSTER and AMBER_G or GREEN_G)
    local ac_b = impact and RED_B or (phase == PHASE_BOOSTER and AMBER_B or GREEN_B)

    ------------------------------------------------------------------ camera frame
    draw.rect_gradient(0, 0, sw, 90 * s,
        ac_r, ac_g, ac_b, A(30), ac_r, ac_g, ac_b, A(30),
        ac_r, ac_g, ac_b, 0, ac_r, ac_g, ac_b, 0)
    draw.rect_gradient(0, sh - 90 * s, sw, sh,
        ac_r, ac_g, ac_b, 0, ac_r, ac_g, ac_b, 0,
        ac_r, ac_g, ac_b, A(26), ac_r, ac_g, ac_b, A(26))
    viewfinder(m * 0.6, m * 0.6, sw - m * 0.6, sh - m * 0.6, 40 * s, ac_r, ac_g, ac_b, A(120), 1.5)

    -- live-feed marker
    local blink = sin(now * 4.0) > 0
    if blink then draw.circle(m * 0.6 + 12 * s, m * 0.6 + 14 * s, 4 * s, RED_R, RED_G, RED_B, A(235)) end
    text.draw_spaced(font.tiny, m * 0.6 + 22 * s, m * 0.6 + 8 * s, 190, 205, 195, A(190), "LIVE", 2 * s)

    ------------------------------------------------------------------ phase banner
    local bw, bh = 420 * s, 8 * s
    local bx, by = cx - bw * 0.5, m - 4 * s
    hazard_bar(bx, by, bx + bw, by + bh, ac_r, ac_g, ac_b, A(impact and 210 or 150), s)
    draw.rect_outline(bx, by, bx + bw, by + bh, ac_r, ac_g, ac_b, A(200), 0, 1.0)

    local status = impact and "WARHEAD COMMITTED"
                   or (phase == PHASE_BOOSTER and "BOOSTER ASCENT" or "GUIDANCE ACTIVE")
    -- Floor at 0.55: a pulse that reaches zero makes the warning READ AS ABSENT half the time,
    -- which is the opposite of what a warning is for.
    local flash = impact and (0.55 + 0.45 * sin(now * 9.0)) or 1
    centre_spaced(font.title, cx, by + bh + 6 * s, 5 * s, ac_r, ac_g, ac_b, A(245 * flash), status)
    centre_spaced(font.tiny, cx, by + bh + 6 * s + text.height(font.title) - 4 * s, 3 * s,
                  170, 190, 178, A(180), "STRATEGIC GUIDANCE SYSTEM")

    ------------------------------------------------------------------ boresight
    if not impact then
        -- Brackets converge as the target closes: wide when far, tight on terminal approach.
        local closure = 1 - min(1, sm_dist / 2000)
        local d = (78 - 42 * closure) * s
        local len = 16 * s
        local ba = A(215)
        draw.line(cx - d, cy - d, cx - d + len, cy - d, ac_r, ac_g, ac_b, ba, 1.8)
        draw.line(cx - d, cy - d, cx - d, cy - d + len, ac_r, ac_g, ac_b, ba, 1.8)
        draw.line(cx + d - len, cy - d, cx + d, cy - d, ac_r, ac_g, ac_b, ba, 1.8)
        draw.line(cx + d, cy - d, cx + d, cy - d + len, ac_r, ac_g, ac_b, ba, 1.8)
        draw.line(cx - d, cy + d - len, cx - d, cy + d, ac_r, ac_g, ac_b, ba, 1.8)
        draw.line(cx - d, cy + d, cx - d + len, cy + d, ac_r, ac_g, ac_b, ba, 1.8)
        draw.line(cx + d, cy + d - len, cx + d, cy + d, ac_r, ac_g, ac_b, ba, 1.8)
        draw.line(cx + d - len, cy + d, cx + d, cy + d, ac_r, ac_g, ac_b, ba, 1.8)

        -- range-closure ring + pipper
        arc(cx, cy, 30 * s, -PI, -PI + PI * 2 * closure, ac_r, ac_g, ac_b, A(200), 2.0)
        draw.circle_outline(cx, cy, 30 * s, DIM_R, DIM_G, DIM_B, A(150), 1.0)
        draw.circle_outline(cx, cy, 4 * s, WHT_R, WHT_G, WHT_B, A(235), 1.2)
        draw.line(cx - 20 * s, cy, cx - 9 * s, cy, ac_r, ac_g, ac_b, A(200), 1.3)
        draw.line(cx + 9 * s, cy, cx + 20 * s, cy, ac_r, ac_g, ac_b, A(200), 1.3)
        draw.line(cx, cy - 20 * s, cx, cy - 9 * s, ac_r, ac_g, ac_b, A(200), 1.3)
        draw.line(cx, cy + 9 * s, cx, cy + 20 * s, ac_r, ac_g, ac_b, A(200), 1.3)
    else
        -- Detonation: rings blowing outward from the pipper.
        for i = 0, 2 do
            local t = ((now * 1.6 + i * 0.33) % 1)
            draw.circle_outline(cx, cy, t * 260 * s, RED_R, RED_G, RED_B, A(200 * (1 - t)), 2.4)
        end
        centre_spaced(font.title, cx, cy - text.height(font.title) * 0.5, 8 * s,
                      RED_R, RED_G, RED_B, A(250 * (0.7 + 0.3 * sin(now * 12))), "DETONATION")
    end

    ------------------------------------------------------------------ propellant + throttle (left)
    local col_h = 250 * s
    local col_bot = cy + col_h * 0.5
    local col_x = m + 16 * s
    local low = sm_fuel < 0.2
    column(col_x, col_bot, 16 * s, col_h, 20, sm_fuel,
           low and RED_R or ac_r, low and RED_G or ac_g, low and RED_B or ac_b, A(255))
    column(col_x + 24 * s, col_bot, 7 * s, col_h, 20, sm_thr, WHT_R, WHT_G, WHT_B, A(200))
    centre_spaced(font.tiny, col_x + 16 * s, col_bot + 10 * s, 2 * s, ac_r, ac_g, ac_b, A(185), "FUEL / THR")
    right_text(font.small, col_x + 34 * s, col_bot - col_h - 18 * s,
               low and RED_R or ac_r, low and RED_G or ac_g, low and RED_B or ac_b, A(230),
               string.format("%d%%", floor(sm_fuel * 100 + 0.5)))

    ------------------------------------------------------------------ altitude ladder (right)
    ladder(sw - m - 26 * s, cy, 200 * s, max(0, sm_alt), 100, s, ac_r, ac_g, ac_b, A(190))
    centre_spaced(font.tiny, sw - m - 26 * s, cy - 200 * s - 20 * s, 3 * s, ac_r, ac_g, ac_b, A(185), "ALT M")

    ------------------------------------------------------------------ range readout (bottom centre)
    local rng = string.format("%d", floor(sm_dist + 0.5))
    local rh = text.height(font.title)
    local ry = sh - m - 124 * s
    centre_spaced(font.tiny, cx, ry - 13 * s, 4 * s, ac_r, ac_g, ac_b, A(195), "RANGE TO TARGET")
    text.draw_centered(font.title, cx - 200 * s, ry, cx + 200 * s, WHT_R, WHT_G, WHT_B, A(250), rng)
    text.draw(font.small, cx + text.width(font.title, rng) * 0.5 + 8 * s, ry + rh - text.height(font.small) - 6 * s,
              ac_r, ac_g, ac_b, A(215), "M")

    -- closure bar under the range number
    local cbw = 260 * s
    local closure = 1 - min(1, sm_dist / 2000)
    draw.rect(cx - cbw * 0.5, ry + rh + 2 * s, cx + cbw * 0.5, ry + rh + 6 * s, DIM_R, DIM_G, DIM_B, A(170), 0)
    draw.rect(cx - cbw * 0.5, ry + rh + 2 * s, cx - cbw * 0.5 + cbw * closure, ry + rh + 6 * s,
              ac_r, ac_g, ac_b, A(240), 0)

    text.draw_centered(font.small, cx - 200 * s, ry + rh + 14 * s, cx + 200 * s, 180, 198, 186, A(215),
                       string.format("SPD %d M/S        ALT %d M", floor(sm_speed + 0.5), floor(max(0, sm_alt) + 0.5)))

    ------------------------------------------------------------------ controls
    if not impact then
        centre_spaced(font.tiny, cx, sh - m - 12 * s, 2 * s, 175, 195, 183, A(180),
                      "WASD STEER    SHIFT BOOST    CTRL BRAKE    ATTACK DETONATE")
    end
end)
