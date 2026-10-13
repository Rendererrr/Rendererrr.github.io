-- Charged Jump HUD. Published by self_charged_jump::draw: charge 0..1, full, height (m), and
-- normalized screen points for the feet (fx/fy), chest (cx/cy), current apex (ax/ay) and max apex
-- (mx/my). flash (0..1) is the launch shockwave. Missing points are off-screen.

local function arc(x, y, r, from, to, cr, cg, cb, ca, th)
    local steps = math.max(2, math.floor(math.abs(to - from) / (math.pi * 2) * 56))
    local px, py = x + math.cos(from) * r, y + math.sin(from) * r
    for i = 1, steps do
        local a = from + (to - from) * i / steps
        local nx, ny = x + math.cos(a) * r, y + math.sin(a) * r
        draw.line(px, py, nx, ny, cr, cg, cb, ca, th)
        px, py = nx, ny
    end
end

local function dashed(x1, y1, x2, y2, cr, cg, cb, ca, th, dash, gap)
    local dx, dy = x2 - x1, y2 - y1
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 1 then return end
    local ux, uy = dx / len, dy / len
    local d = 0
    while d < len do
        local e = math.min(d + dash, len)
        draw.line(x1 + ux * d, y1 + uy * d, x1 + ux * e, y1 + uy * e, cr, cg, cb, ca, th)
        d = e + gap
    end
end

local function lerp(a, b, t) return a + (b - a) * t end

features.on_draw("Charged Jump", function(f)
    if not f.active then return end

    local sw, sh = ctx.screen_w(), ctx.screen_h()
    local ar, ag, ab = theme.accent()
    local now = ctx.time()

    if f.flash and f.fx then
        local p = f.flash
        local x, y = f.fx * sw, f.fy * sh
        local fade = 1 - p
        local r = 24 + 110 * (1 - fade * fade)
        draw.circle_outline(x, y, r, ar, ag, ab, math.floor(230 * fade), 1 + 4 * fade)
        draw.circle_outline(x, y, r * 0.62, 255, 255, 255, math.floor(150 * fade), 1.5)
    end

    if not f.charging then return end

    local c = math.max(0, math.min(1, f.charge or 0))
    local pulse = f.full and (0.5 + 0.5 * math.sin(now * 14)) or 0
    local cr = math.floor(lerp(ar, 255, pulse * 0.7))
    local cg = math.floor(lerp(ag, 255, pulse * 0.7))
    local cb = math.floor(lerp(ab, 255, pulse * 0.7))

    -- Height guide: a faint dashed rail to the max apex, a solid bar to the current apex.
    if f.fx and f.mx then
        local fx, fy = f.fx * sw, f.fy * sh
        dashed(fx, fy, f.mx * sw, f.my * sh, 255, 255, 255, 70, 1.5, 6, 6)
        local tx, ty = f.mx * sw, f.my * sh
        draw.line(tx - 7, ty, tx + 7, ty, 255, 255, 255, 90, 1.5)
    end
    if f.fx and f.ax then
        local fx, fy = f.fx * sw, f.fy * sh
        local tx, ty = f.ax * sw, f.ay * sh
        draw.line(fx, fy, tx, ty, cr, cg, cb, 70, 7)
        draw.line(fx, fy, tx, ty, cr, cg, cb, 235, 2.5)

        -- Apex chevron + height readout.
        local w = 11 + 3 * pulse
        draw.line(tx - w, ty + w * 0.6, tx, ty, cr, cg, cb, 245, 2.5)
        draw.line(tx, ty, tx + w, ty + w * 0.6, cr, cg, cb, 245, 2.5)
        local label = string.format("%d m", math.floor((f.height or 0) + 0.5))
        text.draw_outlined(font.small, tx + w + 6, ty - text.height(font.small) * 0.5,
            255, 255, 255, 240, 0, 0, 0, 170, 1.0, label)
    end

    -- Feet ring that tightens as the charge builds.
    if f.fx then
        local x, y = f.fx * sw, f.fy * sh
        local r = lerp(46, 18, c)
        draw.circle_outline(x, y, r, cr, cg, cb, math.floor(80 + 140 * c), 2)
        if f.full then
            draw.circle_outline(x, y, r + 6 + 8 * pulse, cr, cg, cb, math.floor(120 * (1 - pulse)), 2)
        end
    end

    -- Radial gauge beside the player.
    if f.cx then
        local x, y = f.cx * sw + 70, f.cy * sh
        local r = 22
        local start = -math.pi * 0.5
        draw.circle(x, y, r + 7, 10, 10, 16, 190)
        arc(x, y, r, 0, math.pi * 2, 255, 255, 255, 40, 4)
        if c > 0 then arc(x, y, r, start, start + math.pi * 2 * c, cr, cg, cb, 245, 4) end
        if f.full then
            draw.circle_outline(x, y, r + 7 + 5 * pulse, cr, cg, cb, math.floor(160 * (1 - pulse)), 2)
        end
        local label = f.full and "MAX" or string.format("%d%%", math.floor(c * 100 + 0.5))
        text.draw_centered(font.tiny, x - r, y - text.height(font.tiny) * 0.5, x + r, 255, 255, 255, 245, label)
    end
end)
