features.on_draw("Ammo HUD", function(f)
    if type(f.total) ~= "number" or type(f.maximum) ~= "number" or f.maximum <= 0 or not __panelkit then return end

    local percent = math.max(0, math.min(100, f.total * 100 / f.maximum))
    local low = percent <= math.max(0, math.min(50, f.low_threshold or 15))
    local low_color = low and __panelkit.rgb(f, "low_", 235, 70, 60) or nil
    local clip = math.max(0, f.clip or 0)

    local rows = {}
    local digest
    if f.show_reserve then
        digest = string.format("%d / %d", clip, math.max(0, f.reserve or 0))
        rows[#rows + 1] = { "Loaded", tostring(clip), color = low_color }
        rows[#rows + 1] = { "Reserve", tostring(math.max(0, f.reserve or 0)), color = low_color }
    else
        digest = tostring(math.max(0, f.total))
        rows[#rows + 1] = { "Ammo", digest, color = low_color }
    end
    if f.show_capacity then
        rows[#rows + 1] = { "Capacity", string.format("%d / %d", f.total, f.maximum) }
    end
    if f.show_clip_bar and f.clip_capacity_valid and (f.clip_capacity or 0) > 0 then
        local ar, ag, ab = theme.accent()
        rows[#rows + 1] = { "Magazine", string.format("%d / %d", clip, f.clip_capacity),
            bar = math.max(0, math.min(1, clip / f.clip_capacity)), bar_h = 3,
            bar_color = low_color or { ar, ag, ab }, color = low_color }
    end
    __panelkit.feature("ammo_hud", "Ammo", rows, 82, 82, { digest = { "", digest } })
end)
