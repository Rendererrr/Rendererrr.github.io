
-- Pools panel: Peds / Vehicles / Objects / Total (used/cap) from pools.*, with segmented usage
-- gauges that colour by how close each pool is to its cap, and an inline trend per row.
-- Settings > Theme > HUD Panels > Show Pools. Docks into the rail; draggable while the menu is open.
overlay.on_draw("pool_panel", function()
    if not __panelkit or not __panelkit.gate("pool_panel", "Show Pools", pools) then return end

    local rows = __panelkit.cached("pool_panel")
    if not rows then
        local function get(fn) local c, m = fn(); return c or 0, m or 0 end
        local function frac(c, m) return m > 0 and c / m or 0 end
        local pc, pm = get(pools.peds)
        local vc, vm = get(pools.vehicles)
        local oc, om = get(pools.objects)
        local tc, tm = pc + vc + oc, pm + vm + om
        -- Labels come from C++ (str.panel_pool -> src/lua/lua_strings.cpp) so they translate; a
        -- literal left here could never reach a language pack. Rebuilt only when the panel ticks.
        local L = str.panel_pool()
        rows = {
            { L.peds,     string.format("%d/%d", pc, pm), frac(pc, pm), spark = frac(pc, pm) },
            { L.vehicles, string.format("%d/%d", vc, vm), frac(vc, vm), spark = frac(vc, vm) },
            { L.objects,  string.format("%d/%d", oc, om), frac(oc, om), spark = frac(oc, om) },
            { L.total,    string.format("%d/%d", tc, tm), frac(tc, tm), spark = frac(tc, tm) },
        }
        rows.title  = L.title
        rows.digest = { L.total, string.format("%d/%d", tc, tm) }
        __panelkit.cache("pool_panel", rows)
    end
    __panelkit.panel("pool_panel", 20, 20, rows.title, rows, { bar = true, digest = rows.digest })
end)
