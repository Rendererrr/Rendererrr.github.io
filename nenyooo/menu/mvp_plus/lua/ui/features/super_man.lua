-- Super Man flight HUD.
--
-- Published by misc_super_man::draw: active, pounding, carrying, invuln, breathing, controls, kbm,
-- pound_on / punch_on / grab_on / breath_on, state (0 ground, 1 flight, 2 super flight), frozen,
-- airborne_ms, speed (m/s), altitude (m), heading (deg), flight_speed, super_speed.
--
-- Identity is the shield, not the ring: a diamond crest bottom-left holding the velocity readout,
-- a heading strip under the wordmark, and speed/altitude tapes on the flanks while airborne.

local PI = math.pi
local sin, cos, min, max, floor, abs = math.sin, math.cos, math.min, math.max, math.floor, math.abs

local BLU_R,  BLU_G,  BLU_B  =  60, 118, 232   -- suit blue (primary)
local RED_R,  RED_G,  RED_B  = 226,  42,  56   -- cape red (alert / pound)
local GOLD_R, GOLD_G, GOLD_B = 255, 200,  60   -- crest gold (super flight)
local DIM_R,  DIM_G,  DIM_B  =  38,  66, 110   -- unlit track
local WHT_R,  WHT_G,  WHT_B  = 236, 244, 255

local STATES = { [0] = "GROUNDED", [1] = "FLIGHT", [2] = "SUPER FLIGHT" }
local CARDINALS = { [0] = "N", [45] = "NE", [90] = "E", [135] = "SE",
                    [180] = "S", [225] = "SW", [270] = "W", [315] = "NW" }

local boot_at, was_active = -1, false
local sm_speed, sm_alt, sm_throttle, sm_fly, sm_carry = 0, 0, 0, 0, 0

-- Hint lines are rebuilt only when the binding set actually changes. Concatenating them every
-- frame would hand the render thread a few hundred bytes of garbage per frame for text that
-- changes maybe twice a session.
local hint_sig, hint_1, hint_2 = -1, "", ""

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

local function diamond(cx, cy, rx, ry, r, g, b, a, th)
    draw.line(cx, cy - ry, cx + rx, cy, r, g, b, a, th)
    draw.line(cx + rx, cy, cx, cy + ry, r, g, b, a, th)
    draw.line(cx, cy + ry, cx - rx, cy, r, g, b, a, th)
    draw.line(cx - rx, cy, cx, cy - ry, r, g, b, a, th)
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
            draw.rect(bx, y, bx + bw, y + h, DIM_R, DIM_G, DIM_B, floor(a * 0.34), 1)
        end
    end
end

local function right_text(fnt, x2, y, r, g, b, a, str)
    text.draw(fnt, x2 - text.width(fnt, str), y, r, g, b, a, str)
end

local function centre_spaced(fnt, cx, y, sp, r, g, b, a, str)
    text.draw_spaced(fnt, cx - text.width_spaced(fnt, str, sp) * 0.5, y, r, g, b, a, str, sp)
end

-- Aviation-style vertical tape; ticks scroll past a fixed caret at cy.
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

-- Heading strip. GTA headings run counter-clockwise (90 = west), so the displayed bearing is
-- mirrored -- otherwise turning right scrolls the compass the wrong way.
local function compass(cx, y, w, heading, s, r, g, b, a)
    local bearing = (360 - (heading % 360)) % 360
    local half, span = w * 0.5, 120
    local ppd = w / span
    draw.line(cx - half, y + 15 * s, cx + half, y + 15 * s, r, g, b, floor(a * 0.3), 1.1)
    local first = floor((bearing - span * 0.5) / 15) * 15
    for d = first, bearing + span * 0.5, 15 do
        local nd = ((d % 360) + 360) % 360
        local off = ((d - bearing + 540) % 360) - 180
        local x = cx + off * ppd
        if x >= cx - half and x <= cx + half then
            local fade = 1 - abs(x - cx) / half
            local ta = floor(a * (0.15 + 0.85 * fade))
            local card = CARDINALS[nd]
            draw.line(x, y + 15 * s, x, y + (card and 7 or 11) * s, r, g, b, ta, card and 1.5 or 1.0)
            if card then
                centre_spaced(font.tiny, x, y - 3 * s, 1 * s, r, g, b, ta, card)
            end
        end
    end
    draw.line(cx, y + 17 * s, cx - 5 * s, y + 24 * s, r, g, b, A(235), 1.6)
    draw.line(cx, y + 17 * s, cx + 5 * s, y + 24 * s, r, g, b, A(235), 1.6)
end

-- Right-anchored status chip.
local function chip(x2, y, s, label, r, g, b)
    local w = text.width(font.tiny, label) + 16 * s
    local h = 15 * s
    draw.rect(x2 - w, y, x2, y + h, r, g, b, A(38), 2)
    draw.rect(x2 - w, y, x2 - w + 2.5 * s, y + h, r, g, b, A(255), 0)
    text.draw(font.tiny, x2 - w + 9 * s, y + 3 * s, r, g, b, A(240), label)
    return h + 5 * s
end

features.on_draw("Super Man", function(f)
    local now = ctx.time()
    if f.active and not was_active then boot_at = now end
    was_active = f.active and true or false
    if not f.active then return end

    local dt = min(0.1, max(0.001, ctx.delta()))
    local boot = boot_at < 0 and 1 or min(1, (now - boot_at) / 0.7)
    local ease = 1 - (1 - boot) * (1 - boot) * (1 - boot)
    g_fade = ease

    local sw, sh = ctx.screen_w(), ctx.screen_h()
    local s = max(0.72, min(1.7, sh / 1080))
    local m = 34 * s
    local cx0, cy0 = sw * 0.5, sh * 0.5

    local state = floor(f.state or 0)
    local pounding = f.pounding and true or false
    local super = state == 2
    local ceiling = max(1, f.super_speed or 30)

    sm_speed    = approach(sm_speed, f.speed or 0, 8, dt)
    sm_alt      = approach(sm_alt, f.altitude or 0, 7, dt)
    sm_throttle = approach(sm_throttle, min(1, (f.flight_speed or 0) / ceiling), 8, dt)
    sm_fly      = approach(sm_fly, state ~= 0 and 1 or 0, 5, dt)
    sm_carry    = approach(sm_carry, f.carrying and 1 or 0, 10, dt)

    -- Accent tracks what the suit is doing: blue cruising, gold at super flight, red on a pound.
    local ac_r = pounding and RED_R or (super and GOLD_R or BLU_R)
    local ac_g = pounding and RED_G or (super and GOLD_G or BLU_G)
    local ac_b = pounding and RED_B or (super and GOLD_B or BLU_B)

    ------------------------------------------------------------------ frame
    draw.rect_gradient(0, 0, sw, 80 * s,
        ac_r, ac_g, ac_b, A(26), ac_r, ac_g, ac_b, A(26),
        ac_r, ac_g, ac_b, 0, ac_r, ac_g, ac_b, 0)
    draw.rect_gradient(0, sh - 80 * s, sw, sh,
        ac_r, ac_g, ac_b, 0, ac_r, ac_g, ac_b, 0,
        ac_r, ac_g, ac_b, A(22), ac_r, ac_g, ac_b, A(22))

    if boot < 1 then
        local d = sw * 0.5 * boot
        draw.rect(cx0 - d, sh * 0.5 - 1.5 * s, cx0 + d, sh * 0.5 + 1.5 * s,
            WHT_R, WHT_G, WHT_B, floor(160 * (1 - boot)), 0)
    end

    ------------------------------------------------------------------ wordmark + heading
    local title = "S U P E R M A N"
    local tsp = 3 * s
    local tw = text.width_spaced(font.title, title, tsp)
    local tth = text.height(font.title)
    local ty = m - 8 * s
    text.draw_spaced(font.title, cx0 - tw * 0.5, ty, ac_r, ac_g, ac_b, A(245), title, tsp)

    local label = pounding and "GROUND POUND" or (STATES[state] or "ONLINE")
    centre_spaced(font.small, cx0, ty + tth - 4 * s, 4 * s, WHT_R, WHT_G, WHT_B, A(200), label)

    compass(cx0, ty + tth + 22 * s, 440 * s, f.heading or 0, s, ac_r, ac_g, ac_b, A(215))

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

    ------------------------------------------------------------------ crest (bottom-left)
    local kx, ky = m + 104 * s, sh - m - 104 * s
    local r_thr, r_vel = 86 * s, 73 * s
    local a0, a1 = -2.356, 2.356          -- 270 degrees, gap at the bottom
    local span = (a1 - a0) * ease

    arc(kx, ky, r_thr, a0, a0 + span, DIM_R, DIM_G, DIM_B, A(150), 3.0)
    arc(kx, ky, r_vel, a0, a0 + span, DIM_R, DIM_G, DIM_B, A(120), 2.2)
    arc(kx, ky, r_thr, a0, a0 + span * sm_throttle, ac_r, ac_g, ac_b, A(255), 3.0)
    -- Inner arc is actual velocity against the same ceiling, in cape red so it stays readable
    -- when the accent itself has gone gold at super flight.
    arc(kx, ky, r_vel, a0, a0 + span * min(1, sm_speed / ceiling), RED_R, RED_G, RED_B, A(235), 2.4)

    local pulse = 0.75 + 0.25 * sin(now * 2.2)
    diamond(kx, ky, 50 * s, 59 * s, ac_r, ac_g, ac_b, A(30), 1.0)
    diamond(kx, ky, 50 * s, 59 * s, ac_r, ac_g, ac_b, A(215), 2.0)
    diamond(kx, ky, 37 * s, 44 * s, RED_R, RED_G, RED_B, A(150 * pulse), 1.4)

    local spd = string.format("%d", floor(sm_speed + 0.5))
    local sth = text.height(font.title)
    text.draw_centered(font.title, kx - 50 * s, ky - sth * 0.5 - 3 * s, kx + 50 * s,
        WHT_R, WHT_G, WHT_B, A(250), spd)
    centre_spaced(font.tiny, kx, ky + sth * 0.5 - 4 * s, 2 * s, GOLD_R, GOLD_G, GOLD_B, A(200), "M/S")
    centre_spaced(font.tiny, kx, ky + r_thr * 0.86, 3 * s, ac_r, ac_g, ac_b, A(170), "VELOCITY")

    -- throttle readout beside the crest
    local lx = kx + r_thr + 20 * s
    text.draw_spaced(font.small, lx, ky - 22 * s, 168, 196, 226, A(215), "THROTTLE", 2 * s)
    seg_bar(lx, ky - 6 * s, 124 * s, 6 * s, 12, sm_throttle, ac_r, ac_g, ac_b, A(255))
    text.draw(font.small, lx, ky + 6 * s, 168, 196, 226, A(200),
        string.format("%d / %d", floor((f.flight_speed or 0) + 0.5), floor(ceiling + 0.5)))

    ------------------------------------------------------------------ status (bottom-right)
    local tx2 = sw - m
    local by = sh - m - (f.controls and 44 * s or 6 * s)

    local chips_y = by - 15 * s
    if f.frozen and f.frozen > 0 then
        chips_y = chips_y - chip(tx2, chips_y, s, string.format("FROZEN %d", floor(f.frozen)), WHT_R, WHT_G, WHT_B)
    end
    if f.carrying then chips_y = chips_y - chip(tx2, chips_y, s, "CARRYING", GOLD_R, GOLD_G, GOLD_B) end
    if f.breathing then chips_y = chips_y - chip(tx2, chips_y, s, "FREEZE BREATH", 150, 220, 255) end
    if f.invuln then chips_y = chips_y - chip(tx2, chips_y, s, "INVULNERABLE", BLU_R, BLU_G, BLU_B) end

    local ay = chips_y - text.height(font.item) - 6 * s
    right_text(font.item, tx2, ay, 200, 220, 238, A(230), string.format("ALT  %.1f m", sm_alt))

    local cy_ = ay - text.height(font.title) - 2 * s
    if state ~= 0 then
        local secs = floor((f.airborne_ms or 0) / 1000)
        right_text(font.title, tx2, cy_, WHT_R, WHT_G, WHT_B, A(245),
            string.format("%02d:%02d", floor(secs / 60), secs % 60))
        right_text(font.tiny, tx2, cy_ - 11 * s, ac_r, ac_g, ac_b, A(190), "AIRBORNE")
    else
        right_text(font.item, tx2, cy_ + text.height(font.title) - text.height(font.item),
            168, 196, 226, A(205), "JUMP TO TAKE OFF")
    end

    ------------------------------------------------------------------ reticle
    local base = A(70 + 120 * sm_carry)
    draw.line(cx0 - 14 * s, cy0, cx0 - 6 * s, cy0, ac_r, ac_g, ac_b, base, 1.3)
    draw.line(cx0 + 6 * s, cy0, cx0 + 14 * s, cy0, ac_r, ac_g, ac_b, base, 1.3)
    draw.line(cx0, cy0 - 14 * s, cx0, cy0 - 6 * s, ac_r, ac_g, ac_b, base, 1.3)
    draw.line(cx0, cy0 + 6 * s, cx0, cy0 + 14 * s, ac_r, ac_g, ac_b, base, 1.3)
    if sm_carry > 0.02 then
        -- carrying: the reticle becomes the throw sight
        local d = (30 - 6 * sm_carry) * s
        diamond(cx0, cy0, d, d * 1.15, GOLD_R, GOLD_G, GOLD_B, A(190 * sm_carry), 1.5)
        centre_spaced(font.tiny, cx0, cy0 + 44 * s, 3 * s, GOLD_R, GOLD_G, GOLD_B,
            A(210 * sm_carry), "RELEASE TO THROW")
    end

    ------------------------------------------------------------------ control hints
    if f.controls then
        local kbm = f.kbm ~= false
        local flying = state ~= 0
        local sig = (kbm and 1 or 0) + (flying and 2 or 0) + (f.pound_on and 4 or 0)
                  + (f.grab_on and 8 or 0) + (f.breath_on and 16 or 0)
        if sig ~= hint_sig then
            hint_sig = sig
            hint_1 = (kbm and "SPACE " or "X ") .. (flying and "LAND / BOOST" or "TAKE OFF")
                  .. "   " .. (kbm and "LMB " or "RT ") .. (flying and "HEAT VISION" or "SUPER PUNCH")
            if flying then
                hint_1 = hint_1 .. "   " .. (kbm and "R " or "B ") .. "SPIN ATTACK"
                      .. "   " .. (kbm and "SHIFT+W " or "A+LS ") .. "SUPER FLIGHT"
            end
            hint_2 = ""
            if f.pound_on and flying then
                hint_2 = (kbm and "CTRL " or "LS ") .. "GROUND POUND"
            end
            if f.grab_on then
                hint_2 = hint_2 .. (hint_2 ~= "" and "   " or "") .. (kbm and "E " or "Y ") .. "GRAB / THROW"
            end
            if f.breath_on then
                hint_2 = hint_2 .. (hint_2 ~= "" and "   " or "") .. (kbm and "G " or "DPAD ") .. "FREEZE BREATH"
            end
        end
        centre_spaced(font.tiny, cx0, sh - m - 22 * s, 2 * s, 176, 200, 224, A(185), hint_1)
        if hint_2 ~= "" then
            centre_spaced(font.tiny, cx0, sh - m - 9 * s, 2 * s, 152, 178, 204, A(155), hint_2)
        end
    end
end)
