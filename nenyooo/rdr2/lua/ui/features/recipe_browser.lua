features.on_draw("Recipe Browser", function(f)
    if not __panelkit then return end
    local rows = {{"Recipe", f.valid and "Available" or "No readable crafting recipe"}}
    if f.valid then
        rows[#rows+1] = {"Item", f.name or ""}
        rows[#rows+1] = {"Variant", tostring(f.variant or 1).." / "..tostring(f.variants or 0)}
        rows[#rows+1] = {"Unlock requirements", f.unlocked and "Met" or "Locked"}
        for name, count in string.gmatch(f.rows or "", "([^\t]*)\t([^\n]*)\n") do rows[#rows+1] = {name, count} end
    end
    __panelkit.panel("Recipe Browser", 40, 400, "Recipe Browser", rows)
end)
