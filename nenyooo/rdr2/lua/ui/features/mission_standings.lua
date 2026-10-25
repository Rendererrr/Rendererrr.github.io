features.on_draw("Mission Standings", function(f)
    if not __panelkit then return end
    local rows = {}
    if not f.active then
        rows[1] = {"Status", "Mission leaderboard not published / data unavailable"}
    else
        local entries = {}
        for i = 1, math.min(32, f.count or 0) do
            entries[#entries + 1] = {position = f["position" .. i] or 99,
                name = f["name" .. i] or "?", rank = f["rank" .. i] or "?",
                spectating = f["spectating" .. i]}
        end
        table.sort(entries, function(a, b) return a.position < b.position end)
        for _, entry in ipairs(entries) do
            rows[#rows + 1] = {tostring(entry.position) .. ". " .. entry.name,
                entry.spectating and "Spectating" or "Rank " .. entry.rank}
        end
    end
    __panelkit.panel("Mission Standings", 400, 120, "Mission Standings", rows)
end)
