assert(type(TF2_API_VERSION) == "string" and TF2_API_VERSION:match("^1%."), "Update the TF2 Lua host")
ui.overlay("tf2_player_hud", function()
    local me=tf2.local_player()
    if not me then return end
    render.text(20,100,string.format("%s | %d HP | %.0f u/s",me.class_name,me.health,me.speed),{1,1,1,1},15)
end)
