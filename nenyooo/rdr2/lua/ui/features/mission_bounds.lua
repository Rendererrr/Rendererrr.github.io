features.on_draw("Mission Bounds", function(f)
    if not __panelkit then return end
    local rows = {{"Status", "No active boundary warning / data unavailable"}}
    if f.active then rows = {{"Return to area", f.countdown or "?"}} end
    __panelkit.panel("Mission Bounds", 40, 680, "Mission Bounds", rows)
end)
