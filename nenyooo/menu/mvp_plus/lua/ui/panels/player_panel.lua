
-- Player-info panels for Network -> Players. Standalone overlay (theme-independent). Geolocation and
-- Stats stack in the left column; player details and the live in-game ped preview occupy the right.
--
-- Two rules exist because earlier revisions got them wrong and must not regress:
--   * every value is drawn with text.draw_ellipsis against an explicit budget. A revision that simply
--     right-aligned values let a long one (ISP, AS, Platform) draw back over its own label.
--   * every panel body is push_clip'ed and its height derived from its own row list, so nothing can
--     paint outside its box or off the screen.

-- Value colouring. The sentinels are compared against str.common(), NOT against hardcoded English:
-- player_manager.cpp publishes them through the same TR() literals, so both sides translate together.
-- Hardcoding "Yes" here would silently stop matching in every non-English language.
-- CV is refreshed once per frame by the draw callback -- vcol runs per drawn value (~60 a frame), so
-- calling str.common() inside it would be 60 round-trips into C++ instead of one.
local CV = nil
local function vcol(v)
    local C = CV
    if not C then return 226, 230, 240 end
    if v == C.yes then return 96, 214, 126 end
    if v == C.no then return 128, 134, 150 end
    if v == C.hidden or v == C.na or v == "-" or v == "" or v == C.resolving then return 100, 106, 122 end
    return 226, 230, 240
end

overlay.on_draw("player_panel", function()
    local st = menu.get_setting("Show Player Info")
    local menu_visible = menu.is_visible()
    if not (st and st.on) or (st.value_index == 1 and not menu_visible) then return end
    local it = menu_visible and menu.get_item(menu.selected_index()) or nil

    -- Two ways to be "on" a player: highlighting a row in the Players list, or standing on one of the
    -- per-player subpages (Network Player -> Tracking / Trolling / Kicks / ...), whose rows carry no
    -- info of their own. The page-name gate stops the panels following you around the rest of the menu.
    local p, title
    if it and it.info_type == 1 and it.info then
        p, title = it.info, it.name
    else
        local pg = menu.page_name() or ""
        if pg == "Network Player" or string.sub(pg, 1, 7) == "Player " then
            p = menu.selected_player_info()
            title = menu.selected_player_name()
        end
    end
    if not p then return end

    local L, C = str.panel_player(), str.common()
    CV = C   -- hand this frame's sentinels to vcol()
    -- Colour off the stable verdict flags, not off p.network's text -- that text is translated.
    local netcol = nil
    if p.net_proxy then netcol = { 235, 96, 96 }
    elseif p.net_hosting then netcol = { 235, 176, 96 } end
    local function alert(v) return v == C.yes and { 235, 96, 96 } or nil end

    local sw, shh = ctx.screen_w(), ctx.screen_h()
    local rfont = font.overlay_body or font.small
    local hfont = font.overlay_heading or font.label
    local skin = __panelkit.style

    local ipad   = skin.padx
    local rh     = math.floor(text.height(rfont) + skin.rgap)
    local th     = math.floor(text.height(hfont) + skin.pady * 2)
    local gapx   = __panelkit.GUTTER
    local WA, WB, WC = 252, 300, 180
    local W = WA + gapx + WB + gapx + WC

    -- ---- row builders -----------------------------------------------------------------------------
    local function R(t, l, v, c) t[#t + 1] = { "r", l, v, c } end
    local function P(t, l1, v1, l2, v2, c1, c2) t[#t + 1] = { "p", l1, v1, l2, v2, c1, c2 } end
    local function D(t) t[#t + 1] = { "d" } end
    local function rows_h(rows)
        local h = 0
        for _, e in ipairs(rows) do h = h + (e[1] == "d" and 7 or rh) end
        return h
    end

    -- Draw one label/value inside a cell, ellipsising the value against what the label leaves behind.
    local function put(x, w, y, label, value, colr)
        local v = tostring(value == nil and "-" or value)
        text.draw(rfont, x, y, 150, 156, 172, 255, label)
        local lw = text.width(rfont, label)
        local r, g, b
        if colr then r, g, b = colr[1], colr[2], colr[3] else r, g, b = vcol(v) end
        local budget = w - lw - 8
        local vw = text.width(rfont, v)
        if vw > budget then
            text.draw_ellipsis(rfont, x + lw + 8, y, r, g, b, 255, v, budget)
        else
            text.draw(rfont, x + w - vw, y, r, g, b, 255, v)
        end
    end

    -- Compact title band and clipped rows. Each panel measures its own height.
    local function panel(x, y, w, ptitle, rows, extra_h)
        local bodyh = rows_h(rows) + (extra_h or 0)
        local h = th + 3 + bodyh + ipad
        draw.rect(x, y, x + w, y + h, skin.bg_top[1], skin.bg_top[2], skin.bg_top[3], skin.bg_a)
        draw.rect_outline(x, y, x + w, y + h, skin.border[1], skin.border[2], skin.border[3], 255, 0, 1)
        draw.rect(x + 1, y + 1, x + w - 1, y + th, skin.header[1], skin.header[2], skin.header[3], 255)
        text.draw_ellipsis(hfont, x + ipad, y + math.floor((th - text.height(hfont)) / 2),
            232, 236, 246, 255, ptitle, w - ipad * 2)

        local cx, cw = x + ipad, w - ipad * 2
        local half = math.floor((cw - 10) / 2)
        draw.push_clip(x, y + th + 3, x + w, y + h)
        local yy = y + th + 3 + 3
        for _, e in ipairs(rows) do
            if e[1] == "d" then
                draw.rect(cx, yy + 3, cx + cw, yy + 4, skin.border[1], skin.border[2], skin.border[3], 255)
                yy = yy + 7
            elseif e[1] == "p" then
                put(cx, half, yy, e[2], e[3], e[6])
                -- the divider between the two halves is what makes the reference scan cleanly
                draw.rect(cx + half + 5, yy + 1, cx + half + 6, yy + rh - 3, 255, 255, 255, 22)
                if e[4] then put(cx + half + 10, half, yy, e[4], e[5], e[7]) end
                yy = yy + rh
            else
                put(cx, cw, yy, e[2], e[3], e[4])
                yy = yy + rh
            end
        end
        draw.pop_clip()
        return h
    end

    -- ---- content ----------------------------------------------------------------------------------
    local geo = {}
    R(geo, L.ip, p.ip)
    P(geo, L.port, p.port, L.ping, p.ping)
    P(geo, L.link, p.link, L.conn, p.network, nil, netcol)
    D(geo)
    P(geo, L.city, p.city, L.region, p.region)
    R(geo, L.country, p.country)
    P(geo, L.lat, p.latitude, L.lon, p.longitude)
    D(geo)
    R(geo, L.isp, p.isp)
    R(geo, L.asn, p.asn)

    local st = {}
    P(st, L.rank, L.lvl .. " " .. tostring(p.rank or 0), L.rp, p.rp)
    P(st, L.wallet, p.wallet, L.bank, p.bank)
    R(st, L.kd, p.kd)
    P(st, L.races_won, p.races_won, L.races_lost, p.races_lost)
    D(st)
    P(st, L.script, p.script_host, L.session, p.session_host)
    P(st, L.friend, p.friend_status, L.spoofed, p.spoofed_rid, nil, alert(p.spoofed_rid))
    R(st, L.rid_ped, p.rid_ped)
    R(st, L.rid_net, p.rid_net)
    R(st, L.platform, p.platform_id)
    R(st, L.host_token, p.host_token)

    local mn = {}
    P(mn, L.health, p.health, L.armour, p.armor)
    P(mn, L.wanted, tostring(p.wanted or 0) .. " / 5", L.ammo, p.ammo)
    R(mn, L.weapon, p.weapon)
    R(mn, L.vehicle, p.vehicle)
    D(mn)
    if players.discovery_metadata() then
        R(mn, L.model, p.model_name)
        P(mn, L.type, p.model_label, L.hash, p.model_hash)
    else
        R(mn, L.hash, p.model_hash)
    end
    R(mn, L.coords, p.position)
    P(mn, L.heading, p.heading, L.zone, p.zone)
    P(mn, L.distance, p.distance, L.speed, p.speed)
    D(mn)
    P(mn, L.bullet, p.bullet_proof, L.fire, p.fire_proof)
    P(mn, L.melee, p.melee_proof, L.explosion, p.explosion_proof)
    P(mn, L.invincible, p.god_mode, L.invisible, p.invisible, alert(p.god_mode), alert(p.invisible))
    P(mn, L.off_radar, p.off_radar, L.veh_god, p.veh_god_mode)
    D(mn)
    P(mn, L.crew, p.crew_name, L.tag, p.crew_tag)

    -- ---- placement ---------------------------------------------------------------------------------
    local ped_h = 306

    local hA = th + 3 + rows_h(geo) + ipad
    local hB = th + 3 + rows_h(st)  + ipad
    local hC = th + 3 + rows_h(mn)  + ipad
    local hD = th + 3 + ped_h + ipad + 3
    local upper_right_h = math.max(hC, hD)
    local H  = math.max(hA + gapx + hB, upper_right_h)

    local bx, by, bw = menu.bounds()
    local X0, Y0
    if bw and bw > 0 then
        if (bx + bw * 0.5) < sw * 0.5 then X0 = bx + bw + 14 else X0 = bx - 14 - W end
        Y0 = by
    else
        X0 = 30; Y0 = 80
    end
    if X0 < 8 then X0 = 8 elseif X0 + W > sw - 8 then X0 = sw - 8 - W end
    if Y0 < 8 then Y0 = 8 elseif Y0 + H > shh - 8 then Y0 = shh - 8 - H end

    local xA = X0
    local xB = xA + WA + gapx
    local xC = xB + WB + gapx

    panel(xA, Y0, WA, string.upper(L.geolocation), geo)
    panel(xA, Y0 + hA + gapx, WA, string.upper(L.stats), st)
    panel(xB, Y0, WB, title or L.title, mn)

    -- Preview column: same chrome, but its body is the ped slot over the map rather than rows.
    local yD = Y0
    local px0 = xC + ipad
    local py0 = yD + th + 3 + 3
    local px1 = px0 + WC - ipad * 2
    local py1 = py0 + ped_h

    -- The background is painted as four pieces AROUND the ped slot, never across it. The ped and its
    -- backdrop are drawn by the game (GRAPHICS::DRAW_RECT + the UI3D scene) in the game's render pass;
    -- our D2D overlay composites afterwards, so a single rect over the whole panel would bury both
    -- under near-opaque black -- which is exactly what made the slot look unlit.
    local bg = skin.bg_top
    draw.rect(xC, yD,  xC + WC, py0,      bg[1], bg[2], bg[3], skin.bg_a)
    draw.rect(xC, py0, px0,     py1,      bg[1], bg[2], bg[3], skin.bg_a)
    draw.rect(px1, py0, xC + WC, py1,     bg[1], bg[2], bg[3], skin.bg_a)
    draw.rect(xC, py1, xC + WC, yD + hD,  bg[1], bg[2], bg[3], skin.bg_a)
    draw.rect_outline(xC, yD, xC + WC, yD + hD, skin.border[1], skin.border[2], skin.border[3], 255, 0, 1)
    draw.rect(xC + 1, yD + 1, xC + WC - 1, yD + th, skin.header[1], skin.header[2], skin.header[3], 255)
    text.draw_ellipsis(hfont, xC + ipad, yD + math.floor((th - text.height(hfont)) / 2),
        232, 236, 246, 255, L.preview, WC - ipad * 2)

    draw.rect_outline(px0, py0, px1, py1, 255, 255, 255, 22, 0, 1)
    local ped_ok = false
    if not (wardrobe and wardrobe.is_open and wardrobe.is_open()) then
        -- Backdrop colour is passed through to GRAPHICS::DRAW_RECT. The ped is lit by the game scene and
        -- reads as a near-black silhouette, so the slot is deliberately lighter than the panel.
        ped_ok = players.draw_ped(p.player_id or -1, px0 / sw, py0 / shh, (px1 - px0) / sw, (py1 - py0) / shh,
                                  46, 49, 62)
    end
    if not ped_ok then
        local s = L.no_preview
        text.draw(font.tiny, px0 + ((px1 - px0) - text.width(font.tiny, s)) * 0.5, py0 + ped_h * 0.5 - 6,
            120, 126, 142, 255, s)
    end

end)
