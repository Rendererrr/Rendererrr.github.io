
-- Gravity Gun HUD. Published: aiming (bool), active (bool, holding), count, on_screen (bool), x, y
-- (normalized screen pos of the held entity). Draws control hints + a reticle on the held entity.
features.on_draw("Gravity Gun", function(f)
    if not f.aiming then return end

    local sw, sh = ctx.screen_w(), ctx.screen_h()
    local ar, ag, ab = theme.accent()

    -- Control hints, bottom-centre
    local hint = f.active
        and ("Holding " .. math.floor(f.count or 1) .. "   Scroll: Distance   Fire: Launch")
        or  "Aim at an entity to grab   Scroll: Distance   Fire: Launch"
    text.draw(font.item, sw * 0.5 - 190, sh * 0.90, 235, 235, 240, 255, hint)

    -- Reticle on the held entity
    if f.active and f.on_screen then
        local x, y = (f.x or 0.5) * sw, (f.y or 0.5) * sh
        local s = 16
        draw.rect(x - s,     y - s,     x - s + 6, y - s + 2, ar, ag, ab, 235, 0)
        draw.rect(x - s,     y - s,     x - s + 2, y - s + 6, ar, ag, ab, 235, 0)
        draw.rect(x + s - 6, y - s,     x + s,     y - s + 2, ar, ag, ab, 235, 0)
        draw.rect(x + s - 2, y - s,     x + s,     y - s + 6, ar, ag, ab, 235, 0)
        draw.rect(x - s,     y + s - 2, x - s + 6, y + s,     ar, ag, ab, 235, 0)
        draw.rect(x - s,     y + s - 6, x - s + 2, y + s,     ar, ag, ab, 235, 0)
        draw.rect(x + s - 6, y + s - 2, x + s,     y + s,     ar, ag, ab, 235, 0)
        draw.rect(x + s - 2, y + s - 6, x + s,     y + s,     ar, ag, ab, 235, 0)
    end
end)
