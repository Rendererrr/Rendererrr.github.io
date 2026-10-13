-- Car Bowling. Published by misc_car_bowling::draw while the feature is enabled.
--   state        0 idle, 1 racked (waiting for you), 2 pins falling, 3 scored (re-racking soon)
--   standing     bitmask of pins still up; bit 0 = head pin, rows of 1/2/3/4 going back
--   frame        rolls played this game (0..10); scores = "n,n,...," per frame (-1 = not played)
--   total, best  this game's total / best finished game
--   distance     metres from you to the rack
--   result_age   0..1 for three seconds after a roll is scored, with last_down = pins knocked
--   lane_x/y     screen position above the rack (absent when off screen or not racked)

local function centred(fnt, x, y, str, r, g, b, a)
    text.draw(fnt, x - text.width(fnt, str) * 0.5, y, r, g, b, a, str)
end

local function scores_of(s)
    local out = {}
    for n in (s or ""):gmatch("(-?%d+),") do out[#out + 1] = tonumber(n) end
    return out
end

local function mark(v)
    if not v or v < 0 then return "" end
    if v == 10 then return "X" end
    if v == 0 then return "-" end
    return tostring(v)
end

local function pins(cx, by, mask, gap, rad, ar, ag, ab)
    local i = 0
    for row = 0, 3 do
        for col = 0, row do
            local x = cx + (col - row * 0.5) * gap
            local y = by - row * gap * 0.9
            local up = math.floor(mask / (2 ^ i)) % 2 == 1
            if up then
                draw.circle(x, y, rad, 245, 245, 250, 255)
            else
                draw.circle_outline(x, y, rad, 255, 90, 70, 200, 1.5)
            end
            i = i + 1
        end
    end
end

local function board(f, sw, sh, now, ar, ag, ab)
    local list = scores_of(f.scores)
    local cell = 34
    local pin_w = 80
    local w = pin_w + cell * 10 + 64 + 24
    local h = 78
    local x = sw * 0.5 - w * 0.5
    local y = sh * 0.86 - h

    draw.rect(x, y, x + w, y + h, 10, 10, 16, 210, 8)
    draw.rect(x, y, x + w, y + 3, ar, ag, ab, 255, 2)

    text.draw(font.tiny, x + 12, y + 9, 165, 165, 180, 255, "CAR BOWLING")
    local status
    if f.state == 1 then
        status = string.format("DRIVE THROUGH THE PINS  %dm", math.floor(f.distance or 0))
    elseif f.state == 2 then
        status = "PINS FALLING..."
    elseif f.state == 3 then
        status = "RE-RACKING"
    else
        status = "SETTING UP"
    end
    local best = (f.best or 0) > 0 and string.format("   BEST %d", f.best) or ""
    local right_txt = status .. best
    text.draw(font.tiny, x + w - 12 - text.width(font.tiny, right_txt), y + 9, 200, 200, 215, 255, right_txt)

    pins(x + 12 + pin_w * 0.5, y + h - 14, math.floor(f.standing or 0), 13, 4.5, ar, ag, ab)

    local cy = y + 28
    local current = math.floor(f.frame or 0)
    if f.game_over then current = -1 end
    for i = 1, 10 do
        local cx = x + 12 + pin_w + (i - 1) * cell
        local live = (i - 1) == current
        if live then
            local p = 0.6 + 0.4 * math.sin(now * 6)
            draw.rect(cx, cy, cx + cell - 3, cy + 40, ar, ag, ab, math.floor(110 * p), 3)
        else
            draw.rect(cx, cy, cx + cell - 3, cy + 40, 30, 30, 40, 230, 3)
        end
        centred(font.tiny, cx + (cell - 3) * 0.5, cy + 2, tostring(i), 120, 120, 135, 255)
        local v = list[i]
        local s = mark(v)
        local r, g, b = 240, 240, 245
        if v == 10 then r, g, b = 255, 200, 40 end
        centred(font.small, cx + (cell - 3) * 0.5, cy + 16, s, r, g, b, 255)
    end

    local tx = x + 12 + pin_w + cell * 10 + 6
    draw.rect(tx, cy, tx + 64, cy + 40, 30, 30, 40, 230, 3)
    centred(font.tiny, tx + 32, cy + 2, "TOTAL", 120, 120, 135, 255)
    centred(font.item, tx + 32, cy + 14, tostring(math.floor(f.total or 0)), ar, ag, ab, 255)
end

local function lane(f, sw, sh, now)
    if not f.lane_x then return end
    local x, y = f.lane_x * sw, f.lane_y * sh
    local s = string.format("PINS  %dm", math.floor(f.distance or 0))
    local w = text.width(font.small, s) + 20
    local h = text.height(font.small) + 8
    local p = 0.75 + 0.25 * math.sin(now * 5)
    draw.rect(x - w * 0.5, y - h, x + w * 0.5, y, 10, 10, 16, math.floor(200 * p), 5)
    text.draw(font.small, x - w * 0.5 + 10, y - h + 4, 255, 200, 40, 255, s)
end

local function result(f, sw, sh, now, ar, ag, ab)
    local age = f.result_age or 1
    local a = math.floor(255 * math.min(1, (1 - age) / 0.25))
    local cx, cy = sw * 0.5, sh * 0.30
    local down = math.floor(f.last_down or 0)
    local pop = 1 + 0.6 * math.max(0, 1 - age / 0.06)

    local title, r, g, b
    if down >= 10 then
        title, r, g, b = "STRIKE!", 255, 200, 40
        local rays = 16
        local len = 60 + 220 * math.min(1, age / 0.2)
        for k = 0, rays - 1 do
            local t = k / rays * math.pi * 2 + now * 0.6
            draw.line(cx + math.cos(t) * 40, cy + 20 + math.sin(t) * 40, cx + math.cos(t) * len, cy + 20 + math.sin(t) * len,
                255, 200, 40, math.floor(a * 0.35), 3)
        end
    elseif down == 9 then
        title, r, g, b = "SO CLOSE  9 PINS", 255, 255, 255
    elseif down == 1 then
        title, r, g, b = "1 PIN", 255, 255, 255
    else
        title, r, g, b = string.format("%d PINS", down), 255, 255, 255
    end

    draw.with_scale(cx, cy + 20, pop, function()
        text.draw_outlined(font.display, cx - text.width(font.display, title) * 0.5, cy, r, g, b, a, 0, 0, 0, math.floor(a * 0.8), 2.0, title)
    end)
    if f.game_over then
        local s = string.format("GAME OVER   TOTAL %d", math.floor(f.total or 0))
        centred(font.item, cx, cy + text.height(font.display) + 10, s, ar, ag, ab, a)
    end
end

features.on_draw("Car Bowling", function(f)
    if not f.active then return end
    local sw, sh = ctx.screen_w(), ctx.screen_h()
    local now = ctx.time()
    local ar, ag, ab = theme.accent()

    lane(f, sw, sh, now)
    board(f, sw, sh, now, ar, ag, ab)
    if f.result_age then result(f, sw, sh, now, ar, ag, ab) end
end)
