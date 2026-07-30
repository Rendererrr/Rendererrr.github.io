
-- Spooner vehicle-browser preview. Published by C++ (veh_catalog::preview_draw):
--   state : "ready" | "loading" | "missing"   (image fetch state)
--   path  : absolute .bin cache path for the thumbnail (when ready)
--   name, model, make, class, drivetrain : strings
--   hash, mass, top_speed, gears, steer, drive_force, brake_force, seats, doors : numbers (from the gtaDiscoveryApi catalog)
-- Only dispatched while the "Spooner Veh List" page is open, so no page check is needed here.
features.on_draw("Vehicle Preview", function(f)
    if not f.state then return end

    local pad  = 10
    local pw   = 280
    local img  = pw - pad * 2
    local imgh = img * 0.58
    local hh   = text.height(font.item) + 6                 -- header row
    local nh   = text.height(font.item) + 2                 -- vehicle-name row
    local subh = text.height(font.small) + 3                -- make / model id row
    local sh1  = text.height(font.small)
    local rows = 10                                         -- stat rows
    local statsh = rows * (sh1 + 5)
    local ph   = pad + hh + imgh + 6 + nh + subh + 4 + statsh + pad

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
    local L, C = str.preview_vehicle(), str.common()
    text.draw(font.item, x + pad, y + pad - 1, 235, 235, 240, 255, string.upper(L.title))

    -- thumbnail
    local ix1, iy1 = x + pad, y + pad + hh
    local ix2, iy2 = ix1 + img, iy1 + imgh
    draw.rect(ix1, iy1, ix2, iy2, 26, 26, 32, 255, 4)
    local function ctext(fnt, s, cx, cy, r, g, b)
        text.draw(fnt, cx - text.width(fnt, s) * 0.5, cy - text.height(fnt) * 0.5, r, g, b, 255, s)
    end
    local mx, my = (ix1 + ix2) * 0.5, (iy1 + iy2) * 0.5
    local shown = false
    if f.state == "ready" then shown = draw.preview_image(f.path, ix1, iy1, ix2, iy2, 1.0) end
    if not shown then
        if f.state == "loading" or f.state == "ready" then ctext(font.item, C.loading, mx, my, 180, 180, 190)
        else ctext(font.title, "?", mx, my - 6, 120, 120, 130); ctext(font.small, C.no_preview, mx, iy2 - 14, 150, 150, 160) end
    end
    draw.rect_outline(ix1, iy1, ix2, iy2, 60, 60, 70, 255, 4, 1)

    -- name, then make (left) + model id (right)
    local ny = iy2 + 6
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
