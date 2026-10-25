features.on_draw("Waypoint Marker", function(f)
    if type(f.x) ~= "number" or type(f.y) ~= "number" then return end
    local sw, sh = ctx.screen_w(), ctx.screen_h()
    if not sw or not sh or sw < 1 or sh < 1 then return end
    local x, y = f.x * sw, f.y * sh
    local size = math.max(4, (f.marker_scale or 95) * 0.16)
    local r, g, b, a = f.marker_r or 232, f.marker_g or 198, f.marker_b or 5, f.marker_a or 255
    draw.line(x, y - size, x + size * 0.65, y, r, g, b, a, 2)
    draw.line(x + size * 0.65, y, x, y + size, r, g, b, a, 2)
    draw.line(x, y + size, x - size * 0.65, y, r, g, b, a, 2)
    draw.line(x - size * 0.65, y, x, y - size, r, g, b, a, 2)
    draw.circle(x, y, 3, r, g, b, a)
    local label = tostring(math.floor(f.distance or 0)) .. "m"
    if f.show_bearing and type(f.bearing) == "number" then
        label = label .. string.format("  %03d degrees", math.floor(f.bearing + 0.5) % 360)
    end
    if f.show_eta and type(f.eta_seconds) == "number" and f.eta_seconds >= 0 then
        local eta = math.floor(f.eta_seconds)
        if eta < 360000 then
            local hours = math.floor(eta / 3600)
            local minutes = math.floor(eta / 60) % 60
            local seconds = eta % 60
            if hours > 0 then
                label = label .. string.format("  ETA %d:%02d:%02d", hours, minutes, seconds)
            else
                label = label .. string.format("  ETA %02d:%02d", minutes, seconds)
            end
        end
    end
    local scale = math.max(0.2, f.text_scale or 1)
    text.draw_scaled(font.small, x - text.width(font.small, label) * scale * 0.5,
        y + size + 3, f.text_r or 255, f.text_g or 255, f.text_b or 255,
        f.text_a or 255, scale, label)
end)
