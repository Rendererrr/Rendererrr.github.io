-- Parking Sensors HUD. Published by veh_parking_sensors::draw while reversing (or creeping forward
-- with Front Sensors on):
--   rear      true = rear bumper, false = front bumper
--   range     sensor range in metres
--   closest   nearest obstacle in metres (anything above range means clear)
--   zones     five comma-separated distances, left to right across the bumper
--   guide     two ground lines "x y v,..." (bumper outwards), separated by "|"; omitted when Guide Lines is off
--   hx, hy    screen position of the nearest obstacle (only when it is in range and on screen)
--   display   Sensor Display toggle

local function level(d, range)
    if d > range then return 0 end
    if d <= range / 3 then return 3 end
    if d <= range * 2 / 3 then return 2 end
    return 1
end

local LEVEL_COL = {
    [1] = { 70, 220, 110 },
    [2] = { 255, 200, 40 },
    [3] = { 255, 60, 50 },
}

local function zones(s)
    local out = {}
    for v in (s or ""):gmatch("([^,]+),") do out[#out + 1] = tonumber(v) end
    return out
end

local function guide_lines(s)
    local lines = {}
    for part in (s or ""):gmatch("([^|]*)|") do
        local pts = {}
        for xs, ys, vs in part:gmatch("([^ ,]+) ([^ ,]+) ([01]),") do
            pts[#pts + 1] = { tonumber(xs), tonumber(ys), vs == "1" }
        end
        lines[#lines + 1] = pts
    end
    return lines
end

local function seg_colour(i, n)
    local t = (i - 0.5) / (n - 1)
    if t < 1 / 3 then return LEVEL_COL[3] end
    if t < 2 / 3 then return LEVEL_COL[2] end
    return LEVEL_COL[1]
end

local function draw_guides(lines, sw, sh)
    if #lines < 2 then return end
    for _, pts in ipairs(lines) do
        local n = #pts
        for i = 1, n - 1 do
            local a, b = pts[i], pts[i + 1]
            if a[3] and b[3] then
                local c = seg_colour(i, n)
                draw.line(a[1] * sw, a[2] * sh, b[1] * sw, b[2] * sh, c[1], c[2], c[3], 70, 9)
                draw.line(a[1] * sw, a[2] * sh, b[1] * sw, b[2] * sh, c[1], c[2], c[3], 235, 3)
            end
        end
    end
    local l, r = lines[1], lines[2]
    local n = math.min(#l, #r)
    for i = 3, n, 2 do
        local a, b = l[i], r[i]
        if a[3] and b[3] then
            local c = seg_colour(i - 1, n)
            local ax, ay, bx, by = a[1] * sw, a[2] * sh, b[1] * sw, b[2] * sh
            local tick = 0.22
            draw.line(ax, ay, ax + (bx - ax) * tick, ay + (by - ay) * tick, c[1], c[2], c[3], 220, 3)
            draw.line(bx, by, bx + (ax - bx) * tick, by + (ay - by) * tick, c[1], c[2], c[3], 220, 3)
        end
    end
end

local function arc(cx, cy, r, a0, a1, cr, cg, cb, ca, th)
    local steps = 4
    local px, py = cx + math.cos(a0) * r, cy + math.sin(a0) * r
    for k = 1, steps do
        local a = a0 + (a1 - a0) * k / steps
        local nx, ny = cx + math.cos(a) * r, cy + math.sin(a) * r
        draw.line(px, py, nx, ny, cr, cg, cb, ca, th)
        px, py = nx, ny
    end
end

local function draw_display(f, zs, sw, sh, now)
    local cx, cy = sw * 0.5, sh - 150
    local w, h = 34, 66
    local panel_w, panel_h = 230, 200
    draw.rect(cx - panel_w * 0.5, cy - panel_h * 0.5, cx + panel_w * 0.5, cy + panel_h * 0.5, 10, 10, 16, 175, 10)

    draw.rect(cx - w * 0.5, cy - h * 0.5, cx + w * 0.5, cy + h * 0.5, 225, 225, 235, 235, 9)
    draw.rect(cx - w * 0.5 + 5, cy - h * 0.5 + 12, cx + w * 0.5 - 5, cy - h * 0.5 + 24, 40, 50, 70, 235, 3)
    draw.rect(cx - w * 0.5 + 5, cy + h * 0.5 - 20, cx + w * 0.5 - 5, cy + h * 0.5 - 11, 40, 50, 70, 235, 3)

    local rear = f.rear
    local oy = rear and (cy + h * 0.5 - 6) or (cy - h * 0.5 + 6)
    local base = rear and math.rad(25) or math.rad(-155)
    local span = math.rad(130)
    local n = #zs
    if n == 0 then return end
    local gap = math.rad(3)
    local range = f.range or 3
    for i = 1, n do
        local zone = rear and zs[n - i + 1] or zs[i]
        local a0 = base + span * (i - 1) / n + gap
        local a1 = base + span * i / n - gap
        local lv = level(zone, range)
        for bar = 1, 3 do
            local r = 22 + bar * 13
            local lit = lv >= (4 - bar)
            if lit then
                local c = LEVEL_COL[lv]
                local pulse = lv == 3 and (0.6 + 0.4 * math.sin(now * 14)) or 1
                arc(cx, oy, r, a0, a1, c[1], c[2], c[3], math.floor(255 * pulse), 7)
            else
                arc(cx, oy, r, a0, a1, 70, 70, 82, 150, 7)
            end
        end
    end

    local closest = f.closest or 99
    local label, lr, lg, lb
    if closest <= 0.3 then
        label, lr, lg, lb = "STOP", 255, 60, 50
    elseif closest <= range then
        local c = LEVEL_COL[level(closest, range)]
        label, lr, lg, lb = string.format("%.1f m", closest), c[1], c[2], c[3]
    else
        label, lr, lg, lb = "CLEAR", 160, 230, 170
    end
    local ty = rear and (cy - panel_h * 0.5 + 8) or (cy + panel_h * 0.5 - 8 - text.height(font.item))
    local tw = text.width(font.item, label)
    text.draw_outlined(font.item, cx - tw * 0.5, ty, lr, lg, lb, 255, 0, 0, 0, 170, 1.5, label)
end

local function draw_hit(f, sw, sh, now)
    if not f.hx then return end
    local range = f.range or 3
    local lv = level(f.closest or 99, range)
    if lv == 0 then return end
    local c = LEVEL_COL[lv]
    local x, y = f.hx * sw, f.hy * sh
    local pulse = (now * 2) % 1
    draw.circle_outline(x, y, 8 + pulse * 18, c[1], c[2], c[3], math.floor(220 * (1 - pulse)), 2)
    draw.circle(x, y, 5, c[1], c[2], c[3], 245)
    draw.circle_outline(x, y, 5, 0, 0, 0, 160, 1.5)
    local label = (f.closest or 0) <= 0.3 and "STOP" or string.format("%.1f m", f.closest)
    text.draw_outlined(font.small, x + 12, y - text.height(font.small) * 0.5, 255, 255, 255, 245, 0, 0, 0, 200, 1.5, label)
end

features.on_draw("Parking Sensors", function(f)
    if not f.active then return end
    local sw, sh = ctx.screen_w(), ctx.screen_h()
    local now = ctx.time()
    if f.guide then draw_guides(guide_lines(f.guide), sw, sh) end
    draw_hit(f, sw, sh, now)
    if f.display then draw_display(f, zones(f.zones), sw, sh, now) end
end)
