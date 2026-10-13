-- Snowball Fight. Published by misc_snowball_fight::draw while the feature is enabled.
--   mode         0 = everyone vs you, 1 = free for all
--   fighters     how many people are in the fight
--   landed       snowballs you landed; taken = snowballs that hit you
--   landed_age / taken_age   0..1 just after a hit (absent otherwise)

local function centred(fnt, x, y, str, r, g, b, a)
    text.draw(fnt, x - text.width(fnt, str) * 0.5, y, r, g, b, a, str)
end

local function frost(sw, sh, a)
    local d = math.floor(sh * 0.16)
    draw.rect_gradient(0, 0, sw, d, 235, 245, 255, a, 235, 245, 255, a, 235, 245, 255, 0, 235, 245, 255, 0)
    draw.rect_gradient(0, sh - d, sw, sh, 235, 245, 255, 0, 235, 245, 255, 0, 235, 245, 255, a, 235, 245, 255, a)
    draw.rect_gradient(0, 0, d, sh, 235, 245, 255, a, 235, 245, 255, 0, 235, 245, 255, 0, 235, 245, 255, a)
    draw.rect_gradient(sw - d, 0, sw, sh, 235, 245, 255, 0, 235, 245, 255, a, 235, 245, 255, a, 235, 245, 255, 0)
end

local function stat(x, y, w, label, value, age, r, g, b)
    local pop = age and (1 + 0.45 * math.max(0, 1 - age / 0.25)) or 1
    local s = tostring(math.floor(value or 0))
    draw.with_scale(x + w * 0.5, y + 22, pop, function()
        centred(font.display, x + w * 0.5, y + 4, s, r, g, b, 255)
    end)
    centred(font.tiny, x + w * 0.5, y + 8 + text.height(font.display), label, 160, 170, 185, 255)
    if age then
        local a = math.floor(255 * (1 - age))
        centred(font.small, x + w * 0.5 + 26, y - age * 18, "+1", r, g, b, a)
    end
end

features.on_draw("Snowball Fight", function(f)
    if not f.active then return end
    local sw, sh = ctx.screen_w(), ctx.screen_h()
    local now = ctx.time()

    if f.taken_age then
        frost(sw, sh, math.floor(150 * (1 - f.taken_age)))
    end
    if f.landed_age and f.landed_age < 0.6 then
        local p = f.landed_age / 0.6
        draw.with_scale(sw * 0.5, sh * 0.42, 1 + 0.3 * (1 - p), function()
            text.draw_outlined(font.item, sw * 0.5 - text.width(font.item, "SPLAT!") * 0.5, sh * 0.42 - 30 * p,
                235, 245, 255, math.floor(255 * (1 - p)), 40, 90, 140, math.floor(200 * (1 - p)), 2.0, "SPLAT!")
        end)
    end

    local w = 230
    local h = 40 + text.height(font.tiny) * 3 + text.height(font.display)
    local right = sw * 0.985
    local x, y = right - w, sh * 0.30
    draw.rect(x, y, right, y + h, 10, 14, 22, 205, 8)

    local spin = now * 1.5
    for i = 0, 2 do
        local t = spin + i * 2.094
        draw.line(x + 16 + math.cos(t) * 5, y + 15 + math.sin(t) * 5, x + 16 - math.cos(t) * 5, y + 15 - math.sin(t) * 5,
            200, 230, 255, 255, 1.5)
    end
    text.draw(font.tiny, x + 28, y + 8, 200, 230, 255, 255, "SNOWBALL FIGHT")
    local mode = f.mode == 1 and "FREE FOR ALL" or "EVERYONE VS YOU"
    local people = string.format("%d IN", math.floor(f.fighters or 0))
    text.draw(font.tiny, right - 14 - text.width(font.tiny, people), y + 8, 140, 150, 165, 255, people)
    text.draw(font.tiny, x + 28, y + 8 + text.height(font.tiny), 140, 150, 165, 255, mode)

    local col = (w - 20) * 0.5
    local sy = y + 22 + text.height(font.tiny) * 2
    stat(x + 10, sy, col, "YOU HIT", f.landed, f.landed_age, 170, 220, 255)
    if f.mode == 1 then
        stat(x + 10 + col, sy, col, "FIGHTERS", f.fighters, nil, 240, 240, 245)
    else
        stat(x + 10 + col, sy, col, "HIT BY", f.taken, f.taken_age, 255, 120, 110)
    end
    draw.rect(x + 10 + col, sy + 6, x + 11 + col, sy + text.height(font.display) + 14, 60, 70, 85, 255)
end)
