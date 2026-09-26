
-- Vehicle-browser details panel. Published by C++ (veh_catalog::preview_draw):
--   preview : "off" | "loading" | "live" | "unavailable"   (the live 3D car in front of the camera)
--   name, model, make, class, drivetrain : strings
--   hash, mass, top_speed, gears, steer, drive_force, brake_force, seats, doors : numbers (from the gtaDiscoveryApi catalog)
-- The vehicle itself is not drawn here: it is a local 3D copy placed in the world beside the menu
-- (features/vehicle_preview). Only dispatched while the "Spooner Veh List" page is open.
features.on_draw("Vehicle Preview", function(f)
    if not f.preview then return end

    local pad  = 10
    local pw   = 280
    local hh   = text.height(font.item) + 6                 -- header row
    local nh   = text.height(font.item) + 2                 -- vehicle-name row
    local subh = text.height(font.small) + 3                -- make / model id row
    local sh1  = text.height(font.small)
    local rows = 10                                         -- stat rows
    local statsh = rows * (sh1 + 5)
    local sth  = text.height(font.small) + 4                -- 3D preview status row
    local ph   = pad + hh + sth + 6 + nh + subh + 4 + statsh + pad

    local sw, shh = ctx.screen_w(), ctx.screen_h()
    local bx, by, bw = menu.bounds()
    local gap = 12
    local x, y
    if bw and bw > 0 then
        if (bx + bw * 0.5) < sw * 0.5 then x = bx + bw + gap else x = bx - gap - pw end
        y = by
    else
        x = sw - pw - 24; y = 120
    end
    if x < 8 then x = 8 elseif x + pw > sw - 8 then x = sw - 8 - pw end
    if y < 8 then y = 8 elseif y + ph > shh - 8 then y = shh - 8 - ph end

    local ar, ag, ab = theme.accent()
    draw.rect(x, y, x + pw, y + ph, 16, 16, 22, 238, 6)
    draw.rect(x, y, x + pw, y + 2, ar, ag, ab, 255, 0)
    local L = str.preview_vehicle()
    text.draw(font.item, x + pad, y + pad - 1, 235, 235, 240, 255, string.upper(L.title))

    -- live 3D preview status (the car itself is in the world, not in this panel)
    local status, sr, sg, sb = nil, 150, 150, 160
    if f.preview == "live" then status, sr, sg, sb = L.live, ar, ag, ab
    elseif f.preview == "loading" then status = L.loading3d
    elseif f.preview == "unavailable" then status = L.unavailable end
    local sty = y + pad + hh
    if status then text.draw(font.small, x + pad, sty, sr, sg, sb, 255, status) end

    -- name, then make (left) + model id (right)
    local ny = sty + sth + 6
    text.draw(font.item, x + pad, ny, 240, 240, 245, 255, (f.name ~= "" and f.name) or (f.model or "-"))
    local sy0 = ny + nh
    if f.make and f.make ~= "" then text.draw(font.small, x + pad, sy0, ar, ag, ab, 255, f.make) end
    if f.model and f.model ~= "" then
        text.draw(font.small, x + pw - pad - text.width(font.small, f.model), sy0, 150, 150, 160, 255, f.model)
    end

    -- stat rows: label left, value right-aligned
    local sy = sy0 + subh + 4
    local function fnum(n) return string.format("%d", math.floor((n or 0) + 0.5)) end
    local function frac(n) return string.format("%.2f", n or 0) end
    local function row(label, val, vr, vg, vb)
        text.draw(font.small, x + pad, sy, 150, 152, 160, 255, label)
        text.draw(font.small, x + pw - pad - text.width(font.small, val), sy, vr or 225, vg or 225, vb or 232, 255, val)
        sy = sy + sh1 + 5
    end

    row(L.cls,         (f.class ~= "" and f.class) or "-", ar, ag, ab)
    row(L.hash,        fnum(f.hash))
    row(L.seats,       fnum(f.seats))
    row(L.doors,       fnum(f.doors))
    row(L.mass,        fnum(f.mass) .. " kg")
    row(L.top_speed,   fnum(f.top_speed))
    row(L.gears,       fnum(f.gears))
    row(L.drivetrain,  (f.drivetrain ~= "" and f.drivetrain) or "-")
    row(L.steer,       fnum(f.steer) .. " deg")
    row(L.drive_brake, frac(f.drive_force) .. " / " .. frac(f.brake_force))
end)
