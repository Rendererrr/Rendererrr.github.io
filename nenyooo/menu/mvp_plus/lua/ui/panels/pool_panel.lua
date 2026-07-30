
-- Pools panel: Peds / Vehicles / Objects / Total (used/cap) from pools.*, with usage fill bars.
-- Settings > Theme > Pools Panel > Show Pools. Snaps to other panels; draggable while menu open.
overlay.on_draw("pool_panel", function()
    local st = menu.get_setting("Show Pools")
    if not (st and st.on) or (st.value_index == 1 and not menu.is_visible()) then
        if __panelkit then __panelkit.hide("pool_panel") end
        return
    end
    if not pools or not __panelkit then return end
    local function get(fn) local c, m = fn(); return c or 0, m or 0 end
    local pc, pm = get(pools.peds)
    local vc, vm = get(pools.vehicles)
    local oc, om = get(pools.objects)
    local cur = { pc, vc, oc, pc + vc + oc }
    local mx  = { pm, vm, om, pm + vm + om }
    -- Labels come from C++ (str.panel_pool -> src/lua/lua_strings.cpp) so they translate; a literal
    -- left here could never reach a language pack. Fetched once per frame, always language-current.
    local L = str.panel_pool()
    local rows = {
        { L.peds,     string.format("%d/%d", pc, pm), mx[1] > 0 and cur[1] / mx[1] or 0 },
        { L.vehicles, string.format("%d/%d", vc, vm), mx[2] > 0 and cur[2] / mx[2] or 0 },
        { L.objects,  string.format("%d/%d", oc, om), mx[3] > 0 and cur[3] / mx[3] or 0 },
        { L.total,    string.format("%d/%d", pc + vc + oc, pm + vm + om), mx[4] > 0 and cur[4] / mx[4] or 0 },
    }
    __panelkit.panel("pool_panel", 20, 20, L.title, rows, { bar = true })
end)
