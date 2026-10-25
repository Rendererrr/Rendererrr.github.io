-- Vehicle weapon wheel. Published fields: open (bool), loading (bool, weapon list still downloading),
-- highlight (1..8, the slot being pointed at), cx / cy (the pointer, -1..1), ammo and clip (of the
-- highlighted weapon), slots = "count,pick,name|icon;" x 8, clockwise from the top. icon is an absolute
-- thumbnail path, empty until it has downloaded.
-- Eight slots around a dark disc like the on-foot wheel: the pointed-at slot lights up in the accent
-- colour, the hub names the weapon, its ammo and how many guns the slot holds.

local floor, min, max, sin, cos, sqrt, rad = math.floor, math.min, math.max, math.sin, math.cos, math.sqrt, math.rad
local atan2 = math.atan2 or math.atan
local BIG = font.display or font.title

local function em_of(f) return (text.em and text.em(f)) or text.height(f) end
local function base_of(f) return (text.baseline and text.baseline(f)) or em_of(f) * 0.97 end

local SLOT_NAMES = { "PISTOLS", "MACHINE GUNS", "RIFLES", "SHOTGUNS", "SNIPERS", "HEAVY", "THROWABLES", "MELEE" }
local DISC = { 10, 11, 15 }
local INK = { 244, 245, 248 }
local DIM = { 150, 155, 168 }
local ACC = { 170, 90, 255 }

local R_OUT, R_IN = 250, 112
local R_MID = (R_OUT + R_IN) * 0.5
local SPAN = 45
local open_t = nil

local function pol(cx, cy, r, deg)
    local a = rad(deg)
    return cx + r * sin(a), cy - r * cos(a)
end

local function arc(cx, cy, r, d0, d1, c, a, t)
    local n = max(3, floor(rad(d1 - d0) * r / 7))
    local px, py = pol(cx, cy, r, d0)
    for i = 1, n do
        local x, y = pol(cx, cy, r, d0 + (d1 - d0) * i / n)
        draw.line(px, py, x, y, c[1], c[2], c[3], floor(a), t)
        px, py = x, y
    end
end

local function parse(s)
    local out = {}
    for count, pick, name, icon in (s or ""):gmatch("(%d+),(%d+),([^|]*)|([^;]*);") do
        out[#out + 1] = { count = tonumber(count), pick = tonumber(pick), name = name, icon = icon }
    end
    return out
end

-- Centred text, shrunk to fit `w` (never enlarged past `k`).
local function fit(fnt, x, y, s, w, k, c, a)
    local tw = max(1, text.width(fnt, s))
    k = min(k, w / tw)
    local h = text.height(fnt)
    draw.with_scale(x, y, k, function()
        text.draw(fnt, x - tw * 0.5, y - h * 0.5, c[1], c[2], c[3], floor(a), s)
    end)
end

local function spaced_c(fnt, x, y, s, c, a, sp)
    local w = text.width_spaced(fnt, s, sp)
    text.draw_spaced(fnt, x - w * 0.5, y - text.height(fnt) * 0.5, c[1], c[2], c[3], floor(a), s, sp)
end

-- Centred numerals at an exact pixel height (baseline at y + 0.5 * px).
local function numerals(x, y, px, s, c, a)
    local k = px / max(1, em_of(BIG))
    local w = text.width(BIG, s)
    local ty = y + 0.5 * px - base_of(BIG) * k
    draw.with_scale(x, ty, k, function()
        text.draw(BIG, x - w * 0.5, ty, c[1], c[2], c[3], floor(a), s)
    end)
end

local function chevron(x, y, dir, c, a)
    draw.line(x, y - 4, x + 4 * dir, y, c[1], c[2], c[3], floor(a), 1.6)
    draw.line(x + 4 * dir, y, x, y + 4, c[1], c[2], c[3], floor(a), 1.6)
end

local function slot_content(cx, cy, i, s, lit, fa)
    local x, y = pol(cx, cy, R_MID, (i - 1) * SPAN)
    if not s or s.count == 0 then
        spaced_c(font.tiny, x, y, SLOT_NAMES[i], DIM, (lit and 150 or 70) * fa, 1.2)
        return
    end
    local iw, ih = 116, 58
    local shown = false
    if s.icon ~= "" then
        shown = draw.preview_image(s.icon, x - iw * 0.5, y - ih * 0.5 - 4, x + iw * 0.5, y + ih * 0.5 - 4,
            (lit and 1.0 or 0.6) * fa, true)
    end
    if not shown then
        fit(font.value, x, y - 4, s.name, iw, 1.15, lit and INK or DIM, (lit and 255 or 190) * fa)
    end
    if s.count > 1 then
        local py = y + ih * 0.5 + 6
        if s.count <= 8 then
            local gap = 9
            local sx = x - (s.count - 1) * gap * 0.5
            for p = 1, s.count do
                local on = p == s.pick
                local c = on and (lit and ACC or INK) or DIM
                draw.circle(sx + (p - 1) * gap, py, on and 2.6 or 1.8, c[1], c[2], c[3], floor((on and 255 or 120) * fa))
            end
        else
            spaced_c(font.tiny, x, py, s.pick .. " / " .. s.count, DIM, 200 * fa, 1)
        end
    end
end

-- The lit wedge: concentric rings in a solid colour pre-blended over the disc, each overlapping the next.
-- Opaque strokes can overlap without darkening, so the band has no seams (translucent ones would show a grid).
local function band_ring(cx, cy, r, d0, d1, c, a, t)
    local n = max(3, floor(rad(d1 - d0) * r / 7))
    local ext = 0.8 / r * 57.3
    for i = 0, n - 1 do
        local x1, y1 = pol(cx, cy, r, max(d0, d0 + (d1 - d0) * i / n - ext))
        local x2, y2 = pol(cx, cy, r, min(d1, d0 + (d1 - d0) * (i + 1) / n + ext))
        draw.line(x1, y1, x2, y2, c[1], c[2], c[3], floor(a), t)
    end
end

local function highlight(cx, cy, i, empty, fa)
    local mid = (i - 1) * SPAN
    local d0, d1 = mid - SPAN * 0.5 + 1.2, mid + SPAN * 0.5 - 1.2
    local strength = empty and 0.45 or 1
    local step = 7
    local r = R_IN + step * 0.5
    local c = {}
    while r < R_OUT do
        local mix = (0.16 + 0.26 * (r - R_IN) / (R_OUT - R_IN)) * strength
        for k = 1, 3 do c[k] = DISC[k] + (ACC[k] - DISC[k]) * mix end
        band_ring(cx, cy, min(r, R_OUT - step * 0.5), d0, d1, c, 255 * fa, step + 2)
        r = r + step
    end
    arc(cx, cy, R_OUT + 7, d0, d1, ACC, 255 * strength * fa, 5)
    arc(cx, cy, R_IN - 2, d0 + 4, d1 - 4, ACC, 170 * strength * fa, 2)
end

local function hub(cx, cy, f, slots, now, fa)
    if f.loading then
        local a0 = (now * 360) % 360
        draw.circle_outline(cx, cy - 12, 18, 255, 255, 255, floor(30 * fa), 3)
        arc(cx, cy - 12, 18, a0, a0 + 100, ACC, 255 * fa, 3)
        spaced_c(font.tiny, cx, cy + 26, "LOADING WEAPONS", DIM, 230 * fa, 1.4)
        return
    end
    local h = floor(f.highlight or 1)
    local s = slots[h]
    spaced_c(font.tiny, cx, cy - 46, SLOT_NAMES[h] or "", ACC, 255 * fa, 1.6)
    if not s or s.count == 0 then
        fit(font.value, cx, cy - 10, "Empty", 180, 1.4, DIM, 220 * fa)
        spaced_c(font.tiny, cx, cy + 18, "NO WEAPONS IN THIS SLOT", DIM, 150 * fa, 1)
        return
    end
    local ammo = floor(f.ammo or 0)
    local clip = floor(f.clip or 0)
    local has_ammo = ammo > 0 and clip > 0
    fit(font.value, cx, has_ammo and cy - 18 or cy - 2, s.name, 184, 1.45, INK, 255 * fa)
    if has_ammo then
        numerals(cx, cy + 16, 30, ammo >= 9999 and "INF" or tostring(ammo), INK, 255 * fa)
        spaced_c(font.tiny, cx, cy + 42, "ROUNDS", DIM, 190 * fa, 1.4)
    end
    if s.count > 1 then
        local y = cy + 66
        local label = s.pick .. " OF " .. s.count
        local w = text.width_spaced(font.tiny, label, 1.2)
        spaced_c(font.tiny, cx, y, label, DIM, 220 * fa, 1.2)
        chevron(cx - w * 0.5 - 10, y, -1, ACC, 255 * fa)
        chevron(cx + w * 0.5 + 10, y, 1, ACC, 255 * fa)
    end
end

local function wheel(f, cx, cy, now, fa)
    local slots = parse(f.slots)
    local h = floor(f.highlight or 1)

    draw.circle(cx, cy, R_OUT + 12, 6, 7, 10, floor(60 * fa))
    draw.circle(cx, cy, R_OUT, DISC[1], DISC[2], DISC[3], floor(185 * fa))
    draw.circle(cx, cy, R_IN - 6, 4, 5, 8, floor(150 * fa))
    draw.circle_outline(cx, cy, R_OUT, 255, 255, 255, floor(26 * fa), 1.5)
    draw.circle_outline(cx, cy, R_IN - 6, 255, 255, 255, floor(22 * fa), 1)
    for i = 0, 7 do
        local x1, y1 = pol(cx, cy, R_IN + 6, (i + 0.5) * SPAN)
        local x2, y2 = pol(cx, cy, R_OUT - 6, (i + 0.5) * SPAN)
        draw.line(x1, y1, x2, y2, 255, 255, 255, floor(24 * fa), 1.5)
    end

    if not f.loading then
        local hs = slots[h]
        highlight(cx, cy, h, not hs or hs.count == 0, fa)
        for i = 1, 8 do slot_content(cx, cy, i, slots[i], i == h, fa) end

        local px, py = f.cx or 0, f.cy or 0
        if sqrt(px * px + py * py) > 0.25 then
            local deg = math.deg(atan2(px, -py))
            local x, y = pol(cx, cy, R_IN - 16, deg)
            draw.circle(x, y, 3.5, ACC[1], ACC[2], ACC[3], floor(255 * fa))
        end
    end

    hub(cx, cy, f, slots, now, fa)
end

features.on_draw("Vehicle Weapon Wheel", function(f)
    if not f.open then
        open_t = nil
        return
    end
    local now = ctx.time()
    open_t = open_t or now
    local e = min(1, (now - open_t) / 0.12)
    local ease = 1 - (1 - e) ^ 3

    local sw, sh = ctx.screen_w(), ctx.screen_h()
    local u = max(0.5, min(2.0, sh / 1080))
    local cx, cy = sw * 0.5, sh * 0.5
    ACC[1], ACC[2], ACC[3] = theme.accent()
    -- with_scale returns a failure instead of raising it; re-raise so it is logged and shown.
    local ok, err = draw.with_scale(cx, cy, u * (0.94 + 0.06 * ease), function()
        wheel(f, cx, cy, now, ease)
    end)
    if not ok then error(err, 0) end
end)
