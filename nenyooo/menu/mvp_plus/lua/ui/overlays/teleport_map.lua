
-- Teleport location map. Draws the GTA world map with a marker at the location currently highlighted on
-- the Teleport -> Discoveries list (teleport.preview()). Docks beside the menu. Reuses the shared world
-- map image (players.map_*) and the gtaDiscoveryApi UV calibration (same constants as player_panel.lua).
local MAP_UVSX, MAP_UVOX =  0.0000809375, 0.458203125
local MAP_UVSY, MAP_UVOY = -0.0000800781, 0.675

overlay.on_draw("teleport_map", function()
    if not menu.is_visible() then return end
    local p = teleport.preview()
    if not p or not p.active then return end

    local pad = 10
    local S   = 220                                        -- map square size
    local th  = text.height(font.item) + 6                 -- title row
    local nh  = text.height(font.small) + 2                -- name row
    local cph = text.height(font.tiny)                     -- coords row
    local pw  = S + pad * 2
    local ph  = pad + th + S + 6 + nh + cph + pad

    local sw, sh = ctx.screen_w(), ctx.screen_h()
    local bx, by, bw = menu.bounds()
    local gap = 12
    local x, y
    if bw and bw > 0 then
        -- Dock on whichever side of the menu has room.
        if (bx + bw * 0.5) < sw * 0.5 then x = bx + bw + gap else x = bx - gap - pw end
        y = by
    else
        x = sw - pw - 24; y = 120                          -- fallback: right edge
    end
    if x < 8 then x = 8 elseif x + pw > sw - 8 then x = sw - 8 - pw end
    if y < 8 then y = 8 elseif y + ph > sh - 8 then y = sh - 8 - ph end

    local ar, ag, ab = theme.accent()
    draw.rect(x, y, x + pw, y + ph, 16, 16, 22, 235, 6)
    draw.rect(x, y, x + pw, y + 2, ar, ag, ab, 255, 0)
    text.draw(font.item, x + pad, y + pad - 1, 235, 235, 240, 255, "LOCATION")

    local vx, vy = x + pad, y + pad + th
    draw.rect(vx, vy, vx + S, vy + S, 12, 13, 18, 255)

    local ready = players.map_ensure()
    local path  = players.map_path()

    -- Center the view on the location at a fixed zoom.
    local zoom = 4.0
    local cu = MAP_UVSX * p.x + MAP_UVOX
    local cv = MAP_UVSY * p.y + MAP_UVOY
    local th2 = 0.5 / zoom
    cu = math.max(th2, math.min(1 - th2, cu))
    cv = math.max(th2, math.min(1 - th2, cv))

    draw.push_clip(vx, vy, vx + S, vy + S)
    local side = S * zoom
    local dx0 = vx + S * 0.5 - cu * side
    local dy0 = vy + S * 0.5 - cv * side
    local drawn = ready and draw.preview_image(path, dx0, dy0, dx0 + side, dy0 + side, 1.0, false)
    if drawn then
        local mx = dx0 + (MAP_UVSX * p.x + MAP_UVOX) * side
        local my = dy0 + (MAP_UVSY * p.y + MAP_UVOY) * side
        draw.line(mx - 9, my, mx + 9, my, ar, ag, ab, 1.0)
        draw.line(mx, my - 9, mx, my + 9, ar, ag, ab, 1.0)
        draw.circle(mx, my, 4.0, 0, 0, 0, 200)
        draw.circle(mx, my, 2.6, ar, ag, ab, 255)
        draw.pop_clip()
    else
        draw.pop_clip()
        local s = "Loading map..."
        text.draw(font.tiny, vx + (S - text.width(font.tiny, s)) * 0.5, vy + S * 0.5 - 6, 150, 154, 165, 255, s)
    end
    draw.rect_outline(vx, vy, vx + S, vy + S, ar, ag, ab, 255, 0, 1)

    -- Name + coords caption.
    text.draw(font.small, x + pad, vy + S + 6, 235, 235, 240, 255, p.name or "-")
    local cstr = string.format("%.0f, %.0f, %.0f", p.x, p.y, p.z)
    text.draw(font.tiny, x + pad, vy + S + 6 + nh, 150, 152, 164, 255, cstr)
end)
