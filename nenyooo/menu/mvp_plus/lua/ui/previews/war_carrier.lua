-- War Carrier HUD — warship bridge overlay.
--
-- Same instrument system as the Giant Robot HUD and the Remote Drone camera HUD: heading tape
-- up top, telemetry tapes on the flanks, cards for status/weapons/mission, and a control legend
-- whose keycaps LIGHT UP while the control is actually held (`keys` bitmask).
--
-- Published by war_carrier::draw:
--   mode                                          : autopilot program name
--   helm, command, armed, auto_engage             : booleans
--   target_locked, ciws, missile_ready, heavy     : booleans
--   speed, altitude, vspeed, heading, pitch, roll : numbers
--   missiles, targets, route_index, route_count   : numbers
--   destination (m), uptime (ms), x, y, z         : numbers
--   keys                                          : bitmask, see KEY below

local floor, min, max, abs = math.floor, math.min, math.max, math.abs
local fmt = string.format

local TXT_R, TXT_G, TXT_B = 236, 238, 243
local DIM_R, DIM_G, DIM_B = 138, 143, 156
local OK_R,  OK_G,  OK_B  =  96, 214, 132
local WRN_R, WRN_G, WRN_B = 240, 176,  64
local ERR_R, ERR_G, ERR_B = 236,  78,  72
local BG_R,  BG_G,  BG_B  =   9,  11,  15

local KEY = { FWD = 1, BACK = 2, LEFT = 4, RIGHT = 8, JUMP = 16, DUCK = 32,
              SPRINT = 64, ATTACK = 128, BRAKE = 512 }

local sw, sh = 1920, 1080
local ar, ag, ab = 226, 97, 42
local mask = 0

local sm_speed, sm_alt, sm_hdg, sm_vs = 0, 0, 0, 0

local function approach(cur, target, rate, dt)
    return cur + (target - cur) * min(1, rate * dt)
end

local function approach_deg(cur, target, rate, dt)
    local d = (target - cur + 540) % 360 - 180
    return (cur + d * min(1, rate * dt)) % 360
end

local function held(bits)
    if not bits then return false end
    for _, bit in ipairs(bits) do
        if (floor(mask / bit) % 2) >= 1 then return true end
    end
    return false
end

-- ── primitives (normalized 0..1 coords) ────────────────────────────────────────────

local function rect(x, y, w, h, r, g, b, a, rounding)
    draw.rect(x * sw, y * sh, (x + w) * sw, (y + h) * sh, r, g, b, a, rounding or 0)
end

local function outline(x, y, w, h, r, g, b, a, rounding, th)
    draw.rect_outline(x * sw, y * sh, (x + w) * sw, (y + h) * sh, r, g, b, a, rounding or 0, th or 1)
end

local function hline(x, y, w, r, g, b, a, t)
    t = t or 0.0014
    draw.rect(x * sw, y * sh, (x + w) * sw, (y + t) * sh, r, g, b, a, 0)
end

local function vline(x, y, h, r, g, b, a, t)
    t = t or 0.0014
    draw.rect(x * sw, y * sh, (x + t) * sw, (y + h) * sh, r, g, b, a, 0)
end

local function txt(fnt, s, x, y, r, g, b, a)
    text.draw(fnt, x * sw, y * sh, r, g, b, a, s)
end

local function txt_right(fnt, s, x, y, r, g, b, a)
    text.draw(fnt, x * sw - text.width(fnt, s), y * sh, r, g, b, a, s)
end

local function txt_center(fnt, s, x, y, r, g, b, a)
    text.draw(fnt, x * sw - text.width(fnt, s) * 0.5, y * sh, r, g, b, a, s)
end

local function tw(fnt, s) return text.width(fnt, s) / sw end

-- ── cards ──────────────────────────────────────────────────────────────────────────

local CARD_HEAD = 0.030
local ROW_H = 0.026
local METER_H = 0.036

local function card(x, y, w, h, title, right_label, rr, rg, rb)
    rect(x, y, w, h, BG_R, BG_G, BG_B, 205, 3)
    outline(x, y, w, h, 255, 255, 255, 16, 3, 1)
    hline(x, y, w, ar, ag, ab, 225, 0.0018)
    vline(x, y, h, ar, ag, ab, 90, 0.0009)
    if title then txt(font.tiny, title, x + 0.008, y + 0.008, ar, ag, ab, 235) end
    if right_label then
        txt_right(font.tiny, right_label, x + w - 0.008, y + 0.008, rr or DIM_R, rg or DIM_G, rb or DIM_B, 235)
    end
end

local function card_row(x, y, w, label, value, vr, vg, vb)
    txt(font.tiny, label, x + 0.009, y + 0.004, DIM_R, DIM_G, DIM_B, 230)
    txt_right(font.small, value, x + w - 0.009, y, vr or TXT_R, vg or TXT_G, vb or TXT_B, 240)
end

local function card_meter(x, y, w, label, pct, status, r, g, b)
    pct = min(1, max(0, pct))
    txt(font.tiny, label, x + 0.009, y, DIM_R, DIM_G, DIM_B, 230)
    txt_right(font.tiny, status, x + w - 0.009, y, r, g, b, 240)
    local bx, bw = x + 0.009, w - 0.018
    rect(bx, y + 0.024, bw, 0.005, 255, 255, 255, 22, 1)
    if pct > 0 then rect(bx, y + 0.024, bw * pct, 0.005, r, g, b, 235, 1) end
end

local function pip(x, y, label, lit)
    local d = 0.0072
    rect(x, y, d * sh / sw, d, lit and ar or 60, lit and ag or 62, lit and ab or 70, lit and 245 or 150)
    local c = lit and 225 or 120
    txt(font.tiny, label, x + d * sh / sw + 0.005, y - 0.005, c, c, c, lit and 235 or 165)
    return d * sh / sw + 0.005 + tw(font.tiny, label) + 0.010
end

-- ── instruments ────────────────────────────────────────────────────────────────────

local function compass(cx, cy, w, heading)
    local half, per_deg, bar_h, tick_band = w * 0.5, w / 100.0, 0.030, 0.009
    rect(cx - half, cy, w, bar_h, BG_R, BG_G, BG_B, 185, 2)
    hline(cx - half, cy, w, ar, ag, ab, 210, 0.0014)
    hline(cx - half, cy + bar_h, w, ar, ag, ab, 90, 0.0008)

    for deg = floor((heading - 55) / 10) * 10, heading + 55, 10 do
        local x = cx + (deg - heading) * per_deg
        if x > cx - half + 0.014 and x < cx + half - 0.014 then
            local d360 = (deg % 360 + 360) % 360
            local cardinal = (d360 % 90) == 0
            local major = (d360 % 30) == 0
            local ht = cardinal and tick_band or (major and 0.006 or 0.004)
            vline(x, cy + bar_h - ht, ht,
                  cardinal and ar or 255, cardinal and ag or 255, cardinal and ab or 255,
                  cardinal and 255 or (major and 200 or 120), 0.0008)
            if major then
                local lbl = (d360 == 0 and "N") or (d360 == 90 and "E") or (d360 == 180 and "S")
                          or (d360 == 270 and "W") or tostring(d360)
                txt_center(font.tiny, lbl, x, cy + 0.002,
                           cardinal and ar or 210, cardinal and ag or 210, cardinal and ab or 210,
                           cardinal and 255 or 190)
            end
        end
    end

    local hdg = fmt("%03d", floor(heading) % 360)
    local bw = tw(font.small, hdg) + 0.016
    rect(cx - bw * 0.5, cy + bar_h, bw, 0.026, BG_R, BG_G, BG_B, 225, 2)
    outline(cx - bw * 0.5, cy + bar_h, bw, 0.026, ar, ag, ab, 200, 2, 1)
    txt_center(font.small, hdg, cx, cy + bar_h + 0.005, ar, ag, ab, 255)
end

local function tape(cx, cy, h, value, step, label, units, right)
    local half, per = h * 0.5, h / (step * 10.0)
    local w = 0.030
    local x0 = right and (cx - w) or cx
    rect(x0, cy - half, w, h, BG_R, BG_G, BG_B, 150, 2)
    hline(x0, cy - half, w, ar, ag, ab, 120, 0.0010)
    hline(x0, cy + half, w, ar, ag, ab, 120, 0.0010)
    vline(right and x0 or (x0 + w), cy - half, h, ar, ag, ab, 200, 0.0012)

    for i = -5, 5 do
        local mark = floor(value / step) + i
        local y = cy - (mark * step - value) * per
        if y >= cy - half + 0.001 and y <= cy + half - 0.001 then
            local major = (mark % 5) == 0
            local wt = major and 0.011 or 0.005
            local xt = right and x0 or (x0 + w - wt)
            hline(xt, y, wt, 255, 255, 255, major and 235 or 150, 0.0009)
            if major and abs(y - cy) > 0.024 then
                local lbl = tostring(floor(mark * step))
                if right then txt_right(font.tiny, lbl, x0 - 0.006, y - 0.009, 225, 228, 235, 210)
                else          txt(font.tiny, lbl, x0 + w + 0.006, y - 0.009, 225, 228, 235, 210) end
            end
        end
    end

    local val = fmt("%.1f", value)
    local bw = max(tw(font.small, val) + 0.014, 0.044)
    local bx = right and (x0 - bw) or (x0 + w)
    hline(x0, cy, w, ar, ag, ab, 255, 0.0024)
    rect(bx, cy - 0.014, bw, 0.028, BG_R, BG_G, BG_B, 235, 2)
    outline(bx, cy - 0.014, bw, 0.028, ar, ag, ab, 220, 2, 1)
    txt_center(font.small, val, bx + bw * 0.5, cy - 0.009, ar, ag, ab, 255)

    txt_center(font.tiny, label .. "  " .. units, cx, cy - half - 0.026, ar, ag, ab, 235)
end

local function keycap(x, y, label, lit)
    local w = max(tw(font.tiny, label) + 0.012, 0.026)
    local h = 0.020
    if lit then
        rect(x, y, w, h, ar, ag, ab, 235, 2)
        outline(x, y, w, h, ar, ag, ab, 255, 2, 1)
        txt_center(font.tiny, label, x + w * 0.5, y + 0.002, 16, 16, 18, 255)
    else
        rect(x, y, w, h, 255, 255, 255, 16, 2)
        outline(x, y, w, h, 255, 255, 255, 60, 2, 1)
        txt_center(font.tiny, label, x + w * 0.5, y + 0.002, 220, 223, 230, 235)
    end
    return w
end

local function legend(x, bottom, rows)
    local h = CARD_HEAD + #rows * ROW_H + 0.008
    local widest = 0
    for _, row in ipairs(rows) do
        local run = max(tw(font.tiny, row[1]) + 0.012, 0.026)
        if run > widest then widest = run end
    end
    local w = widest + 0.020 + 0.108
    local y = bottom - h
    card(x, y, w, h, "CONTROLS")
    for i, row in ipairs(rows) do
        local ry = y + CARD_HEAD + (i - 1) * ROW_H
        keycap(x + 0.009, ry, row[1], held(row[3]))
        local on = row[4] ~= false
        local c = on and 226 or 116
        txt(font.tiny, row[2], x + 0.009 + widest + 0.010, ry + 0.003, c, c, on and 236 or 124, on and 235 or 160)
    end
end

-- ── HUD ────────────────────────────────────────────────────────────────────────────

features.on_draw("War Carrier", function(f)
    sw, sh = ctx.screen_w(), ctx.screen_h()
    ar, ag, ab = theme.accent()
    mask = floor(f.keys or 0)
    local dt = min(ctx.delta(), 0.1)

    sm_speed = approach(sm_speed, f.speed or 0, 9, dt)
    sm_alt = approach(sm_alt, f.altitude or 0, 9, dt)
    sm_hdg = approach_deg(sm_hdg, f.heading or 0, 10, dt)
    sm_vs = approach(sm_vs, f.vspeed or 0, 6, dt)

    local armed = f.armed
    local targets = floor(f.targets or 0)
    local missiles = floor(f.missiles or 0)
    local route_count = floor(f.route_count or 0)

    draw.rect_gradient(0, 0, sw, sh * 0.16, 0, 0, 0, 150, 0, 0, 0, 150, 0, 0, 0, 0, 0, 0, 0, 0)
    draw.rect_gradient(0, sh * 0.80, sw, sh, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 165, 0, 0, 0, 165)

    compass(0.5, 0.036, 0.34, sm_hdg)

    -- ── Top-left: ship card ────────────────────────────────────────────────────────
    local up = floor((f.uptime or 0) / 1000)
    local x, y, w = 0.018, 0.030, 0.196
    local h = CARD_HEAD + ROW_H * 3 + 0.010
    card(x, y, w, h, "WAR CARRIER", fmt("%02d:%02d", floor(up / 60), up % 60), TXT_R, TXT_G, TXT_B)
    if (floor((f.uptime or 0) / 500) % 2) == 0 then
        rect(x + w - 0.010 - tw(font.tiny, "00:00") - 0.012, y + 0.010, 0.006, 0.010, ERR_R, ERR_G, ERR_B, 255)
    end
    card_row(x, y + CARD_HEAD, w, "PROGRAM",
             string.upper(f.helm and "Manual helm" or (f.mode or "Hold")), ar, ag, ab)
    card_row(x, y + CARD_HEAD + ROW_H, w, "STATION",
             f.command and "COMMAND" or (f.helm and "HELM" or "AUTO"))
    card_row(x, y + CARD_HEAD + ROW_H * 2, w, "TRACKING", fmt("%d", targets),
             targets > 0 and WRN_R or TXT_R, targets > 0 and WRN_G or TXT_G, targets > 0 and WRN_B or TXT_B)

    -- ── Top-right: weapons card ────────────────────────────────────────────────────
    local sx = 0.786
    local ready = 0
    if f.ciws then ready = ready + 1 end
    if f.missile_ready then ready = ready + 1 end
    if f.heavy then ready = ready + 1 end
    local sh_ = CARD_HEAD + METER_H * 2 + 0.024
    card(sx, y, w, sh_, "WEAPONS", armed and "ARMED" or "SAFE",
         armed and ERR_R or DIM_R, armed and ERR_G or DIM_G, armed and ERR_B or DIM_B)
    card_meter(sx, y + CARD_HEAD, w, "BATTERIES", armed and ready / 3 or 0,
               armed and fmt("%d/3 READY", ready) or "WEAPONS SAFE",
               armed and OK_R or DIM_R, armed and OK_G or DIM_G, armed and OK_B or DIM_B)
    card_meter(sx, y + CARD_HEAD + METER_H, w, "ORDNANCE", min(1, missiles / 8),
               missiles > 0 and fmt("%d IN FLIGHT", missiles) or "TUBES CLEAR",
               missiles > 0 and WRN_R or DIM_R, missiles > 0 and WRN_G or DIM_G,
               missiles > 0 and WRN_B or DIM_B)
    local px = sx + 0.009
    px = px + pip(px, y + sh_ - 0.015, "CIWS", f.ciws and armed)
    px = px + pip(px, y + sh_ - 0.015, "MSL", f.missile_ready and armed)
    pip(px, y + sh_ - 0.015, "HVY", f.heavy and armed)

    -- ── Flanks: speed and altitude ─────────────────────────────────────────────────
    tape(0.060, 0.50, 0.30, sm_speed, 5.0, "SPD", "m/s", false)
    tape(0.940, 0.50, 0.30, sm_alt, 50.0, "ALT", "m", true)
    local vr, vg, vb = DIM_R, DIM_G, DIM_B
    if sm_vs > 0.2 then vr, vg, vb = OK_R, OK_G, OK_B
    elseif sm_vs < -0.2 then vr, vg, vb = WRN_R, WRN_G, WRN_B end
    txt_center(font.tiny, fmt("VS %+.1f", sm_vs), 0.940, 0.664, vr, vg, vb, 240)
    txt_center(font.tiny, f.auto_engage and "AUTO ENGAGE" or "HOLDING FIRE", 0.060, 0.664,
               f.auto_engage and ERR_R or DIM_R, f.auto_engage and ERR_G or DIM_G,
               f.auto_engage and ERR_B or DIM_B, 235)

    -- ── Centre: fire-control reticle while the command camera is up ────────────────
    if f.command then
        local cx, cy = 0.5, 0.5
        local lock = f.target_locked
        local rr, rg, rb = lock and ERR_R or OK_R, lock and ERR_G or OK_G, lock and ERR_B or OK_B
        hline(cx - 0.026, cy, 0.014, rr, rg, rb, 240, 0.0016)
        hline(cx + 0.012, cy, 0.014, rr, rg, rb, 240, 0.0016)
        vline(cx, cy - 0.042, 0.024, rr, rg, rb, 240, 0.0009)
        vline(cx, cy + 0.018, 0.024, rr, rg, rb, 240, 0.0009)
        rect(cx - 0.0016, cy - 0.0028, 0.0032, 0.0056, rr, rg, rb, 255)
        if lock then
            for _, c in ipairs({ { -0.034, -0.050 }, { 0.024, -0.050 }, { -0.034, 0.046 }, { 0.024, 0.046 } }) do
                hline(cx + c[1], cy + c[2], 0.010, rr, rg, rb, 255, 0.0016)
                vline(cx + c[1] + (c[1] < 0 and 0 or 0.010), cy + c[2], 0.012 * (c[2] < 0 and 1 or -1),
                      rr, rg, rb, 255, 0.0010)
            end
        end
        txt_center(font.tiny, lock and "TARGET LOCKED" or "NO TARGET", cx, cy + 0.050, rr, rg, rb, 240)
    end

    -- ── Bottom-left: live control legend ───────────────────────────────────────────
    local rows
    if f.command then
        rows = { { "LMB", armed and "Full salvo" or "Batteries safe", { KEY.ATTACK }, armed },
                 { "MOUSE", "Aim", nil },
                 { "BACK", "Exit view", nil } }
    elseif f.helm then
        rows = { { "W/S", "Thrust", { KEY.FWD, KEY.BACK } },
                 { "A/D", "Turn", { KEY.LEFT, KEY.RIGHT } },
                 { "SPACE", "Climb", { KEY.JUMP } },
                 { "CTRL", "Descend", { KEY.DUCK } },
                 { "SHIFT", "Boost", { KEY.SPRINT } },
                 { "S", "Brake hold", { KEY.BRAKE } },
                 { "BACK", "Leave helm", nil } }
    else
        rows = { { "AUTO", string.upper(f.mode or "Hold"), nil },
                 { "ARM", armed and "Batteries live" or "Batteries safe", nil, armed },
                 { "ENG", f.auto_engage and "Auto engaging" or "Holding fire", nil, f.auto_engage } }
    end
    legend(0.018, 0.936, rows)

    -- ── Bottom bar: position, attitude, mission ────────────────────────────────────
    local by, bh2 = 0.944, 0.044
    card(0.018, by, 0.196, bh2, nil)
    txt(font.tiny, "POS", 0.027, by + 0.006, DIM_R, DIM_G, DIM_B, 225)
    txt_right(font.tiny, fmt("X %.0f   Y %.0f", f.x or 0, f.y or 0), 0.208, by + 0.006,
              TXT_R, TXT_G, TXT_B, 235)
    txt(font.tiny, "ALT", 0.027, by + 0.023, DIM_R, DIM_G, DIM_B, 225)
    txt_right(font.tiny, fmt("%.0f m   HDG %03d", sm_alt, floor(sm_hdg) % 360), 0.208, by + 0.023,
              TXT_R, TXT_G, TXT_B, 235)

    -- Attitude: numbers plus a level bar that pitches and rolls with the hull.
    card(0.402, by, 0.196, bh2, nil)
    local pitch, roll = f.pitch or 0, f.roll or 0
    txt(font.tiny, fmt("PIT %+.1f", pitch), 0.411, by + 0.006, TXT_R, TXT_G, TXT_B, 235)
    txt_center(font.tiny, fmt("ROL %+.1f", roll), 0.500, by + 0.006, TXT_R, TXT_G, TXT_B, 235)
    txt_right(font.tiny, fmt("YAW %03d", floor(sm_hdg) % 360), 0.589, by + 0.006, TXT_R, TXT_G, TXT_B, 235)
    local horizon = by + 0.032 - min(1, max(-1, pitch / 45)) * 0.006
    local roll_off = min(1, max(-1, roll / 30)) * 0.006
    hline(0.435, horizon - roll_off, 0.130, ar, ag, ab, 200, 0.0016)
    rect(0.411, horizon - 0.001, 0.018, 0.003, ar, ag, ab, 235)
    rect(0.571, horizon - 0.001, 0.018, 0.003, ar, ag, ab, 235)

    card(0.786, by, 0.196, bh2, nil)
    if route_count > 0 then
        txt(font.tiny, "PATROL", 0.795, by + 0.006, DIM_R, DIM_G, DIM_B, 225)
        txt_right(font.tiny, fmt("%d / %d", floor(f.route_index or 0), route_count), 0.976, by + 0.006,
                  TXT_R, TXT_G, TXT_B, 235)
        rect(0.795, by + 0.029, 0.181, 0.005, 255, 255, 255, 22, 1)
        rect(0.795, by + 0.029, 0.181 * min(1, floor(f.route_index or 0) / route_count), 0.005, ar, ag, ab, 235, 1)
    elseif (f.destination or 0) > 0 then
        txt(font.tiny, "WAYPOINT", 0.795, by + 0.006, DIM_R, DIM_G, DIM_B, 225)
        txt_right(font.small, fmt("%.0f m", f.destination), 0.976, by + 0.004, ar, ag, ab, 245)
    else
        txt(font.tiny, "DRIVE", 0.795, by + 0.006, DIM_R, DIM_G, DIM_B, 225)
        txt_right(font.small, fmt("%.0f m/s", sm_speed), 0.976, by + 0.004, ar, ag, ab, 245)
        rect(0.795, by + 0.029, 0.181, 0.005, 255, 255, 255, 22, 1)
        rect(0.795, by + 0.029, 0.181 * min(1, sm_speed / 30), 0.005, ar, ag, ab, 235, 1)
    end
end)
