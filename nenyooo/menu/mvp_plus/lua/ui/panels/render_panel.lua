
-- Render counts panel: how many of each entity type are ACTUALLY drawn this frame (main pass,
-- shadow passes excluded) from pools.*_render. Objects and Fragments are the two object draw
-- paths (regular CObjects vs breakable/fragment props). Count only -- no max. Each row carries the
-- change since one second ago, so you can see the scene loading rather than guessing.
-- Settings > Theme > HUD Panels > Show Render. Docks into the rail; draggable while menu open.
overlay.on_draw("render_panel", function()
    if not __panelkit or not __panelkit.gate("render_panel", "Show Render", pools) then return end

    local rows = __panelkit.cached("render_panel")
    if not rows then
        local function n(fn) if not fn then return 0 end return fn() or 0 end
        local pc = n(pools.peds_render)
        local vc = n(pools.vehicles_render)
        local oc = n(pools.objects_render)
        local fc = n(pools.objects_frag_render)
        local total = pc + vc + oc + fc
        local L = str.panel_render()
        rows = {
            { L.peds,      string.format("%d", pc), delta = pc },
            { L.vehicles,  string.format("%d", vc), delta = vc },
            { L.objects,   string.format("%d", oc), delta = oc },
            { L.fragments, string.format("%d", fc), delta = fc },
            { L.total,     string.format("%d", total) },
        }
        rows.title  = L.title
        rows.digest = { L.total, string.format("%d", total) }
        __panelkit.cache("render_panel", rows)
    end
    __panelkit.panel("render_panel", 20, 240, rows.title, rows, { digest = rows.digest })
end)
