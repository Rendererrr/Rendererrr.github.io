features.on_draw("Saddle Inventory", function(f)
    if not __panelkit then return end
    local rows={}
    for name,value in string.gmatch(f.rows or "", "([^\t]*)\t([^\n]*)\n") do rows[#rows+1]={name,value} end
    if #rows==0 then rows={{"Inventory","Refresh to query the saddle horse"}} end
    __panelkit.panel("Saddle Inventory",40,400,"Saddle Inventory",rows)
end)
