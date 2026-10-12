-- Ammo counter. Published fields: active (bool), reloading (bool), clip, max_clip, reserve,
-- weapon (name, optional), shot_age (0..1 just after a shot, optional).
-- Two toggles publish here (Weapon > Visuals and World > HUD); a call with active = false must not
-- reset anything, or one toggle would cancel the other's animation.

local reload_started = nil

local function centred(fnt, x, y, str, r, g, b, a)
    text.draw(fnt, x - text.width(fnt, str) * 0.5, y, r, g, b, a, str)
end

features.on_draw("Ammo Counter", function(f)
    if not f.active then return end

    local sw, sh = ctx.screen_w(), ctx.screen_h()
    local now = ctx.time()
    local ar, ag, ab = theme.accent()
    local clip = math.floor(f.clip or 0)
    local max_clip = math.max(1, math.floor(f.max_clip or 1))
    local reserve = math.floor(f.reserve or 0)
    local ratio = math.max(0, math.min(1, clip / max_clip))
    local empty = clip == 0
    local low = not empty and ratio <= 0.25

    if f.reloading then
        reload_started = reload_started or now
    else
        reload_started = nil
    end

    local r, g, b = 240, 240, 245
    if empty then r, g, b = 255, 70, 60 elseif low then r, g, b = 255, 180, 50 end

    local w, h = 250, 104
    local right, bottom = sw * 0.985, sh * 0.80
    local x, y = right - w, bottom - h
    local kick = f.shot_age and (1 - f.shot_age) or 0

    draw.rect(x, y, right, bottom, 10, 10, 16, 200, 8)
    draw.rect(right - 3, y, right, bottom, ar, ag, ab, 255, 2)

    local name = f.weapon and string.upper(f.weapon) or "AMMO"
    text.draw(font.tiny, x + 14, y + 10, 160, 160, 175, 255, name)

    local big = tostring(clip)
    local bh = text.height(font.title)
    local bx = x + 14
    local by = y + 14 + text.height(font.tiny)
    draw.with_scale(bx, by + bh * 0.5, 1 + 0.18 * kick, function()
        text.draw(font.title, bx, by + kick * 2, r, g, b, 255, big)
    end)
    local reserve_txt = reserve >= 9999 and "/ INF" or ("/ " .. tostring(reserve))
    local bw = text.width(font.title, big)
    text.draw(font.item, bx + bw + 8, by + bh - text.height(font.item) - 2, 180, 180, 195, 255, reserve_txt)

    -- Magazine: one pip per round up to 30, a bar beyond that.
    local py = bottom - 18
    local pw = w - 28
    if max_clip <= 30 then
        local gap = 2
        local pip = (pw - gap * (max_clip - 1)) / max_clip
        for i = 1, max_clip do
            local px = x + 14 + (i - 1) * (pip + gap)
            if i <= clip then
                local last = i == clip and kick > 0
                local pr, pg, pb = r, g, b
                if last then pr, pg, pb = 255, 255, 255 end
                draw.rect(px, py, px + pip, py + 8, pr, pg, pb, 255, 1)
            else
                draw.rect(px, py, px + pip, py + 8, 45, 45, 55, 220, 1)
            end
        end
    else
        draw.rect(x + 14, py, x + 14 + pw, py + 8, 45, 45, 55, 220, 2)
        if ratio > 0 then draw.rect(x + 14, py, x + 14 + pw * ratio, py + 8, r, g, b, 255, 2) end
    end

    if reload_started then
        local t = (now - reload_started) % 1.2 / 1.2
        draw.rect(x, y, right, bottom, 0, 0, 0, 120, 8)
        local sx = x + 14 + pw * t
        draw.rect_gradient(sx - 40, py - 2, sx, py + 10, ar, ag, ab, 0, ar, ag, ab, 200, ar, ag, ab, 200, ar, ag, ab, 0)
        local pulse = 0.6 + 0.4 * math.sin(now * 10)
        centred(font.item, x + w * 0.5, y + h * 0.5 - text.height(font.item) * 0.5 - 6, "RELOADING", 255, 255, 255, math.floor(255 * pulse))
    elseif empty then
        local pulse = 0.55 + 0.45 * math.sin(now * 9)
        draw.rect_outline(x, y, right, bottom, 255, 70, 60, math.floor(255 * pulse), 8, 2)
        local msg = reserve > 0 and "RELOAD" or "NO AMMO"
        local mw = text.width(font.small, msg) + 16
        local mx = right - 14 - mw
        local my = y + 10
        draw.rect(mx, my - 2, mx + mw, my + text.height(font.small) + 2, 255, 70, 60, math.floor(220 * pulse), 4)
        text.draw(font.small, mx + 8, my, 255, 255, 255, 255, msg)
    elseif low then
        local msg = "LOW"
        local mw = text.width(font.tiny, msg) + 12
        local mx = right - 14 - mw
        draw.rect(mx, y + 9, mx + mw, y + 11 + text.height(font.tiny), 255, 180, 50, 200, 3)
        text.draw(font.tiny, mx + 6, y + 10, 20, 20, 20, 255, msg)
    end
end)
