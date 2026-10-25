features.on_draw("Kill Counter", function(f)
    if type(f.kills) ~= "number" or not __panelkit then return end

    local headshots = f.headshots or 0
    local rate = f.kills > 0 and math.floor(headshots * 100 / f.kills + 0.5) or 0
    local rows = {
        { "Kills", tostring(f.kills) },
        { "Headshots", string.format("%d  (%d%%)", headshots, rate) },
    }
    if f.show_streak then
        rows[#rows + 1] = { "Streak", tostring(f.streak or 0) }
        rows[#rows + 1] = { "Best Streak", tostring(f.best_streak or 0) }
    end
    if f.show_animals then rows[#rows + 1] = { "Animals", tostring(f.animals or 0) } end
    __panelkit.feature("kill_counter", "Kill Counter", rows, 86, 26, { digest = { "", tostring(f.kills) } })
end)
