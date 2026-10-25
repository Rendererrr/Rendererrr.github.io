-- Downloadable-theme preview. Published by C++ (menu_theme_download::preview_draw):
--   state     : "ready" | "loading" | "missing" | "none"
--   path      : absolute .png cache path for the preview (when ready)
--   name      : theme name
--   bytes     : download size
--   installed : already on disk
--   update    : installed but a newer version is published
--   progress  : 0..100, present only while this theme is downloading
-- Only dispatched while the Download Themes page is open, so no page check is needed here.
features.on_draw("Theme Preview", function(f)
    if not f.state or f.state == "none" then return end

    local pad = 10
    local pw  = 280
    local img = pw - pad * 2
    local ih  = math.floor(img * 9 / 16)               -- theme shots are widescreen, not square
    local th  = text.height(font.item) + 6             -- title row
    local ch  = text.height(font.small) + 4            -- caption row
    local ph  = pad + th + ih + 6 + ch * 2 + pad

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

    local L, C = str.preview_theme(), str.common()
    text.draw(font.item, x + pad, y + pad - 1, 235, 235, 240, 255, string.upper(L.title))

    local ix1, iy1 = x + pad, y + pad + th
    local ix2, iy2 = ix1 + img, iy1 + ih
    draw.rect(ix1, iy1, ix2, iy2, 26, 26, 32, 255, 4)

    local function ctext(fnt, s, cx, cy, r, g, b)
        text.draw(fnt, cx - text.width(fnt, s) * 0.5, cy - text.height(fnt) * 0.5, r, g, b, 255, s)
    end

    local mx, my = (ix1 + ix2) * 0.5, (iy1 + iy2) * 0.5
    local shown = false
    if f.state == "ready" then
        -- fit=true: theme shots vary in aspect, so letterbox rather than stretch.
        shown = draw.preview_image(f.path, ix1, iy1, ix2, iy2, 1.0, true)
    end
    if not shown then
        if f.state == "loading" or f.state == "ready" then
            ctext(font.item, C.loading, mx, my, 180, 180, 190)
        else
            ctext(font.title, "?", mx, my - 8, 120, 120, 130)
            ctext(font.small, L.no_preview, mx, iy2 - 16, 150, 150, 160)
        end
    end
    draw.rect_outline(ix1, iy1, ix2, iy2, 60, 60, 70, 255, 4, 1)

    -- Progress bar sits inside the image box so it reads as "this tile is downloading".
    if f.progress then
        local p  = math.max(0, math.min(100, f.progress)) / 100
        local by1 = iy2 - 6
        draw.rect(ix1, by1, ix2, iy2, 0, 0, 0, 170, 0)
        draw.rect(ix1, by1, ix1 + (ix2 - ix1) * p, iy2, ar, ag, ab, 255, 0)
    end

    local ty = iy2 + 6
    text.draw(font.small, x + pad, ty, 225, 225, 232, 255, f.name or "")
    ty = ty + ch

    local status, sr, sg, sb
    if f.progress then
        status = string.format("%s  %d%%", L.downloading, f.progress)
        sr, sg, sb = ar, ag, ab
    elseif f.update then
        status = L.update;    sr, sg, sb = 245, 190,  60
    elseif f.installed then
        status = L.installed; sr, sg, sb =  90, 220, 120
    else
        local mb = (f.bytes or 0) / 1048576
        status = string.format("%s  ·  %.1f MB", L.get, mb)
        sr, sg, sb = 160, 160, 170
    end
    text.draw(font.small, x + pad, ty, sr, sg, sb, 255, status)
end)
