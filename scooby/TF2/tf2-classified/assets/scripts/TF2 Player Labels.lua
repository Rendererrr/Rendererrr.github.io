assert(type(TF2_API_VERSION) == "string" and TF2_API_VERSION:match("^1%."), "Update the TF2 Lua host")
local enabled=features.add{id="labels",label="Lua player labels",category="TF2 scripts",default=true}
ui.overlay("tf2_labels",function()
    if not features.active(enabled) then return end
    for _,e in ipairs(tf2.entities{kind="player",max_distance=100}) do
        local p=tf2.world_to_screen(e.position)
        if p and p.on_screen then render.text(p.x,p.y,e.name,{.3,.8,1,1}) end
    end
end)
