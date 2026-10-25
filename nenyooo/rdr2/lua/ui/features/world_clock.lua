features.on_draw("World Clock", function(f)
    if type(f.hour) ~= "number" or type(f.minute) ~= "number" or not __panelkit then return end

    local hour = math.floor(f.hour) % 24
    local suffix = ""
    if not f.twenty_four_hour then
        suffix = hour >= 12 and " PM" or " AM"
        hour = hour % 12
        if hour == 0 then hour = 12 end
    end
    local clock
    if f.show_seconds then
        clock = string.format("%02d:%02d:%02d%s", hour, math.floor(f.minute), math.floor(f.second or 0), suffix)
    else
        clock = string.format("%02d:%02d%s", hour, math.floor(f.minute), suffix)
    end

    local rows = { { "Time", clock } }
    if f.show_date then
        local year = math.floor(f.year or 0)
        local month = math.floor(f.month or 0)
        local day = math.floor(f.day or 0)
        rows[#rows + 1] = { "Date", string.format("%04d-%02d-%02d", year, month, day) }
        if f.show_weekday and month >= 1 and month <= 12 then
            local offsets = { 0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4 }
            local weekdays = { "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday" }
            local y = month < 3 and year - 1 or year
            local index = (y + math.floor(y / 4) - math.floor(y / 100) +
                math.floor(y / 400) + offsets[month] + day) % 7 + 1
            rows[#rows + 1] = { "Day", weekdays[index] }
        end
    end
    __panelkit.feature("world_clock", "World Clock", rows, 82, 5, { digest = { "", clock } })
end)
