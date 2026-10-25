features.on_draw("Fishing", function(f)
    if not __panelkit then return end
    local rows = {{"Fishing task", f.active and "Active" or "Equip rod and begin fishing"}, {"Selected bait owned", tostring(f.owned or 0)}}
    __panelkit.panel("Fishing", 40, 400, "Fishing", rows)
end)
