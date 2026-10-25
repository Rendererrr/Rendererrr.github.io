local query, results, revision, offset = "", {}, -1, 0
local function search()
    results = query ~= "" and items.search(query) or {}
    revision, offset = items.revision(), 0
end
features.on_draw("Command Palette", function(f)
    if not __panelkit then return end
    ui.begin_frame(); ui.show_cursor()
    local x, y = __panelkit.move("Command Palette", 160, 120, 520, 420)
    draw.rect(x, y, x+520, y+420, 18, 18, 24, 240, 6)
    text.draw(font.item, x+12, y+8, 245,245,245,255, "Command Palette — F6")
    if ui.button(x+470,y+5,38,27,"×",false,false,false) then
        ui.blur()
        local handle=f.hash and items.get(f.hash)
        if handle then items.set_on(handle,false) end
        return
    end
    local id = ui.id("command_palette_query")
    local active = ui.focused() == id
    local value = query
    if active then value = ui.text_edit(id) end
    if value ~= query then query=value; search() end
    if revision ~= items.revision() then search() end
    if ui.button(x+12,y+38,496,30,query ~= "" and query or "Search features…",false,false,false) then ui.focus(id,query,0) end
    for i=1,8 do
        local handle=results[offset+i]
        if handle then
            local hash=items.hash_of(handle)
            if ui.button(x+12,y+76+(i-1)*35,446,30,items.full_id(handle),false,false,false) then items.activate(handle) end
            if ui.button(x+462,y+76+(i-1)*35,46,30,items.favorite_has(hash) and "−" or "+",false,false,false) then items.favorite_toggle(hash) end
        end
    end
    if ui.button(x+12,y+370,100,30,"Previous",false,false,offset==0) then offset=math.max(0,offset-8) end
    if ui.button(x+120,y+370,100,30,"Next",false,false,offset+8>=#results) then offset=offset+8 end
    text.draw(font.small,x+236,y+378,210,210,210,255,tostring(#results).." matches (maximum 128)")
end)
