local offset = 0
features.on_draw("Favorites Panel", function()
    if not __panelkit then return end
    ui.begin_frame(); local interactive=menu.is_visible(); if interactive then ui.show_cursor() end
    local hashes=items.favorite_hashes()
    offset=math.min(offset, math.max(0, math.floor((#hashes-1)/8)*8))
    local x,y=__panelkit.move("Favorites Panel",720,120,380,370)
    draw.rect(x,y,x+380,y+370,18,18,24,240,6)
    text.draw(font.item,x+12,y+8,245,245,245,255,"Favorites — pin from Command Palette")
    for i=1,8 do
        local hash=hashes[offset+i]
        if hash then
            local handle=items.get(hash)
            local label=handle and items.name(handle) or "Unavailable feature"
            if ui.button(x+12,y+44+(i-1)*34,300,29,label,false,false,not interactive or handle==nil) and handle then items.activate(handle) end
            if ui.button(x+318,y+44+(i-1)*34,48,29,"−",false,false,not interactive) then items.favorite_toggle(hash) end
        end
    end
    if ui.button(x+12,y+330,100,28,"Previous",false,false,not interactive or offset==0) then offset=math.max(0,offset-8) end
    if ui.button(x+120,y+330,100,28,"Next",false,false,not interactive or offset+8>=#hashes) then offset=offset+8 end
end)
