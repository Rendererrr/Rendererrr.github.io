features.on_draw("Trip Meter", function(f)
    if type(f.distance_m) ~= "number" or not __panelkit then return end

    local function format_time(milliseconds)
        local total = math.floor(math.max(0, milliseconds or 0) / 1000)
        local hours = math.floor(total / 3600)
        local minutes = math.floor(total / 60) % 60
        local seconds = total % 60
        if hours > 0 then return string.format("%d:%02d:%02d", hours, minutes, seconds) end
        return string.format("%02d:%02d", minutes, seconds)
    end

    local miles = f.miles
    local distance_unit, speed_unit = miles and "mi" or "km", miles and "mph" or "km/h"
    local distance_scale = miles and (1 / 1609.344) or (1 / 1000)
    local speed_scale = miles and 2.23694 or 3.6
    local function speed_text(ms) return string.format("%.0f %s", (ms or 0) * speed_scale, speed_unit) end

    local distance = string.format("%.2f %s", f.distance_m * distance_scale, distance_unit)
    local rows = {
        { "Distance", distance },
        { "Speed", speed_text(f.speed_ms) },
    }
    if f.show_top then rows[#rows + 1] = { "Top", speed_text(f.top_speed_ms) } end
    if f.show_average then
        local moving_s = (f.moving_ms or 0) / 1000
        rows[#rows + 1] = { "Average", speed_text(moving_s > 1 and f.distance_m / moving_s or 0) }
    end
    rows[#rows + 1] = { "Time", format_time(f.elapsed_ms) }
    __panelkit.feature("trip_meter", "Trip Meter", rows, 86, 45, { digest = { "", distance } })
end)
