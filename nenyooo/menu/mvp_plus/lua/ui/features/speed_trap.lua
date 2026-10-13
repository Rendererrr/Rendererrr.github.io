-- Speed Trap HUD. Published by veh_speed_trap::draw:
--   lx/ly (0..1) = screen point above the trap (missing when off-screen or far), distance (m), best (km/h)
--   result (km/h) + result_age 0..1 + record + delta (km/h) while the clocked reading is showing

local function centered(fnt, cx, y, r, g, b, a, s)
    text.draw(fnt, cx - text.width(fnt, s) * 0.5, y, r, g, b, a, s)
end

local function camera_icon(x, y, a, r, g, b)
    draw.rect(x - 11, y - 7, x + 7, y + 7, r, g, b, a, 3)
    draw.rect(x + 7, y - 4, x + 13, y + 4, r, g, b, a, 1)
    draw.circle(x - 2, y, 4, 10, 10, 16, a)
    draw.circle(x - 2, y, 2, r, g, b, a)
end

local function world_label(f, sw, sh, now)
    if not f.lx then return end
    local d = f.distance or 0
    local a = math.max(0, math.min(1, 1.15 - d / 350))
    if a <= 0.02 then return end
    local x, y = f.lx * sw, f.ly * sh
    local alpha = math.floor(240 * a)

    local title = "SPEED TRAP"
    local sub = f.best and string.format("BEST %d km/h", math.floor(f.best + 0.5)) or "NO RECORD YET"
    local dist = string.format("%d m", math.floor(d + 0.5))
    local w = math.max(text.width(font.small, title), text.width(font.tiny, sub)) + 56
    local h = text.height(font.small) + text.height(font.tiny) + 16
    local x1, y1 = x - w * 0.5, y - h

    draw.rect(x1, y1, x1 + w, y1 + h, 12, 10, 4, math.floor(190 * a), 6)
    camera_icon(x1 + 22, y1 + h * 0.5, alpha, 255, 190, 40)
    text.draw(font.small, x1 + 40, y1 + 6, 255, 255, 255, alpha, title)
    text.draw(font.tiny, x1 + 40, y1 + 8 + text.height(font.small), 255, 205, 110, alpha, sub)
    draw.line(x, y1 + h, x, y1 + h + 14, 255, 190, 40, math.floor(alpha * 0.8), 2)
    centered(font.tiny, x, y1 + h + 16, 220, 220, 230, math.floor(alpha * 0.85), dist)
end

local function reading(f, sw, sh, now)
    local age = f.result_age or 1
    local a = math.min(1, age / 0.05, (1 - age) / 0.15)
    if a <= 0 then return end

    local cx = sw * 0.5
    local w, h = 300, 132
    local pop = 1 + 0.12 * math.max(0, 1 - age / 0.08)
    local x1, y1 = cx - w * 0.5, sh * 0.08

    local hr, hg, hb = 255, 190, 40
    if f.record then hr, hg, hb = 70, 235, 110 end

    draw.rect(x1, y1, x1 + w, y1 + h, 8, 8, 12, math.floor(215 * a), 8)
    draw.rect_outline(x1, y1, x1 + w, y1 + h, hr, hg, hb, math.floor(120 * a), 8, 1.5)
    draw.rect(x1, y1, x1 + w, y1 + 3, hr, hg, hb, math.floor(255 * a), 0)

    local flash = math.max(0, 1 - age / 0.06)
    if flash > 0 then draw.rect(0, 0, sw, sh, 255, 255, 255, math.floor(90 * flash), 0) end

    camera_icon(x1 + 24, y1 + 18, math.floor(230 * a), hr, hg, hb)
    text.draw(font.tiny, x1 + 42, y1 + 11, 200, 200, 210, math.floor(235 * a),
        f.record and "NEW TRAP RECORD" or "CLOCKED")

    draw.with_scale(cx, y1 + 34, 2.0 * pop, function()
        centered(font.display, cx, y1 + 34, 255, 255, 255, math.floor(255 * a),
            string.format("%d", math.floor((f.result or 0) + 0.5)))
    end)
    centered(font.tiny, cx, y1 + 86, 170, 170, 180, math.floor(230 * a), "km/h")

    local line
    local lr, lg, lb = 235, 80, 70
    if f.record then
        if (f.delta or 0) > 0 then line = string.format("+%d km/h over your old best", math.floor(f.delta + 0.5))
        else line = "First reading at this trap" end
        lr, lg, lb = 70, 235, 110
    else
        line = string.format("%d km/h   BEST %d km/h", math.floor((f.delta or 0) + 0.5), math.floor((f.best or 0) + 0.5))
    end
    centered(font.small, cx, y1 + h - text.height(font.small) - 8, lr, lg, lb, math.floor(245 * a), line)
end

features.on_draw("Speed Trap", function(f)
    if not f.active then return end
    local sw, sh = ctx.screen_w(), ctx.screen_h()
    local now = ctx.time()
    world_label(f, sw, sh, now)
    if f.result then reading(f, sw, sh, now) end
end)
