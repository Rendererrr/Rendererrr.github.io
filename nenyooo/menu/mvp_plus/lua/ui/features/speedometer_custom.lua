-- Custom Speedometer. C++ publishes vehicle telemetry only; this file owns the visual.
-- The gauge is deliberately screen-space: a real dial, moving needle, graduated arc,
-- gear/engine readouts, and animated flame tongues driven by road speed and RPM.

local sin, cos, pi = math.sin, math.cos, math.pi
local floor, min, max = math.floor, math.min, math.max

local START = pi * 0.75
local SWEEP = pi * 1.50
local smooth_ratio = 0
local smooth_rpm = 0
local smooth_speed = 0
local last_t = ctx.time and ctx.time() or 0

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function point(cx, cy, radius, angle)
    return cx + cos(angle) * radius, cy + sin(angle) * radius
end

local function centered(fnt, cx, y, value, r, g, b, a)
    text.draw(fnt, cx - text.width(fnt, value) * 0.5, y, r, g, b, a, value)
end

local function arc_line(cx, cy, radius, a0, a1, r, g, b, a, thickness)
    local x0, y0 = point(cx, cy, radius, a0)
    local x1, y1 = point(cx, cy, radius, a1)
    draw.line(x0, y0, x1, y1, r, g, b, a, thickness)
end

local function fire_color(t)
    if t < 0.45 then
        return 255, floor(180 + t * 110), 35
    end
    return 255, floor(230 - (t - 0.45) * 300), 20
end

local function draw_flames(cx, cy, radius, heat, now, scale)
    if heat < 0.025 then return end
    local count = 30
    for i = 0, count - 1 do
        local f = i / (count - 1)
        local angle = START + SWEEP * f
        local wave = 0.55 + 0.45 * sin(now * (8.0 + (i % 5)) + i * 2.17)
        local flare = 0.35 + 0.65 * sin(pi * f)
        local length = (3 + 25 * heat * wave * flare) * scale
        local wobble = sin(now * 11.0 + i * 1.63) * 0.045 * heat
        local bx, by = point(cx, cy, radius + 3 * scale, angle)
        local mx, my = point(cx, cy, radius + length * 0.56, angle + wobble)
        local tx, ty = point(cx, cy, radius + length, angle - wobble * 0.45)
        local cr, cg, cb = fire_color(f)
        local alpha = floor(85 + 150 * heat * wave)

        -- Red body, orange core and a small hot tip make each streak read as flame,
        -- instead of a plain radial equalizer bar.
        draw.line(bx, by, mx, my, 235, 45, 8, alpha, 4.8 * scale)
        draw.line(mx, my, tx, ty, cr, cg, cb, alpha, 2.6 * scale)
        draw.line(bx, by, mx, my, 255, 205, 55, floor(alpha * 0.72), 1.25 * scale)
        if wave > 0.82 then
            draw.circle(tx, ty, 1.7 * scale, 255, 225, 105, floor(alpha * 0.55))
        end
    end
end

features.on_draw("Custom Speedometer", function(f)
    if not f.enabled or not f.active then return end

    local now = ctx.time and ctx.time() or 0
    local dt = clamp(now - last_t, 0.001, 0.10)
    last_t = now

    local speed = max(0, f.speed or 0)
    local maximum = max(1, f.max_speed or 1)
    local target_ratio = clamp(speed / maximum, 0, 1)
    local target_rpm = clamp(f.rpm or 0, 0, 1)
    local follow = min(1, dt * 8.5)
    smooth_ratio = smooth_ratio + (target_ratio - smooth_ratio) * follow
    smooth_rpm = smooth_rpm + (target_rpm - smooth_rpm) * follow
    smooth_speed = smooth_speed + (speed - smooth_speed) * min(1, dt * 12)

    local scale = clamp(ctx.screen_h() / 1080, 0.72, 1.35)
    local radius = 118 * scale
    local cx = ctx.screen_w() - 154 * scale
    local cy = ctx.screen_h() - 154 * scale
    local heat = clamp(max(smooth_rpm * 0.90, smooth_ratio), 0, 1)
    local pulse = 0.5 + 0.5 * sin(now * 5.5)

    -- Flame aura is behind the instrument so the bezel and values remain crisp.
    draw_flames(cx, cy, radius, heat, now, scale)
    draw.circle(cx + 4 * scale, cy + 7 * scale, radius + 12 * scale, 0, 0, 0, 105)
    draw.circle(cx, cy, radius + 7 * scale, 12, 8, 7, 235)
    draw.circle_outline(cx, cy, radius + 6 * scale, 255, 74, 12,
                        floor(125 + heat * 100 + pulse * 20), 2.2 * scale)
    draw.circle(cx, cy, radius - 2 * scale, 8, 11, 15, 245)
    draw.circle(cx, cy - 9 * scale, radius - 17 * scale, 15, 19, 25, 235)

    -- Graduated 270-degree dial. Active segments heat from amber to red near the limiter.
    local segments = 72
    for i = 0, segments - 1 do
        local f0 = i / segments
        local f1 = (i + 0.72) / segments
        local a0 = START + SWEEP * f0
        local a1 = START + SWEEP * f1
        if f0 <= smooth_ratio then
            local rr, gg, bb = fire_color(f0)
            arc_line(cx, cy, radius - 12 * scale, a0, a1, rr, gg, bb, 245, 4.2 * scale)
        else
            arc_line(cx, cy, radius - 12 * scale, a0, a1, 48, 53, 61, 210, 2.2 * scale)
        end
    end

    -- Major/minor ticks and six numeric references around the face.
    for i = 0, 30 do
        local f0 = i / 30
        local angle = START + SWEEP * f0
        local major = (i % 5) == 0
        local outer = radius - 21 * scale
        local inner = outer - (major and 12 or 6) * scale
        local x0, y0 = point(cx, cy, outer, angle)
        local x1, y1 = point(cx, cy, inner, angle)
        local hot = f0 <= smooth_ratio
        draw.line(x0, y0, x1, y1,
                  hot and 255 or 105, hot and 158 or 112, hot and 28 or 122,
                  major and 245 or 185, major and 2.0 * scale or 1.0 * scale)

        if major then
            local value = tostring(floor((maximum * f0) / 10 + 0.5) * 10)
            local lx, ly = point(cx, cy, radius - 43 * scale, angle)
            text.draw(font.small, lx - text.width(font.small, value) * 0.5,
                      ly - 6 * scale, 154, 162, 174, 220, value)
        end
    end

    -- Needle: shadow, hot body, white cap and a short counterweight.
    local needle_angle = START + SWEEP * smooth_ratio
    local nx, ny = point(cx, cy, radius - 38 * scale, needle_angle)
    local bx, by = point(cx, cy, 17 * scale, needle_angle + pi)
    draw.line(bx + 2 * scale, by + 2 * scale, nx + 2 * scale, ny + 2 * scale,
              0, 0, 0, 180, 5.0 * scale)
    draw.line(bx, by, nx, ny, 255, 72, 16, 255, 3.4 * scale)
    draw.line(cx, cy, nx, ny, 255, 210, 88, 225, 1.2 * scale)
    draw.circle(cx, cy, 10 * scale, 24, 27, 32, 255)
    draw.circle_outline(cx, cy, 10 * scale, 255, 106, 20, 255, 2.0 * scale)
    draw.circle(cx, cy, 3.5 * scale, 244, 245, 248, 255)

    -- Digital core supplements the analogue dial; it is not the whole speedometer.
    local shown = tostring(floor(smooth_speed + 0.5))
    centered(font.title, cx, cy + 24 * scale, shown, 245, 247, 250, 255)
    centered(font.small, cx, cy + 54 * scale, f.metric and "KPH" or "MPH",
             255, 132, 28, 245)

    local gear = floor(f.gear or 0)
    local gear_text = gear < 0 and "R" or (gear == 0 and "N" or tostring(gear))
    draw.circle(cx, cy + 80 * scale, 15 * scale, 18, 20, 24, 245)
    draw.circle_outline(cx, cy + 80 * scale, 15 * scale,
                        smooth_rpm > 0.84 and 255 or 255,
                        smooth_rpm > 0.84 and 45 or 126,
                        smooth_rpm > 0.84 and 18 or 20, 245, 1.7 * scale)
    centered(font.item, cx, cy + 70 * scale, gear_text, 248, 249, 252, 255)

    local rpm_text = string.format("RPM  %d%%", floor(smooth_rpm * 100 + 0.5))
    centered(font.small, cx, cy + 100 * scale, rpm_text, 139, 146, 158, 210)

    -- Engine-health strip closes the open bottom of the dial.
    local health = clamp(f.engine_health or 0, 0, 1)
    local bar_w = 86 * scale
    local bar_y = cy + 116 * scale
    draw.rect(cx - bar_w * 0.5, bar_y, cx + bar_w * 0.5, bar_y + 3 * scale,
              42, 45, 51, 220, 1.5 * scale)
    local hr = health < 0.35 and 255 or 255
    local hg = health < 0.35 and 52 or 135
    draw.rect(cx - bar_w * 0.5, bar_y,
              cx - bar_w * 0.5 + bar_w * health, bar_y + 3 * scale,
              hr, hg, 24, 245, 1.5 * scale)
end)
