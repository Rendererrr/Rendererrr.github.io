
-- Nuclear Missile HUD. Published fields: flying (bool), speed, altitude (m), distance (m).
-- Control hints + a live flight readout while piloting the rocket.
features.on_draw("Nuclear Missile", function(f)
    if not f.flying then return end

    local ctrls = {
        "Arrows / WASD  -  Steer",
        "Shift  -  Throttle Up",
        "Ctrl  -  Throttle Down",
        "Attack  -  Detonate",
    }
    local stats = {
        string.format("Speed       %d",   math.floor((f.speed    or 0) + 0.5)),
        string.format("Altitude    %d m", math.floor((f.altitude or 0) + 0.5)),
        string.format("Distance    %d m", math.floor((f.distance or 0) + 0.5)),
    }

    local sw, sh = ctx.screen_w(), ctx.screen_h()
    local pad = 10
    local lh  = text.height(font.item) + 4
    local gap = math.floor(lh * 0.4)
    local w   = 240
    local h   = pad * 2 + lh * (1 + #ctrls + #stats) + gap
    local x   = 20
    local y   = sh * 0.5 - h * 0.5

    draw.rect(x, y, x + w, y + h, 12, 12, 18, 200, 6)
    draw.rect(x, y, x + 3, y + h, 168, 85, 247, 255, 6)  -- accent edge

    local ar, ag, ab = theme.accent()
    local cy = y + pad
    text.draw(font.item, x + pad + 6, cy, ar, ag, ab, 255, "NUCLEAR MISSILE"); cy = cy + lh
    for _, l in ipairs(ctrls) do
        text.draw(font.item, x + pad + 6, cy, 210, 210, 216, 255, l); cy = cy + lh
    end
    cy = cy + gap
    for _, l in ipairs(stats) do
        text.draw(font.item, x + pad + 6, cy, 235, 235, 240, 255, l); cy = cy + lh
    end
end)
