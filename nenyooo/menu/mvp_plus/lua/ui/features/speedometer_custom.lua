-- Custom Speedometer. C++ (veh_speedo::draw) publishes telemetry only; this file owns the visual.
--   speed / max_speed (display units), metric, rpm 0..1, gear (-1 R, 0 N), gears, throttle / brake 0..1,
--   handbrake, burnout, drifting, slip_angle (deg, + = tail out right), drivetrain (1 RWD, 2 FWD, 3 AWD),
--   engine_health / body_health / tank_health 0..1, veh_name (omitted when unknown),
--   design (index into DESIGNS -- order must match veh_speedo::m_designs),
--   show_flags / show_rpm / show_engine / show_telemetry.
-- While the menu is open the gauge can be dragged anywhere and resized from its corner grip. Placement
-- persists in speedo_hud_x / speedo_hud_y (centre, 0..1 of the screen) and speedo_hud_scale; the
-- menu's Reset Position clears all three.
-- Every design is laid out in 1080p reference pixels and drawn through one draw.with_scale, so it
-- scales as a whole; big numerals use font.display (fixed size) scaled to an exact pixel height.

local sin, cos, pi, abs = math.sin, math.cos, math.pi, math.abs
local floor, min, max = math.floor, math.min, math.max

local START, SWEEP = pi * 0.75, pi * 1.5
local REDLINE = 0.86
local SCALE_LO, SCALE_HI = 0.6, 1.8
local GRIP = 16

local INK    = { 242, 244, 248 }
local DIM    = { 112, 119, 133 }
local BG     = { 9, 11, 15 }
local BLACK  = { 0, 0, 0 }
local TRACK  = { 36, 40, 50 }
local BEZEL  = { 15, 17, 22 }
local FACE   = { 8, 10, 14 }
local HUB    = { 24, 27, 33 }
local RED    = { 255, 58, 46 }
local AMB    = { 255, 168, 36 }
local GRN    = { 64, 226, 120 }
local HOTTIP = { 255, 214, 120 }
local ACC    = { 170, 90, 255 }
local FIRE   = { 255, 180, 35 }
local EMBER  = { 235, 45, 8 }
local CORE   = { 255, 205, 55 }
local SOOT   = { 12, 8, 7 }
local BLAZE  = { 255, 74, 12 }
local SMOKE  = { 15, 19, 25 }
local COLD   = { 48, 53, 61 }
local SPIKE  = { 255, 72, 16 }
local ORANGE = { 255, 132, 28 }
local REDBED = { 90, 30, 30 }
local BIG    = font.display or font.title

-- Font metrics: em = the slot's size in px, base = top-of-box to baseline (both from the engine when
-- available, so placement does not depend on the face's line spacing).
local function em_of(f) return (text.em and text.em(f)) or text.height(f) end
local function base_of(f) return (text.baseline and text.baseline(f)) or em_of(f) * 0.97 end

local S = { speed = 0, ratio = 0, rpm = 0, thr = 0, brk = 0, slip = 0, fade = 0, pop = 0, top = 160, step = 20 }
local last_gear, was_active = nil, false
local last_t = ctx.time and ctx.time() or 0
local own, drag_dx, drag_dy = nil, 0, 0
local hold_x, hold_y, rz_mx, rz_my, rz_base, rz_s = 0, 0, 0, 0, 1, 1
local FA = 1

-- ---------------------------------------------------------------- helpers

local function clamp(v, lo, hi) if v < lo then return lo elseif v > hi then return hi end return v end
local function approach(cur, target, rate, dt) return cur + (target - cur) * min(1, rate * dt) end
local function inside(px, py, x, y, w, h) return px >= x and py >= y and px <= x + w and py <= y + h end
local function pol(cx, cy, r, a) return cx + cos(a) * r, cy + sin(a) * r end
local function A(a) return floor(clamp(a, 0, 255) * FA) end

local function get_num(k)
    local v = menu.get_setting(k)
    if v == nil or v == "" then return nil end
    return tonumber(v)
end
local function set_num(k, v) menu.set_setting(k, tostring(floor(v * 10000 + 0.5) / 10000)) end

local function rect(x1, y1, x2, y2, c, a, r) draw.rect(x1, y1, x2, y2, c[1], c[2], c[3], A(a), r or 0) end
local function frame(x1, y1, x2, y2, c, a, r, t) draw.rect_outline(x1, y1, x2, y2, c[1], c[2], c[3], A(a), r or 0, t or 1) end
local function line(x1, y1, x2, y2, c, a, t) draw.line(x1, y1, x2, y2, c[1], c[2], c[3], A(a), t or 1) end
local function disc(x, y, r, c, a) draw.circle(x, y, r, c[1], c[2], c[3], A(a)) end
local function ring(x, y, r, c, a, t) draw.circle_outline(x, y, r, c[1], c[2], c[3], A(a), t or 1) end

local function arc(cx, cy, r, a0, a1, c, a, t)
    local n = max(4, floor(abs(a1 - a0) * r / 5))
    local px, py = pol(cx, cy, r, a0)
    for i = 1, n do
        local x, y = pol(cx, cy, r, a0 + (a1 - a0) * i / n)
        line(px, py, x, y, c, a, t)
        px, py = x, y
    end
end

-- Progress arc coloured along its length (e.g. accent -> amber -> red for revs), not by its tip.
local function prog_arc(cx, cy, r, a0, sweep, v, colfn, a, t)
    local n = 36
    for i = 0, n - 1 do
        local t0 = i / n
        if t0 >= v then break end
        arc(cx, cy, r, a0 + sweep * t0, a0 + sweep * min(v, (i + 1) / n), colfn(t0), a, t)
    end
end

local function txt(fnt, x, y, s, c, a, align)
    local w = text.width(fnt, s)
    if align == "c" then x = x - w * 0.5 elseif align == "r" then x = x - w end
    text.draw(fnt, x, y, c[1], c[2], c[3], A(a or 255), s)
    return w
end

local function spaced(fnt, x, y, s, c, a, sp, align)
    local w = text.width_spaced(fnt, s, sp)
    if align == "c" then x = x - w * 0.5 elseif align == "r" then x = x - w end
    text.draw_spaced(fnt, x, y, c[1], c[2], c[3], A(a or 255), s, sp)
    return w
end

-- Byte-safe truncation: never cuts a localized vehicle name inside a UTF-8 sequence.
local function fit(fnt, s, w)
    if text.width(fnt, s) <= w then return s end
    local n = #s - 1
    while n > 1 do
        local b = s:byte(n + 1)
        if (b < 0x80 or b >= 0xC0) and text.width(fnt, s:sub(1, n) .. "..") <= w then break end
        n = n - 1
    end
    return s:sub(1, n) .. ".."
end

-- Big numerals at an exact pixel height with tabular (fixed-width) digits, so the readout never
-- jitters sideways as the number changes. `ghost` leading characters are drawn faint (LCD zeros).
-- Returns the drawn width in reference pixels. Laid out so the baseline sits at y + 0.97 * px.
local function big(x, y, px, s, c, a, align, ghost)
    local k = px / max(1, em_of(BIG))
    y = y + 0.97 * px - base_of(BIG) * k
    local cell = text.width(BIG, "0")
    local n = #s
    local w = cell * n
    local x0 = x
    if align == "c" then x0 = x - w * 0.5 elseif align == "r" then x0 = x - w end
    ghost = ghost or 0
    draw.with_scale(x, y, k, function()
        for i = 1, n do
            local ch = s:sub(i, i)
            local cx = x0 + (i - 1) * cell + (cell - text.width(BIG, ch)) * 0.5
            local ca = i <= ghost and a * 0.12 or a
            text.draw(BIG, cx, y, c[1], c[2], c[3], A(ca), ch)
        end
    end)
    return w * k
end

local function big_shadow(x, y, px, s, c, a, align, ghost)
    big(x + 2, y + 3, px, s, BLACK, a * 0.55, align, ghost)
    return big(x, y, px, s, c, a, align, ghost)
end

local function bar(x, y, w, h, v, c, a)
    rect(x, y, x + w, y + h, TRACK, 215, h * 0.5)
    v = clamp(v or 0, 0, 1)
    if v > 0.004 then rect(x, y, x + max(h, w * v), y + h, c, a or 245, h * 0.5) end
end

local function rpm_col(t)
    if t >= REDLINE then return RED elseif t >= 0.7 then return AMB end
    return ACC
end

local function fire(t)
    if t < 0.45 then FIRE[2] = floor(180 + t * 110); FIRE[3] = 35
    else FIRE[2] = floor(clamp(230 - (t - 0.45) * 300, 40, 255)); FIRE[3] = 20 end
    return FIRE
end

local function seg_bar(x, y, w, h, v, n, colfn, gap)
    gap = gap or 2
    local sw = (w - gap * (n - 1)) / n
    for i = 0, n - 1 do
        local t = (i + 0.5) / n
        local sx = x + i * (sw + gap)
        if t <= v then rect(sx, y, sx + sw, y + h, colfn(t), 245, 1)
        else rect(sx, y, sx + sw, y + h, TRACK, 200, 1) end
    end
end

local function gear_str(g)
    g = floor(g or 0)
    if g < 0 then return "R" elseif g == 0 then return "N" end
    return tostring(g)
end

local function unit_str(f) return f.metric and "KM/H" or "MPH" end
local function speed_str() return tostring(floor(S.speed + 0.5)) end
local function pad3(s) if #s >= 3 then return s, 0 end return string.rep("0", 3 - #s) .. s, 3 - #s end

local DT = { "RWD", "FWD", "AWD" }
local function dt_str(f) return DT[floor(f.drivetrain or 0)] end
local function slip_deg() return floor(abs(S.slip) + 0.5) end

local FLAG_NAMES = { "HBK", "BRK", "TCS", "DRIFT" }
local LAMP_W = { 0, 0, 0, 0 }
local function flag(f, i)
    if i == 1 then return f.handbrake, AMB
    elseif i == 2 then return S.brk > 0.15, RED
    elseif i == 3 then return f.burnout, AMB end
    return f.drifting, ACC
end

-- Indicator lamps: dim outline when off, filled when on. Returns width, height.
local function lamps(x, y, f, align)
    local fnt, gap = font.tiny, 5
    local ph = text.height(fnt) + 7
    local total = gap * 3
    for i = 1, 4 do LAMP_W[i] = text.width(fnt, FLAG_NAMES[i]) + 12; total = total + LAMP_W[i] end
    local cx = x
    if align == "c" then cx = x - total * 0.5 elseif align == "r" then cx = x - total end
    for i = 1, 4 do
        local on, c = flag(f, i)
        local w = LAMP_W[i]
        if on then
            rect(cx, y, cx + w, y + ph, c, 235, 3)
            txt(fnt, cx + w * 0.5, y + 3, FLAG_NAMES[i], BG, 255, "c")
        else
            frame(cx, y, cx + w, y + ph, DIM, 80, 3, 1)
            txt(fnt, cx + w * 0.5, y + 3, FLAG_NAMES[i], DIM, 140, "c")
        end
        cx = cx + w + gap
    end
    return total, ph
end

-- Dial furniture shared by the round designs: graduated ticks with numerals every major step.
local function ticks(cx, cy, r, top, step, lit_to, colfn, label_r, minors)
    minors = minors or 4
    local n = max(1, floor(top / step + 0.5)) * minors
    local lh = text.height(font.small)
    for i = 0, n do
        local t = i / n
        local ang = START + SWEEP * t
        local major = i % minors == 0
        local x0, y0 = pol(cx, cy, r, ang)
        local x1, y1 = pol(cx, cy, r - (major and 11 or 5), ang)
        local lit = t <= lit_to
        line(x0, y0, x1, y1, lit and colfn(t) or DIM, major and 240 or 140, major and 2 or 1)
        if major and label_r then
            local lx, ly = pol(cx, cy, label_r, ang)
            txt(font.small, lx, ly - lh * 0.6, tostring(floor(i / minors * step + 0.5)), lit and INK or DIM, 225, "c")
        end
    end
end

local function needle(cx, cy, len, ang, c)
    local nx, ny = pol(cx, cy, len, ang)
    local bx, by = pol(cx, cy, 16, ang + pi)
    line(bx + 2, by + 2, nx + 2, ny + 2, BLACK, 160, 5)
    line(bx, by, nx, ny, c, 255, 3.2)
    line(cx, cy, nx, ny, HOTTIP, 210, 1.1)
    disc(cx, cy, 10, HUB, 255)
    ring(cx, cy, 10, c, 255, 2)
    disc(cx, cy, 3.5, INK, 255)
end

local function gear_badge(cx, cy, r, f)
    local hot = S.rpm >= REDLINE
    local s = 1 + 0.25 * S.pop
    disc(cx, cy, r * s, HUB, 245)
    ring(cx, cy, r * s, hot and RED or ACC, 245, 1.8)
    local g = gear_str(f.gear)
    local px = r * 1.25
    big(cx, cy - px * 0.62, px, g, hot and RED or INK, 255, "c")
end

-- Dark rounded card with a soft drop shadow and a thin accent rule along the top.
local function card(x1, y1, x2, y2, r)
    rect(x1 + 3, y1 + 5, x2 + 3, y2 + 5, BLACK, 90, r)
    rect(x1, y1, x2, y2, BG, 222, r)
    frame(x1, y1, x2, y2, INK, 18, r, 1)
end

-- ---------------------------------------------------------------- designs

local function draw_flames(cx, cy, radius, heat, now)
    if heat < 0.025 then return end
    for i = 0, 29 do
        local t = i / 29
        local ang = START + SWEEP * t
        local wave = 0.55 + 0.45 * sin(now * (8 + (i % 5)) + i * 2.17)
        local flare = 0.35 + 0.65 * sin(pi * t)
        local len = 3 + 25 * heat * wave * flare
        local wob = sin(now * 11 + i * 1.63) * 0.045 * heat
        local bx, by = pol(cx, cy, radius + 3, ang)
        local mx, my = pol(cx, cy, radius + len * 0.56, ang + wob)
        local tx, ty = pol(cx, cy, radius + len, ang - wob * 0.45)
        local a = 85 + 150 * heat * wave
        line(bx, by, mx, my, EMBER, a, 4.8)
        line(mx, my, tx, ty, fire(t), a, 2.6)
        line(bx, by, mx, my, CORE, a * 0.72, 1.25)
    end
end

local function flame_dial(f, x, y, w, h, now)
    local cx, cy, R = x + w * 0.5, y + 146, 118
    local heat = clamp(max(S.rpm * 0.9, S.ratio), 0, 1)
    local pulse = 0.5 + 0.5 * sin(now * 5.5)

    draw_flames(cx, cy, R, heat, now)
    disc(cx + 4, cy + 7, R + 12, BLACK, 105)
    disc(cx, cy, R + 7, SOOT, 235)
    ring(cx, cy, R + 6, BLAZE, 125 + heat * 100 + pulse * 20, 2.2)
    disc(cx, cy, R - 2, FACE, 245)
    disc(cx, cy - 9, R - 17, SMOKE, 235)

    for i = 0, 71 do
        local t0 = i / 72
        local a0, a1 = START + SWEEP * t0, START + SWEEP * (i + 0.72) / 72
        if t0 <= S.ratio then arc(cx, cy, R - 12, a0, a1, fire(t0), 245, 4.2)
        else arc(cx, cy, R - 12, a0, a1, COLD, 210, 2.2) end
    end
    ticks(cx, cy, R - 21, S.top, S.step, S.ratio, fire, R - 46)
    if f.show_rpm then
        arc(cx, cy, R - 64, START, START + SWEEP, TRACK, 200, 3)
        prog_arc(cx, cy, R - 64, START, SWEEP, S.rpm, rpm_col, 245, 3)
    end
    needle(cx, cy, R - 36, START + SWEEP * S.ratio, SPIKE)

    big(cx, cy + 18, 40, speed_str(), INK, 255, "c")
    spaced(font.tiny, cx, cy + 61, unit_str(f), ORANGE, 245, 2, "c")
    gear_badge(cx, cy + 88, 14, f)
    if f.show_flags then
        local on1 = f.handbrake
        local on2 = S.brk > 0.15
        txt(font.tiny, cx - 26, cy + 83, "HBK", on1 and AMB or DIM, on1 and 255 or 110, "r")
        txt(font.tiny, cx + 26, cy + 83, "BRK", on2 and RED or DIM, on2 and 255 or 110)
    end
    if f.show_engine then
        local hp = clamp(f.engine_health or 0, 0, 1)
        bar(cx - 43, cy + 114, 86, 3, hp, hp < 0.35 and RED or AMB)
    end
end

local function tach_first(f, x, y, w, h, now)
    local cx, cy, R = x + w * 0.5, y + 190, 132
    local a0, a1 = pi * 1.08, pi * 1.92
    local span = a1 - a0
    card(x, y + 10, x + w, y + h, 14)

    -- Shift lights: fill from 70% to the redline, all flash red past it.
    local over = S.rpm >= REDLINE
    local blink = over and (sin(now * 30) > 0)
    for i = 0, 6 do
        local lx = cx + (i - 3) * 24
        local t = 0.70 + (REDLINE - 0.70) * i / 6
        local on = S.rpm >= t
        local c = i < 3 and GRN or (i < 5 and AMB or RED)
        if over then c = RED; on = blink end
        disc(lx, y + 30, 7, on and c or TRACK, on and 255 or 220)
        if on then disc(lx, y + 30, 11, c, 60) end
    end

    -- Tachometer band: 48 segments, redline zone tinted even when unlit.
    for i = 0, 47 do
        local t = (i + 0.5) / 48
        local ang = a0 + span * t
        local lit = t <= S.rpm
        local c = lit and rpm_col(t) or (t >= REDLINE and REDBED or TRACK)
        local x0, y0 = pol(cx, cy, R - 7, ang)
        local x1, y1 = pol(cx, cy, R + 7, ang)
        line(x0, y0, x1, y1, c, lit and 250 or 215, 4.2)
    end
    for k = 0, 8 do
        local ang = a0 + span * k / 8
        local lx, ly = pol(cx, cy, R - 24, ang)
        local lit = k / 8 <= S.rpm
        txt(font.small, lx, ly - text.height(font.small) * 0.6, tostring(k), lit and INK or DIM, 230, "c")
    end
    spaced(font.tiny, cx - 128, cy - 18, "x1000 RPM", DIM, 200, 1.5)

    local g = gear_str(f.gear)
    local gp = 64 * (1 + 0.18 * S.pop)
    big_shadow(cx, cy - 86 - (gp - 64) * 0.5, gp, g, over and RED or INK, 255, "c")

    big(cx - 6, cy - 2, 34, speed_str(), INK, 255, "r")
    spaced(font.tiny, cx + 2, cy + 18, unit_str(f), ACC, 240, 1.5)

    if f.show_flags then lamps(cx, y + h - 32, f, "c") end
    if f.show_engine then bar(x + 24, y + h - 9, w - 48, 3, f.engine_health, (f.engine_health or 0) < 0.35 and RED or GRN) end
end

local function card_size(f)
    local h = 122
    if f.show_rpm then h = h + 22 end
    h = h + 32
    if f.show_telemetry then h = h + 58 end
    if f.show_engine then h = h + 20 end
    if f.show_flags then h = h + 30 end
    return 300, h + 8
end

local function labeled_bar(x, y, w, label, v, c, value)
    txt(font.tiny, x, y, label, DIM, 230)
    if value then txt(font.tiny, x + w, y, value, INK, 230, "r") end
    bar(x, y + text.height(font.tiny) + 5, w, 4, v, c)
end

local function telemetry_card(f, x, y, w, h, now)
    card(x, y, x + w, y + h, 10)
    rect(x + 12, y, x + w - 12, y + 3, ACC, 255, 1.5)
    local px, iw = x + 16, w - 32

    local name = f.veh_name and fit(font.item, f.veh_name, iw - 60) or "VEHICLE"
    txt(font.item, px, y + 11, name, INK, 245)
    local dts = dt_str(f)
    if dts then
        local tw = text.width(font.tiny, dts) + 12
        frame(x + w - 16 - tw, y + 11, x + w - 16, y + 11 + text.height(font.tiny) + 7, ACC, 200, 3, 1)
        txt(font.tiny, x + w - 16 - tw * 0.5, y + 14, dts, ACC, 255, "c")
    end

    local cy = y + 36
    big(px - 2, cy, 58, speed_str(), INK, 255, "l")
    spaced(font.tiny, px, cy + 64, unit_str(f), DIM, 230, 2)
    local gx = x + w - 16 - 62
    rect(gx, cy + 4, gx + 62, cy + 66, HUB, 240, 8)
    frame(gx, cy + 4, gx + 62, cy + 66, S.rpm >= REDLINE and RED or ACC, 220, 8, 1.5)
    local gp = 42 * (1 + 0.15 * S.pop)
    big(gx + 31, cy + 35 - gp * 0.6, gp, gear_str(f.gear), S.rpm >= REDLINE and RED or INK, 255, "c")
    txt(font.tiny, gx + 31, cy + 70, "GEAR", DIM, 200, "c")
    local yy = cy + 86

    if f.show_rpm then
        seg_bar(px, yy, iw, 9, S.rpm, 24, rpm_col, 2)
        yy = yy + 22
    end

    local half = (iw - 16) * 0.5
    labeled_bar(px, yy, half, "THROTTLE", S.thr, GRN, string.format("%d%%", floor(S.thr * 100 + 0.5)))
    labeled_bar(px + half + 16, yy, half, "BRAKE", S.brk, RED, string.format("%d%%", floor(S.brk * 100 + 0.5)))
    yy = yy + 32

    if f.show_telemetry then
        txt(font.tiny, px, yy, "SLIP ANGLE", DIM, 230)
        txt(font.tiny, px + iw, yy, string.format("%d DEG", slip_deg()), f.drifting and ACC or INK, 240, "r")
        local sy = yy + text.height(font.tiny) + 6
        local mid = px + iw * 0.5
        rect(px, sy, px + iw, sy + 6, TRACK, 215, 3)
        local sx = mid + clamp(S.slip / 60, -1, 1) * iw * 0.5
        rect(min(mid, sx), sy, max(mid, sx), sy + 6, f.drifting and ACC or AMB, 240, 3)
        line(mid, sy - 3, mid, sy + 9, INK, 120, 1)
        yy = yy + 28
        labeled_bar(px, yy, half, "BODY", f.body_health, (f.body_health or 0) < 0.35 and RED or INK,
            string.format("%d%%", floor((f.body_health or 0) * 100 + 0.5)))
        labeled_bar(px + half + 16, yy, half, "FUEL TANK", f.tank_health, (f.tank_health or 0) < 0.35 and RED or INK,
            string.format("%d%%", floor((f.tank_health or 0) * 100 + 0.5)))
        yy = yy + 30
    end
    if f.show_engine then
        labeled_bar(px, yy, iw, "ENGINE", f.engine_health, (f.engine_health or 0) < 0.35 and RED or GRN,
            string.format("%d%%", floor((f.engine_health or 0) * 100 + 0.5)))
        yy = yy + 20
    end
    if f.show_flags then lamps(px, y + h - 30, f, "l") end
end

local function bare_numerals(f, x, y, w, h, now)
    local s = speed_str()
    local right = x + 160
    local hot = S.rpm >= REDLINE
    big_shadow(right, y, 72, s, INK, 255, "r")
    spaced(font.label, right + 8, y + 22, unit_str(f), hot and RED or ACC, 245, 2)
    local gp = 26 * (1 + 0.2 * S.pop)
    big_shadow(right + 8, y + 40, gp, gear_str(f.gear), hot and RED or INK, 230, "l")
    local ly = y + 82
    if f.show_rpm then
        rect(x + 10, ly + 1, right + 1, ly + 5, BLACK, 90, 2)
        bar(x + 9, ly, right - x - 9, 3, S.rpm, rpm_col(S.rpm))
        ly = ly + 10
    end
    if f.show_flags then
        local fx = right
        for i = 4, 1, -1 do
            local on, c = flag(f, i)
            if on then fx = fx - txt(font.tiny, fx, ly, FLAG_NAMES[i], c, 255, "r") - 8 end
        end
    end
end

local function native_rows(f)
    local n = 2
    if f.show_rpm then n = n + 1 end
    if f.show_engine then n = n + 1 end
    if f.show_telemetry then n = n + 1 end
    return n
end

local function native_size(f)
    local h = native_rows(f) * 37
    if f.show_flags then h = h + 30 end
    return 270, h
end

-- Same visual language as the game's own bottom-right timers: label on a dark band that fades in
-- from the left, value hard right.
local function native_row(x, y, w, label)
    draw.rect_gradient(x, y, x + w, y + 34, 0, 0, 0, A(20), 0, 0, 0, A(185), 0, 0, 0, A(185), 0, 0, 0, A(20))
    spaced(font.label, x + w * 0.30, y + 17 - text.height(font.label) * 0.6, label, INK, 230, 1)
end

local function panel_native(f, x, y, w, h, now)
    local yy = y
    if f.show_flags then
        lamps(x + w - 8, yy, f, "r")
        yy = yy + 30
    end
    native_row(x, yy, w, "SPEED")
    local uw = spaced(font.tiny, x + w - 10, yy + 15, unit_str(f), DIM, 230, 1, "r")
    big(x + w - 16 - uw, yy + 4, 25, speed_str(), INK, 255, "r")
    yy = yy + 37
    native_row(x, yy, w, "GEAR")
    big(x + w - 12, yy + 4, 25, gear_str(f.gear), S.rpm >= REDLINE and RED or INK, 255, "r")
    yy = yy + 37
    if f.show_rpm then
        native_row(x, yy, w, "RPM")
        bar(x + w * 0.55, yy + 15, w * 0.45 - 12, 5, S.rpm, rpm_col(S.rpm))
        yy = yy + 37
    end
    if f.show_engine then
        native_row(x, yy, w, "ENGINE")
        local hp = clamp(f.engine_health or 0, 0, 1)
        bar(x + w * 0.55, yy + 15, w * 0.45 - 12, 5, hp, hp < 0.35 and RED or GRN)
        yy = yy + 37
    end
    if f.show_telemetry then
        native_row(x, yy, w, "DRIFT")
        local s = string.format("%d DEG", slip_deg())
        if dt_str(f) then s = dt_str(f) .. "   " .. s end
        txt(font.value, x + w - 12, yy + 17 - text.height(font.value) * 0.6, s, f.drifting and ACC or INK, 245, "r")
    end
end

local function lower_third(f, x, y, w, h, now)
    local hot = S.rpm >= REDLINE
    rect(x + 3, y + 5, x + w + 3, y + h + 5, BLACK, 90, 4)
    rect(x, y, x + w, y + h, BG, 225, 4)
    rect(x, y, x + h, y + h, hot and RED or ACC, 245, 4)
    local gp = 46 * (1 + 0.15 * S.pop)
    big(x + h * 0.5, y + h * 0.5 - gp * 0.6, gp, gear_str(f.gear), BG, 255, "c")

    local s, ghost = pad3(speed_str())
    local sw = big(x + h + 18, y + 6, 50, s, INK, 255, "l", ghost)
    spaced(font.label, x + h + 26 + sw, y + 18, unit_str(f), ACC, 245, 2)
    if f.show_telemetry and dt_str(f) then
        txt(font.tiny, x + h + 26 + sw, y + 38, dt_str(f), DIM, 230)
    end

    local rx = x + w - 16
    line(x + 300, y + 12, x + 300, y + h - 12, INK, 30, 1)
    local name = f.veh_name and fit(font.item, f.veh_name, rx - x - 452) or ""
    if name ~= "" then txt(font.item, rx, y + 10, name, INK, 245, "r") end
    if f.show_telemetry then
        local s2 = string.format("SLIP %d DEG", slip_deg())
        txt(font.tiny, rx, y + 32, s2, f.drifting and ACC or DIM, 235, "r")
    end
    if f.show_flags then lamps(rx, y + h - 24, f, "r") end
    local mx0, mw = x + 316, 116
    local rows = f.show_engine and 3 or 2
    local ry = y + (h - rows * 20) * 0.5
    local function mini(label, v, c)
        txt(font.tiny, mx0, ry, label, DIM, 220)
        bar(mx0 + 46, ry + 4, mw - 46, 4, v, c)
        ry = ry + 20
    end
    mini("THR", S.thr, GRN)
    mini("BRK", S.brk, RED)
    if f.show_engine then mini("ENG", f.engine_health, (f.engine_health or 0) < 0.35 and RED or GRN) end

    if f.show_rpm then
        rect(x, y + h - 3, x + w, y + h, TRACK, 230, 0)
        if S.rpm > 0.004 then rect(x, y + h - 3, x + w * S.rpm, y + h, rpm_col(S.rpm), 255, 0) end
        local rl = x + w * REDLINE
        rect(rl, y + h - 6, rl + 2, y + h, RED, 200, 0)
    end
end

local function round_gauge(cx, cy, R, ratio, top, step, colfn, redzone, show_arc)
    disc(cx + 3, cy + 6, R + 9, BLACK, 110)
    disc(cx, cy, R + 6, BEZEL, 245)
    ring(cx, cy, R + 6, ACC, 140, 1.5)
    disc(cx, cy, R, FACE, 245)
    if redzone then arc(cx, cy, R - 8, START + SWEEP * redzone, START + SWEEP, RED, 190, 5) end
    if show_arc then prog_arc(cx, cy, R - 2, START, SWEEP, ratio, colfn, 230, 2.5) end
    ticks(cx, cy, R - 4, top, step, ratio, colfn, R - 30)
    needle(cx, cy, R - 18, START + SWEEP * ratio, colfn(ratio))
end

local function acc_col() return ACC end
local function health_col(t) return t < 0.35 and RED or GRN end

local function twin_cluster(f, x, y, w, h, now)
    local R = 104
    local lx, rx, cy = x + R + 10, x + w - R - 10, y + R + 14
    round_gauge(lx, cy, R, S.ratio, S.top, S.step, acc_col, nil, true)
    big(lx, cy + 26, 30, speed_str(), INK, 255, "c")
    spaced(font.tiny, lx, cy + 60, unit_str(f), ACC, 240, 1.5, "c")

    if f.show_rpm then
        round_gauge(rx, cy, R, S.rpm, 8, 1, rpm_col, REDLINE, true)
        spaced(font.tiny, rx, cy + 60, "RPM x1000", DIM, 220, 1.5, "c")
    else
        round_gauge(rx, cy, R, clamp(f.engine_health or 0, 0, 1), 100, 25, health_col, nil, true)
        spaced(font.tiny, rx, cy + 60, "ENGINE %", DIM, 220, 1.5, "c")
    end

    local mx = x + w * 0.5
    gear_badge(mx, cy - 6, 24, f)
    if f.show_flags then
        for i = 1, 4 do
            local on, c = flag(f, i)
            txt(font.tiny, mx, cy + 34 + (i - 1) * 14, FLAG_NAMES[i], on and c or DIM, on and 255 or 100, "c")
        end
    end
    if f.show_telemetry and dt_str(f) then txt(font.tiny, mx, y + 8, dt_str(f), DIM, 230, "c") end
    if f.show_engine and f.show_rpm then
        bar(mx - 30, y + h - 10, 60, 3, f.engine_health, (f.engine_health or 0) < 0.35 and RED or GRN)
    end
end

local function drift_hud(f, x, y, w, h, now)
    local cx, cy, R = x + w * 0.5, y + 190, 150
    local drifting = f.drifting
    local slip = clamp(S.slip, -90, 90)

    -- Track, the sweet-spot bands either side and the live trail from centre to the marker.
    arc(cx, cy, R, pi, 2 * pi, TRACK, 220, 7)
    arc(cx, cy, R, pi * 1.5 + pi * 0.5 * 15 / 90, pi * 1.5 + pi * 0.5 * 45 / 90, GRN, 90, 7)
    arc(cx, cy, R, pi * 1.5 - pi * 0.5 * 45 / 90, pi * 1.5 - pi * 0.5 * 15 / 90, GRN, 90, 7)
    for k = -90, 90, 15 do
        local ang = pi * 1.5 + pi * 0.5 * k / 90
        local x0, y0 = pol(cx, cy, R + 8, ang)
        local x1, y1 = pol(cx, cy, R + (k % 45 == 0 and 16 or 12), ang)
        line(x0, y0, x1, y1, k == 0 and INK or DIM, k % 45 == 0 and 230 or 140, k % 45 == 0 and 2 or 1)
    end
    local ang = pi * 1.5 + pi * 0.5 * slip / 90
    local c = drifting and ACC or AMB
    if abs(slip) > 0.5 then arc(cx, cy, R, pi * 1.5, ang, c, 245, 7) end
    local x0, y0 = pol(cx, cy, R - 14, ang)
    local x1, y1 = pol(cx, cy, R + 14, ang)
    line(x0, y0, x1, y1, c, 90, 9)
    line(x0, y0, x1, y1, INK, 255, 3)

    if drifting then
        local p = 0.6 + 0.4 * sin(now * 9)
        spaced(font.label, cx, y + 2, "DRIFTING", ACC, 255 * p, 3, "c")
    end
    big_shadow(cx, cy - 116, 54, tostring(floor(abs(slip) + 0.5)), drifting and ACC or INK, 255, "c")
    spaced(font.tiny, cx, cy - 52, "DRIFT ANGLE", DIM, 230, 2, "c")

    local by = cy - 30
    big(cx - 16, by, 30, speed_str(), INK, 255, "r")
    spaced(font.tiny, cx - 16, by + 34, unit_str(f), DIM, 220, 1.5, "r")
    local hot = S.rpm >= REDLINE
    big(cx + 16, by, 30 * (1 + 0.2 * S.pop), gear_str(f.gear), hot and RED or INK, 255, "l")
    spaced(font.tiny, cx + 16, by + 34, "GEAR", DIM, 220, 1.5)

    local pw = 70
    bar(cx - R + 6, cy - 6, pw, 4, S.thr, GRN)
    txt(font.tiny, cx - R + 6, cy + 2, "THR", DIM, 220)
    bar(cx + R - 6 - pw, cy - 6, pw, 4, S.brk, RED)
    txt(font.tiny, cx + R - 6, cy + 2, "BRK", DIM, 220, "r")
    if f.show_rpm then
        local ry = cy + 20
        seg_bar(cx - 100, ry, 200, 6, S.rpm, 20, rpm_col, 2)
    end
    if f.show_flags then lamps(cx, y + h - 22, f, "c") end
end

-- home(sw, sh, pw, ph, base) -> default top-left in screen pixels
local function home_br(sw, sh, pw, ph, b) return sw - pw - 36 * b, sh - ph - 36 * b end
local function home_bc(sw, sh, pw, ph, b) return (sw - pw) * 0.5, sh - ph - 28 * b end
local function home_rc(sw, sh, pw, ph, b) return sw - pw - 36 * b, sh * 0.5 end
local function fixed(w, h) return function() return w, h end end

-- Order is an API: it must match veh_speedo::m_designs (the menu stores an index).
local DESIGNS = {
    { size = fixed(300, 294),            draw = flame_dial,     home = home_br },  -- Flame Dial
    { size = fixed(320, 268),            draw = tach_first,     home = home_br },  -- Tach First
    { size = card_size,                  draw = telemetry_card, home = home_rc },  -- Telemetry Card
    { size = fixed(240, 112),            draw = bare_numerals,  home = home_br },  -- Bare Numerals
    { size = native_size,                draw = panel_native,   home = home_br },  -- Panel Native
    { size = fixed(620, 74),             draw = lower_third,    home = home_bc },  -- Lower Third
    { size = fixed(540, 244),            draw = twin_cluster,   home = home_br },  -- Twin Cluster
    { size = fixed(380, 250),            draw = drift_hud,      home = home_bc },  -- Drift HUD
}

-- ---------------------------------------------------------------- frame

features.on_draw("Custom Speedometer", function(f)
    if not f.enabled or not f.active then
        was_active, own = false, nil
        return
    end

    local now = ctx.time and ctx.time() or 0
    local dt = clamp(now - last_t, 0.001, 0.1)
    last_t = now
    if not was_active then
        S.speed, S.ratio, S.rpm, S.thr, S.brk, S.slip, S.fade, S.pop = 0, 0, 0, 0, 0, 0, 0, 0
        last_gear = nil
    end
    was_active = true

    local ar, ag, ab = theme.accent()
    ACC[1], ACC[2], ACC[3] = ar or 170, ag or 90, ab or 255

    local maxv = max(1, f.max_speed or 1)
    local want = max(60, maxv * 1.05)
    S.top, S.step = nil, nil
    for _, st in ipairs({ 10, 20, 25, 40, 50, 60, 80, 100 }) do
        local n = math.ceil(want / st)
        if n <= 8 then S.top, S.step = n * st, st; break end
    end
    if not S.top then S.top, S.step = math.ceil(want / 100) * 100, 100 end

    local speed = max(0, f.speed or 0)
    S.speed = approach(S.speed, speed, 12, dt)
    S.ratio = approach(S.ratio, clamp(speed / S.top, 0, 1), 8.5, dt)
    S.rpm   = approach(S.rpm, clamp(f.rpm or 0, 0, 1), 10, dt)
    S.thr   = approach(S.thr, clamp(f.throttle or 0, 0, 1), 14, dt)
    S.brk   = approach(S.brk, clamp(f.brake or 0, 0, 1), 14, dt)
    S.slip  = approach(S.slip, f.slip_angle or 0, 9, dt)
    S.fade  = approach(S.fade, 1, 6, dt)
    local g = floor(f.gear or 0)
    if last_gear and g ~= last_gear then S.pop = 1 end
    last_gear = g
    S.pop = max(0, S.pop - dt * 4)

    local d = DESIGNS[floor(f.design or 0) + 1] or DESIGNS[1]
    local w, h = d.size(f)
    local sw, sh = ctx.screen_w(), ctx.screen_h()
    local base = clamp(sh / 1080, 0.6, 2.0)

    local user = clamp(get_num("speedo_hud_scale") or 1, SCALE_LO, SCALE_HI)
    if own == "resize" then user = rz_s end
    local u = clamp(base * user, 0.5, 2.0)
    local pw, ph = w * u, h * u

    local px, py
    local fx, fy = get_num("speedo_hud_x"), get_num("speedo_hud_y")
    if own then px, py = hold_x, hold_y
    elseif fx and fy then px, py = fx * sw - pw * 0.5, fy * sh - ph * 0.5
    else px, py = d.home(sw, sh, pw, ph, base) end

    -- Drag anywhere on the gauge, resize from the bottom-right grip; only while the menu has the cursor.
    local live = menu.is_visible() and not menu.overlay_active()
    local mx, my = input.mouse_x(), input.mouse_y()
    local gs = GRIP * base
    if live and own == nil and input.mouse_clicked(0) then
        if inside(mx, my, px + pw - gs, py + ph - gs, gs, gs) then
            own, rz_mx, rz_my, rz_base, rz_s = "resize", mx, my, user, user
            hold_x, hold_y = px, py
        elseif inside(mx, my, px, py, pw, ph) then
            own, drag_dx, drag_dy = "drag", mx - px, my - py
            hold_x, hold_y = px, py
        end
    end
    if own == "drag" then
        if live and input.mouse_down(0) then
            hold_x, hold_y = mx - drag_dx, my - drag_dy
            px, py = hold_x, hold_y
        else
            own = nil
            set_num("speedo_hud_x", (px + pw * 0.5) / sw)
            set_num("speedo_hud_y", (py + ph * 0.5) / sh)
        end
    elseif own == "resize" then
        if live and input.mouse_down(0) then
            rz_s = clamp(rz_base + ((mx - rz_mx) + (my - rz_my)) * 0.5 / 220, SCALE_LO, SCALE_HI)
            u = clamp(base * rz_s, 0.5, 2.0)
            pw, ph = w * u, h * u
            px, py = hold_x, hold_y
        else
            own = nil
            set_num("speedo_hud_scale", rz_s)
            set_num("speedo_hud_x", (px + pw * 0.5) / sw)
            set_num("speedo_hud_y", (py + ph * 0.5) / sh)
        end
    end
    px = clamp(px, 0, max(0, sw - pw))
    py = clamp(py, 0, max(0, sh - ph))

    FA = S.fade
    local ok, err = draw.with_scale(px, py, u, function() d.draw(f, px, py, w, h, now) end)
    FA = 1
    if ok == false then error(err, 0) end

    if live and (own or inside(mx, my, px, py, pw, ph)) then
        frame(px - 5, py - 5, px + pw + 5, py + ph + 5, ACC, own and 200 or 120, 6, 1)
        local gx, gy = px + pw, py + ph
        for i = 1, 3 do
            local o = i * 4 * base
            line(gx - o, gy, gx, gy - o, ACC, 220, 1.5)
        end
    end
end)
