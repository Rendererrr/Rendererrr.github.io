
-- Coordinates panel: X / Y / Z + heading + speed. Position from self.*; speed from veh.*.
-- Settings > Theme > Coords Panel > Show Coords. Snaps to other panels; draggable while menu open.
local COMPASS = { "N", "NE", "E", "SE", "S", "SW", "W", "NW" }
overlay.on_draw("coords_panel", function()
    local st = menu.get_setting("Show Coords")
    if not (st and st.on) or (st.value_index == 1 and not menu.is_visible()) then
        if __panelkit then __panelkit.hide("coords_panel") end
        return
    end
    if not self or not __panelkit then return end
    local sx, sy, sz = self.pos()
    local hd = self.heading()
    local dir = COMPASS[(math.floor((hd + 22.5) / 45) % 8) + 1]
    local mps = (veh and veh.speed()) or 0
    -- X/Y/Z, the compass rose and the mph/km/h units are left as-is: they read the same in every
    -- language. Only the prose labels come from C++ (str.panel_coords -> src/lua/lua_strings.cpp).
    local L = str.panel_coords()
    local rows = {
        { "X",       string.format("%.1f", sx) },
        { "Y",       string.format("%.1f", sy) },
        { "Z",       string.format("%.1f", sz) },
        { L.heading, string.format("%03d %s", math.floor(hd + 0.5), dir) },
        { L.speed,   string.format("%d mph", math.floor(mps * 2.23694 + 0.5)) },
        { "",        string.format("%d km/h", math.floor(mps * 3.6 + 0.5)) },
    }
    __panelkit.panel("coords_panel", 20, 120, L.title, rows)
end)
