
-- UGC job info panel. Draws beside the menu when a job result row is highlighted (info_type 30) and
-- stays pinned on the Job detail page. Shows name / author / category / players / rank req / rating /
-- likes / language / description + the Snapmatic thumbnail (fetched on open). Global overlay (any
-- theme). Data comes from the jobs.* bridge (see lua_players.cpp).
local function wrap(fnt, s, maxw)
    local out = {}
    if not s or s == "" then return out end
    local line = ""
    for word in tostring(s):gmatch("%S+") do
        local test = (line == "") and word or (line .. " " .. word)
        if text.width(fnt, test) > maxw and line ~= "" then
            out[#out + 1] = line; line = word
        else line = test end
        if #out >= 6 then break end
    end
    if line ~= "" and #out < 7 then out[#out + 1] = line end
    return out
end

overlay.on_draw("job_panel", function()
    if not menu.is_visible() then return end
    local show = false
    local pg = menu.page_name()
    local it = menu.get_item(menu.selected_index())
    if it and it.info_type == 30 then
        jobs.select(pg == "Job Search", it.i_val or 0)   -- live-follow the highlighted row
        show = true
    elseif pg == "Job" or pg == "Job Comments" then show = true end
    if not show then return end
    local j = jobs.current()
    if not j or not j.name or j.name == "" then return end

    local sw, shh = ctx.screen_w(), ctx.screen_h()
    local pad = 14
    local rh = math.floor(text.height(font.small) + 8)
    local header_h = 32
    local W = 300
    local innerw = W - pad * 2
    local th = math.floor(innerw * 9 / 16)   -- 16:9 thumbnail

    local function fmt_players(a, b)
        a = a or 0; b = b or 0
        if a <= 0 and b <= 0 then return "-" end
        if b <= a then return tostring(a > 0 and a or b) end
        return string.format("%d - %d", a, b)
    end
    local L, C = str.panel_job(), str.common()
    local rows = {
        { L.author,   (j.author ~= nil and j.author ~= "") and j.author or "-" },
        { L.category, j.category or "-" },
        { L.players,  fmt_players(j.players_min, j.players_max) },
        { L.rank_req, (j.rank and j.rank > 0) and tostring(j.rank) or "1" },
    }
    if (j.likes and j.likes > 0) or (j.dislikes and j.dislikes > 0) then
        rows[#rows + 1] = { L.likes, string.format("%d / %d", j.likes or 0, j.dislikes or 0) }
    end
    if j.rating and j.rating > 0 then
        rows[#rows + 1] = { L.rating, string.format("%.0f%%", j.rating * 100) }
    end
    if j.lang and j.lang ~= "" then rows[#rows + 1] = { L.language, j.lang } end

    -- Name + description are wrapped multi-line blocks.
    local name_lines = wrap(font.item, j.name, innerw)
    local desc_lines = wrap(font.small, j.description, innerw)

    local H = header_h + pad + th + 8 + #name_lines * (text.height(font.item) + 2) + 8
              + #rows * rh
    if #desc_lines > 0 then H = H + 8 + #desc_lines * rh end
    H = H + pad

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
    text.draw(font.item, X0 + pad, Y0 + (header_h - text.height(font.item)) / 2, 255, 255, 255, 255,
        string.format(L.title_fmt, j.category or L.job))
    draw.rect_outline(X0, Y0, X0 + W, Y0 + H, ar, ag, ab, 130, 12)

    local yy = Y0 + header_h + pad
    -- Snapmatic thumbnail (16:9). Placeholder box + "Loading..." until the image is downloaded/decoded.
    local tx0, ty0, tx1, ty1 = X0 + pad, yy, X0 + pad + innerw, yy + th
    if not jobs.draw_thumb(tx0, ty0, tx1, ty1) then
        draw.rect(tx0, ty0, tx1, ty1, 255, 255, 255, 18, 8)
        local s = C.loading_image
        text.draw(font.small, tx0 + (innerw - text.width(font.small, s)) / 2, ty0 + th / 2 - 8, 255, 255, 255, 90, s)
    end
    draw.rect_outline(tx0, ty0, tx1, ty1, ar, ag, ab, 110, 8)
    yy = yy + th + 8
    for _, l in ipairs(name_lines) do
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
    if #desc_lines > 0 then
        yy = yy + 8
        for _, l in ipairs(desc_lines) do
            text.draw(font.small, X0 + pad, yy, 255, 255, 255, 170, l)
            yy = yy + rh
        end
    end
end)
