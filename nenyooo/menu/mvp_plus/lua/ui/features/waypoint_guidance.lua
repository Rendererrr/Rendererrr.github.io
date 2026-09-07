-- 3D Waypoint Guidance readout. The route chevrons and the destination marker are drawn in the
-- world by the game-thread feature; this script owns the screen-space callout that annotates the
-- destination, and the edge pointer that replaces it when the destination is behind the camera.

local BULLET = "\194\183"   -- UTF-8 U+00B7 (Lua 5.1 has no \u{...} escape)
local NUM_SCALE = 1.5       -- draw.with_scale factor for the headline distance (clamped to 2.0)
local LEG = 34              -- diagonal leader run from the ring to the knee
local STUB = 12             -- horizontal run from the knee into the panel edge
local MARGIN = 8            -- keep the panel at least this far off every screen edge

-- Alpha reaches these from a fade times a pulse, so it can overshoot; IM_COL32 wraps if it does.
local function a8(v)
    if v < 0 then return 0 end
    if v > 255 then return 255 end
    return math.floor(v)
end

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function fmt_distance(d)
    if d >= 1000 then return string.format("%.1f", d / 1000), "km" end
    return string.format("%d", math.floor(d + 0.5)), "m"
end

local function fmt_eta(seconds)
    if not seconds or seconds <= 0 or seconds > 5400 then return nil end
    local m = math.floor(seconds / 60)
    local s = math.floor(seconds % 60)
    if m >= 60 then return string.format("%dh %02dm", math.floor(m / 60), m % 60) end
    return string.format("%d:%02d", m, s)
end

local function subtitle_for(f)
    local label = f.waypoint and "WAYPOINT" or "OBJECTIVE"
    local eta = fmt_eta(f.eta)
    if eta then return label .. "  " .. BULLET .. "  " .. eta end
    return label
end

-- A ring sits on the destination itself and a leader carries the readout off to one side, so the
-- thing you are driving at is never hidden behind its own label.
local function draw_callout(x, y, f, ar, ag, ab, alpha, pulse)
    local sw, sh = ctx.screen_w(), ctx.screen_h()
    local value, unit = fmt_distance(f.distance or 0)
    local subtitle = ((f.mode or 1) >= 2) and subtitle_for(f) or nil

    local value_w = text.width(font.value, value) * NUM_SCALE
    local value_h = text.height(font.value) * NUM_SCALE
    local unit_w = text.width(font.small, unit)
    local sub_w = subtitle and text.width_spaced(font.tiny, subtitle, 1.2) or 0
    local pad_x, pad_y = 11, 7
    local w = pad_x * 2 + math.max(value_w + 4 + unit_w, sub_w)
    local h = pad_y * 2 + value_h + (subtitle and (text.height(font.tiny) + 3) or 0)

    -- Throw the callout towards whichever side still has room for the panel.
    local dir_x = (x + LEG + STUB + w + MARGIN > sw) and -1 or 1
    local dir_y = (y - LEG - h * 0.5 - MARGIN < 0) and 1 or -1

    local kx = x + LEG * dir_x
    local ky = clamp(y + LEG * dir_y, h * 0.5 + MARGIN, math.max(h * 0.5 + MARGIN, sh - h * 0.5 - MARGIN))

    local x1 = (dir_x > 0) and (kx + STUB) or (kx - STUB - w)
    x1 = clamp(x1, MARGIN, math.max(MARGIN, sw - w - MARGIN))
    local x2 = x1 + w
    local y1 = ky - h * 0.5
    local y2 = y1 + h
    -- Clamping may have moved the panel, so the horizontal run ends wherever its edge landed.
    local attach = (dir_x > 0) and x1 or x2

    draw.line(x + 4.5 * dir_x, y + 4.5 * dir_y, kx, ky, ar, ag, ab, a8(alpha * 0.75), 1.4)
    draw.line(kx, ky, attach, ky, ar, ag, ab, a8(alpha * 0.75), 1.4)

    draw.rect(x1 + 1, y1 + 2, x2 + 1, y2 + 4, 0, 0, 0, a8(alpha * 0.30), 4)
    draw.rect(x1, y1, x2, y2, 10, 14, 21, a8(math.min(alpha, 234)), 4)
    draw.rect_outline(x1, y1, x2, y2, ar, ag, ab, a8(alpha * 0.28), 4, 1.0)

    -- Accent rule on the edge the leader arrives at; it carries the arrival pulse.
    local rule = (dir_x > 0) and x1 or (x2 - 2)
    draw.rect(rule, y1 + 3, rule + 2, y2 - 3, ar, ag, ab, a8(alpha * pulse), 1)

    local tx = x1 + pad_x
    local ty = y1 + pad_y
    draw.with_scale(tx, ty, NUM_SCALE, function()
        text.draw(font.value, tx, ty, 244, 248, 252, a8(alpha), value)
    end)
    text.draw(font.small, tx + value_w + 4, ty + value_h - text.height(font.small) - 1,
        ar, ag, ab, a8(alpha * 0.90), unit)
    if subtitle then
        text.draw_spaced(font.tiny, tx, ty + value_h + 2, 150, 164, 182,
            a8(alpha * 0.88), subtitle, 1.2)
    end

    -- Ring last so the leader tucks under it.
    draw.circle(x, y, 8.5, ar, ag, ab, a8(alpha * 0.16 * pulse))
    draw.circle_outline(x, y, 6, ar, ag, ab, a8(alpha * 0.70 * pulse), 1.4)
    draw.circle(x, y, 2.6, ar, ag, ab, a8(alpha * pulse))
end

-- Destination is behind or beside the camera: park a compass badge on the screen edge, chevron
-- pointing the way to turn.
local function draw_edge_pointer(f, ar, ag, ab, alpha, pulse)
    local sw, sh = ctx.screen_w(), ctx.screen_h()
    local cx, cy = sw * 0.5, sh * 0.5
    local margin = 74
    local hx, hy = cx - margin, cy - margin
    local b = f.bearing or 0
    local dx, dy = math.sin(b), -math.cos(b)

    -- Push the badge out to the nearest edge of the inset rectangle.
    local sx = math.abs(dx) > 1e-4 and hx / math.abs(dx) or 1e9
    local sy = math.abs(dy) > 1e-4 and hy / math.abs(dy) or 1e9
    local s = math.min(sx, sy)
    local px, py = cx + dx * s, cy + dy * s

    local radius = 21
    draw.circle(px, py + 2, radius, 0, 0, 0, a8(alpha * 0.32))
    draw.circle(px, py, radius, 10, 14, 21, a8(math.min(alpha, 236)))
    for i = 3, 1, -1 do
        draw.circle_outline(px, py, radius + i * 1.6, ar, ag, ab, a8(alpha * pulse * 0.16 / i), 1.5)
    end
    draw.circle_outline(px, py, radius, ar, ag, ab, a8(alpha * 0.65), 1.2)

    -- Chevron built from two strokes, rotated to the bearing.
    local ax, ay = dx, dy
    local rx, ry = -dy, dx
    local tip_x, tip_y = px + ax * 9, py + ay * 9
    local back = 5
    local wing = 7
    draw.line(tip_x, tip_y, px - ax * back + rx * wing, py - ay * back + ry * wing,
        244, 248, 252, a8(alpha), 2.2)
    draw.line(tip_x, tip_y, px - ax * back - rx * wing, py - ay * back - ry * wing,
        244, 248, 252, a8(alpha), 2.2)

    local value, unit = fmt_distance(f.distance or 0)
    local label = value .. " " .. unit
    local lw = text.width(font.value, label)
    local ly = py + radius + 5
    draw.rect(px - lw * 0.5 - 6, ly - 2, px + lw * 0.5 + 6, ly + text.height(font.value) + 3,
        10, 14, 21, a8(math.min(alpha, 226)), 5)
    draw.rect_outline(px - lw * 0.5 - 6, ly - 2, px + lw * 0.5 + 6, ly + text.height(font.value) + 3,
        ar, ag, ab, a8(alpha * 0.45), 5, 1.0)
    text.draw(font.value, px - lw * 0.5, ly, 232, 240, 248, a8(alpha), label)
end

features.on_draw("Waypoint Guidance", function(f)
    if not f.active then return end

    local alpha = f.a or 220
    if alpha < 4 then return end
    local ar, ag, ab = f.r or 40, f.g or 180, f.b or 255

    -- Close to the destination the accent breathes so the arrival reads at a glance.
    local pulse = 1.0
    if f.arriving then pulse = 1.0 + 0.45 * (0.5 + 0.5 * math.sin(ctx.time() * 5.0)) end

    if f.offscreen then
        draw_edge_pointer(f, ar, ag, ab, alpha, pulse)
        return
    end

    local sw, sh = ctx.screen_w(), ctx.screen_h()
    draw_callout((f.x or 0.5) * sw, (f.y or 0.5) * sh, f, ar, ag, ab, alpha, pulse)
end)
