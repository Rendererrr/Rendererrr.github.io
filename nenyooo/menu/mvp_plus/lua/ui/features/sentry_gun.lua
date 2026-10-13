-- Sentry Gun. Published by wep_sentry_gun::draw while any turret is deployed.
--   sentries  per turret: "type,state,kills,kill_age,distance,label_on,lx,ly,laser_on,mx,my,tx,ty;"
--             type 0 Phalanx / 1 Missile Pod; state 0 scanning, 1 locking, 2 firing, 3 reloading
--             (lx,ly) above the turret; (mx,my)->(tx,ty) muzzle to target; kill_age 0..1 after a kill
-- The range ring is drawn in the world by the game (Show Range), not here.

local NAMES = { [0] = "PHALANX", [1] = "MISSILE POD" }
local STATES = { [0] = "SCANNING", [1] = "LOCKING", [2] = "FIRING", [3] = "RELOADING" }
local COLOURS = {
    [0] = { 90, 200, 255 },
    [1] = { 255, 200, 40 },
    [2] = { 255, 60, 50 },
    [3] = { 255, 140, 40 },
}

local function parse(s)
    local out = {}
    for item in (s or ""):gmatch("([^;]+);") do
        local v = {}
        for n in item:gmatch("([^,]+)") do v[#v + 1] = tonumber(n) end
        if #v >= 13 then
            out[#out + 1] = {
                type = v[1], state = v[2], kills = v[3], kill_age = v[4], distance = v[5],
                label_on = v[6] == 1, lx = v[7], ly = v[8],
                laser_on = v[9] == 1, mx = v[10], my = v[11], tx = v[12], ty = v[13],
            }
        end
    end
    return out
end

local function laser(s, sw, sh, now, r, g, b)
    local x1, y1, x2, y2 = s.mx * sw, s.my * sh, s.tx * sw, s.ty * sh
    local flicker = s.state == 2 and (0.6 + 0.4 * math.sin(now * 40)) or (0.5 + 0.5 * math.sin(now * 8))
    local a = math.floor(200 * flicker)
    draw.line(x1, y1, x2, y2, r, g, b, math.floor(a * 0.35), 6)
    draw.line(x1, y1, x2, y2, r, g, b, a, 1.5)
    local rr = s.state == 1 and (14 - 6 * ((now * 3) % 1)) or 7
    draw.circle_outline(x2, y2, rr, r, g, b, a, 2)
    draw.circle(x2, y2, 2.5, 255, 255, 255, a)
end

local function label(s, sw, sh, now, r, g, b)
    local x, y = s.lx * sw, s.ly * sh
    local fade = math.max(0, math.min(1, 1.3 - s.distance / 160))
    if fade <= 0.02 then return end
    local a = math.floor(245 * fade)
    local title = NAMES[s.type] or "SENTRY"
    local status = STATES[s.state] or ""
    local sub = s.kills > 0 and string.format("%s   %d KILLS", status, s.kills) or status
    local w = math.max(text.width(font.small, title), text.width(font.tiny, sub)) + 34
    local h = text.height(font.small) + text.height(font.tiny) + 12
    local x1, y1 = x - w * 0.5, y - h
    draw.rect(x1, y1, x1 + w, y1 + h, 10, 10, 16, math.floor(190 * fade), 6)
    local pulse = (s.state == 2 or s.state == 1) and (0.6 + 0.4 * math.sin(now * 12)) or 1
    draw.circle(x1 + 13, y1 + h * 0.5, 4.5, r, g, b, math.floor(a * pulse))
    text.draw(font.small, x1 + 24, y1 + 5, 255, 255, 255, a, title)
    text.draw(font.tiny, x1 + 24, y1 + 7 + text.height(font.small), r, g, b, a, sub)

    if s.kill_age and s.kill_age >= 0 then
        local p = s.kill_age
        local ka = math.floor(255 * math.min(1, (1 - p) / 0.35))
        local msg = "+1 KILL"
        draw.with_scale(x, y1 - 20, 1 + 0.4 * math.max(0, 1 - p / 0.12), function()
            text.draw_outlined(font.item, x - text.width(font.item, msg) * 0.5, y1 - 26 - p * 22, 255, 220, 60, ka,
                0, 0, 0, math.floor(ka * 0.8), 2.0, msg)
        end)
    end
end

features.on_draw("Sentry Gun", function(f)
    if not f.active then return end
    local sw, sh = ctx.screen_w(), ctx.screen_h()
    local now = ctx.time()
    for _, s in ipairs(parse(f.sentries)) do
        local c = COLOURS[s.state] or COLOURS[0]
        if s.laser_on then laser(s, sw, sh, now, c[1], c[2], c[3]) end
        if s.label_on then label(s, sw, sh, now, c[1], c[2], c[3]) end
    end
end)
