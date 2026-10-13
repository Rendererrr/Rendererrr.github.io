-- Target Scanner. Published by wep_target_scanner::draw while you aim.
--   kind        0 nothing / ground, 1 person, 2 vehicle, 3 object; target = entity id (changes on a new target)
--   label       name (player name, "Pedestrian", vehicle name or "Object"); detail = held weapon or plate
--   distance m, speed m/s, metric; health/armour 0..1 (omitted when unknown); occupants for vehicles
--   hostile     the person is fighting you or hates you; player = it is another player
--   x1,y1,x2,y2 target's screen box (0..1); hx,hy where your aim lands

local last_target, locked_at = nil, 0

local function bar(x, y, w, frac, r, g, b)
    draw.rect(x, y, x + w, y + 5, 40, 40, 48, 230, 2)
    if frac > 0 then draw.rect(x, y, x + w * math.min(1, frac), y + 5, r, g, b, 255, 2) end
end

local function corners(x1, y1, x2, y2, len, r, g, b, a, th)
    draw.line(x1, y1, x1 + len, y1, r, g, b, a, th)
    draw.line(x1, y1, x1, y1 + len, r, g, b, a, th)
    draw.line(x2, y1, x2 - len, y1, r, g, b, a, th)
    draw.line(x2, y1, x2, y1 + len, r, g, b, a, th)
    draw.line(x1, y2, x1 + len, y2, r, g, b, a, th)
    draw.line(x1, y2, x1, y2 - len, r, g, b, a, th)
    draw.line(x2, y2, x2 - len, y2, r, g, b, a, th)
    draw.line(x2, y2, x2, y2 - len, r, g, b, a, th)
end

features.on_draw("Target Scanner", function(f)
    if not f.active then
        last_target = nil
        return
    end
    local sw, sh = ctx.screen_w(), ctx.screen_h()
    local now = ctx.time()
    local ar, ag, ab = theme.accent()
    local kind = f.kind or 0

    local dist = f.distance or 0
    local speed = f.speed or 0
    local dist_txt = f.metric and string.format("%.1f m", dist) or string.format("%.1f yd", dist * 1.0936)
    local speed_txt = f.metric and string.format("%d km/h", math.floor(speed * 3.6 + 0.5))
        or string.format("%d mph", math.floor(speed * 2.237 + 0.5))

    if kind == 0 then
        last_target = nil
        if f.hx then
            local x, y = f.hx * sw, f.hy * sh
            draw.circle_outline(x, y, 6, 255, 255, 255, 160, 1.5)
            text.draw_outlined(font.tiny, x + 12, y - text.height(font.tiny) * 0.5, 230, 230, 235, 230, 0, 0, 0, 170, 1.5, dist_txt)
        end
        return
    end

    if f.target ~= last_target then
        last_target = f.target
        locked_at = now
    end
    local lock = math.min(1, (now - locked_at) / 0.18)
    local ease = 1 - (1 - lock) ^ 3

    local cr, cg, cb = ar, ag, ab
    if f.hostile then cr, cg, cb = 255, 60, 50 end

    local x1, y1, x2, y2
    if f.x1 then
        x1, y1, x2, y2 = f.x1 * sw, f.y1 * sh, f.x2 * sw, f.y2 * sh
    else
        local x, y = (f.hx or 0.5) * sw, (f.hy or 0.5) * sh
        x1, y1, x2, y2 = x - 30, y - 30, x + 30, y + 30
    end
    local pad = 6 + 26 * (1 - ease)
    x1, y1, x2, y2 = x1 - pad, y1 - pad, x2 + pad, y2 + pad
    local len = math.max(10, math.min(28, math.min(x2 - x1, y2 - y1) * 0.25))
    local alpha = math.floor(255 * ease)
    corners(x1, y1, x2, y2, len, 0, 0, 0, math.floor(alpha * 0.5), 5)
    corners(x1, y1, x2, y2, len, cr, cg, cb, alpha, 2.5)
    if lock < 1 then
        draw.rect_outline(x1, y1, x2, y2, cr, cg, cb, math.floor(120 * (1 - lock)), 0, 1.5)
    end

    local title = f.label or ""
    local rows = {}
    rows[#rows + 1] = { "DIST", dist_txt }
    if kind == 1 or kind == 2 then rows[#rows + 1] = { "SPEED", speed_txt } end
    if kind == 1 and f.detail then rows[#rows + 1] = { "WEAPON", f.detail } end
    if kind == 2 and f.detail then rows[#rows + 1] = { "PLATE", f.detail } end
    if kind == 2 and f.occupants then rows[#rows + 1] = { "ON BOARD", string.format("%d", f.occupants) } end

    local lw = 0
    for _, r in ipairs(rows) do lw = math.max(lw, text.width(font.tiny, r[1])) end
    local vw = 0
    for _, r in ipairs(rows) do vw = math.max(vw, text.width(font.tiny, r[2])) end
    local tag = nil
    if f.hostile then tag = "HOSTILE" elseif f.player then tag = "PLAYER" end
    local tw = text.width(font.small, title) + (tag and text.width(font.tiny, tag) + 22 or 0)
    local w = math.max(tw, lw + vw + 18, 150) + 24
    local rh = text.height(font.tiny) + 5
    local bars = (f.health and 1 or 0) + (f.armour and 1 or 0)
    local h = 12 + text.height(font.small) + 6 + #rows * rh + bars * 14 + 8

    local px = x2 + 12
    if px + w > sw - 10 then px = x1 - 12 - w end
    local py = math.max(10, math.min(sh - h - 10, y1))
    local slide = (1 - ease) * 18
    px = px + (px > x2 and slide or -slide)

    draw.rect(px, py, px + w, py + h, 10, 10, 16, math.floor(215 * ease), 6)
    local cy = py + 10
    text.draw(font.small, px + 12, cy, 255, 255, 255, alpha, title)
    if tag then
        local tx = px + 12 + text.width(font.small, title) + 10
        local tagw = text.width(font.tiny, tag) + 10
        local th = text.height(font.tiny) + 4
        local ty = cy + (text.height(font.small) - th) * 0.5
        draw.rect(tx, ty, tx + tagw, ty + th, cr, cg, cb, math.floor(230 * ease), 3)
        text.draw(font.tiny, tx + 5, ty + 2, 255, 255, 255, alpha, tag)
    end
    cy = cy + text.height(font.small) + 6

    for _, r in ipairs(rows) do
        text.draw(font.tiny, px + 12, cy, 150, 150, 165, alpha, r[1])
        text.draw(font.tiny, px + 12 + lw + 14, cy, 235, 235, 240, alpha, r[2])
        cy = cy + rh
    end

    local bw = w - 24
    if f.health then
        local hp = math.max(0, math.min(1, f.health))
        bar(px + 12, cy + 4, bw, hp, math.floor(255 * (1 - hp) + 40 * hp), math.floor(60 + 160 * hp), 60)
        cy = cy + 14
    end
    if f.armour then
        bar(px + 12, cy + 4, bw, f.armour, 80, 160, 255)
    end

    if f.hx then
        local x, y = f.hx * sw, f.hy * sh
        local pulse = 0.6 + 0.4 * math.sin(now * 10)
        draw.circle(x, y, 3, cr, cg, cb, math.floor(255 * pulse))
    end
end)
