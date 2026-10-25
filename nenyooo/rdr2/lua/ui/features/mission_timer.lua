features.on_draw("Mission Timer", function(f)
    if not __panelkit then return end
    local rows = {{"Status", "No active team countdown / data unavailable"}}
    if f.active then
        local seconds = math.floor(math.max(0, f.remaining_ms or 0) / 1000)
        rows = {{"Team", tostring(f.team or "?")},
            {"Remaining", string.format("%02d:%02d", math.floor(seconds / 60), seconds % 60)}}
    end
    __panelkit.panel("Mission Timer", 40, 540, "Mission Timer", rows)
end)
