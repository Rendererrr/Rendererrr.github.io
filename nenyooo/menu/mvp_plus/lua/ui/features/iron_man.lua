-- J.A.R.V.I.S. helmet HUD for the Iron Man feature.
--
-- Published by world_iron_man::draw: active, flying, aiming, locked, overheated, ultimate_ready,
-- controls, state, target_type, projectiles, locks, weapon (name), weapon_index, and the normalised
-- 0..1 gauges energy / shield / heat / charge / ultimate_cooldown plus speed (m/s), altitude (m)
-- and target_distance (m).
--
-- Layout is a visor rather than a panel: arc reactor bottom-left, flight telemetry bottom-right,
-- targeting reticle dead centre, status crown up top, ultimate + control hints along the bottom.

local PI = math.pi
local sin, cos, min, max, floor, abs = math.sin, math.cos, math.min, math.max, math.floor, math.abs

local CY_R,   CY_G,   CY_B   = 116, 226, 255   -- holographic cyan (primary)
local BLU_R,  BLU_G,  BLU_B  = 118, 168, 255   -- shield
local DIM_R,  DIM_G,  DIM_B  =  30,  96, 126   -- unlit track
local GOLD_R, GOLD_G, GOLD_B = 255, 186,  68   -- heat / gold accents
local RED_R,  RED_G,  RED_B  = 255,  76,  58   -- lock / alert
local HOT_R,  HOT_G,  HOT_B  = 232, 250, 255   -- reactor core white

local STATES = { [0] = "OFFLINE", [1] = "SUIT ONLINE", [2] = "TAKEOFF", [3] = "FLIGHT", [4] = "LANDING", [5] = "GROUND SLAM" }
local TARGETS = { [0] = "POSITION", [1] = "HOSTILE", [2] = "VEHICLE", [3] = "OBJECT" }

-- persistent across frames: boot animation + gauge smoothing
local boot_at, was_active = -1, false
local sm_energy, sm_shield, sm_heat = 0, 0, 0
local sm_speed, sm_alt, sm_dist = 0, 0, 0
local sm_aim, sm_lock, sm_fly = 0, 0, 0

-- Global boot fade, applied to every alpha through A(). Kept at chunk scope so the draw
-- callback does not build a closure per frame on the render thread.
local g_fade = 1
local function A(v) return floor(v * g_fade) end

local function approach(cur, target, rate, dt)
    return cur + (target - cur) * min(1, rate * dt)
end

-- Polyline arc. Angle 0 points up, positive sweeps clockwise.
local function arc(cx, cy, rad, a0, a1, r, g, b, a, th)
    if a <= 0 or a1 <= a0 then return end
    local steps = max(2, math.ceil((a1 - a0) / 0.09))
    local d = (a1 - a0) / steps
    local px, py = cx + sin(a0) * rad, cy - cos(a0) * rad
    for i = 1, steps do
        local t = a0 + d * i
        local nx, ny = cx + sin(t) * rad, cy - cos(t) * rad
        draw.line(px, py, nx, ny, r, g, b, a, th)
        px, py = nx, ny
    end
end

local function dashed_ring(cx, cy, rad, dashes, phase, fill, r, g, b, a, th)
    local step = PI * 2 / dashes
    for i = 0, dashes - 1 do
        local a0 = phase + i * step
        arc(cx, cy, rad, a0, a0 + step * fill, r, g, b, a, th)
    end
end

local function tick_ring(cx, cy, r_in, r_out, count, phase, r, g, b, a, th)
    for i = 0, count - 1 do
        local t = phase + (i / count) * PI * 2
        local major = (i % 5) == 0
        local ri = major and (r_in - (r_out - r_in) * 0.9) or r_in
        draw.line(cx + sin(t) * ri, cy - cos(t) * ri, cx + sin(t) * r_out, cy - cos(t) * r_out,
            r, g, b, major and a or floor(a * 0.5), th)
    end
end

-- Four L brackets on the corners of a box -- the recurring frame motif.
local function frame_corners(x1, y1, x2, y2, len, r, g, b, a, th)
    draw.line(x1, y1, x1 + len, y1, r, g, b, a, th)
    draw.line(x1, y1, x1, y1 + len, r, g, b, a, th)
    draw.line(x2 - len, y1, x2, y1, r, g, b, a, th)
    draw.line(x2, y1, x2, y1 + len, r, g, b, a, th)
    draw.line(x1, y2 - len, x1, y2, r, g, b, a, th)
    draw.line(x1, y2, x1 + len, y2, r, g, b, a, th)
    draw.line(x2, y2 - len, x2, y2, r, g, b, a, th)
    draw.line(x2 - len, y2, x2, y2, r, g, b, a, th)
end

local function seg_bar(x, y, w, h, segs, value, r, g, b, a)
    local gap = max(1.0, w * 0.006)
    local bw = (w - gap * (segs - 1)) / segs
    local lit = max(0, min(1, value)) * segs
    for i = 0, segs - 1 do
        local bx = x + i * (bw + gap)
        local fill = min(1, max(0, lit - i))
        if fill > 0 then
            draw.rect(bx, y, bx + bw, y + h, r, g, b, floor(a * (0.4 + 0.6 * fill)), 1)
        else
            draw.rect(bx, y, bx + bw, y + h, DIM_R, DIM_G, DIM_B, floor(a * 0.32), 1)
        end
    end
end

local function right_text(fnt, x2, y, r, g, b, a, str)
    text.draw(fnt, x2 - text.width(fnt, str), y, r, g, b, a, str)
end

-- Aviation-style vertical tape. Ticks scroll past a fixed caret at cy; dir picks which
-- side the ticks and labels hang off (1 = right, -1 = left).
local function tape(x, cy, half, value, step, dir, s, r, g, b, a)
    local per = half / 5.5
    local base = floor(value / step)
    draw.line(x, cy - half, x, cy + half, r, g, b, floor(a * 0.4), 1.2)
    for i = -6, 6 do
        local v = (base + i) * step
        local ty = cy + (value - v) / step * per
        if v >= 0 and ty >= cy - half and ty <= cy + half then
            local major = (i + base) % 5 == 0
            local len = (major and 13 or 6) * s
            local ta = floor(a * (0.4 + 0.6 * (1 - abs(ty - cy) / half)))
            draw.line(x, ty, x + dir * len, ty, r, g, b, major and ta or floor(ta * 0.7), major and 1.5 or 1.1)
            if major then
                local lbl = string.format("%d", v)
                local lw = text.width(font.tiny, lbl)
                text.draw(font.tiny, dir > 0 and (x + len + 5 * s) or (x - len - 5 * s - lw),
                    ty - text.height(font.tiny) * 0.5, r, g, b, floor(ta * 0.85), lbl)
            end
        end
    end
    draw.line(x, cy, x + dir * 20 * s, cy - 6 * s, r, g, b, a, 1.7)
    draw.line(x, cy, x + dir * 20 * s, cy + 6 * s, r, g, b, a, 1.7)
    draw.line(x + dir * 20 * s, cy - 6 * s, x + dir * 20 * s, cy + 6 * s, r, g, b, floor(a * 0.6), 1.2)
end

local function centre_spaced(fnt, cx, y, sp, r, g, b, a, str)
    text.draw_spaced(fnt, cx - text.width_spaced(fnt, str, sp) * 0.5, y, r, g, b, a, str, sp)
end

-- One gauge row beside the reactor: colour cap, label, right-aligned percentage.
local function legend_row(x, y, w, s, label, value, r, g, b)
    draw.rect(x, y + 3 * s, x + 3 * s, y + 12 * s, r, g, b, A(255), 0)
    text.draw_spaced(font.small, x + 9 * s, y, 168, 196, 210, A(215), label, 2 * s)
    right_text(font.small, x + w, y, r, g, b, A(245), string.format("%d%%", floor(value * 100 + 0.5)))
end

features.on_draw("Iron Man", function(f)
    local now = ctx.time()
    if f.active and not was_active then boot_at = now end
    was_active = f.active and true or false
    if not f.active then return end

    local dt = min(0.1, max(0.001, ctx.delta()))
    local boot = boot_at < 0 and 1 or min(1, (now - boot_at) / 0.85)
    local ease = 1 - (1 - boot) * (1 - boot) * (1 - boot)
    local fade = ease

    local sw, sh = ctx.screen_w(), ctx.screen_h()
    local s = max(0.72, min(1.7, sh / 1080))
    local m = 34 * s
    local cx0, cy0 = sw * 0.5, sh * 0.5
    local hot = f.overheated and true or false

    -- gauges are lerped so the rings glide instead of snapping every tick
    sm_energy = approach(sm_energy, f.energy or 0, 9, dt)
    sm_shield = approach(sm_shield, f.shield or 0, 9, dt)
    sm_heat   = approach(sm_heat,   f.heat   or 0, 9, dt)
    sm_speed  = approach(sm_speed,  f.speed  or 0, 7, dt)
    sm_alt    = approach(sm_alt,    f.altitude or 0, 7, dt)
    sm_dist   = approach(sm_dist,   f.target_distance or 0, 12, dt)
    sm_aim    = approach(sm_aim,    (f.aiming or f.locked) and 1 or 0, 12, dt)
    sm_lock   = approach(sm_lock,   f.locked and 1 or 0, 16, dt)
    sm_fly    = approach(sm_fly,    (f.flying or (f.state or 0) >= 2) and 1 or 0, 5, dt)

    -- accent shifts amber->red as the suit cooks
    local ac_r = hot and RED_R or CY_R
    local ac_g = hot and RED_G or CY_G
    local ac_b = hot and RED_B or CY_B
    g_fade = fade

    ------------------------------------------------------------------ visor
    draw.rect_gradient(0, 0, sw, 74 * s,
        ac_r, ac_g, ac_b, A(hot and 34 or 24), ac_r, ac_g, ac_b, A(hot and 34 or 24),
        ac_r, ac_g, ac_b, 0, ac_r, ac_g, ac_b, 0)
    draw.rect_gradient(0, sh - 74 * s, sw, sh,
        ac_r, ac_g, ac_b, 0, ac_r, ac_g, ac_b, 0,
        ac_r, ac_g, ac_b, A(hot and 30 or 20), ac_r, ac_g, ac_b, A(hot and 30 or 20))
    frame_corners(m * 0.55, m * 0.55, sw - m * 0.55, sh - m * 0.55, 46 * s, ac_r, ac_g, ac_b, A(105), 1.5)

    if boot < 1 then
        local sy = sh * boot
        draw.rect(0, sy - 2 * s, sw, sy + 2 * s, HOT_R, HOT_G, HOT_B, floor(150 * (1 - boot)), 0)
    end

    ------------------------------------------------------------------ status crown
    local title = "J.A.R.V.I.S."
    local tsp = 7 * s
    local tw = text.width_spaced(font.title, title, tsp)
    local tth = text.height(font.title)
    local ty = m - 6 * s
    text.draw_spaced(font.title, cx0 - tw * 0.5, ty, ac_r, ac_g, ac_b, A(245), title, tsp)
    for i = 1, 3 do
        local off = 30 * s * i
        local al = A(150 / i)
        local ly = ty + tth * 0.52
        draw.line(cx0 - tw * 0.5 - 16 * s - off, ly, cx0 - tw * 0.5 - 16 * s - off + 22 * s, ly, ac_r, ac_g, ac_b, al, 1.3)
        draw.line(cx0 + tw * 0.5 + 16 * s + off - 22 * s, ly, cx0 + tw * 0.5 + 16 * s + off, ly, ac_r, ac_g, ac_b, al, 1.3)
    end

    local sy0 = ty + tth - 2 * s
    if hot then
        local flash = 0.55 + 0.45 * sin(now * 11.0)
        centre_spaced(font.small, cx0, sy0, 4 * s, RED_R, RED_G, RED_B, A(140 + 115 * flash), "// SYSTEM OVERHEAT //")
    else
        centre_spaced(font.small, cx0, sy0, 4 * s, 150, 190, 208, A(190), STATES[floor(f.state or 0)] or "ONLINE")
    end

    ------------------------------------------------------------------ arc reactor (bottom-left)
    local rc_x, rc_y = m + 104 * s, sh - m - 104 * s
    local r_tick, r_pow, r_shd, r_heat, r_core = 90 * s, 76 * s, 63 * s, 51 * s, 37 * s
    local a0, a1 = -2.356, 2.356          -- 270 degree sweep, gap at the bottom
    local span = (a1 - a0) * ease
    local pulse = 0.72 + 0.28 * sin(now * 2.4)

    tick_ring(rc_x, rc_y, r_tick, r_tick + 7 * s, 40, now * 0.32, ac_r, ac_g, ac_b, A(95), 1.2)
    dashed_ring(rc_x, rc_y, r_tick + 12 * s, 3, -now * 0.5, 0.16, ac_r, ac_g, ac_b, A(70), 1.6)

    arc(rc_x, rc_y, r_pow,  a0, a0 + span, DIM_R, DIM_G, DIM_B, A(150), 3.0)
    arc(rc_x, rc_y, r_shd,  a0, a0 + span, DIM_R, DIM_G, DIM_B, A(120), 2.4)
    arc(rc_x, rc_y, r_heat, a0, a0 + span, DIM_R, DIM_G, DIM_B, A(100), 2.0)
    arc(rc_x, rc_y, r_pow,  a0, a0 + span * sm_energy, CY_R, CY_G, CY_B, A(255), 3.0)
    arc(rc_x, rc_y, r_shd,  a0, a0 + span * sm_shield, BLU_R, BLU_G, BLU_B, A(235), 2.4)
    arc(rc_x, rc_y, r_heat, a0, a0 + span * sm_heat,
        hot and RED_R or GOLD_R, hot and RED_G or GOLD_G, hot and RED_B or GOLD_B, A(235), 2.0)

    -- reactor core: layered glow + the segmented triangle motif
    for i = 6, 1, -1 do
        draw.circle(rc_x, rc_y, r_core * (0.42 + i * 0.1),
            HOT_R, HOT_G, HOT_B, A((8 + i * 2) * pulse * (0.35 + 0.65 * sm_energy)))
    end
    draw.circle_outline(rc_x, rc_y, r_core, ac_r, ac_g, ac_b, A(190), 1.6)
    for i = 0, 5 do
        local b0 = (i / 6) * PI * 2 + now * 0.22
        arc(rc_x, rc_y, r_core * 0.82, b0, b0 + 0.72, HOT_R, HOT_G, HOT_B, A(105 * pulse), 2.2)
    end
    draw.circle(rc_x, rc_y, r_core * 0.2, HOT_R, HOT_G, HOT_B, A(200 * pulse))

    local pwr = string.format("%d", floor((f.energy or 0) * 100 + 0.5))
    local pth = text.height(font.title)
    text.draw_centered(font.title, rc_x - r_core, rc_y - pth * 0.5, rc_x + r_core, HOT_R, HOT_G, HOT_B, A(250), pwr)
    centre_spaced(font.tiny, rc_x, rc_y + r_pow * 0.80, 3 * s, ac_r, ac_g, ac_b, A(165), "ARC REACTOR")

    -- gauge legend to the right of the rings
    local lx = rc_x + r_tick + 20 * s
    local lw = 92 * s
    local lh = 20 * s
    legend_row(lx, rc_y - lh, lw, s, "SHIELD", f.shield or 0, BLU_R, BLU_G, BLU_B)
    legend_row(lx, rc_y, lw, s, "HEAT", f.heat or 0,
        hot and RED_R or GOLD_R, hot and RED_G or GOLD_G, hot and RED_B or GOLD_B)

    ------------------------------------------------------------------ telemetry (bottom-right)
    local tx2 = sw - m
    local tby = sh - m - (f.controls and 44 * s or 6 * s)
    local wname = f.weapon or "Palm Repulsor"
    local widx = floor(f.weapon_index or 0)

    local pip_w, pip_h, pip_g = 24 * s, 5 * s, 4 * s
    local pip_y = tby - pip_h
    for i = 0, 3 do
        local px = tx2 - (4 - i) * (pip_w + pip_g) + pip_g
        if i == widx then
            draw.rect(px, pip_y, px + pip_w, pip_y + pip_h, GOLD_R, GOLD_G, GOLD_B, A(255), 1)
        else
            draw.rect(px, pip_y, px + pip_w, pip_y + pip_h, DIM_R, DIM_G, DIM_B, A(150), 1)
        end
    end
    right_text(font.small, tx2 - 4 * (pip_w + pip_g) + pip_g - 10 * s, pip_y - 3 * s, 168, 196, 210, A(200), "WEAPON")

    local wy = pip_y - text.height(font.item) - 6 * s
    right_text(font.item, tx2, wy, GOLD_R, GOLD_G, GOLD_B, A(245), wname)

    local ry = wy - 10 * s
    draw.line(tx2 - 210 * s, ry, tx2, ry, ac_r, ac_g, ac_b, A(120), 1.2)

    local spd = string.format("%d", floor(sm_speed + 0.5))
    local spd_h = text.height(font.title)
    local sy = ry - 8 * s - spd_h
    right_text(font.small, tx2, sy + spd_h - text.height(font.small) - 4 * s, 168, 196, 210, A(215), "M/S")
    right_text(font.title, tx2 - text.width(font.small, "M/S") - 7 * s, sy, HOT_R, HOT_G, HOT_B, A(250), spd)

    local ay = sy - text.height(font.item) - 3 * s
    right_text(font.item, tx2, ay, 190, 216, 228, A(225), string.format("ALT  %.1f m", sm_alt))

    local hy = ay - text.height(font.small) - 6 * s
    right_text(font.small, tx2, hy, 168, 196, 210, A(190),
        string.format("PROJ %d    LOCKS %d", floor(f.projectiles or 0), floor(f.locks or 0)))
    frame_corners(tx2 - 214 * s, hy - 8 * s, tx2 + 6 * s, tby + 6 * s, 14 * s, ac_r, ac_g, ac_b, A(105), 1.3)

    ------------------------------------------------------------------ flight tapes
    if sm_fly > 0.02 then
        local ta = A(150 * sm_fly)
        local half = 170 * s
        local lxt, rxt = m + 30 * s, sw - m - 30 * s
        tape(lxt, cy0, half, sm_speed, 5, 1, s, ac_r, ac_g, ac_b, ta)
        tape(rxt, cy0, half, max(0, sm_alt), 20, -1, s, ac_r, ac_g, ac_b, ta)
        centre_spaced(font.tiny, lxt + 10 * s, cy0 - half - 18 * s, 3 * s, ac_r, ac_g, ac_b, ta, "SPD M/S")
        centre_spaced(font.tiny, rxt - 10 * s, cy0 - half - 18 * s, 3 * s, ac_r, ac_g, ac_b, ta, "ALT M")
    end

    ------------------------------------------------------------------ reticle
    if sm_aim > 0.01 or (f.charge or 0) > 0 or f.flying then
        local base = A(90 * (0.35 + 0.65 * sm_aim))
        draw.line(cx0 - 15 * s, cy0, cx0 - 6 * s, cy0, ac_r, ac_g, ac_b, base, 1.3)
        draw.line(cx0 + 6 * s, cy0, cx0 + 15 * s, cy0, ac_r, ac_g, ac_b, base, 1.3)
        draw.line(cx0, cy0 - 15 * s, cx0, cy0 - 6 * s, ac_r, ac_g, ac_b, base, 1.3)
        draw.line(cx0, cy0 + 6 * s, cx0, cy0 + 15 * s, ac_r, ac_g, ac_b, base, 1.3)
    end

    if sm_aim > 0.01 then
        local scan = A(170 * sm_aim)
        dashed_ring(cx0, cy0, 42 * s, 12, now * 0.9, 0.42, GOLD_R, GOLD_G, GOLD_B, floor(scan * (1 - sm_lock)), 1.6)
        -- brackets close in from 46px to 26px as the lock resolves
        local d = (46 - 20 * sm_lock) * s
        local len = 12 * s
        local lr = sm_lock > 0.5 and RED_R or GOLD_R
        local lg = sm_lock > 0.5 and RED_G or GOLD_G
        local lb = sm_lock > 0.5 and RED_B or GOLD_B
        local la = A(200 * sm_aim)
        draw.line(cx0 - d, cy0 - d, cx0 - d + len, cy0 - d, lr, lg, lb, la, 1.8)
        draw.line(cx0 - d, cy0 - d, cx0 - d, cy0 - d + len, lr, lg, lb, la, 1.8)
        draw.line(cx0 + d - len, cy0 - d, cx0 + d, cy0 - d, lr, lg, lb, la, 1.8)
        draw.line(cx0 + d, cy0 - d, cx0 + d, cy0 - d + len, lr, lg, lb, la, 1.8)
        draw.line(cx0 - d, cy0 + d - len, cx0 - d, cy0 + d, lr, lg, lb, la, 1.8)
        draw.line(cx0 - d, cy0 + d, cx0 - d + len, cy0 + d, lr, lg, lb, la, 1.8)
        draw.line(cx0 + d, cy0 + d - len, cx0 + d, cy0 + d, lr, lg, lb, la, 1.8)
        draw.line(cx0 + d - len, cy0 + d, cx0 + d, cy0 + d, lr, lg, lb, la, 1.8)

        if f.locked then
            local lp = 0.6 + 0.4 * sin(now * 7.5)
            draw.circle_outline(cx0, cy0, (30 + 5 * lp) * s, RED_R, RED_G, RED_B, A(150 * lp * sm_lock), 1.4)
            local tt = TARGETS[floor(f.target_type or 0)] or "ENTITY"
            centre_spaced(font.small, cx0, cy0 + 56 * s, 3 * s, RED_R, RED_G, RED_B, A(235 * sm_lock),
                string.format("LOCK  %s  %dM", tt, floor(sm_dist + 0.5)))
            local n = max(1, floor(f.locks or 1))
            if n > 1 then
                local pw = 7 * s
                local tot = n * pw + (n - 1) * 4 * s
                for i = 0, n - 1 do
                    local px = cx0 - tot * 0.5 + i * (pw + 4 * s)
                    draw.rect(px, cy0 + 72 * s, px + pw, cy0 + 75 * s, RED_R, RED_G, RED_B, A(220), 0)
                end
            end
        elseif f.aiming then
            centre_spaced(font.small, cx0, cy0 + 56 * s, 3 * s, GOLD_R, GOLD_G, GOLD_B, A(210 * sm_aim),
                string.format("SCANNING  %dM", floor(sm_dist + 0.5)))
        end
    end

    -- unibeam charge collapses inward on the reticle
    local ch = f.charge or 0
    if ch > 0 then
        arc(cx0, cy0, 60 * s, -PI, -PI + PI * 2 * ch, HOT_R, HOT_G, HOT_B, A(240), 3.0)
        draw.circle(cx0, cy0, 20 * s * ch, HOT_R, HOT_G, HOT_B, A(90 * ch))
        draw.circle_outline(cx0, cy0, (66 - 30 * ch) * s, HOT_R, HOT_G, HOT_B, A(140 * ch), 1.6)
        centre_spaced(font.small, cx0, cy0 - 84 * s, 4 * s, HOT_R, HOT_G, HOT_B, A(240),
            string.format("UNIBEAM  %d%%", floor(ch * 100 + 0.5)))
    end

    ------------------------------------------------------------------ ultimate + hints (bottom centre)
    local uw = 268 * s
    local ux = cx0 - uw * 0.5
    local uy = sh - m - (f.controls and 46 * s or 8 * s)
    local ready = f.ultimate_ready and true or false
    local cd = f.ultimate_cooldown or 0
    local prog = 1 - cd
    -- house_party() also refuses while overheated or short on reactor energy, so say which it is
    -- instead of showing a full bar that does nothing when pressed.
    local ustate
    if hot then ustate = "LOCKED OUT"
    elseif cd > 0 then ustate = string.format("%d%%", floor(prog * 100 + 0.5))
    elseif not ready then ustate = "LOW POWER"
    else ustate = "READY" end

    local ur = ready and GOLD_R or (hot and RED_R or 150)
    local ug = ready and GOLD_G or (hot and RED_G or 182)
    local ub = ready and GOLD_B or (hot and RED_B or 198)
    local upulse = ready and (0.62 + 0.38 * sin(now * 4.0)) or 1

    text.draw_spaced(font.tiny, ux, uy - 13 * s, ur, ug, ub, A(210), "HOUSE PARTY", 3 * s)
    right_text(font.tiny, ux + uw, uy - 13 * s, ur, ug, ub, A(210), ustate)
    seg_bar(ux, uy, uw, 5 * s, 24, prog,
        ready and GOLD_R or (hot and RED_R or CY_R), ready and GOLD_G or (hot and RED_G or CY_G),
        ready and GOLD_B or (hot and RED_B or CY_B), A((ready and 255 or 190) * upulse))

    if f.controls then
        local h1 = "JUMP ASCEND   CTRL DESCEND   SHIFT BOOST   MELEE ABILITY"
        local h2 = "AIM+ATTACK FIRE   AIM+RELOAD CYCLE WEAPON   AIM+WHEEL CYCLE TARGET"
        centre_spaced(font.tiny, cx0, sh - m - 22 * s, 2 * s, 158, 190, 206, A(180), h1)
        centre_spaced(font.tiny, cx0, sh - m - 9 * s, 2 * s, 140, 170, 186, A(150), h2)
    end
end)
