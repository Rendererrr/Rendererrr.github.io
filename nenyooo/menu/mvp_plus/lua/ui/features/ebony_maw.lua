-- Ebony Maw telekinesis HUD.
--
-- Published by world_ebony_maw::draw: active, show_hud, show_marker, aiming, locked,
-- target_on_screen, rocks, max_rocks, projectiles, target_type (0 position, 1 ped, 2 vehicle,
-- 3 object), target_distance (m), target_x / target_y (NORMALISED 0..1 screen coords),
-- cooldown (1 just fired -> 0 ready), mode.
--
-- Identity is the orbit: the ammunition gauge is a ring of stones circling a core, which is what
-- the power actually looks like. Violet and pale stone, gold when a launch is ready.

local PI = math.pi
local sin, cos, min, max, floor, abs = math.sin, math.cos, math.min, math.max, math.floor, math.abs

local VIO_R,  VIO_G,  VIO_B  = 178, 122, 255   -- telekinetic violet (primary)
local DEEP_R, DEEP_G, DEEP_B =  74,  48, 116   -- unlit track
local GOLD_R, GOLD_G, GOLD_B = 255, 198,  92   -- ready / locked
local STN_R,  STN_G,  STN_B  = 214, 206, 220   -- stone
local WHT_R,  WHT_G,  WHT_B  = 240, 235, 248

local TARGETS = { [0] = "POSITION", [1] = "HOSTILE", [2] = "VEHICLE", [3] = "OBJECT" }

local boot_at, was_active = -1, false
local sm_rocks, sm_dist, sm_aim, sm_cool = 0, 0, 0, 0

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

-- Corner brackets around a point -- used for the target marker.
local function brackets(cx, cy, d, len, r, g, b, a, th)
    draw.line(cx - d, cy - d, cx - d + len, cy - d, r, g, b, a, th)
    draw.line(cx - d, cy - d, cx - d, cy - d + len, r, g, b, a, th)
    draw.line(cx + d - len, cy - d, cx + d, cy - d, r, g, b, a, th)
    draw.line(cx + d, cy - d, cx + d, cy - d + len, r, g, b, a, th)
    draw.line(cx - d, cy + d - len, cx - d, cy + d, r, g, b, a, th)
    draw.line(cx - d, cy + d, cx - d + len, cy + d, r, g, b, a, th)
    draw.line(cx + d, cy + d - len, cx + d, cy + d, r, g, b, a, th)
    draw.line(cx + d - len, cy + d, cx + d, cy + d, r, g, b, a, th)
end

-- Hint lines are rebuilt only when the binding set changes, not every frame.
local hint_sig, hint_1 = -1, ""

features.on_draw("Ebony Maw", function(f)
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

    local rocks = floor(f.rocks or 0)
    local max_rocks = max(1, floor(f.max_rocks or 1))
    local cooldown = max(0, min(1, f.cooldown or 0))
    local ready = cooldown <= 0.001

    sm_rocks = approach(sm_rocks, rocks, 10, dt)
    sm_dist  = approach(sm_dist, f.target_distance or 0, 10, dt)
    sm_aim   = approach(sm_aim, f.aiming and 1 or 0, 12, dt)
    sm_cool  = approach(sm_cool, 1 - cooldown, 10, dt)

    ------------------------------------------------------------------ target marker
    -- Drawn at the projected target, not at screen centre -- the feature already publishes the
    -- world-to-screen projection, so the marker belongs where the rock is actually going.
    if f.show_marker and f.aiming and f.target_on_screen then
        local tx, ty = (f.target_x or 0.5) * sw, (f.target_y or 0.5) * sh
        local mr = f.locked and GOLD_R or VIO_R
        local mg = f.locked and GOLD_G or VIO_G
        local mb = f.locked and GOLD_B or VIO_B
        local a  = A(ready and 245 or 150)

        if f.locked then
            local pulse = 0.6 + 0.4 * sin(now * 6.5)
            draw.circle_outline(tx, ty, (26 + 5 * pulse) * s, mr, mg, mb, floor(a * 0.55 * pulse), 1.4)
        end
        brackets(tx, ty, (f.locked and 22 or 17) * s, 8 * s, mr, mg, mb, a, 1.8)
        draw.circle(tx, ty, 2.5 * s, mr, mg, mb, a)

        local state = (not ready) and "CHARGING" or (f.locked and "LOCKED" or "IMPACT POINT")
        centre_spaced(font.small, tx, ty + (f.locked and 32 or 27) * s, 2 * s, mr, mg, mb, a,
            string.format("%s  %dM", state, floor(sm_dist + 0.5)))
    end

    -- Aiming with the target off screen: say so, rather than leaving the player wondering where the
    -- marker went.
    if f.show_marker and f.aiming and not f.target_on_screen then
        centre_spaced(font.small, cx0, cy0 + 44 * s, 3 * s, VIO_R, VIO_G, VIO_B, A(190 * sm_aim),
                      "TARGET OFF SCREEN")
    end

    if not f.show_hud then return end

    ------------------------------------------------------------------ crown
    local title = "EBONY MAW"
    local tsp = 6 * s
    local tw = text.width_spaced(font.title, title, tsp)
    local tth = text.height(font.title)
    local ty0 = m - 6 * s
    text.draw_spaced(font.title, cx0 - tw * 0.5, ty0, VIO_R, VIO_G, VIO_B, A(240), title, tsp)
    centre_spaced(font.small, cx0, ty0 + tth - 4 * s, 4 * s, STN_R, STN_G, STN_B, A(190),
                  f.mode or "ROCK BARRAGE")

    ------------------------------------------------------------------ orbit gauge (bottom-left)
    -- The ammunition IS an orbit, so the gauge is one: max_rocks slots on a slowly turning ring,
    -- filled for each stone currently held. Cooldown wraps the outside and turns gold when a
    -- launch is available.
    local ox, oy = m + 96 * s, sh - m - 108 * s
    local r_ring = 58 * s
    local spin = now * 0.45

    arc(ox, oy, r_ring + 16 * s, -PI, PI, DEEP_R, DEEP_G, DEEP_B, A(140), 2.0)
    arc(ox, oy, r_ring + 16 * s, -PI, -PI + PI * 2 * sm_cool,
        ready and GOLD_R or VIO_R, ready and GOLD_G or VIO_G, ready and GOLD_B or VIO_B, A(235), 2.6)

    draw.circle_outline(ox, oy, r_ring, DEEP_R, DEEP_G, DEEP_B, A(150), 1.2)
    for i = 0, max_rocks - 1 do
        local ang = spin + (i / max_rocks) * PI * 2
        local px = ox + sin(ang) * r_ring
        local py = oy - cos(ang) * r_ring
        if i < rocks then
            draw.circle(px, py, 5.5 * s, STN_R, STN_G, STN_B, A(240))
            draw.circle_outline(px, py, 5.5 * s, VIO_R, VIO_G, VIO_B, A(200), 1.2)
        else
            draw.circle_outline(px, py, 4.0 * s, DEEP_R, DEEP_G, DEEP_B, A(190), 1.2)
        end
    end

    -- core
    local pulse = 0.7 + 0.3 * sin(now * 2.2)
    for i = 4, 1, -1 do
        draw.circle(ox, oy, (10 + i * 3) * s, VIO_R, VIO_G, VIO_B, A(12 * i * pulse))
    end
    local cnt = string.format("%d", rocks)
    text.draw_centered(font.title, ox - r_ring, oy - text.height(font.title) * 0.5, ox + r_ring,
                       WHT_R, WHT_G, WHT_B, A(250), cnt)
    centre_spaced(font.tiny, ox, oy + r_ring * 0.52, 2 * s, STN_R, STN_G, STN_B, A(180),
                  string.format("OF %d", max_rocks))
    centre_spaced(font.tiny, ox, oy + r_ring + 26 * s, 3 * s, VIO_R, VIO_G, VIO_B, A(175), "ORBIT")

    ------------------------------------------------------------------ telemetry (bottom-right)
    local tx2 = sw - m
    local by = sh - m - 30 * s
    local lh = text.height(font.item) + 4 * s

    right_text(font.item, tx2, by - lh * 2, STN_R, STN_G, STN_B, A(230),
               string.format("IN FLIGHT   %d", floor(f.projectiles or 0)))

    if f.aiming then
        local tt = TARGETS[floor(f.target_type or 0)] or "ENTITY"
        right_text(font.item, tx2, by - lh,
                   f.locked and GOLD_R or VIO_R, f.locked and GOLD_G or VIO_G, f.locked and GOLD_B or VIO_B,
                   A(240), string.format("%s   %dM", tt, floor(sm_dist + 0.5)))
    else
        right_text(font.item, tx2, by - lh, 150, 140, 165, A(200), "NO TARGET")
    end

    right_text(font.small, tx2, by, ready and GOLD_R or 150, ready and GOLD_G or 140,
               ready and GOLD_B or 165, A(225),
               ready and "BARRAGE READY" or string.format("CHARGING  %d%%", floor(sm_cool * 100 + 0.5)))

    ------------------------------------------------------------------ controls
    -- world_ebony_maw::draw does not publish `kbm` today, so this always resolves to the
    -- keyboard set. Left as a branch rather than hardcoded: publishing kbm is one line in the
    -- C++ snapshot (Superman already does it) and the pad labels then light up for free.
    local kbm = f.kbm ~= false
    local sig = (kbm and 1 or 0)
    if sig ~= hint_sig then
        hint_sig = sig
        hint_1 = kbm
            and "WASD STEER   SPACE ASCEND   CTRL DESCEND   SHIFT BOOST   RMB AIM   LMB LAUNCH"
            or  "LS STEER   X ASCEND   LS DESCEND   A BOOST   LT AIM   RT LAUNCH"
    end
    centre_spaced(font.tiny, cx0, sh - m - 10 * s, 2 * s, 178, 168, 194, A(180), hint_1)
end)
