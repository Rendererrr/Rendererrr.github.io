
-- Custom Textures source picker preview. Published by C++ (menu_textures_options::draw_preview):
--   state        : "ready" (a pool row is highlighted) | "none"
--   path         : absolute path to the highlighted source image (the NEW replacement)
--   current_path : absolute path to a PNG of the live target texture (CURRENT; async, may not exist yet)
--   target       : the game texture name being replaced
--   source       : the new/bound source image name
-- Dispatched while the "CT Pick" or "CT Binding" page is open. Shows CURRENT -> NEW side by side, with
-- the target + source names underneath (these replace the old top header rows).
features.on_draw("Replacement Preview", function(f)
    if not f.state then return end

    local two  = (f.path ~= nil and f.path ~= "")          -- two-up (current -> new) vs single texture
    local pad  = 10
    local pw   = 300
    local gapc = 16                                        -- gap between the two thumbnails
    local tw   = two and ((pw - pad * 2 - gapc) * 0.5) or 200   -- thumbnail width
    local th   = tw                                        -- square
    local hh   = text.height(font.item) + 6                -- header
    local lh   = text.height(font.small) + 3               -- caption row under thumbs
    local lhh  = text.height(font.small)
    local nh   = two and (lhh * 2 + 7) or (lhh + 4)        -- info rows underneath
    local ph   = pad + hh + th + lh + 4 + nh + pad

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
    local L, C = str.preview_replacement(), str.common()
    text.draw(font.item, x + pad, y + pad - 1, 235, 235, 240, 255, string.upper(two and L.title_two or L.title_one))

    local function ctext(fnt, s, cx, cy, r, g, b)
        text.draw(fnt, cx - text.width(fnt, s) * 0.5, cy - text.height(fnt) * 0.5, r, g, b, 255, s)
    end
    local ty = y + pad + hh
    local function thumb(tx, p, ready, label)
        local x1, y1, x2, y2 = tx, ty, tx + tw, ty + th
        draw.rect(x1, y1, x2, y2, 26, 26, 32, 255, 4)
        local shown = false
        if ready and p and p ~= "" then shown = draw.preview_image(p, x1, y1, x2, y2, 1.0) end
        if not shown then ctext(font.small, ready and C.loading or C.none, (x1+x2)*0.5, (y1+y2)*0.5, 150, 150, 160) end
        draw.rect_outline(x1, y1, x2, y2, 60, 60, 70, 255, 4, 1)
        if label and label ~= "" then ctext(font.small, label, (x1+x2)*0.5, y2 + lh*0.5 + 1, 160, 162, 170) end
    end

    local iy = ty + th + lh + 4
    if two then
        local lx = x + pad
        local rx = x + pad + tw + gapc
        thumb(lx, f.current_path, true, L.current)
        thumb(rx, f.path, f.state == "ready", L.added)
        ctext(font.item, ">", (lx + tw + rx) * 0.5, ty + th * 0.5, ar, ag, ab)
        if f.target and f.target ~= "" then text.draw(font.small, x + pad, iy, 150, 152, 160, 255, L.target .. ": " .. f.target) end
        if f.source and f.source ~= "" then text.draw(font.small, x + pad, iy + lhh + 3, ar, ag, ab, 255, L.added .. ": " .. f.source) end
    else
        thumb(x + (pw - tw) * 0.5, f.current_path, true, "")   -- single, centered
        if f.target and f.target ~= "" then
            ctext(font.small, f.target, x + pw * 0.5, iy + lhh * 0.5, ar, ag, ab)
        end
    end
end)
