features.on_draw("Herb Finder", function(f)
    if not __panelkit then return end
    local rows = {}
    for name, distance in string.gmatch(f.rows or "", "([^\t]*)\t([^\n]*)\n") do rows[#rows+1] = {name, distance} end
    if #rows == 0 then rows = {{"Plants", "No matching loaded objects"}} end
    __panelkit.panel("Herb Finder", 40, 400, "Herb Finder", rows)
end)
