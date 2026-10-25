features.on_draw("World Scanner HUD", function(f)
    if type(f.humans) ~= "number" or not __panelkit then return end

    local threat = __panelkit.rgb(f, "threat_", 235, 70, 60)
    local hostiles = f.hostiles or 0
    local rows = { { "Radius", string.format("%.0f m", math.max(0, f.radius or 0)) } }
    if f.show_humans then rows[#rows + 1] = { "Humans", tostring(f.humans or 0) } end
    if f.show_animals then rows[#rows + 1] = { "Animals", tostring(f.animals or 0) } end
    if f.show_horses then rows[#rows + 1] = { "Horses", tostring(f.horses or 0) } end
    if f.show_vehicles then rows[#rows + 1] = { "Vehicles", tostring(f.vehicles or 0) } end
    if f.show_hostiles then
        rows[#rows + 1] = { "Hostiles", tostring(hostiles), color = hostiles > 0 and threat or nil }
    end
    if f.show_bodies then rows[#rows + 1] = { "Bodies", tostring(f.bodies or 0) } end
    __panelkit.feature("world_scanner", "World Scanner", rows, 82, 62,
        { digest = { "", hostiles > 0 and (tostring(hostiles) .. " hostile") or tostring(f.humans or 0) } })
end)
