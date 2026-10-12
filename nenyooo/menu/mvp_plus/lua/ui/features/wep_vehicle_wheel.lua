-- Vehicle Weapon Wheel. Published by wep_vehicle_wheel::draw while the wheel is held open in a vehicle.
--   slots      eight "count,pick,name|icon;" entries, clockwise from the top: pistols, machine guns,
--              rifles, shotguns, snipers, heavy, throwables, melee. pick is 1-based; icon is a cached
--              thumbnail path (empty while it downloads)
--   highlight  1-based slot under the pointer; cx, cy pointer direction (-1..1, +y = down)
--   ammo       ammo for the highlighted gun; loading = weapon list not downloaded yet

local LABELS = { "PISTOLS", "MACHINE GUNS", "RIFLES", "SHOTGUNS", "SNIPERS", "HEAVY", "THROWABLES", "MELEE" }
local R_IN, R_OUT = 120, 260
local opened_at = nil

local function parse(s)
    local out = {}
    for item in (s or ""):gmatch("([^;]*);") do
        local count, pick, name, icon = item:match("^(%d+),(%d+),(.-)|(.*)$")
        out[#out + 1] = { count = tonumber(count) or 0, pick = tonumber(pick) or 1, name = name or "", icon = icon or "" }
    end
    return out
end

local function slot_angle(i)
    return math.rad(-90 + (i - 1) * 45)
end

local function wedge(cx, cy, i, r1, r2, r, g, b, a)
    local half = math.rad(22.5) - math.rad(1.2)
    local mid = slot_angle(i)
    local step = math.rad(1.5)
    local th = r2 * step + 1.5
    local t = mid - half
    while t <= mid + half do
        local c, s = math.cos(t), math.sin(t)
        draw.line(cx + c * r1, cy + s * r1, cx + c * r2, cy + s * r2, r, g, b, a, th)
        t = t + step
    end
end

local function arc(cx, cy, r, a0, a1, cr, cg, cb, ca, th)
    local steps = 10
    local px, py = cx + math.cos(a0) * r, cy + math.sin(a0) * r
    for k = 1, steps do
        local t = a0 + (a1 - a0) * k / steps
        local nx, ny = cx + math.cos(t) * r, cy + math.sin(t) * r
        draw.line(px, py, nx, ny, cr, cg, cb, ca, th)
        px, py = nx, ny
    end
end

local function centred(fnt, x, y, str, r, g, b, a)
    text.draw(fnt, x - text.width(fnt, str) * 0.5, y, r, g, b, a, str)
end

features.on_draw("Vehicle Weapon Wheel", function(f)
    if not f.open then
        opened_at = nil
        return
    end
    local now = ctx.time()
    opened_at = opened_at or now
    local grow = math.min(1, (now - opened_at) / 0.12)
    local ease = 1 - (1 - grow) ^ 3

    local sw, sh = ctx.screen_w(), ctx.screen_h()
    local cx, cy = sw * 0.5, sh * 0.5
    local ar, ag, ab = theme.accent()
    local slots = parse(f.slots)
    local hl = f.highlight or 1

    draw.with_scale(cx, cy, 0.85 + 0.15 * ease, function()
        draw.circle(cx, cy, R_OUT + 14, 0, 0, 0, math.floor(110 * ease))

        for i = 1, 8 do
            local s = slots[i] or { count = 0 }
            local on = i == hl
            if on and s.count > 0 then
                wedge(cx, cy, i, R_IN, R_OUT + 10, ar, ag, ab, math.floor(225 * ease))
            elseif on then
                wedge(cx, cy, i, R_IN, R_OUT, 70, 70, 82, math.floor(220 * ease))
            else
                wedge(cx, cy, i, R_IN, R_OUT, 18, 18, 26, math.floor((s.count > 0 and 215 or 150) * ease))
            end
        end

        for i = 1, 8 do
            local s = slots[i] or { count = 0, icon = "", name = "" }
            local on = i == hl
            local a = slot_angle(i)
            local mr = (R_IN + R_OUT) * 0.5 + (on and 6 or 0)
            local mx, my = cx + math.cos(a) * mr, cy + math.sin(a) * mr
            local alpha = math.floor(255 * ease)

            local lr = R_OUT - 16
            local lx, ly = cx + math.cos(a) * lr, cy + math.sin(a) * lr
            local label = LABELS[i]
            local tr, tg, tb = 150, 150, 165
            if on then tr, tg, tb = 255, 255, 255 end
            centred(font.tiny, lx, ly - text.height(font.tiny) * 0.5, label, tr, tg, tb, s.count > 0 and alpha or math.floor(alpha * 0.45))

            if s.count > 0 then
                local iw, ih = on and 104 or 88, on and 52 or 44
                local drew = false
                if s.icon ~= "" then
                    drew = draw.preview_image(s.icon, mx - iw * 0.5, my - ih * 0.5 + 6, mx + iw * 0.5, my + ih * 0.5 + 6, on and 1.0 or 0.8, true)
                end
                if not drew then
                    local short = s.name
                    if text.width(font.small, short) > iw + 20 then short = short:sub(1, 12) .. "." end
                    centred(font.small, mx, my - text.height(font.small) * 0.5 + 4, short, 235, 235, 240, alpha)
                end
                if s.count > 1 then
                    local dots_y = my + ih * 0.5 + 14
                    local n = math.min(s.count, 8)
                    local gap = 9
                    local x0 = mx - (n - 1) * gap * 0.5
                    for d = 1, n do
                        local lit = d == math.min(s.pick, n)
                        local dr = lit and 3.5 or 2.2
                        if lit then draw.circle(x0 + (d - 1) * gap, dots_y, dr, 255, 255, 255, alpha)
                        else draw.circle(x0 + (d - 1) * gap, dots_y, dr, 140, 140, 155, math.floor(alpha * 0.8)) end
                    end
                end
            end
        end

        draw.circle(cx, cy, R_IN - 8, 10, 10, 16, math.floor(235 * ease))
        draw.circle_outline(cx, cy, R_IN - 8, ar, ag, ab, math.floor(200 * ease), 2)

        local len = math.sqrt((f.cx or 0) ^ 2 + (f.cy or 0) ^ 2)
        if len > 0.05 then
            local pa = math.atan2(f.cy, f.cx)
            arc(cx, cy, R_IN - 8, pa - 0.3, pa + 0.3, 255, 255, 255, math.floor(230 * ease), 4)
        end

        local s = slots[hl] or { count = 0, name = "" }
        if f.loading then
            centred(font.small, cx, cy - text.height(font.small) * 0.5, "Loading weapons...", 220, 220, 230, 255)
        elseif s.count > 0 then
            local name = s.name
            local nf = font.item
            if text.width(nf, name) > (R_IN - 20) * 2 then nf = font.small end
            local y = cy - text.height(nf) - 4
            centred(nf, cx, y, name, 255, 255, 255, 255)
            local ammo = f.ammo or 0
            local ammo_s = ammo >= 9999 and "UNLIMITED" or (ammo > 0 and string.format("%d ROUNDS", ammo) or "")
            if ammo_s ~= "" then centred(font.tiny, cx, cy + 4, ammo_s, 200, 200, 210, 255) end
            if s.count > 1 then
                centred(font.tiny, cx, cy + 8 + text.height(font.tiny), string.format("%d / %d  -  SCROLL TO CYCLE", s.pick, s.count), ar, ag, ab, 255)
            end
        else
            centred(font.small, cx, cy - text.height(font.small) * 0.5, "Empty slot", 150, 150, 165, 255)
        end
    end)
end)
