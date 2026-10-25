features.on_draw("Train Controller", function(f)
    if not __panelkit then return end
    local rows = {{"Train", f.loading and "Loading" or (f.active and "Ready" or "No created train")}, {"Carriages", tostring(f.cars or 0)}, {"Speed", string.format("%.1f m/s", f.speed or 0)}}
    __panelkit.panel("Train Controller", 40, 400, "Train Controller", rows)
end)
