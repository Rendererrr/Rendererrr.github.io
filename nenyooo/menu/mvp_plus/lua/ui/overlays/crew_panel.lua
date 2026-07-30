
-- Social Club crew info panel. Draws beside the menu when a crew row is selected in My Crews
-- (info_type 20) or Crew Search results (info_type 21), and stays pinned on the crew detail /
-- members pages. Shows tag / motto / members / type / division / access / your membership, with the
-- crew's own colour tinting the header. Data comes from the crews.* bridge (see lua_players.cpp).
local cp_idx, cp_kind = -1, 20
local function hex2rgb(s)
    if type(s) ~= "string" then return nil end
    s = s:gsub("#", "")
    if #s < 6 then return nil end
    local r, g, b = tonumber(s:sub(1,2),16), tonumber(s:sub(3,4),16), tonumber(s:sub(5,6),16)
    if r and g and b then return r, g, b end
    return nil
end
overlay.on_draw("crew_panel", function()
    if not menu.is_visible() then return end
    local it = menu.get_item(menu.selected_index())
    local idx, kind = -1, 20
    if it and (it.info_type == 20 or it.info_type == 21 or it.info_type == 22) then
        idx, kind = it.i_val or -1, it.info_type
        cp_idx, cp_kind = idx, kind
    else
        local pg = menu.page_name()
        if pg == "Network Crew" or pg == "Crew Members" then idx, kind = cp_idx, cp_kind end
    end
    if idx < 0 then return end
    local c = crews.info(kind, idx)
    if not c or not c.name or c.name == "" then return end

    local sw, shh = ctx.screen_w(), ctx.screen_h()
    local pad = 14
    local rh = math.floor(text.height(font.small) + 8)
    local L, C = str.panel_crew(), str.common()
    local rows = {
        { L.tag,     (c.tag ~= nil and c.tag ~= "") and c.tag or "-" },
        { L.members, tostring(c.members or 0) },
    }
    if c.type ~= nil and c.type ~= "" then table.insert(rows, { L.type, c.type }) end
    if c.division ~= nil and c.division ~= "" then table.insert(rows, { L.division, c.division }) end
    table.insert(rows, { L.access, c.is_open and L.open or (c.is_private and L.private or L.closed) })
    if c.is_system then table.insert(rows, { L.type, L.system }) end
    if c.is_verified then table.insert(rows, { L.verified, C.yes }) end
    table.insert(rows, { L.you, c.is_primary and L.primary or (c.is_member and L.member or L.not_member) })

    -- Extras from Clans.asmx/GetDesc: accurate member count + creation date (no emblem exists in ROS).
    -- The row is located by its label, so the comparison uses the same L.members the row was built
    -- with -- a hardcoded "Members" here would stop matching the moment the label is translated.
    local meta = crews.meta()
    if meta.members and meta.members > 0 then
        for _, e in ipairs(rows) do if e[1] == L.members then e[2] = tostring(meta.members) end end
    end
    if meta.created ~= nil and meta.created ~= "" then table.insert(rows, { L.created, meta.created }) end
    local motto = (c.motto ~= nil and c.motto ~= "") and c.motto or nil
    local header_h = 32
    local W = 280
    local motto_h = motto and (rh + 4) or 0
    local H = header_h + pad + #rows * rh + motto_h + pad

    local bx, by, bw = menu.bounds()
    local X0, Y0
    if bw and bw > 0 then
        if (bx + bw * 0.5) < sw * 0.5 then X0 = bx + bw + 16 else X0 = bx - 16 - W end
        Y0 = by
    else X0 = 30; Y0 = 80 end
    if X0 < 8 then X0 = 8 elseif X0 + W > sw - 8 then X0 = sw - 8 - W end
    if Y0 < 8 then Y0 = 8 elseif Y0 + H > shh - 8 then Y0 = shh - 8 - H end

    local ar, ag, ab = theme.accent()
    local hr, hg, hb = hex2rgb(c.color)
    if not hr then hr, hg, hb = ar, ag, ab end   -- fall back to the theme accent

    draw.rect(X0, Y0, X0 + W, Y0 + H, 12, 11, 20, 238, 12)
    -- header tinted with the crew colour, top corners rounded, flat bottom + gloss + divider
    draw.rect(X0, Y0, X0 + W, Y0 + header_h, hr, hg, hb, 255, 12)
    draw.rect(X0, Y0 + header_h - 12, X0 + W, Y0 + header_h, hr, hg, hb, 255)
    draw.rect_gradient(X0, Y0, X0 + W, Y0 + header_h,
        255, 255, 255, 50, 255, 255, 255, 50, 255, 255, 255, 0, 255, 255, 255, 0)
    draw.rect(X0, Y0 + header_h - 2, X0 + W, Y0 + header_h, 0, 0, 0, 60)
    local title = c.name
    if c.tag ~= nil and c.tag ~= "" then title = title .. "  [" .. c.tag .. "]" end
    text.draw(font.item, X0 + pad, Y0 + (header_h - text.height(font.item)) / 2, 255, 255, 255, 255, title)
    draw.rect_outline(X0, Y0, X0 + W, Y0 + H, hr, hg, hb, 130, 12)

    local yy = Y0 + header_h + pad
    for _, e in ipairs(rows) do
        text.draw(font.small, X0 + pad, yy, 255, 255, 255, 110, e[1])
        local v = tostring(e[2])
        text.draw(font.small, X0 + W - pad - text.width(font.small, v), yy, 255, 255, 255, 235, v)
        yy = yy + rh
    end
    if motto then
        -- clip a long motto to the panel width (single line)
        draw.push_clip(X0 + pad, yy, X0 + W - pad, yy + rh)
        text.draw(font.small, X0 + pad, yy + 2, 200, 200, 210, 210, '"' .. motto .. '"')
        draw.pop_clip()
    end
end)
