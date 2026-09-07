-- Downloadable-script preview. Published by C++ (menu_script_download::preview_draw):
--   state       : "ready" | "loading" | "missing" | "none"
--   path        : absolute .png cache path for the preview (when ready)
--   name        : script name
--   description : one-line summary from the index
--   bytes       : download size
--   installed   : already on disk
--   update      : installed but a newer version is published
--   progress    : 0..100, present only while this script is downloading
-- Only dispatched while the Download Scripts page is open, so no page check is needed here.
features.on_draw("Script Preview", function(f)
    if not f.state or f.state == "none" then return end

    local pad = 10
    local pw  = 300
    local img = pw - pad * 2
    local ih  = math.floor(img * 9 / 16)               -- screenshots are widescreen
    local th  = text.height(font.item) + 6             -- title row
    local ch  = text.height(font.small) + 4            -- caption row

    -- Wrap the description across up to three lines so long summaries stay legible.
    local desc = f.description or ""
    local desc_lines = {}
    if desc ~= "" then
        local max_w = pw - pad * 2
        local words, cur = {}, ""
        for w in string.gmatch(desc, "%S+") do words[#words + 1] = w end
        for _, w in ipairs(words) do
            local candidate = (cur == "") and w or (cur .. " " .. w)
            if text.width(font.small, candidate) <= max_w then
                cur = candidate
            else
                desc_lines[#desc_lines + 1] = cur
                cur = w
                if #desc_lines >= 3 then break end
            end
        end
        if cur ~= "" and #desc_lines < 3 then desc_lines[#desc_lines + 1] = cur end
    end
    local dh = #desc_lines * ch
    local ph = pad + th + ih + 6 + ch * 2 + (dh > 0 and dh + 4 or 0) + pad

    local sw, sh = ctx.screen_w(), ctx.screen_h()
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
    if y < 8 then y = 8 elseif y + ph > sh - 8 then y = sh - 8 - ph end

    local ar, ag, ab = theme.accent()
    draw.rect(x, y, x + pw, y + ph, 16, 16, 22, 235, 6)
    draw.rect(x, y, x + pw, y + 2, ar, ag, ab, 255, 0)

    local L, C = str.preview_script(), str.common()
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
        if mb < 0.1 then
            status = string.format("%s  ·  %d KB", L.get, math.floor((f.bytes or 0) / 1024))
        else
            status = string.format("%s  ·  %.1f MB", L.get, mb)
        end
        sr, sg, sb = 160, 160, 170
    end
    text.draw(font.small, x + pad, ty, sr, sg, sb, 255, status)

    if dh > 0 then
        ty = ty + ch + 4
        for _, line in ipairs(desc_lines) do
            text.draw(font.small, x + pad, ty, 180, 180, 190, 255, line)
            ty = ty + ch
        end
    end
end)
