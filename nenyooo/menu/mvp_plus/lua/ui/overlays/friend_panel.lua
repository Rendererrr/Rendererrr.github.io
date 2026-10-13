
-- Social Club profile panel. Draws beside the menu when a person row is selected in any of the three
-- Friends lists (info_type 6=friend, 7=incoming request, 8=sent request), and stays pinned while
-- you're inside that person's detail page -- just like the player panel stays up for the selected
-- player. Shows avatar + name / Rockstar ID / online status / last-seen date / relationship. Global
-- overlay (any theme). Data comes from the friends.* bridge (see lua_players.cpp).
-- `page` is compared against menu.page_name(), so it is PROTOCOL and stays English. The displayed
-- title/relationship moved to C++ (str.panel_friend -> src/lua/lua_strings.cpp) so they translate;
-- they are keyed by the same info_type, so L.title[kind] / L.rel[kind] line up with this table.
local KINDS = {
    [6]  = { page = "Network Friend" },
    [7]  = { page = "Network Friend Request" },
    [8]  = { page = "Network Sent Request" },
    [9]  = { page = "Network Blocked" },
    [10] = { page = "Network Fake Friend" },
    [11] = { page = "Network Monitored" },
}
local fp_idx, fp_kind = -1, 6   -- last selected row, remembered across the detail page

overlay.on_draw("friend_panel", function()
    if not menu.is_visible() then return end
    -- Which person to show: the selected list row, or the one we drilled into (its detail page keeps
    -- the panel up). Refresh fp_idx/fp_kind whenever a person row is highlighted.
    local it = menu.get_item(menu.selected_index())
    local idx, kind = -1, 6
    if it and KINDS[it.info_type] then
        idx, kind = it.i_val or -1, it.info_type
        fp_idx, fp_kind = idx, kind
    else
        local pg = menu.page_name()
        for k, v in pairs(KINDS) do
            if pg == v.page then idx, kind = fp_idx, k break end
        end
    end
    if idx < 0 then return end
    local f = friends.info(kind, idx)
    if not f then return end

    local sw, shh = ctx.screen_w(), ctx.screen_h()
    local pad, av = 14, 150
    local rh = math.floor(text.height(font.small) + 8)
    local L, C = str.panel_friend(), str.common()
    local rows = {
        { L.name,         f.name or "-" },
        { L.rid,          f.rid or "-" },
        { L.status,       f.online and C.online or C.offline },
        { L.last_seen,    (f.seen ~= nil and f.seen ~= "") and f.seen or "-" },
        { L.relationship, (f.rel ~= nil and f.rel ~= "") and f.rel or L.rel[kind] },
    }
    -- Session presence (only after a "Check Session" for this exact person).
    local pr = friends.presence()
    if pr and pr.rid == f.rid and pr.status ~= nil and pr.status ~= "" then
        table.insert(rows, { L.session, pr.status })
    end
    local header_h = 32
    local W = math.max(pad + av + pad, 250)
    local H = header_h + pad + av + 10 + #rows * rh + pad

    local bx, by, bw = menu.bounds()
    local X0, Y0
    if bw and bw > 0 then
        if (bx + bw * 0.5) < sw * 0.5 then X0 = bx + bw + 16 else X0 = bx - 16 - W end
        Y0 = by
    else X0 = 30; Y0 = 80 end
    if X0 < 8 then X0 = 8 elseif X0 + W > sw - 8 then X0 = sw - 8 - W end
    if Y0 < 8 then Y0 = 8 elseif Y0 + H > shh - 8 then Y0 = shh - 8 - H end

    local ar, ag, ab = theme.accent()
    -- card body
    draw.rect(X0, Y0, X0 + W, Y0 + H, 12, 11, 20, 238, 12)
    -- header title bar: solid accent with the top corners rounded to match the card and the bottom
    -- squared off so it sits flush against the body (no floating "pill"), a soft top-down gloss for
    -- depth, and a bright hairline divider under it.
    draw.rect(X0, Y0, X0 + W, Y0 + header_h, ar, ag, ab, 255, 12)
    draw.rect(X0, Y0 + header_h - 12, X0 + W, Y0 + header_h, ar, ag, ab, 255)
    draw.rect_gradient(X0, Y0, X0 + W, Y0 + header_h,
        255, 255, 255, 50, 255, 255, 255, 50, 255, 255, 255, 0, 255, 255, 255, 0)
    draw.rect(X0, Y0 + header_h - 2, X0 + W, Y0 + header_h, 255, 255, 255, 60)
    text.draw(font.item, X0 + pad, Y0 + (header_h - text.height(font.item)) / 2, 255, 255, 255, 255, L.title[kind])
    -- crisp card outline on top of everything
    draw.rect_outline(X0, Y0, X0 + W, Y0 + H, ar, ag, ab, 130, 12)

    local ax0, ay0 = X0 + (W - av) / 2, Y0 + header_h + pad
    if not friends.draw_avatar(kind, idx, ax0, ay0, ax0 + av, ay0 + av) then
        draw.rect(ax0, ay0, ax0 + av, ay0 + av, 255, 255, 255, 20, 8)
        local s = C.loading
        text.draw(font.small, ax0 + (av - text.width(font.small, s)) / 2, ay0 + av / 2 - 6, 255, 255, 255, 90, s)
    end
    draw.rect_outline(ax0, ay0, ax0 + av, ay0 + av, ar, ag, ab, 110, 8)

    local yy = ay0 + av + 10
    for _, e in ipairs(rows) do
        text.draw(font.small, X0 + pad, yy, 255, 255, 255, 110, e[1])
        local v = tostring(e[2])
        local vc = 235
        text.draw(font.small, X0 + W - pad - text.width(font.small, v), yy, 255, 255, 255, vc, v)
        yy = yy + rh
    end
end)
