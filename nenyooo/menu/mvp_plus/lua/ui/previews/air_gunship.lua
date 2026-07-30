
-- AC-130 gun-camera HUD. Published by C++ (air_gunship::draw) while the gunship is up:
--   gunner : true while you're looking through the gun camera
--   auto   : Auto Engage is on
--   gun    : loaded cannon name        vision : vision mode name
--   fov    : current camera FOV (zoom) engaged: auto engagements this sortie (rounds sent, not kills)
-- Only the reticle needs the camera; the status strip shows whenever the gunship is airborne so you
-- can see Auto working from the ground.
features.on_draw("Air Gunship", function(f)
    local sw, sh = ctx.screen_w(), ctx.screen_h()
    local ar, ag, ab = theme.accent()
    local cx, cy = sw * 0.5, sh * 0.5

    if f.gunner then
        -- Reticle: gapped crosshair + corner ticks, scaled by zoom so it tightens as you narrow the FOV.
        local k = math.max(0.35, (f.fov or 35) / 45)
        local gap, arm = 14 * k, 26 * k
        local r, g, b = 120, 255, 170
        draw.rect(cx - gap - arm, cy - 1, cx - gap, cy + 1, r, g, b, 220)
        draw.rect(cx + gap, cy - 1, cx + gap + arm, cy + 1, r, g, b, 220)
        draw.rect(cx - 1, cy - gap - arm, cx + 1, cy - gap, r, g, b, 220)
        draw.rect(cx - 1, cy + gap, cx + 1, cy + gap + arm, r, g, b, 220)
        draw.rect(cx - 1, cy - 1, cx + 1, cy + 1, r, g, b, 255)

        local box = 90 * k
        local t = 2
        for _, s in ipairs({ {-1,-1}, {1,-1}, {-1,1}, {1,1} }) do
            local bx, by = cx + s[1] * box, cy + s[2] * box
            draw.rect(bx - (s[1] > 0 and 18 or 0), by - t * 0.5, bx + (s[1] > 0 and 0 or 18), by + t * 0.5, r, g, b, 140)
            draw.rect(bx - t * 0.5, by - (s[2] > 0 and 18 or 0), bx + t * 0.5, by + (s[2] > 0 and 0 or 18), r, g, b, 140)
        end

        text.draw(font.tiny, cx + gap + arm + 8, cy - text.height(font.tiny) * 0.5, r, g, b, 200,
                  string.format("%.0f", f.fov or 35))
    end

    -- Status strip, bottom-left.
    local pad = 14
    local lines = {
        { "GUNSHIP", 235, 235, 240 },
        { "Gun     " .. (f.gun or "-"), 190, 192, 204 },
        { "Vision  " .. (f.vision or "-"), 190, 192, 204 },
        { "Auto    " .. (f.auto and ("ON  (" .. math.floor(f.engaged or 0) .. ")") or "off"),
          f.auto and 120 or 150, f.auto and 255 or 152, f.auto and 170 or 164 },
    }
    local lh = text.height(font.small) + 3
    local bw, bh = 190, lh * #lines + pad
    local bx, by = pad, sh - pad - bh
    draw.rect(bx, by, bx + bw, by + bh, 12, 13, 18, 205, 5)
    draw.rect(bx, by, bx + 2, by + bh, ar, ag, ab, 255, 0)
    for i, l in ipairs(lines) do
        text.draw(i == 1 and font.item or font.small, bx + 12, by + pad * 0.5 + (i - 1) * lh,
                  l[2], l[3], l[4], 255, l[1])
    end

    if f.gunner then
        local hint = "LMB fire   Space gun   Ctrl vision   Scroll/RMB zoom   Backspace exit"
        text.draw(font.tiny, sw * 0.5 - text.width(font.tiny, hint) * 0.5, sh - pad - text.height(font.tiny),
                  150, 152, 164, 220, hint)
    end
end)
