-- Arcane grimoire HUD for Witch Mode.
--
-- Published by witch_mode::draw (see src/features/witch_mode.cpp): active, mounted, aiming,
-- casting, boosting, target, target_player, controls, state (0..6), spell_index (0..3), spell
-- (name string), target_type, cooldown (0..1 -- 1 == ready), speed (m/s), altitude (m),
-- target_distance (m).
--
-- Layout is a grimoire rather than a HUD strip:
--   - Bottom-right: circular rune SIGIL with the active spell's glyph inside, rune-tick ring
--     around it, cooldown arc that fills clockwise from 12 o'clock, four spell dots at NE/SE/
--     SW/NW, and an info column showing state / cooldown / altitude / velocity.
--   - Screen centre: rotating pentagram reticle whenever the player is aiming (locked target
--     annotated with distance and SOUL/TARGET label).
--   - Bottom centre: parchment-style control scroll bracketed by rune diamonds.

local PI, TAU = math.pi, math.pi * 2
local sin, cos, min, max, floor = math.sin, math.cos, math.min, math.max, math.floor
local random = math.random

-- Per-spell palette + on-sigil roman-numeral glyph (matches C++ spell_type order).
local SPELL_COLORS = {
    [0] = { 255, 132,  58, "FIREBALL",        "IX"  },  -- fireball        = warm orange
    [1] = { 126, 210, 255, "CHAIN LIGHTNING", "V"   },  -- chain lightning = ice blue
    [2] = { 190, 130, 255, "TELEKINESIS",     "III" },  -- telekinesis     = violet
    [3] = { 255, 108, 220, "ARCANE BLAST",    "VII" },  -- arcane blast    = pink
}
local STATES = {
    [0] = "DORMANT", [1] = "AWAKENED", [2] = "MOUNTING", [3] = "ASCENDING",
    [4] = "SOARING", [5] = "DESCENDING", [6] = "DISMOUNTING",
}

-- Grimoire base palette.
local INK_R,   INK_G,   INK_B   =  14,   8,  22   -- deep ink pool
local RIM_R,   RIM_G,   RIM_B   = 168, 132, 236   -- amethyst rim
local DIM_R,   DIM_G,   DIM_B   =  68,  46, 106   -- unlit rune
local PARCH_R, PARCH_G, PARCH_B = 240, 232, 255   -- ghostly parchment
local MUTE_R,  MUTE_G,  MUTE_B  = 138, 128, 170   -- label muted

-- Persistent state (chunk-scope: no closure allocation per frame).
local was_active = false
local wake       = 0
local sm_cool, sm_speed, sm_alt, sm_dist = 0, 0, 0, 0
local particles  = {}
local last_time  = 0
local BULLET     = "\226\128\162"   -- UTF-8 U+2022 (Lua 5.1 has no \u{...} escape)

local function approach(cur, target, rate, dt)
    return cur + (target - cur) * min(1, rate * dt)
end

-- Polyline ring outline (draw has no thick circle; polylining lets us match linewidth).
local function ring(cx, cy, rad, r, g, b, a, th, segs)
    if a <= 0 then return end
    segs = segs or max(24, floor(rad * 0.8))
    local d = TAU / segs
    local px, py = cx + rad, cy
    for i = 1, segs do
        local t = i * d
        local nx, ny = cx + cos(t) * rad, cy + sin(t) * rad
        draw.line(px, py, nx, ny, r, g, b, a, th)
        px, py = nx, ny
    end
end

-- Arc a0..a1 (radians), 12 o'clock start, sweeping clockwise.
local function arc(cx, cy, rad, a0, a1, r, g, b, a, th)
    if a <= 0 or a1 <= a0 then return end
    local segs = max(4, floor((a1 - a0) * rad * 0.16))
    local d = (a1 - a0) / segs
    local px, py = cx + sin(a0) * rad, cy - cos(a0) * rad
    for i = 1, segs do
        local t = a0 + d * i
        local nx, ny = cx + sin(t) * rad, cy - cos(t) * rad
        draw.line(px, py, nx, ny, r, g, b, a, th)
        px, py = nx, ny
    end
end

-- N-pointed star outline. Rot in radians; positive rotates clockwise.
local function star(cx, cy, r_out, r_in, points, rot, r, g, b, a, th)
    if a <= 0 then return end
    local prev_x, prev_y
    local n = points * 2
    for i = 0, n do
        local t = rot + (i / n) * TAU
        local rr = (i % 2 == 0) and r_out or r_in
        local x, y = cx + sin(t) * rr, cy - cos(t) * rr
        if prev_x then draw.line(prev_x, prev_y, x, y, r, g, b, a, th) end
        prev_x, prev_y = x, y
    end
end

-- Radial tick marks around a circle (rune-ring decoration).
local function rune_ticks(cx, cy, r_in, r_out, count, phase, r, g, b, a, th)
    if a <= 0 then return end
    local d = TAU / count
    for i = 0, count - 1 do
        local t = phase + i * d
        draw.line(cx + sin(t) * r_in, cy - cos(t) * r_in,
                  cx + sin(t) * r_out, cy - cos(t) * r_out, r, g, b, a, th)
    end
end

local function right_text(fnt, x, y, r, g, b, a, value)
    text.draw(fnt, x - text.width(fnt, value), y, r, g, b, a, value)
end

-- Emit one magical sparkle -- upward-drifting particle from the sigil.
local function emit(x, y, r, g, b)
    if #particles >= 48 then return end
    local ang = random() * TAU
    local sp  = 10 + random() * 26
    local life = 0.9 + random() * 0.6
    particles[#particles + 1] = {
        x = x, y = y,
        vx = cos(ang) * sp,
        vy = sin(ang) * sp - 14,
        life = life, life0 = life,
        r = r, g = g, b = b,
    }
end

local function update_particles(dt)
    for i = #particles, 1, -1 do
        local p = particles[i]
        p.life = p.life - dt
        if p.life <= 0 then
            table.remove(particles, i)
        else
            p.x  = p.x + p.vx * dt
            p.y  = p.y + p.vy * dt
            p.vy = p.vy + 28 * dt          -- soft gravity settle
            p.vx = p.vx * (1 - dt * 0.7)   -- friction
        end
    end
end

local function draw_particles(fade)
    for _, p in ipairs(particles) do
        local a = floor(210 * (p.life / p.life0) * fade)
        if a > 0 then
            draw.rect(p.x - 1.2, p.y - 1.2, p.x + 1.2, p.y + 1.2, p.r, p.g, p.b, a, 0)
        end
    end
end

features.on_draw("Witch Mode", function(f)
    if not f.active then
        was_active = false
        wake = 0
        return
    end

    local now = ctx.time()
    local dt  = (last_time > 0) and min(0.1, now - last_time) or 0.016
    last_time = now

    local sw, sh = ctx.screen_w(), ctx.screen_h()
    local s = max(0.75, min(1.5, sh / 1080))

    -- Wake-in fade (used to gate every alpha through A()).
    if not was_active then
        wake = 0
        was_active = true
    end
    wake = min(1.0, wake + dt * 2.6)
    local fade = wake
    local function A(v) return floor(v * fade) end

    -- Clamp spell index and resolve palette + glyph.
    local spell = floor(f.spell_index or 0)
    if spell < 0 then spell = 0 elseif spell > 3 then spell = 3 end
    local sp = SPELL_COLORS[spell]
    local sr, sg, sb = sp[1], sp[2], sp[3]
    local spell_name, rune = sp[4], sp[5]

    -- Smooth telemetry (raw values jitter frame-to-frame otherwise).
    sm_cool  = approach(sm_cool,  max(0, min(1, f.cooldown or 1)), 8, dt)
    sm_speed = approach(sm_speed, f.speed or 0, 4, dt)
    sm_alt   = approach(sm_alt,   f.altitude or 0, 4, dt)
    sm_dist  = approach(sm_dist,  f.target_distance or 0, 6, dt)

    ------------------------------------------------------------------
    -- 1. GRIMOIRE PANEL (bottom-right: rune sigil + info column)
    ------------------------------------------------------------------
    local sigil_r = 54 * s
    local panel_w, panel_h = 310 * s, 138 * s
    local px = sw - panel_w - 40 * s
    local py = sh - panel_h - 62 * s
    local cx = px + sigil_r + 18 * s
    local cy = py + panel_h * 0.5

    -- Ink pool.
    draw.rect(px, py, px + panel_w, py + panel_h, INK_R, INK_G, INK_B, A(190), 10)
    -- Top spell-tinted rim.
    draw.rect_gradient(px, py, px + panel_w, py + 3 * s,
        sr, sg, sb, A(235), sr, sg, sb, A(235),
        sr, sg, sb, A(70),  sr, sg, sb, A(70))
    -- Amethyst hairline along the bottom.
    draw.rect_gradient(px, py + panel_h - 1.5 * s, px + panel_w, py + panel_h,
        RIM_R, RIM_G, RIM_B, A(0),   RIM_R, RIM_G, RIM_B, A(0),
        RIM_R, RIM_G, RIM_B, A(140), RIM_R, RIM_G, RIM_B, A(140))

    -- SIGIL: three concentric rings.
    ring(cx, cy, sigil_r,           DIM_R, DIM_G, DIM_B, A(210), 1.5)
    ring(cx, cy, sigil_r -  6 * s,  RIM_R, RIM_G, RIM_B, A(120), 1)
    ring(cx, cy, sigil_r - 18 * s,  sr, sg, sb,          A(180), 1)

    -- Rotating rune-tick outer ring + 4 cardinal marker dots.
    local phase = now * 0.35
    rune_ticks(cx, cy, sigil_r + 3 * s, sigil_r + 9 * s, 12, phase,
        RIM_R, RIM_G, RIM_B, A(150), 1)
    for i = 0, 3 do
        local t  = phase + i * (TAU / 4)
        local ix = cx + sin(t) * (sigil_r + 12 * s)
        local iy = cy - cos(t) * (sigil_r + 12 * s)
        draw.rect(ix - 1.5 * s, iy - 1.5 * s, ix + 1.5 * s, iy + 1.5 * s,
            sr, sg, sb, A(230), 0)
    end

    -- Cooldown sweep: fills the sigil rim clockwise from top.
    arc(cx, cy, sigil_r, 0, TAU * sm_cool, sr, sg, sb, A(240), 2.5)

    -- Faint pentagram behind the glyph; slow wobble adds life.
    local star_r = sigil_r - 12 * s
    star(cx, cy, star_r, star_r * 0.42, 5, sin(now * 0.4) * 0.05,
        sr, sg, sb, A(75), 1)

    -- Central roman-numeral glyph.
    local glyph_w = text.width(font.title, rune)
    text.draw(font.title, cx - glyph_w * 0.5, cy - 14 * s,
        PARCH_R, PARCH_G, PARCH_B, A(248), rune)

    -- INFO COLUMN (right of sigil).
    local ix = cx + sigil_r + 22 * s
    local iy = py + 18 * s
    local col_r_edge = px + panel_w - 14 * s

    text.draw_spaced(font.small, ix, iy, RIM_R, RIM_G, RIM_B, A(215), "GRIMOIRE", 2 * s)
    right_text(font.tiny, col_r_edge, iy + 2 * s,
        MUTE_R, MUTE_G, MUTE_B, A(220), STATES[floor(f.state or 0)] or "AWAKENED")

    -- Spell name (headline).
    text.draw(font.item, ix, iy + 20 * s, sr, sg, sb, A(250), spell_name)

    -- Cooldown label + %.
    local ready = sm_cool >= 0.999
    local cool_label = ready and "READY" or "CHANNELING"
    text.draw(font.tiny, ix, iy + 46 * s, PARCH_R, PARCH_G, PARCH_B, A(225), cool_label)
    right_text(font.tiny, col_r_edge, iy + 46 * s,
        sr, sg, sb, A(245), string.format("%3d%%", floor(sm_cool * 100 + 0.5)))

    -- Slim linear cooldown bar under the labels.
    local bx = ix
    local by = iy + 60 * s
    local bw = col_r_edge - ix
    draw.rect(bx, by, bx + bw, by + 3 * s, DIM_R, DIM_G, DIM_B, A(190), 1)
    draw.rect(bx, by, bx + bw * sm_cool, by + 3 * s, sr, sg, sb, A(245), 1)

    -- Telemetry glyphs.
    local ty = iy + 78 * s
    local mid = ix + (col_r_edge - ix) * 0.5
    text.draw(font.tiny,  ix,  ty,          MUTE_R, MUTE_G, MUTE_B, A(200), "ALTITUDE")
    text.draw(font.small, ix,  ty + 12 * s, PARCH_R, PARCH_G, PARCH_B, A(240),
        string.format("%3.0fm", sm_alt))
    text.draw(font.tiny,  mid, ty,          MUTE_R, MUTE_G, MUTE_B, A(200), "VELOCITY")
    text.draw(font.small, mid, ty + 12 * s, PARCH_R, PARCH_G, PARCH_B, A(240),
        string.format("%3.0fm/s", sm_speed))

    ------------------------------------------------------------------
    -- 2. SPELL WHEEL (4 dots at NE/SE/SW/NW around the sigil)
    ------------------------------------------------------------------
    for i = 0, 3 do
        local ang = -PI * 0.75 + i * (PI * 0.5)   -- NW start, then NE, SE, SW
        local wx  = cx + sin(ang) * (sigil_r + 24 * s)
        local wy  = cy - cos(ang) * (sigil_r + 24 * s)
        local sc  = SPELL_COLORS[i]
        local active = (i == spell)
        local dot_r  = active and (4 * s) or (2.6 * s)
        local a      = A(active and 245 or 130)
        draw.rect(wx - dot_r, wy - dot_r, wx + dot_r, wy + dot_r, sc[1], sc[2], sc[3], a, 1)
        if active then
            ring(wx, wy, dot_r + 3 * s, sc[1], sc[2], sc[3], A(150), 1, 16)
        end
    end

    ------------------------------------------------------------------
    -- 3. AMBIENT SPARKLES from the sigil while flying / casting
    ------------------------------------------------------------------
    if f.mounted then
        local rate = f.casting and 0.9 or (f.boosting and 0.55 or 0.18)
        if random() < rate then
            local ang = random() * TAU
            local rr  = sigil_r * (0.6 + random() * 0.38)
            emit(cx + sin(ang) * rr, cy - cos(ang) * rr, sr, sg, sb)
        end
    end
    update_particles(dt)
    draw_particles(fade)

    ------------------------------------------------------------------
    -- 4. CENTRE PENTAGRAM RETICLE when aiming
    ------------------------------------------------------------------
    if f.aiming then
        local rx, ry = sw * 0.5, sh * 0.5
        local pulse  = 1 + sin(now * 4) * 0.08
        local r_out  = 16 * s * pulse
        local r_in   = r_out * 0.42

        ring(rx, ry, r_out + 5 * s, sr, sg, sb, A(120), 1)
        star(rx, ry, r_out, r_in, 5, now * 0.6, sr, sg, sb, A(220), 1.4)
        draw.rect(rx - 1, ry - 1, rx + 1, ry + 1, sr, sg, sb, A(235), 0)

        if f.target then
            local dist = string.format("%.0fm", sm_dist)
            local dw   = text.width(font.tiny, dist)
            text.draw(font.tiny, rx - dw * 0.5, ry + r_out + 8 * s,
                sr, sg, sb, A(230), dist)
            local kind = f.target_player and "SOUL" or "TARGET"
            local kw   = text.width(font.tiny, kind)
            text.draw(font.tiny, rx - kw * 0.5, ry - r_out - 18 * s,
                PARCH_R, PARCH_G, PARCH_B, A(210), kind)
        end
    end

    ------------------------------------------------------------------
    -- 5. CONTROL SCROLL (bottom-centre parchment strip)
    ------------------------------------------------------------------
    if f.controls then
        local hint
        if f.mounted then
            hint = "WASD FLY   " .. BULLET
                .. "   SPACE/CTRL ALTITUDE   " .. BULLET
                .. "   SHIFT BOOST   " .. BULLET
                .. "   AIM+ATTACK CAST   " .. BULLET
                .. "   AIM+RELOAD SPELL"
        else
            hint = "JUMP TO MOUNT THE BROOM"
        end
        local tw = text.width(font.tiny, hint)
        local hx = sw * 0.5 - tw * 0.5
        local hy = sh - 30 * s
        draw.rect(hx - 20 * s, hy - 6 * s, hx + tw + 20 * s, hy + 14 * s,
            INK_R, INK_G, INK_B, A(180), 4)
        for side = -1, 1, 2 do
            local dx = (side == -1) and (hx - 11 * s) or (hx + tw + 11 * s)
            local dy = hy + 4 * s
            star(dx, dy, 4 * s, 1.6 * s, 4, PI * 0.25, sr, sg, sb, A(215), 1)
        end
        text.draw(font.tiny, hx, hy, PARCH_R, PARCH_G, PARCH_B, A(235), hint)
    end
end)
