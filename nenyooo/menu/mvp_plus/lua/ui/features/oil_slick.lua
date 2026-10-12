-- Oil Slick HUD. Published by veh_oil_slick::draw as one blob per slick:
--   "label_on,lx,ly,left,seconds,distance,hits,hit_age|x y v,x y v,...;"
-- left 0..1 is the time remaining, hit_age 0..1 while a "spun out" flash is playing (-1 otherwise),
-- and the ring points trace the slick's edge on the ground (v = 1 when on screen).

local NAME, HIT_TEXT = "OIL SLICK", "SPUN OUT!"
local CR, CG, CB = 150, 90, 255

local function ring_points(s)
    local pts = {}
    for xs, ys, vs in s:gmatch("([^ ,]+) ([^ ,]+) ([01]),") do
        pts[#pts + 1] = { tonumber(xs), tonumber(ys), vs == "1" }
    end
    return pts
end

local function draw_ring(pts, sw, sh, left, alpha, flash)
    local n = #pts
    if n < 3 then return end
    local lit = math.floor(left * n + 0.5)
    for i = 1, n do
        local a, b = pts[i], pts[(i % n) + 1]
        if a[3] and b[3] then
            local on = i <= lit
            local r, g, bl = CR, CG, CB
            local al = on and alpha or math.floor(alpha * 0.25)
            if flash > 0 then r, g, bl = 255, 255, 255 al = math.floor(alpha * (0.4 + 0.6 * flash)) end
            draw.line(a[1] * sw, a[2] * sh, b[1] * sw, b[2] * sh, r, g, bl, math.floor(al * 0.35), 8)
            draw.line(a[1] * sw, a[2] * sh, b[1] * sw, b[2] * sh, r, g, bl, al, 2.5)
        end
    end
end

local function icon(x, y, a)
    draw.circle(x, y + 2, 7, CR, CG, CB, a)
    draw.line(x - 4, y - 2, x, y - 9, CR, CG, CB, a, 3)
    draw.line(x + 4, y - 2, x, y - 9, CR, CG, CB, a, 3)
    draw.circle(x - 2, y, 2, 255, 255, 255, math.floor(a * 0.7))
end

local function label(it, sw, sh, now)
    local x, y = it.lx * sw, it.ly * sh
    local fade = math.max(0, math.min(1, 1.2 - it.distance / 150))
    if fade <= 0.02 then return end
    local a = math.floor(240 * fade)
    local urgent = it.left < 0.25
    local secs = string.format("%d s", math.max(0, math.ceil(it.seconds)))
    local sub = it.hits > 0 and string.format("%s   %d CAUGHT", secs, it.hits) or secs

    local w = math.max(text.width(font.small, NAME), text.width(font.tiny, sub)) + 50
    local h = text.height(font.small) + text.height(font.tiny) + 14
    local x1, y1 = x - w * 0.5, y - h
    draw.rect(x1, y1, x1 + w, y1 + h, 10, 8, 16, math.floor(185 * fade), 6)
    local br = urgent and (0.5 + 0.5 * math.sin(now * 12)) or 1
    draw.rect(x1, y1 + h - 3, x1 + w * math.max(0, it.left), y1 + h, CR, CG, CB, math.floor(a * br), 0)
    icon(x1 + 18, y1 + h * 0.5, a)
    text.draw(font.small, x1 + 34, y1 + 5, 255, 255, 255, a, NAME)
    local sr, sg, sb = 210, 210, 220
    if urgent then sr, sg, sb = 255, 140, 120 end
    text.draw(font.tiny, x1 + 34, y1 + 7 + text.height(font.small), sr, sg, sb, a, sub)

    if it.hit_age >= 0 then
        local p = it.hit_age
        local pop = 1 + 0.4 * math.max(0, 1 - p / 0.15)
        local ha = math.floor(255 * math.min(1, (1 - p) / 0.3))
        draw.with_scale(x, y1 - 26, pop, function()
            local tw = text.width(font.item, HIT_TEXT)
            text.draw_outlined(font.item, x - tw * 0.5, y1 - 26 - p * 18, 255, 255, 255, ha, CR, CG, CB, ha, 2.0, HIT_TEXT)
        end)
    end
end

features.on_draw("Oil Slick", function(f)
    if not f.active or not f.slicks or f.slicks == "" then return end
    local sw, sh = ctx.screen_w(), ctx.screen_h()
    local now = ctx.time()
    for item in f.slicks:gmatch("([^;]+);") do
        local head, ring = item:match("^([^|]*)|(.*)$")
        if head then
            local on, lx, ly, left, secs, dist, hits, hit_age = head:match(
                "^([01]),([^,]+),([^,]+),([^,]+),([^,]+),([^,]+),([^,]+),([^,]+)$")
            if on then
                local it = {
                    lx = tonumber(lx), ly = tonumber(ly), left = tonumber(left), seconds = tonumber(secs),
                    distance = tonumber(dist), hits = tonumber(hits), hit_age = tonumber(hit_age),
                }
                local fade = math.max(0, math.min(1, 1.2 - it.distance / 150))
                local flash = it.hit_age >= 0 and (1 - it.hit_age) or 0
                local pulse = it.left < 0.25 and (0.55 + 0.45 * math.sin(now * 12)) or 1
                draw_ring(ring_points(ring), sw, sh, it.left, math.floor(230 * fade * pulse), flash)
                if on == "1" then label(it, sw, sh, now) end
            end
        end
    end
end)
