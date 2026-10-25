features.on_draw("Stopwatch", function(f)
    if type(f.elapsed_ms) ~= "number" or not __panelkit then return end

    local function format_time(milliseconds, show_milliseconds)
        milliseconds = math.max(0, math.floor(milliseconds or 0))
        local total_seconds = math.floor(milliseconds / 1000)
        local hours = math.floor(total_seconds / 3600)
        local minutes = math.floor(total_seconds / 60) % 60
        local seconds = total_seconds % 60
        local base
        if hours > 0 then
            base = string.format("%02d:%02d:%02d", hours, minutes, seconds)
        else
            base = string.format("%02d:%02d", minutes, seconds)
        end
        if show_milliseconds then
            return base .. string.format(".%03d", milliseconds % 1000)
        end
        return base
    end

    local countdown_ms = math.max(1, math.min(120, math.floor(f.countdown_minutes or 5))) * 60000
    local display_ms = f.countdown_mode and math.max(0, countdown_ms - f.elapsed_ms) or f.elapsed_ms
    local state, state_color
    if f.countdown_mode and display_ms <= 0 then
        state, state_color = "Complete", __panelkit.style.good
    elseif f.paused then
        state, state_color = "Paused", __panelkit.style.warn
    elseif f.countdown_mode then
        state = "Countdown"
    else
        state = "Running"
    end

    local elapsed = format_time(display_ms, f.show_milliseconds)
    local rows = {
        { "Time", elapsed },
        { "State", state, color = state_color },
    }
    if f.show_lap and (f.lap_ms or 0) > 0 then
        local lap_ms = f.countdown_mode and math.max(0, countdown_ms - f.lap_ms) or f.lap_ms
        rows[#rows + 1] = { "Lap", format_time(lap_ms, f.show_milliseconds) }
    end
    __panelkit.feature("stopwatch", "Stopwatch", rows, 45, 10, { digest = { "", elapsed } })
end)
