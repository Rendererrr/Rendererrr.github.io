-- Trip Meter: live trip computer. Published by veh_trip_meter::draw while you drive with it enabled.
--   distance      trip distance in the chosen unit (km or miles); imperial = true for miles
--   seconds       time spent moving
--   speed/avg/top current, average and top speed in km/h or mph
--   history       recent speeds "v,v,..." oldest first (omitted when Speed Graph is off)
--   milestone     whole kilometres/miles so far; milestone_age 0..1 while its flash plays
--   top_age       0..1 while a new top speed flash plays; reset_age 0..1 after Reset Trip

-- Font metrics: em = the slot's size in px, base = top-of-box to baseline (both from the engine when
-- available, so placement does not depend on the face's line spacing).
local function em_of(f) return (text.em and text.em(f)) or text.height(f) end
local function base_of(f) return (text.baseline and text.baseline(f)) or em_of(f) * 0.97 end

local W = 290
local DIGITS = 5

local function history(s)
    local out = {}
    for v in (s or ""):gmatch("([^,]+),") do out[#out + 1] = tonumber(v) end
    return out
end

local function clock(sec)
    sec = math.floor(sec or 0)
    local h, m, s = math.floor(sec / 3600), math.floor(sec / 60) % 60, sec % 60
    if h > 0 then return string.format("%d:%02d:%02d", h, m, s) end
    return string.format("%d:%02d", m, s)
end

-- Odometer: whole units plus one decimal, each digit in its own cell; the tenths wheel rolls smoothly.
local function odometer(x, y, value, ar, ag, ab, glow)
    local cw, ch = 30, 40
    local tenths = value * 10
    local digits = DIGITS + 1
    for i = 1, digits do
        local cx = x + (i - 1) * (cw + 4) + (i == digits and 8 or 0)
        local last = i == digits
        local br, bg, bb = 18, 18, 26
        if last then br, bg, bb = ar * 0.25, ag * 0.25, ab * 0.25 end
        draw.rect(cx, y, cx + cw, y + ch, math.floor(br), math.floor(bg), math.floor(bb), 235, 4)
        if glow > 0 then
            draw.rect_outline(cx, y, cx + cw, y + ch, ar, ag, ab, math.floor(255 * glow), 4, 2)
        end

        local place = 10 ^ (digits - i)
        local d = math.floor(tenths / place) % 10
        local roll = 0
        if last then roll = tenths - math.floor(tenths) end

        draw.push_clip(cx, y, cx + cw, y + ch)
        -- Digits are scaled to the cell (font.display is a fixed size): 70% of the cell height,
        -- with the box top placed so the glyph sits optically centred.
        local px = ch * 0.7
        local k = px / em_of(font.display)
        local ty = y + ch * 0.5 + px * 0.36 - base_of(font.display) * k - roll * ch
        local function digit(n, yy)
            local s = tostring(n % 10)
            local mid = cx + cw * 0.5
            local r, g, b = 240, 240, 245
            if last then r, g, b = 255, 255, 255 end
            draw.with_scale(mid, yy, k, function()
                text.draw(font.display, mid - text.width(font.display, s) * 0.5, yy, r, g, b, 255, s)
            end)
        end
        digit(d, ty)
        if roll > 0 then digit(d + 1, ty + ch) end
        draw.pop_clip()

        draw.rect_gradient(cx, y, cx + cw, y + 9, 0, 0, 0, 150, 0, 0, 0, 150, 0, 0, 0, 0, 0, 0, 0, 0)
        draw.rect_gradient(cx, y + ch - 9, cx + cw, y + ch, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 150, 0, 0, 0, 150)
    end
    local dot_x = x + (digits - 1) * (cw + 4) + 2
    draw.circle(dot_x, y + ch - 6, 2.5, 230, 230, 235, 255)
    return digits * (cw + 4) + 8
end

local function stat(x, y, w, label, value, unit, r, g, b, glow)
    if glow > 0 then
        draw.rect(x, y, x + w, y + 44, r, g, b, math.floor(60 * glow), 5)
    end
    text.draw(font.tiny, x + 8, y + 4, 160, 160, 175, 255, label)
    local vy = y + 6 + text.height(font.tiny)
    text.draw(font.item, x + 8, vy, r, g, b, 255, value)
    local vw = text.width(font.item, value)
    text.draw(font.tiny, x + 12 + vw, vy + text.height(font.item) - text.height(font.tiny) - 1, 150, 150, 165, 255, unit)
end

local function graph(x, y, w, h, hist, top, ar, ag, ab)
    draw.rect(x, y, x + w, y + h, 14, 14, 20, 220, 4)
    local n = #hist
    if n < 2 then return end
    local peak = math.max(top or 0, 10)
    for k = 1, 3 do
        local gy = y + h * k / 4
        draw.line(x + 4, gy, x + w - 4, gy, 255, 255, 255, 18, 1)
    end
    local step = (w - 8) / (60 - 1)
    local x0 = x + 4 + (60 - n) * step
    local px, py
    for i = 1, n do
        local v = math.min(hist[i] / peak, 1)
        local nx, ny = x0 + (i - 1) * step, y + h - 4 - v * (h - 8)
        if px then
            draw.line(px, py, nx, ny, ar, ag, ab, 60, 6)
            draw.line(px, py, nx, ny, ar, ag, ab, 245, 2)
        end
        px, py = nx, ny
    end
    draw.circle(px, py, 3.5, 255, 255, 255, 255)
end

features.on_draw("Trip Meter", function(f)
    if not f.active then return end
    local sw, sh = ctx.screen_w(), ctx.screen_h()
    local now = ctx.time()
    local ar, ag, ab = theme.accent()
    local unit = f.imperial and "mi" or "km"
    local speed_unit = f.imperial and "mph" or "km/h"

    local mile_glow = f.milestone_age and (1 - f.milestone_age) or 0
    local top_glow = f.top_age and (1 - f.top_age) or 0
    local reset_glow = f.reset_age and (1 - f.reset_age) or 0

    local has_graph = f.history ~= nil
    local h = 186 + (has_graph and 58 or 0)
    local x = sw * 0.016
    local y = sh * 0.80 - h - 12
    draw.rect(x, y, x + W, y + h, 10, 10, 16, 210, 8)
    if mile_glow > 0 then
        local pulse = 0.6 + 0.4 * math.sin(now * 18)
        draw.rect_outline(x, y, x + W, y + h, ar, ag, ab, math.floor(255 * mile_glow * pulse), 8, 2.5)
    end

    text.draw(font.small, x + 16, y + 12, 255, 255, 255, 255, "TRIP")
    local t = clock(f.seconds)
    text.draw(font.small, x + W - 16 - text.width(font.small, t), y + 12, 200, 200, 210, 255, t)

    local oy = y + 20 + text.height(font.small)
    local used = odometer(x + 16, oy, f.distance or 0, ar, ag, ab, mile_glow)
    text.draw(font.small, x + 18 + used, oy + 40 - text.height(font.small) - 2, 170, 170, 185, 255, unit)

    local sy = oy + 54
    local cw = (W - 32) / 3
    stat(x + 16, sy, cw, "NOW", string.format("%d", math.floor((f.speed or 0) + 0.5)), speed_unit, 255, 255, 255, 0)
    stat(x + 16 + cw, sy, cw, "AVG", string.format("%d", math.floor((f.avg or 0) + 0.5)), speed_unit, 200, 220, 255, 0)
    stat(x + 16 + cw * 2, sy, cw, "TOP", string.format("%d", math.floor((f.top or 0) + 0.5)), speed_unit,
        255, top_glow > 0 and 210 or 200, top_glow > 0 and 60 or 120, top_glow)

    if has_graph then
        graph(x + 16, sy + 54, W - 32, 50, history(f.history), f.top, ar, ag, ab)
    end

    local banner, br, bg, bb, ba
    if reset_glow > 0 then
        banner, br, bg, bb, ba = "TRIP RESET", 255, 255, 255, reset_glow
    elseif top_glow > 0 then
        banner, br, bg, bb, ba = "NEW TOP SPEED", 255, 210, 60, top_glow
    elseif mile_glow > 0 then
        banner, br, bg, bb, ba = string.format("%d %s", f.milestone or 0, string.upper(unit)), ar, ag, ab, mile_glow
    end
    if banner then
        local p = 1 - ba
        local pop = 1 + 0.35 * math.max(0, 1 - p / 0.12)
        local alpha = math.floor(255 * math.min(1, ba / 0.3))
        local bx, by = x + W * 0.5, y - 26 - p * 10
        draw.with_scale(bx, by, pop, function()
            local tw = text.width(font.item, banner)
            text.draw_outlined(font.item, bx - tw * 0.5, by, br, bg, bb, alpha, 0, 0, 0, math.floor(alpha * 0.8), 2.0, banner)
        end)
    end
end)
