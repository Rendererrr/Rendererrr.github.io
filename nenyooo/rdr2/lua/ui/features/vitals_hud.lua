features.on_draw("Vitals HUD", function(f)
    if type(f.health) ~= "number" or type(f.stamina) ~= "number" or not __panelkit then return end

    local threshold = math.max(1, math.min(50, f.low_threshold or 20))
    local warning = __panelkit.rgb(f, "warning_", 255, 55, 45)
    local function vital(label, value, color)
        value = math.max(0, math.min(100, value or 0))
        local low = f.low_warning and value <= threshold
        return { label, f.show_values and string.format("%d%%", math.floor(value + 0.5)) or "",
            bar = value / 100, bar_h = 4, bar_color = low and warning or color, color = low and warning or nil }
    end

    local rows = {
        vital("Health", f.health, __panelkit.rgb(f, "health_", 190, 65, 60)),
        vital("Stamina", f.stamina, __panelkit.rgb(f, "stamina_", 235, 210, 85)),
    }
    if f.show_deadeye then
        rows[#rows + 1] = vital("Dead Eye", f.deadeye, __panelkit.rgb(f, "deadeye_", 235, 235, 235))
    end
    __panelkit.feature("vitals_hud", "Vitals", rows, 6, 66,
        { digest = { "", string.format("%d%%", math.floor(math.max(0, f.health) + 0.5)) } })
end)
