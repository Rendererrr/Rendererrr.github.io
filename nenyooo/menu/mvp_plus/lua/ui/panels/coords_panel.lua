
-- Coordinates panel: precise position, location, heading, travel mode and speed.
-- Settings > Theme > HUD Panels > Show Coords. Docks into the rail; draggable while menu open.
local COMPASS = { "N", "NE", "E", "SE", "S", "SW", "W", "NW" }
overlay.on_draw("coords_panel", function()
    if not __panelkit or not __panelkit.gate("coords_panel", "Show Coords", self) then return end

    local rows = __panelkit.cached("coords_panel")
    if not rows then
        local sx, sy, sz = self.pos()
        local hd = self.heading()
        local dir = COMPASS[(math.floor((hd + 22.5) / 45) % 8) + 1]
        local mps = (veh and veh.speed()) or 0
        local in_vehicle = veh and veh.in_vehicle and veh.in_vehicle() or false
        local street = veh and veh.street and veh.street() or "-"
        local crossing = veh and veh.crossing and veh.crossing() or "-"
        local zone = veh and veh.zone and veh.zone() or "-"
        local interior = veh and veh.interior and veh.interior() or 0
        -- Axis names, compass points and measurement units are structural. Prose labels come from
        -- C++ (str.panel_coords -> src/lua/lua_strings.cpp) so they remain language-current.
        local L = str.panel_coords()
        rows = {
            { L.position, "", section = true },
            { "X",       string.format("%.2f", sx) },
            { "Y",       string.format("%.2f", sy) },
            { "Z",       string.format("%.2f", sz) },
            { L.zone,     zone },
            { L.street,   street },
            { L.cross_street, crossing },
            { L.interior, interior > 0 and string.format("#%d", interior) or L.outside },
            { L.movement, "", section = true },
            { L.heading,  string.format("%03d deg", math.floor(hd + 0.5)) },
            { L.direction, dir },
            { L.travel_mode, in_vehicle and L.in_vehicle or L.on_foot },
            { L.speed,   string.format("%d mph", math.floor(mps * 2.23694 + 0.5)) },
            { "",        string.format("%d km/h", math.floor(mps * 3.6 + 0.5)), allow_empty = true },
            { "",        string.format("%.1f m/s", mps), allow_empty = true },
        }
        rows.title  = L.title
        rows.digest = { L.zone, zone }
        __panelkit.cache("coords_panel", rows)
    end
    __panelkit.panel("coords_panel", 20, 120, rows.title, rows, { digest = rows.digest })
end)
