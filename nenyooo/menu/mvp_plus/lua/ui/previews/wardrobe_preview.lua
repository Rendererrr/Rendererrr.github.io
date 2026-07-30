
-- Wardrobe clothing preview. Published by C++ (pedops::wardrobe_draw):
--   state    : "ready" | "loading" | "missing" | "unsupported"
--   path     : absolute .bin cache path for the thumbnail (when ready)
--   label    : category folder name ("tops", "hats", ...) or ""
--   drawable, texture : numbers
-- Only dispatched while the Wardrobe page is open, so no page check is needed here.
features.on_draw("Wardrobe Preview", function(f)
    if not f.state then return end

    local pad   = 10
    local pw    = 230
    local img   = pw - pad * 2
    local th    = text.height(font.item) + 6           -- title row
    local ch    = text.height(font.small) + 4          -- caption row
    local ph    = pad + th + img + 6 + ch + pad

    local sw, sh = ctx.screen_w(), ctx.screen_h()
    local bx, by, bw = menu.bounds()
    local gap = 12
    local x, y
    if bw and bw > 0 then
        -- Dock on whichever side of the menu has room.
        if (bx + bw * 0.5) < sw * 0.5 then x = bx + bw + gap else x = bx - gap - pw end
        y = by
    else
        x = sw - pw - 24; y = 120                       -- fallback: right edge
    end
    if x < 8 then x = 8 elseif x + pw > sw - 8 then x = sw - 8 - pw end
    if y < 8 then y = 8 elseif y + ph > sh - 8 then y = sh - 8 - ph end

    local ar, ag, ab = theme.accent()
    draw.rect(x, y, x + pw, y + ph, 16, 16, 22, 235, 6)
    draw.rect(x, y, x + pw, y + 2, ar, ag, ab, 255, 0)
    local L, C = str.preview_wardrobe(), str.common()
    text.draw(font.item, x + pad, y + pad - 1, 235, 235, 240, 255, string.upper(L.title))

    local ix1, iy1 = x + pad, y + pad + th
    local ix2, iy2 = ix1 + img, iy1 + img
    draw.rect(ix1, iy1, ix2, iy2, 26, 26, 32, 255, 4)

    local function ctext(fnt, s, cx, cy, r, g, b)
        text.draw(fnt, cx - text.width(fnt, s) * 0.5, cy - text.height(fnt) * 0.5, r, g, b, 255, s)
    end

    local mx, my = (ix1 + ix2) * 0.5, (iy1 + iy2) * 0.5
    local shown = false
    if f.state == "ready" then
        shown = draw.preview_image(f.path, ix1, iy1, ix2, iy2, 1.0)
    end
    if not shown then
        if f.state == "ready" or f.state == "loading" then
            ctext(font.item, C.loading, mx, my, 180, 180, 190)
        else
            ctext(font.title, "?", mx, my - 8, 120, 120, 130)
            local msg = (f.state == "missing") and L.no_preview or L.freemode
            ctext(font.small, msg, mx, iy2 - 16, 150, 150, 160)
        end
    end
    draw.rect_outline(ix1, iy1, ix2, iy2, 60, 60, 70, 255, 4, 1)

    local cap = "-"
    if f.label and f.label ~= "" then
        cap = string.format("%s  #%d / %s %d", f.label, math.floor(f.drawable or 0), L.tex, math.floor(f.texture or 0))
    end
    text.draw(font.small, x + pad, iy2 + 6, ar, ag, ab, 255, cap)
end)
