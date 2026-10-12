
-- Compass HUD. Published fields: active (bool), heading (deg, GTA convention), street (string),
-- waypoint_heading / waypoint_distance (only while a waypoint is set).
local floor, abs = math.floor, math.abs
local CARDINALS = { [0] = "N", [45] = "NE", [90] = "E", [135] = "SE",
                    [180] = "S", [225] = "SW", [270] = "W", [315] = "NW" }

-- GTA headings run counter-clockwise (90 = west); flip them into a clockwise bearing.
local function bearing(h)
    return (360 - (h % 360)) % 360
end

local function offset(d, b)
    return ((d - b + 540) % 360) - 180
end

features.on_draw("Compass", function(f)
    if not f.active then return end

    local sw, sh = ctx.screen_w(), ctx.screen_h()
    local s = sh / 1080
    local w = 420 * s
    local cx = sw * 0.5
    local y = 18 * s
    local half, span = w * 0.5, 150
    local ppd = w / span
    local b = bearing(f.heading or 0)
    local ar, ag, ab = theme.accent()

    draw.rect(cx - half - 10 * s, y - 6 * s, cx + half + 10 * s, y + 30 * s, 10, 10, 16, 140, 6 * s)

    local first = floor((b - span * 0.5) / 15) * 15
    for d = first, b + span * 0.5, 15 do
        local nd = ((d % 360) + 360) % 360
        local x = cx + offset(nd, b) * ppd
        if x >= cx - half and x <= cx + half then
            local fade = 1 - abs(x - cx) / half
            local a = floor(255 * (0.15 + 0.85 * fade))
            local card = CARDINALS[nd]
            if card then
                draw.line(x, y + 24 * s, x, y + 14 * s, 235, 235, 240, a, 1.6)
                local tw = text.width(font.small, card)
                local r, g, bl = 235, 235, 240
                if nd == 0 then r, g, bl = 235, 80, 80 end
                text.draw(font.small, x - tw * 0.5, y - 2 * s, r, g, bl, a, card)
            else
                draw.line(x, y + 24 * s, x, y + 18 * s, 200, 200, 210, floor(a * 0.8), 1.0)
            end
        end
    end

    if f.waypoint_heading then
        local off = offset(bearing(f.waypoint_heading), b)
        local x = cx + math.max(-half, math.min(half, off * ppd))
        local a = abs(off * ppd) > half and 150 or 255
        draw.circle(x, y + 8 * s, 5 * s, 200, 90, 240, a)
        local dist = f.waypoint_distance or 0
        local label = dist >= 1000 and string.format("%.1f km", dist / 1000) or string.format("%d m", floor(dist))
        local lw = text.width(font.tiny, label)
        text.draw(font.tiny, cx - lw * 0.5, y + 34 * s, 200, 90, 240, 255, label)
    end

    draw.line(cx, y + 26 * s, cx - 5 * s, y + 32 * s, ar, ag, ab, 255, 1.6)
    draw.line(cx, y + 26 * s, cx + 5 * s, y + 32 * s, ar, ag, ab, 255, 1.6)

    local street = f.street or ""
    if street ~= "" then
        local sy = y + (f.waypoint_heading and 50 or 36) * s
        local tw = text.width(font.small, street)
        text.draw(font.small, cx - tw * 0.5, sy, 230, 230, 235, 220, street)
    end
end)
