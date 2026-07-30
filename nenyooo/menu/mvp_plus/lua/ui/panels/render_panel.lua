
-- Render counts panel: how many of each entity type are ACTUALLY drawn this frame (main pass,
-- shadow passes excluded) from pools.*_render. Objects and Fragments are the two object draw
-- paths (regular CObjects vs breakable/fragment props). Count only -- no max.
-- Settings > Theme > Render Panel > Show Render. Snaps to other panels; draggable while menu open.
overlay.on_draw("render_panel", function()
    local st = menu.get_setting("Show Render")
    if not (st and st.on) or (st.value_index == 1 and not menu.is_visible()) then
        if __panelkit then __panelkit.hide("render_panel") end
        return
    end
    if not pools or not __panelkit then return end
    local function n(fn) if not fn then return 0 end return fn() or 0 end
    local pc = n(pools.peds_render)
    local vc = n(pools.vehicles_render)
    local oc = n(pools.objects_render)
    local fc = n(pools.objects_frag_render)
    local L = str.panel_render()
    local rows = {
        { L.peds,      string.format("%d", pc) },
        { L.vehicles,  string.format("%d", vc) },
        { L.objects,   string.format("%d", oc) },
        { L.fragments, string.format("%d", fc) },
        { L.total,     string.format("%d", pc + vc + oc + fc) },
    }
    __panelkit.panel("render_panel", 20, 240, L.title, rows)
end)
