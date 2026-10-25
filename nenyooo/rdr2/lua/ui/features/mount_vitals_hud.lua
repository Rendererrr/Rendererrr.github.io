features.on_draw("Mount Vitals HUD", function(f)
    if type(f.health) ~= "number" or type(f.stamina) ~= "number" or not __panelkit then return end

    local function vital(label, value, core, color)
        value = math.max(0, math.min(100, value or 0))
        local detail = ""
        if f.show_values then detail = string.format("%d%%", math.floor(value + 0.5)) end
        if f.show_cores then
            if detail ~= "" then detail = detail .. "  " end
            detail = detail .. string.format("Core %d%%", math.floor(math.max(0, math.min(100, core or 0)) + 0.5))
        end
        return { label, detail, bar = value / 100, bar_h = 4, bar_color = color }
    end

    local rows = {
        vital("Health", f.health, f.health_core, __panelkit.rgb(f, "health_", 195, 85, 75)),
        vital("Stamina", f.stamina, f.stamina_core, __panelkit.rgb(f, "stamina_", 235, 210, 85)),
    }
    __panelkit.feature("mount_vitals_hud", "Mount Vitals", rows, 6, 52,
        { digest = { "", string.format("%d%%", math.floor(math.max(0, f.health) + 0.5)) } })
end)
