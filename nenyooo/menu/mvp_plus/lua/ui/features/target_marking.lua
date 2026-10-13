-- Target Marking. Published by wep_target_marking::draw while anything is tagged or being locked onto.
--   marks     "on,x,y,bearing,distance,left,age,vehicle;" per tagged target
--             on = above-target point is on screen at (x,y); bearing = degrees clockwise from straight
--             ahead (for the edge arrow when off screen); left 0..1 time remaining; age seconds since tagged
--   ax,ay     target currently being aimed at; progress 0..1 towards tagging it

local RED = { 255, 55, 55 }

local function marks(s)
    local out = {}
    for item in (s or ""):gmatch("([^;]+);") do
        local on, x, y, b, d, left, age, veh = item:match("^([01]),([^,]+),([^,]+),([^,]+),([^,]+),([^,]+),([^,]+),([01])$")
        if on then
            out[#out + 1] = { on = on == "1", x = tonumber(x), y = tonumber(y), bearing = tonumber(b),
                distance = tonumber(d), left = tonumber(left), age = tonumber(age), vehicle = veh == "1" }
        end
    end
    return out
end

local function arc(cx, cy, r, frac, cr, cg, cb, ca, th)
    local steps = 32
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

-- Downward-pointing diamond pin, like a mission target marker.
local function pin(x, y, s, a)
    local r, g, b = RED[1], RED[2], RED[3]
    local top, mid, tip = y - 16 * s, y - 6 * s, y + 4 * s
    local w = 9 * s
    for _, pass in ipairs({ { 0, 0, 0, math.floor(a * 0.6), 6 }, { r, g, b, a, 3 } }) do
        draw.line(x, top, x + w, mid, pass[1], pass[2], pass[3], pass[4], pass[5])
        draw.line(x + w, mid, x, tip, pass[1], pass[2], pass[3], pass[4], pass[5])
        draw.line(x, tip, x - w, mid, pass[1], pass[2], pass[3], pass[4], pass[5])
        draw.line(x - w, mid, x, top, pass[1], pass[2], pass[3], pass[4], pass[5])
    end
    draw.circle(x, mid - 1 * s, 3 * s, r, g, b, a)
end

local function on_screen_mark(m, sw, sh, now)
    local x, y = m.x * sw, m.y * sh
    local s = math.max(0.7, math.min(1.3, 1.3 - m.distance / 200))
    local pop = 1 + 0.6 * math.max(0, 1 - m.age / 0.25)
    local bob = math.sin(now * 3 + m.x * 10) * 3
    local fade = m.left < 0.15 and (0.5 + 0.5 * math.sin(now * 14)) or 1
    local a = math.floor(255 * fade)

    draw.with_scale(x, y, pop, function()
        pin(x, y - 18 + bob, s, a)
        arc(x, y - 24 * s + bob, 16 * s, m.left, RED[1], RED[2], RED[3], math.floor(150 * fade), 2)
        local d = string.format("%dm", math.floor(m.distance + 0.5))
        text.draw_outlined(font.tiny, x - text.width(font.tiny, d) * 0.5, y + 2 + bob, 255, 255, 255, a,
            0, 0, 0, math.floor(a * 0.8), 1.5, d)
    end)

    if m.age < 1.2 then
        local p = m.age / 1.2
        local ta = math.floor(255 * math.min(1, (1 - p) / 0.4))
        local label = "TAGGED"
        text.draw_outlined(font.small, x - text.width(font.small, label) * 0.5, y - 62 - p * 20, RED[1], RED[2], RED[3], ta,
            0, 0, 0, math.floor(ta * 0.8), 2.0, label)
    end
end

local function edge_arrow(m, sw, sh, now)
    local cx, cy = sw * 0.5, sh * 0.5
    local rad = math.rad(m.bearing)
    local rx, ry = sw * 0.42, sh * 0.40
    local x, y = cx + math.sin(rad) * rx, cy - math.cos(rad) * ry
    local ux, uy = math.sin(rad), -math.cos(rad)
    local px, py = -uy, ux
    local pulse = 0.65 + 0.35 * math.sin(now * 6)
    local a = math.floor(240 * pulse)
    local len, w = 16, 10
    local tx, ty = x + ux * len, y + uy * len
    draw.circle(x, y, 15, 10, 10, 16, 180)
    draw.line(x - px * w, y - py * w, tx, ty, RED[1], RED[2], RED[3], a, 3.5)
    draw.line(x + px * w, y + py * w, tx, ty, RED[1], RED[2], RED[3], a, 3.5)
    local d = string.format("%dm", math.floor(m.distance + 0.5))
    text.draw_outlined(font.tiny, x - text.width(font.tiny, d) * 0.5, y + 18, 255, 255, 255, a, 0, 0, 0, 180, 1.5, d)
end

features.on_draw("Target Marking", function(f)
    if not f.active then return end
    local sw, sh = ctx.screen_w(), ctx.screen_h()
    local now = ctx.time()

    for _, m in ipairs(marks(f.marks)) do
        if m.on then on_screen_mark(m, sw, sh, now) else edge_arrow(m, sw, sh, now) end
    end

    if f.ax and f.progress then
        local x, y = f.ax * sw, f.ay * sh
        local p = f.progress
        draw.circle_outline(x, y, 20, 255, 255, 255, 70, 2)
        arc(x, y, 20, p, RED[1], RED[2], RED[3], 255, 3.5)
        local spin = now * 4
        for k = 0, 3 do
            local a = spin + k * math.pi / 2
            local r1, r2 = 26 - 6 * p, 32 - 6 * p
            draw.line(x + math.cos(a) * r1, y + math.sin(a) * r1, x + math.cos(a) * r2, y + math.sin(a) * r2,
                RED[1], RED[2], RED[3], math.floor(120 + 135 * p), 2.5)
        end
    end
end)
