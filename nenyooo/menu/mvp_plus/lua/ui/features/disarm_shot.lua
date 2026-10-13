-- Disarm Shot. Published by wep_disarm_shot::draw for a moment after each arm or hand hit.
--   marks   "label_on,lx,ly,hit_on,hx,hy,age,kind,reaction;" per hit
--           (lx,ly) above the ped's head, (hx,hy) where the bullet hit, age 0..1
--           kind 1 = weapon knocked away, 2 = arm hit on someone unarmed
--           reaction 0 = drop only, 1 = surrender, 2 = flee

local SUB = { [1] = "HANDS UP", [2] = "RUNNING" }

local function marks(s)
    local out = {}
    for item in (s or ""):gmatch("([^;]+);") do
        local lo, lx, ly, ho, hx, hy, age, kind, reaction = item:match(
            "^([01]),([^,]+),([^,]+),([01]),([^,]+),([^,]+),([^,]+),(%d+),(%d+)$")
        if lo then
            out[#out + 1] = {
                label_on = lo == "1", lx = tonumber(lx), ly = tonumber(ly),
                hit_on = ho == "1", hx = tonumber(hx), hy = tonumber(hy),
                age = tonumber(age), kind = tonumber(kind), reaction = tonumber(reaction),
            }
        end
    end
    return out
end

local function hitmarker(x, y, p, r, g, b)
    local a = math.floor(255 * (1 - p))
    local spread = 6 + 14 * p
    local len = 9
    for _, d in ipairs({ { 1, 1 }, { -1, 1 }, { 1, -1 }, { -1, -1 } }) do
        local sx, sy = x + d[1] * spread, y + d[2] * spread
        draw.line(sx, sy, sx + d[1] * len, sy + d[2] * len, 0, 0, 0, math.floor(a * 0.6), 5)
        draw.line(sx, sy, sx + d[1] * len, sy + d[2] * len, r, g, b, a, 2.5)
    end
    if p < 0.3 then
        draw.circle_outline(x, y, 4 + 40 * p, r, g, b, math.floor(255 * (1 - p / 0.3)), 2)
    end
end

local function broken_gun(x, y, a, r, g, b)
    draw.rect(x - 11, y - 4, x + 2, y + 1, r, g, b, a, 1)
    draw.rect(x - 8, y + 1, x - 4, y + 8, r, g, b, a, 1)
    draw.line(x + 5, y - 6, x + 12, y + 7, 255, 255, 255, a, 2.5)
    draw.line(x + 12, y - 6, x + 5, y + 7, 255, 255, 255, a, 2.5)
end

features.on_draw("Disarm Shot", function(f)
    if not f.active then return end
    local sw, sh = ctx.screen_w(), ctx.screen_h()
    for _, m in ipairs(marks(f.marks)) do
        local p = m.age
        local disarmed = m.kind == 1
        local r, g, b = 255, 200, 40
        if not disarmed then r, g, b = 255, 255, 255 end

        if m.hit_on then hitmarker(m.hx * sw, m.hy * sh, p, r, g, b) end

        if m.label_on then
            local fade = math.min(1, (1 - p) / 0.35)
            local a = math.floor(255 * fade)
            local x, y = m.lx * sw, m.ly * sh - p * 28
            local title = disarmed and "DISARMED" or "ARM SHOT"
            local sub = SUB[m.reaction]
            local pop = 1 + 0.45 * math.max(0, 1 - p / 0.12)
            draw.with_scale(x, y, pop, function()
                local tw = text.width(font.item, title)
                local icon_w = disarmed and 28 or 0
                local x0 = x - (tw + icon_w) * 0.5
                if disarmed then broken_gun(x0 + 12, y + text.height(font.item) * 0.5, a, r, g, b) end
                text.draw_outlined(font.item, x0 + icon_w, y, r, g, b, a, 0, 0, 0, math.floor(a * 0.8), 2.0, title)
                if sub then
                    local sw2 = text.width(font.tiny, sub)
                    text.draw_outlined(font.tiny, x - sw2 * 0.5, y + text.height(font.item) + 2, 230, 230, 235, a,
                        0, 0, 0, math.floor(a * 0.7), 1.5, sub)
                end
            end)
        end
    end
end)
