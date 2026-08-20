-- UFO Mode saucer HUD.
--
-- Published by misc_ufo_mode::draw: active, beaming, firing, boosting, cloaked, shield, stealth,
-- antigrav, emp, pulse_on, kbm, beam_mode (0 abduct, 1 lift, 2 repel), beam_targets, speed (m/s),
-- altitude (m), pulse_cd and laser_cd (1 just fired -> 0 ready).
--
-- The saucer runs four independent cooldowns and three concealment states that were previously
-- invisible -- you were guessing whether the pulse was back or the cloak had actually engaged.
-- So the layout is built around the two things you cannot otherwise know: the beam and the
-- cooldowns. Alien green on deep violet, ring-shaped, so it reads as a saucer instrument.

local PI = math.pi
local sin, cos, min, max, floor, abs = math.sin, math.cos, math.min, math.max, math.floor, math.abs

local GRN_R,  GRN_G,  GRN_B  = 122, 255, 168   -- saucer green (primary)
local DEEP_R, DEEP_G, DEEP_B =  38,  84,  62   -- unlit track
local VIO_R,  VIO_G,  VIO_B  = 186, 132, 255   -- beam / abduction
local AMB_R,  AMB_G,  AMB_B  = 255, 196,  84   -- lift
local RED_R,  RED_G,  RED_B  = 255,  92,  72   -- repel / charging
local WHT_R,  WHT_G,  WHT_B  = 232, 255, 240

-- beam_mode -> label + colour. Index matches the "Beam Mode" array item.
local BEAM_NAME = { [0] = "ABDUCT", [1] = "LIFT", [2] = "REPEL" }

local boot_at, was_active = -1, false
local sm_speed, sm_alt, sm_beam, sm_targets = 0, 0, 0, 0

local g_fade = 1
local function A(v) return floor(v * g_fade) end

local function approach(cur, target, rate, dt)
    return cur + (target - cur) * min(1, rate * dt)
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

local function centre_spaced(fnt, cx, y, sp, r, g, b, a, str)
    text.draw_spaced(fnt, cx - text.width_spaced(fnt, str, sp) * 0.5, y, r, g, b, a, str, sp)
end

local function right_text(fnt, x2, y, r, g, b, a, str)
    text.draw(fnt, x2 - text.width(fnt, str), y, r, g, b, a, str)
end

-- Small status chip, right-anchored. Returns the height consumed so callers can stack upward.
local function chip(x2, y, s, label, r, g, b)
    local w = text.width(font.tiny, label) + 16 * s
    local h = 15 * s
    draw.rect(x2 - w, y, x2, y + h, r, g, b, A(40), 2)
    draw.rect(x2 - w, y, x2 - w + 2.5 * s, y + h, r, g, b, A(255), 0)
    text.draw(font.tiny, x2 - w + 9 * s, y + 3 * s, r, g, b, A(240), label)
    return h + 5 * s
end

-- Horizontal cooldown pip row: fills left-to-right as the ability comes back.
local function cooldown_row(x, y, w, h, ready_frac, label, r, g, b, s)
    local segs = 14
    local gap = max(1.0, w * 0.006)
    local bw = (w - gap * (segs - 1)) / segs
    local lit = max(0, min(1, ready_frac)) * segs
    for i = 0, segs - 1 do
        local bx = x + i * (bw + gap)
        local fill = min(1, max(0, lit - i))
        if fill > 0 then
            draw.rect(bx, y, bx + bw, y + h, r, g, b, A(255 * (0.45 + 0.55 * fill)), 1)
        else
            draw.rect(bx, y, bx + bw, y + h, DEEP_R, DEEP_G, DEEP_B, A(150), 1)
        end
    end
    text.draw_spaced(font.tiny, x, y - 12 * s, 168, 200, 180, A(200), label, 2 * s)
end

local hint_sig, hint_1 = -1, ""

features.on_draw("UFO Mode", function(f)
    local now = ctx.time()
    if f.active and not was_active then boot_at = now end
    was_active = f.active and true or false
    if not f.active then return end

    local dt = min(0.1, max(0.001, ctx.delta()))
    local boot = boot_at < 0 and 1 or min(1, (now - boot_at) / 0.6)
    g_fade = 1 - (1 - boot) * (1 - boot)

    local sw, sh = ctx.screen_w(), ctx.screen_h()
    local s = max(0.72, min(1.7, sh / 1080))
    local m = 34 * s
    local cx0, cy0 = sw * 0.5, sh * 0.5

    local beam_mode = floor(f.beam_mode or 0)
    local pulse_ready = (f.pulse_cd or 0) <= 0.001
    local targets = floor(f.beam_targets or 0)

    sm_speed   = approach(sm_speed, f.speed or 0, 8, dt)
    sm_alt     = approach(sm_alt, f.altitude or 0, 8, dt)
    sm_beam    = approach(sm_beam, f.beaming and 1 or 0, 12, dt)
    sm_targets = approach(sm_targets, targets, 10, dt)

    -- The beam colour is the mode, so the player can tell abduct from repel at a glance instead of
    -- reading the menu.
    local bm_r = beam_mode == 2 and RED_R or (beam_mode == 1 and AMB_R or VIO_R)
    local bm_g = beam_mode == 2 and RED_G or (beam_mode == 1 and AMB_G or VIO_G)
    local bm_b = beam_mode == 2 and RED_B or (beam_mode == 1 and AMB_B or VIO_B)

    ------------------------------------------------------------------ frame
    draw.rect_gradient(0, 0, sw, 74 * s,
        GRN_R, GRN_G, GRN_B, A(22), GRN_R, GRN_G, GRN_B, A(22),
        GRN_R, GRN_G, GRN_B, 0, GRN_R, GRN_G, GRN_B, 0)
    draw.rect_gradient(0, sh - 74 * s, sw, sh,
        GRN_R, GRN_G, GRN_B, 0, GRN_R, GRN_G, GRN_B, 0,
        GRN_R, GRN_G, GRN_B, A(20), GRN_R, GRN_G, GRN_B, A(20))

    ------------------------------------------------------------------ crown
    local title = "U F O"
    local tsp = 8 * s
    local tw = text.width_spaced(font.title, title, tsp)
    local tth = text.height(font.title)
    local ty0 = m - 6 * s
    text.draw_spaced(font.title, cx0 - tw * 0.5, ty0, GRN_R, GRN_G, GRN_B, A(240), title, tsp)
    centre_spaced(font.small, cx0, ty0 + tth - 4 * s, 4 * s, 168, 200, 180, A(190), "SAUCER CONTROL")

    ------------------------------------------------------------------ saucer gauge (bottom-left)
    -- A ring, because the craft is one. Outer arc = throttle-ish speed against a nominal ceiling,
    -- inner glow pulses with the engine, centre carries the altitude that keeps you off the ground.
    local ox, oy = m + 96 * s, sh - m - 104 * s
    local r_out, r_in = 74 * s, 60 * s
    local spin = now * 0.6

    -- rotating dish ticks
    for i = 0, 23 do
        local ang = spin + (i / 24) * PI * 2
        local major = (i % 6) == 0
        local r0 = r_out + (major and 8 or 4) * s
        draw.line(ox + sin(ang) * r_out, oy - cos(ang) * r_out,
                  ox + sin(ang) * r0,    oy - cos(ang) * r0,
                  GRN_R, GRN_G, GRN_B, A(major and 190 or 110), major and 1.6 or 1.0)
    end

    local a0, a1 = -2.356, 2.356
    local spd_frac = min(1, sm_speed / 100)
    arc(ox, oy, r_in, a0, a1, DEEP_R, DEEP_G, DEEP_B, A(150), 3.0)
    arc(ox, oy, r_in, a0, a0 + (a1 - a0) * spd_frac,
        f.boosting and WHT_R or GRN_R, f.boosting and WHT_G or GRN_G, f.boosting and WHT_B or GRN_B,
        A(250), 3.0)

    local pulse = 0.7 + 0.3 * sin(now * 2.6)
    for i = 5, 1, -1 do
        draw.circle(ox, oy, (14 + i * 5) * s, GRN_R, GRN_G, GRN_B, A(9 * i * pulse))
    end

    local alt_txt = string.format("%d", floor(max(0, sm_alt) + 0.5))
    text.draw_centered(font.title, ox - r_in, oy - text.height(font.title) * 0.5 - 2 * s, ox + r_in,
                       WHT_R, WHT_G, WHT_B, A(250), alt_txt)
    centre_spaced(font.tiny, ox, oy + text.height(font.title) * 0.5 - 4 * s, 2 * s,
                  168, 200, 180, A(190), "ALT M")
    centre_spaced(font.tiny, ox, oy + r_out + 22 * s, 3 * s, GRN_R, GRN_G, GRN_B, A(180),
                  string.format("SPD %d M/S", floor(sm_speed + 0.5)))

    ------------------------------------------------------------------ tractor beam (centre)
    -- Only while the beam is live. The ring is the capture column seen from above; the count is
    -- what the beam is actually moving, which is the one thing the effect itself does not tell you.
    if sm_beam > 0.02 then
        local rr = (56 + 8 * sin(now * 5.0)) * s
        for i = 0, 2 do
            local t = ((now * 0.9 + i * 0.33) % 1)
            draw.circle_outline(cx0, cy0, rr * (0.5 + t * 0.9), bm_r, bm_g, bm_b,
                                A(150 * sm_beam * (1 - t)), 1.6)
        end
        draw.circle_outline(cx0, cy0, rr, bm_r, bm_g, bm_b, A(210 * sm_beam), 2.0)
        centre_spaced(font.small, cx0, cy0 + rr + 14 * s, 4 * s, bm_r, bm_g, bm_b, A(235 * sm_beam),
                      BEAM_NAME[beam_mode] or "BEAM")
        if targets > 0 then
            centre_spaced(font.item, cx0, cy0 - text.height(font.item) * 0.5, 2 * s,
                          WHT_R, WHT_G, WHT_B, A(245 * sm_beam),
                          string.format("%d LOCKED", targets))
        end
    end

    ------------------------------------------------------------------ cooldowns (bottom centre)
    local cw = 240 * s
    local cxl = cx0 - cw * 0.5
    local cy_pulse = sh - m - 46 * s

    if f.pulse_on then
        cooldown_row(cxl, cy_pulse, cw, 6 * s, 1 - (f.pulse_cd or 0),
                     pulse_ready and "REPULSOR READY" or "REPULSOR CHARGING",
                     pulse_ready and GRN_R or RED_R, pulse_ready and GRN_G or RED_G,
                     pulse_ready and GRN_B or RED_B, s)
    end

    ------------------------------------------------------------------ status chips (bottom right)
    local tx2 = sw - m
    local chy = sh - m - 30 * s
    if f.antigrav then chy = chy - chip(tx2, chy, s, "ANTI-GRAVITY", VIO_R, VIO_G, VIO_B) end
    if f.emp and f.pulse_on then chy = chy - chip(tx2, chy, s, "EMP", AMB_R, AMB_G, AMB_B) end
    if f.stealth then chy = chy - chip(tx2, chy, s, "STEALTH", 150, 200, 175) end
    if f.cloaked then chy = chy - chip(tx2, chy, s, "CLOAKED", WHT_R, WHT_G, WHT_B) end
    if f.shield then chy = chy - chip(tx2, chy, s, "SHIELD", GRN_R, GRN_G, GRN_B) end

    -- weapon state sits above the chips
    right_text(font.small, tx2, chy - 4 * s,
               f.firing and RED_R or 150, f.firing and RED_G or 180, f.firing and RED_B or 165,
               A(225), f.firing and "LASERS FIRING" or "LASERS IDLE")

    ------------------------------------------------------------------ controls
    local kbm = f.kbm ~= false
    local sig = (kbm and 1 or 0) + (f.pulse_on and 2 or 0)
    if sig ~= hint_sig then
        hint_sig = sig
        if kbm then
            hint_1 = "WASD FLY   SPACE/CTRL ALTITUDE   SHIFT BOOST   LMB LASERS   RMB BEAM"
            if f.pulse_on then hint_1 = hint_1 .. "   R PULSE" end
        else
            hint_1 = "LS FLY   X/LS ALTITUDE   A BOOST   RT LASERS   LT BEAM"
            if f.pulse_on then hint_1 = hint_1 .. "   B PULSE" end
        end
    end
    centre_spaced(font.tiny, cx0, sh - m - 10 * s, 2 * s, 168, 196, 180, A(180), hint_1)
end)
