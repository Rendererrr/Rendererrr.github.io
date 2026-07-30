
-- Snapmatic photo gallery panel. Draws beside the menu when a photo row is highlighted (info_type 31)
-- in Photo Results / Photo Search. Shows the large image + caption / creator / likes. Data + image via
-- the photos.* bridge (see lua_players.cpp). Global overlay (any theme).
local function wrap(fnt, s, maxw, maxlines)
    local out = {}
    if not s or s == "" then return out end
    local line = ""
    for word in tostring(s):gmatch("%S+") do
        local test = (line == "") and word or (line .. " " .. word)
        if text.width(fnt, test) > maxw and line ~= "" then out[#out + 1] = line; line = word
        else line = test end
        if #out >= maxlines then break end
    end
    if line ~= "" and #out < maxlines + 1 then out[#out + 1] = line end
    return out
end

overlay.on_draw("photo_panel", function()
    if not menu.is_visible() then return end
    local pg = menu.page_name()
    local it = menu.get_item(menu.selected_index())
    if not (it and it.info_type == 31) then return end
    photos.select(pg == "Photo Search", it.i_val or 0)   -- live-follow the highlighted photo
    local p = photos.current()
    if not p or not p.id or p.id == "" then return end

    local sw, shh = ctx.screen_w(), ctx.screen_h()
    local pad = 14
    local rh = math.floor(text.height(font.small) + 8)
    local header_h = 32
    local W = 360
    local innerw = W - pad * 2
    local th = math.floor(innerw * 9 / 16)

    local L, C = str.panel_photo(), str.common()
    local cap_lines = wrap(font.item, (p.caption ~= nil and p.caption ~= "") and p.caption or L.untitled, innerw, 2)
    local rows = {}
    if p.creator ~= nil and p.creator ~= "" then rows[#rows + 1] = { L.creator, p.creator } end
    rows[#rows + 1] = { L.likes, tostring(p.likes or 0) }

    local H = header_h + pad + th + 8 + #cap_lines * (text.height(font.item) + 2) + 8 + #rows * rh + pad

    local bx, by, bw = menu.bounds()
    local X0, Y0
    if bw and bw > 0 then
        if (bx + bw * 0.5) < sw * 0.5 then X0 = bx + bw + 16 else X0 = bx - 16 - W end
        Y0 = by
    else X0 = 30; Y0 = 80 end
    if X0 < 8 then X0 = 8 elseif X0 + W > sw - 8 then X0 = sw - 8 - W end
    if Y0 < 8 then Y0 = 8 elseif Y0 + H > shh - 8 then Y0 = shh - 8 - H end

    local ar, ag, ab = theme.accent()
    draw.rect(X0, Y0, X0 + W, Y0 + H, 12, 11, 20, 238, 12)
    draw.rect(X0, Y0, X0 + W, Y0 + header_h, ar, ag, ab, 255, 12)
    draw.rect(X0, Y0 + header_h - 12, X0 + W, Y0 + header_h, ar, ag, ab, 255)
    draw.rect_gradient(X0, Y0, X0 + W, Y0 + header_h,
        255, 255, 255, 50, 255, 255, 255, 50, 255, 255, 255, 0, 255, 255, 255, 0)
    draw.rect(X0, Y0 + header_h - 2, X0 + W, Y0 + header_h, 255, 255, 255, 60)
    text.draw(font.item, X0 + pad, Y0 + (header_h - text.height(font.item)) / 2, 255, 255, 255, 255, L.title)
    draw.rect_outline(X0, Y0, X0 + W, Y0 + H, ar, ag, ab, 130, 12)

    local yy = Y0 + header_h + pad
    local tx0, ty0, tx1, ty1 = X0 + pad, yy, X0 + pad + innerw, yy + th
    if not photos.draw_photo(tx0, ty0, tx1, ty1) then
        draw.rect(tx0, ty0, tx1, ty1, 255, 255, 255, 18, 8)
        local s = C.loading_image
        text.draw(font.small, tx0 + (innerw - text.width(font.small, s)) / 2, ty0 + th / 2 - 8, 255, 255, 255, 90, s)
    end
    draw.rect_outline(tx0, ty0, tx1, ty1, ar, ag, ab, 110, 8)
    yy = yy + th + 8
    for _, l in ipairs(cap_lines) do
        text.draw(font.item, X0 + pad, yy, 255, 255, 255, 255, l)
        yy = yy + text.height(font.item) + 2
    end
    yy = yy + 8
    for _, e in ipairs(rows) do
        text.draw(font.small, X0 + pad, yy, 255, 255, 255, 110, e[1])
        local v = tostring(e[2])
        text.draw(font.small, X0 + W - pad - text.width(font.small, v), yy, 255, 255, 255, 235, v)
        yy = yy + rh
    end
end)
