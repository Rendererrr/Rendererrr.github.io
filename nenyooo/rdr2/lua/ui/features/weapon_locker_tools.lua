features.on_draw("Weapon Locker Tools", function(f)
    if not __panelkit then return end
    local rows = {{"Status", "Open the in-game weapon locker"}}
    if f.active then
        rows = {{"Eligible weapons", tostring(f.count or 0)},
            {"Selected", f.name ~= "" and f.name or "Refresh and select an entry"},
            {"Location", f.carried and "Available to carry" or "Stored / unavailable"}}
    end
    __panelkit.panel("Weapon Locker Tools", 40, 260, "Weapon Locker Tools", rows)
end)
