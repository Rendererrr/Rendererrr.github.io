-- Air Time HUD. Published by veh_air_time::draw:
--   airborne + live_seconds / live_height / live_distance / live_flips / live_rolls / live_spins / live_score
--   result_* (same fields + result_landing: 0 clean, 1 rough, 2 crash) + result_age 0..1 + record
--   best_seconds, best_score
-- flips > 0 are front flips, < 0 back flips; rolls and spins count full turns either way.

local LANDINGS = {
    [0] = { "CLEAN LANDING", 70, 235, 110 },
    [1] = { "ROUGH LANDING  -25%", 255, 180, 60 },
    [2] = { "CRASH LANDING", 235, 60, 60 },
}

local function centered(fnt, cx, y, r, g, b, a, s)
    text.draw(fnt, cx - text.width(fnt, s) * 0.5, y, r, g, b, a, s)
end

local function commas(n)
    local s = tostring(math.floor(n + 0.5))
    return (s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

local function tricks(f, p)
    local list = {}
    local flips = math.floor(f[p .. "flips"] or 0)
    local rolls = math.abs(math.floor(f[p .. "rolls"] or 0))
    local spins = math.abs(math.floor(f[p .. "spins"] or 0))
    if flips > 0 then list[#list + 1] = flips > 1 and (flips .. "x FRONTFLIP") or "FRONTFLIP" end
    if flips < 0 then list[#list + 1] = flips < -1 and ((-flips) .. "x BACKFLIP") or "BACKFLIP" end
    if rolls > 0 then list[#list + 1] = rolls > 1 and (rolls .. "x BARREL ROLL") or "BARREL ROLL" end
    if spins > 0 then list[#list + 1] = (spins * 360) .. " SPIN" end
    return list
end

local function air_title(seconds)
    if seconds >= 5 then return "MASSIVE AIR" end
    if seconds >= 3.5 then return "HUGE AIR" end
    if seconds >= 2 then return "BIG AIR" end
    return "AIR TIME"
end

local function live(f, sw, sh, ar, ag, ab, now)
    local cx, y = sw * 0.5, sh * 0.12
    local secs = f.live_seconds or 0
    centered(font.tiny, cx, y, 200, 200, 210, 235, "AIRBORNE")
    draw.with_scale(cx, y + 16, 1.7, function()
        text.draw_outlined(font.display, cx - text.width(font.display, string.format("%.2f", secs)) * 0.5, y + 16,
            255, 255, 255, 255, 0, 0, 0, 190, 2.0, string.format("%.2f", secs))
    end)
    local stats = string.format("%.1f m HIGH   %d m FAR", f.live_height or 0, math.floor((f.live_distance or 0) + 0.5))
    centered(font.small, cx, y + 16 + text.height(font.display) * 1.7 + 4, 220, 220, 230, 240, stats)

    local list = tricks(f, "live_")
    local ty = y + 16 + text.height(font.display) * 1.7 + text.height(font.small) + 12
    for i, t in ipairs(list) do
        local pulse = 0.8 + 0.2 * math.sin(now * 10 + i)
        local w = text.width(font.small, t) + 20
        draw.rect(cx - w * 0.5, ty, cx + w * 0.5, ty + text.height(font.small) + 6, ar, ag, ab, math.floor(200 * pulse), 4)
        centered(font.small, cx, ty + 3, 255, 255, 255, 255, t)
        ty = ty + text.height(font.small) + 10
    end
end

local function card(f, sw, sh, ar, ag, ab, now)
    local age = f.result_age or 1
    local a = math.min(1, age / 0.04, (1 - age) / 0.15)
    if a <= 0 then return end
    local cx = sw * 0.5
    local y = sh * 0.10 - (1 - math.min(1, age / 0.06)) * 16
    local pop = 1 + 0.15 * math.max(0, 1 - age / 0.08)
    local landing = LANDINGS[math.floor(f.result_landing or 0)] or LANDINGS[0]

    local list = tricks(f, "result_")
    local title = #list > 0 and table.concat(list, " + ") or air_title(f.result_seconds or 0)
    local tr, tg, tb = 255, 255, 255
    if f.record then tr, tg, tb = 255, 200, 60 elseif #list > 0 then tr, tg, tb = ar, ag, ab end

    draw.with_scale(cx, y, 1.25 * pop, function()
        text.draw_outlined(font.display, cx - text.width(font.display, title) * 0.5, y,
            tr, tg, tb, math.floor(255 * a), 0, 0, 0, math.floor(200 * a), 2.0, title)
    end)

    local sy = y + text.height(font.display) * 1.25 + 8
    local stats = string.format("%.2f s   %.1f m HIGH   %d m FAR",
        f.result_seconds or 0, f.result_height or 0, math.floor((f.result_distance or 0) + 0.5))
    text.draw_outlined(font.small, cx - text.width(font.small, stats) * 0.5, sy,
        235, 235, 240, math.floor(245 * a), 0, 0, 0, math.floor(170 * a), 1.5, stats)

    local score = "+" .. commas(f.result_score or 0)
    local scy = sy + text.height(font.small) + 4
    text.draw_outlined(font.item, cx - text.width(font.item, score) * 0.5, scy,
        255, 255, 255, math.floor(250 * a), 0, 0, 0, math.floor(170 * a), 1.5, score)

    local ly = scy + text.height(font.item) + 4
    centered(font.tiny, cx, ly, landing[2], landing[3], landing[4], math.floor(240 * a), landing[1])
    if f.record then
        local pulse = 0.75 + 0.25 * math.sin(now * 8)
        centered(font.small, cx, ly + text.height(font.tiny) + 4, 255, 200, 60, math.floor(255 * a * pulse), "NEW RECORD")
    elseif f.best_seconds then
        centered(font.tiny, cx, ly + text.height(font.tiny) + 4, 180, 180, 190, math.floor(220 * a),
            string.format("BEST %.2f s   %s PTS", f.best_seconds, commas(f.best_score or 0)))
    end
end

features.on_draw("Air Time", function(f)
    if not f.active then return end
    local sw, sh = ctx.screen_w(), ctx.screen_h()
    local ar, ag, ab = theme.accent()
    local now = ctx.time()
    if f.airborne then live(f, sw, sh, ar, ag, ab, now)
    elseif f.result_age then card(f, sw, sh, ar, ag, ab, now) end
end)
