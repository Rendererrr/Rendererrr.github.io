features.on_draw("Weather Monitor HUD", function(f)
    if type(f.temperature) ~= "number" or not __panelkit then return end

    local celsius = f.temperature
    local temperature = string.format("%.1f %s", f.fahrenheit and celsius * 9 / 5 + 32 or celsius,
        f.fahrenheit and "F" or "C")
    local extreme = f.highlight_extremes and (celsius <= 0 or celsius >= 35)

    local rows = {
        { "Temperature", temperature, color = extreme and __panelkit.rgb(f, "warning_", 240, 95, 65) or nil },
    }
    if f.show_precipitation then
        rows[#rows + 1] = { "Rain", string.format("%d%%", math.floor(math.max(0, math.min(1, f.rain or 0)) * 100 + 0.5)) }
        rows[#rows + 1] = { "Snow", string.format("%d%%", math.floor(math.max(0, math.min(1, f.snow or 0)) * 100 + 0.5)) }
    end
    if f.show_wind then
        local wind = string.format("%.1f", math.max(0, f.wind_speed or 0))
        if f.show_wind_direction and f.wind_direction_valid then
            local bearing = (f.wind_bearing or 0) % 360
            local names = { "N", "NE", "E", "SE", "S", "SW", "W", "NW" }
            wind = wind .. "  " .. names[math.floor((bearing + 22.5) / 45) % 8 + 1] ..
                string.format("  %.0f°", bearing)
        end
        rows[#rows + 1] = { "Wind", wind }
    end
    __panelkit.feature("weather_monitor", "Weather", rows, 6, 38, { digest = { "", temperature } })
end)
