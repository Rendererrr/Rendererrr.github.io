features.on_draw("Wagon Transport", function(f)
    if not __panelkit then return end
    local rows = {{"Wagon", (f.vehicle or 0) ~= 0 and tostring(f.vehicle) or "Enter or select a wagon"}, {"Seats", tostring(f.seats or 0)}, {"Selected seat", tostring(f.seat or -1)}, {"Occupant", (f.occupant or 0) ~= 0 and tostring(f.occupant) or "Empty"}}
    __panelkit.panel("Wagon Transport", 40, 400, "Wagon Transport", rows)
end)
