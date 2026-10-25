local page = 0
features.on_draw("Script Diagnostics", function(f)
    if not __panelkit then return end
    ui.begin_frame(); local interactive=menu.is_visible(); if interactive then ui.show_cursor() end
    local entries={}
    for name,state,timing,error in string.gmatch(f.rows or "", "([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\n]*)\n") do
        entries[#entries+1]={name,state,timing,error}
    end
    page=math.min(page,math.max(0,math.floor((#entries-1)/5)))
    local x,y=__panelkit.move("Script Diagnostics",160,560,650,390)
    draw.rect(x,y,x+650,y+390,18,18,24,240,6)
    text.draw(font.item,x+12,y+8,245,245,245,255,"Scripts — last / average / peak callback time")
    for i=1,5 do
        local row=entries[page*5+i]
        if row then
            text.draw_ellipsis(font.small,x+12,y+42+(i-1)*58,235,235,235,255,row[1].." — "..row[2],625)
            text.draw(font.small,x+12,y+60+(i-1)*58,170,200,240,255,row[3])
            text.draw_ellipsis(font.small,x+12,y+78+(i-1)*58,245,120,120,255,row[4],625)
        end
    end
    if ui.button(x+12,y+345,100,28,"Previous",false,false,not interactive or page==0) then page=page-1 end
    if ui.button(x+120,y+345,100,28,"Next",false,false,not interactive or (page+1)*5>=#entries) then page=page+1 end
end)
