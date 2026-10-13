-- Stunt Ramps placement preview. Published by veh_stunt_ramps::preview_draw while the Stunt Ramps page
-- is open with Show Preview on. A see-through copy of the ramp already sits in the world; this script
-- adds its ground outline, the run-up from your car and the jump direction.
--   points    nine "x y v," screen points: 1-4 ramp footprint corners, 5 run-up start (in front of you),
--             6 low edge (where you drive on), 7 high edge (where you take off), 8 arrow tip, 9 label
--   ready     false while the ramp's direction is still being worked out
--   size      size name, distance (m), rotation (degrees)

local function points(s)
    local pts = {}
    for xs, ys, vs in (s or ""):gmatch("([^ ,]+) ([^ ,]+) ([01]),") do
        pts[#pts + 1] = { tonumber(xs), tonumber(ys), vs == "1" }
    end
    return pts
end

local function seg(a, b, sw, sh, r, g, bl, al, th)
    if not (a and b and a[3] and b[3]) then return end
    draw.line(a[1] * sw, a[2] * sh, b[1] * sw, b[2] * sh, r, g, bl, math.floor(al * 0.3), th + 6)
    draw.line(a[1] * sw, a[2] * sh, b[1] * sw, b[2] * sh, r, g, bl, al, th)
end

local function dashed(a, b, sw, sh, r, g, bl, al, now)
    if not (a and b and a[3] and b[3]) then return end
    local x1, y1, x2, y2 = a[1] * sw, a[2] * sh, b[1] * sw, b[2] * sh
    local len = math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
    if len < 1 then return end
    local ux, uy = (x2 - x1) / len, (y2 - y1) / len
    local dash, gap = 14, 10
    local d = -((now * 40) % (dash + gap))
    while d < len do
        local s0, s1 = math.max(0, d), math.min(len, d + dash)
        if s1 > s0 then
            draw.line(x1 + ux * s0, y1 + uy * s0, x1 + ux * s1, y1 + uy * s1, r, g, bl, al, 3)
        end
        d = d + dash + gap
    end
end

local function arrow(tail, tip, sw, sh, r, g, bl, al, now)
    if not (tail and tip and tail[3] and tip[3]) then return end
    local x1, y1, x2, y2 = tail[1] * sw, tail[2] * sh, tip[1] * sw, tip[2] * sh
    local len = math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
    if len < 4 then return end
    local ux, uy = (x2 - x1) / len, (y2 - y1) / len
    local px, py = -uy, ux
    for k = 0, 2 do
        local t = ((now * 1.2) + k / 3) % 1
        local cx, cy = x1 + ux * len * t, y1 + uy * len * t
        local w = math.max(6, len * 0.12)
        local a = math.floor(al * math.sin(t * math.pi))
        draw.line(cx - ux * w + px * w, cy - uy * w + py * w, cx, cy, r, g, bl, a, 4)
        draw.line(cx - ux * w - px * w, cy - uy * w - py * w, cx, cy, r, g, bl, a, 4)
    end
    local w = math.max(9, len * 0.16)
    draw.line(x2 - ux * w + px * w, y2 - uy * w + py * w, x2, y2, r, g, bl, al, 5)
    draw.line(x2 - ux * w - px * w, y2 - uy * w - py * w, x2, y2, r, g, bl, al, 5)
end

local function label(p, f, sw, sh, ar, ag, ab)
    if not (p and p[3]) then return end
    local x, y = p[1] * sw, p[2] * sh
    local title = string.upper((f.size or "") .. " RAMP")
    local sub
    if f.ready then
        sub = string.format("%d m ahead   %d DEG", math.floor((f.distance or 0) + 0.5), math.floor((f.rotation or 0) + 0.5))
    else
        sub = "Finding the ramp's direction..."
    end
    local w = math.max(text.width(font.small, title), text.width(font.tiny, sub)) + 28
    local h = text.height(font.small) + text.height(font.tiny) + 14
    local x1, y1 = x - w * 0.5, y - h
    draw.rect(x1, y1, x1 + w, y1 + h, 10, 10, 16, 200, 6)
    text.draw(font.small, x1 + 14, y1 + 5, 255, 255, 255, 245, title)
    text.draw(font.tiny, x1 + 14, y1 + 7 + text.height(font.small), 200, 200, 210, 235, sub)
end

features.on_draw("Stunt Ramps", function(f)
    if not f.active then return end
    local sw, sh = ctx.screen_w(), ctx.screen_h()
    local now = ctx.time()
    local ar, ag, ab = theme.accent()
    local pts = points(f.points)
    if #pts < 9 then return end

    local pulse = 0.75 + 0.25 * math.sin(now * 4)
    for i = 1, 4 do
        seg(pts[i], pts[(i % 4) + 1], sw, sh, ar, ag, ab, math.floor(235 * pulse), 2.5)
    end

    dashed(pts[5], pts[6], sw, sh, 255, 255, 255, 190, now)
    seg(pts[6], pts[7], sw, sh, 90, 230, 120, 230, 3)
    arrow(pts[7], pts[8], sw, sh, 255, 200, 40, 240, now)
    label(pts[9], f, sw, sh, ar, ag, ab)
end)
