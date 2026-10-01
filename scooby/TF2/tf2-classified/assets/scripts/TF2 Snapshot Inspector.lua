-- Opt-in diagnostic overlay. Compatible with both TF2 Lua 1.1 hosts.
assert(tf2 and tf2.capabilities().active_weapon and tf2.capabilities().condition_list,
       "Update the TF2 Lua host to 1.1 or newer")
ui.overlay("tf2_snapshot_inspector", function()
    local me=tf2.local_player()
    if not me then
        render.text(20,140,"TF2 snapshot: no local session",{1,1,1,1},15)
        return
    end
    local weapon=tf2.active_weapon()
    local label=weapon and ("item "..weapon.item_id) or "weapon unavailable"
    local speed=tf2.vec.length2d(me.velocity)
    render.text(20,140,string.format("%s | %s | %.0f u/s",me.class_name,label,speed),{1,1,1,1},15)
    for i,p in ipairs(tf2.players{max_distance=100,limit=3}) do
        local conditions=tf2.conditions(p.handle)
        render.text(20,140+i*18,string.format("%s | %s | %s | %d conditions",
            p.name,p.class_name or "Unknown",tf2.team_name(p.team or 0),#conditions),{1,1,1,1},15)
    end
end)
