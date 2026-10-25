features.on_draw("Speedometer", function(f)
    if type(f.speed) ~= "number" or not __panelkit then return end

    local unit = f.imperial and "MPH" or "KPH"
    local speed = string.format("%.0f %s", math.max(0, f.speed), unit)
    local rows = { { "Speed", speed } }
    if f.show_peak then
        rows[#rows + 1] = { "Peak", string.format("%.0f %s", math.max(0, f.peak or 0), unit) }
    end
    if f.show_trip then
        rows[#rows + 1] = { "Trip", string.format("%.2f %s", math.max(0, f.trip or 0), f.imperial and "mi" or "km") }
    end
    if f.show_average then
        rows[#rows + 1] = { "Average", string.format("%.1f %s", math.max(0, f.average or 0), unit) }
    end
    if f.show_moving_time then
        local elapsed = math.max(0, math.floor(f.moving_seconds or 0))
        local hours = math.floor(elapsed / 3600)
        local minutes = math.floor(elapsed / 60) % 60
        local seconds = elapsed % 60
        rows[#rows + 1] = { "Moving", hours > 0 and string.format("%d:%02d:%02d", hours, minutes, seconds)
            or string.format("%02d:%02d", minutes, seconds) }
    end
    if f.show_vertical then
        local vertical = f.vertical or 0
        rows[#rows + 1] = { "Vertical", string.format("%s%.1f %s", vertical >= 0 and "+" or "", vertical,
            f.imperial and "ft/s" or "m/s") }
    end
    if f.show_altitude then
        rows[#rows + 1] = { "Altitude", string.format("%.0f %s", f.altitude or 0, f.imperial and "ft" or "m") }
    end
    __panelkit.feature("speedometer", "Speedometer", rows, 45, 80, { digest = { "", speed } })
end)
