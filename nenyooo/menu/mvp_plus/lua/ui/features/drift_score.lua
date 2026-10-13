-- Drift Score HUD. Published by veh_drift_score::draw:
--   live (a drift is in progress), sliding, score, mult (1..5), mult_progress 0..1, angle (signed deg)
--   chain_left 0..1 (time left to resume before the drift banks), best
--   result + rating (0 nice .. 4 legendary) + result_age 0..1 + new_best + failed after a drift ends

local RATINGS = {
    [0] = { "NICE DRIFT", 220, 220, 230 },
    [1] = { "GOOD DRIFT", 120, 200, 255 },
    [2] = { "GREAT DRIFT", 70, 235, 110 },
    [3] = { "INSANE DRIFT", 255, 140, 40 },
    [4] = { "LEGENDARY DRIFT", 255, 200, 60 },
}

local shown = 0

local function commas(n)
    local s = tostring(math.floor(n + 0.5))
    local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    return (out:gsub("^,", ""))
end

local function centered(fnt, cx, y, r, g, b, a, s)
    text.draw(fnt, cx - text.width(fnt, s) * 0.5, y, r, g, b, a, s)
end

local function arc(x, y, rad, from, to, r, g, b, a, th)
    local steps = math.max(2, math.floor(math.abs(to - from) / math.pi * 32))
    local px, py = x + math.cos(from) * rad, y + math.sin(from) * rad
    for i = 1, steps do
        local t = from + (to - from) * i / steps
        local nx, ny = x + math.cos(t) * rad, y + math.sin(t) * rad
        draw.line(px, py, nx, ny, r, g, b, a, th)
        px, py = nx, ny
    end
end

local function live_panel(f, sw, sh, ar, ag, ab, now)
    local cx, cy = sw * 0.5, sh * 0.80
    local score = f.score or 0
    shown = shown + (score - shown) * 0.35
    if score < shown then shown = score end

    -- Angle gauge: a half ring with a needle that swings with the slide.
    local rad = 70
    local base = math.pi
    arc(cx, cy, rad, base, base + math.pi, 255, 255, 255, 45, 6)
    local ang = math.max(-90, math.min(90, f.angle or 0))
    local t = (ang + 90) / 180
    local hot = math.min(1, math.abs(ang) / 60)
    local nr = math.floor(ar + (255 - ar) * hot)
    local ng = math.floor(ag + (120 - ag) * hot)
    local nb = math.floor(ab + (40 - ab) * hot)
    local mid = base + math.pi * 0.5
    local tip = base + math.pi * t
    arc(cx, cy, rad, math.min(mid, tip), math.max(mid, tip), nr, ng, nb, 235, 6)
    draw.line(cx, cy, cx + math.cos(tip) * (rad - 10), cy + math.sin(tip) * (rad - 10), 255, 255, 255, 235, 2.5)
    draw.circle(cx, cy, 5, 255, 255, 255, 235)
    centered(font.tiny, cx, cy + 8, 200, 200, 210, 220, string.format("%d DEG", math.floor(math.abs(ang) + 0.5)))

    -- Score above the gauge.
    local label = f.sliding and "DRIFT" or "CHAIN"
    local sy = cy - rad - 78
    centered(font.tiny, cx, sy - 14, 200, 200, 210, 235, label)
    draw.with_scale(cx, sy, 1.6, function()
        centered(font.display, cx, sy, 255, 255, 255, 255, commas(shown))
    end)

    -- Multiplier badge with a ring that fills toward the next step.
    local mx, my = cx + rad + 44, cy - 20
    local mult = math.floor(f.mult or 1)
    draw.circle(mx, my, 22, 10, 10, 16, 210)
    arc(mx, my, 22, -math.pi * 0.5, -math.pi * 0.5 + math.pi * 2, 255, 255, 255, 40, 3)
    arc(mx, my, 22, -math.pi * 0.5, -math.pi * 0.5 + math.pi * 2 * (f.mult_progress or 0), ar, ag, ab, 240, 3)
    centered(font.small, mx, my - text.height(font.small) * 0.5, 255, 255, 255, 250, "x" .. mult)

    -- Chain timer: drains while you are straight; slide again before it empties.
    if not f.sliding then
        local left = math.max(0, math.min(1, f.chain_left or 0))
        local w = 200
        local by = cy + 30
        local r, g, b = 255, math.floor(80 + 120 * left), 40
        draw.rect(cx - w * 0.5, by, cx + w * 0.5, by + 5, 40, 40, 48, 220, 2)
        draw.rect(cx - w * 0.5, by, cx - w * 0.5 + w * left, by + 5, r, g, b, 245, 2)
        local pulse = 0.6 + 0.4 * math.sin(now * 12)
        centered(font.tiny, cx, by + 8, r, g, b, math.floor(240 * pulse), "SLIDE AGAIN TO KEEP THE CHAIN")
    end
end

local function result_banner(f, sw, sh, now)
    local age = f.result_age or 1
    local a = math.min(1, age / 0.04, (1 - age) / 0.15)
    if a <= 0 then return end
    local cx = sw * 0.5
    local y = sh * 0.14 - (1 - math.min(1, age / 0.06)) * 16
    local pop = 1 + 0.15 * math.max(0, 1 - age / 0.08)

    local title, r, g, b
    if f.failed then
        title, r, g, b = "DRIFT FAILED", 235, 60, 60
    else
        local rt = RATINGS[math.floor(f.rating or 0)] or RATINGS[0]
        title, r, g, b = rt[1], rt[2], rt[3], rt[4]
    end

    draw.with_scale(cx, y, 1.4 * pop, function()
        text.draw_outlined(font.display, cx - text.width(font.display, title) * 0.5, y,
            r, g, b, math.floor(255 * a), 0, 0, 0, math.floor(200 * a), 2.0, title)
    end)

    local score = commas(f.result or 0)
    local sy = y + text.height(font.display) * 1.4 + 6
    local sw2 = text.width(font.item, score)
    text.draw_outlined(font.item, cx - sw2 * 0.5, sy, 255, 255, 255, math.floor(250 * a), 0, 0, 0, math.floor(180 * a), 1.5, score)
    if f.failed then
        draw.line(cx - sw2 * 0.5 - 4, sy + text.height(font.item) * 0.55, cx + sw2 * 0.5 + 4, sy + text.height(font.item) * 0.55, 235, 60, 60, math.floor(240 * a), 2.5)
    end

    local line_y = sy + text.height(font.item) + 6
    if f.new_best then
        local pulse = 0.75 + 0.25 * math.sin(now * 8)
        centered(font.small, cx, line_y, 255, 200, 60, math.floor(255 * a * pulse), "NEW BEST")
    elseif f.failed then
        centered(font.small, cx, line_y, 235, 140, 130, math.floor(235 * a), "You hit something; points lost")
    elseif f.best then
        centered(font.small, cx, line_y, 200, 200, 210, math.floor(230 * a), "BEST " .. commas(f.best))
    end
end

features.on_draw("Drift Score", function(f)
    if not f.active then
        shown = 0
        return
    end
    local sw, sh = ctx.screen_w(), ctx.screen_h()
    local ar, ag, ab = theme.accent()
    local now = ctx.time()
    if f.live then live_panel(f, sw, sh, ar, ag, ab, now) else shown = 0 end
    if f.result then result_banner(f, sw, sh, now) end
end)
