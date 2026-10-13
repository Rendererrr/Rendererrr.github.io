-- Ammo counter. Published fields: active (bool), reloading (bool), clip, max_clip, reserve,
-- weapon (name, optional), shot_age (0..1 just after a shot, optional).
-- Two toggles publish here (Weapon > Visuals and World > HUD); a call with active = false must not
-- reset anything, or one toggle would cancel the other's animation.
-- A right-aligned cluster on a soft fade (no boxed card): weapon name, the clip count in fixed-width
-- digits with the reserve beside it, and the magazine as a strip of rounds underneath.

local floor, min, max, sin = math.floor, math.min, math.max, math.sin
local BIG = font.display or font.title

-- Font metrics: em = the slot's size in px, base = top-of-box to baseline (both from the engine when
-- available, so placement does not depend on the face's line spacing).
local function em_of(f) return (text.em and text.em(f)) or text.height(f) end
local function base_of(f) return (text.baseline and text.baseline(f)) or em_of(f) * 0.97 end

local INK  = { 244, 245, 248 }
local DIM  = { 150, 155, 168 }
local SPENT = { 58, 60, 70 }
local AMB  = { 255, 176, 46 }
local RED  = { 255, 66, 56 }
local ACC  = { 170, 90, 255 }

local W, H = 300, 96
local reload_started = nil

local function txt(fnt, x, y, s, c, a, align)
    local w = text.width(fnt, s)
    if align == "r" then x = x - w elseif align == "c" then x = x - w * 0.5 end
    text.draw(fnt, x, y, c[1], c[2], c[3], floor(a), s)
    return w
end

local function spaced(fnt, x, y, s, c, a, sp)
    local w = text.width_spaced(fnt, s, sp)
    text.draw_spaced(fnt, x - w, y, c[1], c[2], c[3], floor(a), s, sp)
    return w
end

-- Right-aligned numerals at an exact pixel height, fixed-width digits so the count never jitters.
-- Laid out so the baseline sits at y + 0.97 * px.
local function numerals(right, y, px, s, c, a)
    local k = px / max(1, em_of(BIG))
    y = y + 0.97 * px - base_of(BIG) * k
    local cell = text.width(BIG, "0")
    local w = cell * #s
    draw.with_scale(right, y, k, function()
        for i = 1, #s do
            local ch = s:sub(i, i)
            local cx = right - w + (i - 1) * cell + (cell - text.width(BIG, ch)) * 0.5
            text.draw(BIG, cx, y, c[1], c[2], c[3], floor(a), ch)
        end
    end)
    return w * k
end

local function chip(right, y, label, c, a)
    local fnt = font.tiny
    local w = text.width(fnt, label) + 12
    local h = text.height(fnt) + 6
    draw.rect(right - w, y, right, y + h, c[1], c[2], c[3], floor(a), 3)
    text.draw(fnt, right - w + 6, y + 3, 16, 16, 20, 255, label)
    return w
end

local function draw_counter(f, right, top, now)
    local clip = floor(f.clip or 0)
    local max_clip = max(1, floor(f.max_clip or 1))
    local reserve = floor(f.reserve or 0)
    local ratio = max(0, min(1, clip / max_clip))
    local empty = clip == 0
    local low = not empty and ratio <= 0.25
    local reloading = reload_started ~= nil
    local kick = f.shot_age and (1 - f.shot_age) or 0
    local pulse = 0.55 + 0.45 * sin(now * 9)

    local c = INK
    if empty then c = RED elseif low then c = AMB end
    local digit_a = reloading and 110 or (empty and 255 * pulse or 255)

    -- Soft backdrop: fades in from the left so the cluster reads on bright ground without a box edge.
    local x1 = right - W
    draw.rect_gradient(x1, top, right + 14, top + H, 0, 0, 0, 0, 0, 0, 0, 165, 0, 0, 0, 165, 0, 0, 0, 0)

    -- Row 1: weapon name, state chip to its left.
    local ny = top + 8
    local name = f.weapon and string.upper(f.weapon) or "AMMO"
    local nw = spaced(font.tiny, right, ny, name, DIM, 235, 1.5)
    local cx = right - nw - 10
    if reloading then
        chip(cx, ny - 3, "RELOADING", ACC, 230)
    elseif empty then
        chip(cx, ny - 3, reserve > 0 and "RELOAD" or "NO AMMO", RED, 200 + 55 * pulse)
    elseif low then
        chip(cx, ny - 3, "LOW", AMB, 225)
    end

    -- Row 2: clip count + reserve, sharing a baseline.
    local px = 46
    local ny2 = top + 22
    local reserve_txt = reserve >= 9999 and "/ INF" or ("/ " .. tostring(reserve))
    local rw = txt(font.value, right, ny2 + px * 0.97 - text.height(font.value) * 1.02, reserve_txt, DIM, 235, "r")
    local nr = right - rw - 8
    local pop = 1 + 0.12 * kick
    draw.with_scale(nr, ny2 + px * 0.97, pop, function()
        numerals(nr, ny2, px, tostring(clip), c, digit_a)
    end)

    -- Row 3: the magazine. One tick per round up to 40, a bar beyond that.
    local my, mh = top + H - 16, 9
    local mw = W - 40
    if max_clip <= 40 then
        local gap = max_clip > 24 and 2 or 3
        local tw = min(10, (mw - gap * (max_clip - 1)) / max_clip)
        local total = tw * max_clip + gap * (max_clip - 1)
        local sx = right - total
        local fill = clip
        if reloading then fill = floor(max_clip * ((now - reload_started) % 1.2 / 1.2)) end
        for i = 1, max_clip do
            local tx = sx + (i - 1) * (tw + gap)
            if i <= fill then
                local tc = reloading and ACC or c
                draw.rect(tx, my, tx + tw, my + mh, tc[1], tc[2], tc[3], 245, 1)
            elseif i == clip + 1 and kick > 0 and not reloading then
                draw.rect(tx, my, tx + tw, my + mh, 255, 255, 255, floor(255 * kick), 1)
            else
                draw.rect(tx, my, tx + tw, my + mh, SPENT[1], SPENT[2], SPENT[3], 220, 1)
            end
        end
    else
        local bx = right - mw
        local v = ratio
        if reloading then v = (now - reload_started) % 1.2 / 1.2 end
        local bc = reloading and ACC or c
        draw.rect(bx, my + 2, right, my + mh - 2, SPENT[1], SPENT[2], SPENT[3], 220, 2)
        if v > 0 then draw.rect(right - mw * v, my + 2, right, my + mh - 2, bc[1], bc[2], bc[3], 245, 2) end
    end
end

features.on_draw("Ammo Counter", function(f)
    if not f.active then return end
    local now = ctx.time()
    if f.reloading then reload_started = reload_started or now else reload_started = nil end

    local sw, sh = ctx.screen_w(), ctx.screen_h()
    local u = math.max(0.5, math.min(2.0, sh / 1080))
    local right, top = sw - 40 * u, sh * 0.80 - H * u
    ACC[1], ACC[2], ACC[3] = theme.accent()
    draw.with_scale(right, top, u, function()
        draw_counter(f, right, top, now)
    end)
end)
