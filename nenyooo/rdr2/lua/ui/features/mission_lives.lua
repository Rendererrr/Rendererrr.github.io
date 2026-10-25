features.on_draw("Mission Lives", function(f)
    if not __panelkit then return end
    local rows = {}
    if not f.active then
        rows[1] = {"Status", "No supported active mission / data unavailable"}
    else
        local modes = {[0] = "Individual", [1] = "Team", [2] = "Shared", [3] = "Group"}
        rows[1] = {"Counting mode", modes[f.mode] or "Unknown"}
        for i = 1, math.min(8, f.count or 0) do
            local remaining = f["remaining" .. i]
            rows[#rows + 1] = {"Team " .. tostring(f["team" .. i] or "?"),
                remaining == -1 and "No finite limit" or tostring(remaining or "?")}
        end
    end
    __panelkit.panel("Mission Lives", 40, 400, "Mission Lives", rows)
end)
