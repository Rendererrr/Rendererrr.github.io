
-- Player-info panels for Network -> Players. Standalone overlay (theme-independent). Four boxes:
-- Geolocation and Stats stacked in a left column, the main player panel beside them, and a preview
-- column holding the live ped (players.draw_ped / UI3D) over the world map.
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

-- World-map state. world -> UV transform from gtaDiscoveryApi map calibration.
local MAP_UVSX, MAP_UVOX =  0.0000809375, 0.458203125
local MAP_UVSY, MAP_UVOY = -0.0000800781, 0.675
local map_zoom, map_cu, map_cv    = 1.0, 0.5, 0.5
local map_tzoom, map_tcu, map_tcv = 1.0, 0.5, 0.5
local map_focus = -1
local map_drag, map_dpx, map_dpy = false, 0, 0
local function mclamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
local function mease(speed, dt) if dt <= 0 then return 1.0 end return 1.0 - math.exp(-speed * dt) end

overlay.on_draw("player_panel", function()
    if not menu.is_visible() then return end
    local it = menu.get_item(menu.selected_index())

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
    local rfont = font.small
    local ar, ag, ab = theme.accent()

    local ipad   = 8
    local rh     = math.floor(text.height(rfont) + 4)
    local th     = math.floor(text.height(rfont) + 10)   -- panel title bar
    local gapx   = 8
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

    -- Square dark box + title + accent rule + clipped rows. Returns its own height so panels stack.
    local function panel(x, y, w, ptitle, rows, extra_h)
        local bodyh = rows_h(rows) + (extra_h or 0)
        local h = th + 3 + bodyh + ipad
        draw.rect(x, y, x + w, y + h, 14, 14, 18, 238)
        draw.rect_outline(x, y, x + w, y + h, 255, 255, 255, 22, 0, 1)
        text.draw_ellipsis(rfont, x + ipad, y + math.floor((th - text.height(rfont)) / 2),
            232, 236, 246, 255, ptitle, w - ipad * 2)
        draw.rect(x, y + th, x + w, y + th + 2, ar, ag, ab, 255)   -- accent rule, the reference's motif

        local cx, cw = x + ipad, w - ipad * 2
        local half = math.floor((cw - 10) / 2)
        draw.push_clip(x, y + th + 3, x + w, y + h)
        local yy = y + th + 3 + 3
        for _, e in ipairs(rows) do
            if e[1] == "d" then
                draw.rect(cx, yy + 3, cx + cw, yy + 4, ar, ag, ab, 120)
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
    R(mn, L.model, p.model_name)
    P(mn, L.type, p.model_label, L.hash, p.model_hash)
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
    local ped_h  = 306
    local map_S  = WC - ipad * 2
    local prev_h = ped_h + 6 + rh + map_S

    local hA = th + 3 + rows_h(geo) + ipad
    local hB = th + 3 + rows_h(st)  + ipad
    local hC = th + 3 + rows_h(mn)  + ipad
    local hD = th + 3 + prev_h + ipad
    local H  = math.max(hA + gapx + hB, hC, hD)

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
    local px1 = px0 + map_S
    local py1 = py0 + ped_h

    -- The background is painted as four pieces AROUND the ped slot, never across it. The ped and its
    -- backdrop are drawn by the game (GRAPHICS::DRAW_RECT + the UI3D scene) in the game's render pass;
    -- our D2D overlay composites afterwards, so a single rect over the whole panel would bury both
    -- under near-opaque black -- which is exactly what made the slot look unlit.
    draw.rect(xC, yD,  xC + WC, py0,      14, 14, 18, 238)   -- title strip
    draw.rect(xC, py0, px0,     py1,      14, 14, 18, 238)   -- left of slot
    draw.rect(px1, py0, xC + WC, py1,     14, 14, 18, 238)   -- right of slot
    draw.rect(xC, py1, xC + WC, yD + hD,  14, 14, 18, 238)   -- map area below
    draw.rect_outline(xC, yD, xC + WC, yD + hD, 255, 255, 255, 22, 0, 1)
    text.draw(rfont, xC + ipad, yD + math.floor((th - text.height(rfont)) / 2), 232, 236, 246, 255, string.upper(L.preview))
    draw.rect(xC, yD + th, xC + WC, yD + th + 2, ar, ag, ab, 255)

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
        text.draw(font.tiny, px0 + (map_S - text.width(font.tiny, s)) * 0.5, py0 + ped_h * 0.5 - 6,
            120, 126, 142, 255, s)
    end

    -- Geometry consumed by the world-map block below (kept verbatim from the previous revision).
    local map_vx  = px0
    local map_top = py1 + 6
    local map_y   = map_top + rh
    -- World map (third column on the right). Plots every active player; local = cyan, selected/
    -- highlighted = accent, others = white. Drag to pan, scroll to zoom, click a blip to zoom+center.
    do
        local S  = map_S
        local vx = map_vx
        local vy = map_y
        local dt = ctx.delta()
        local hi_id = p.player_id or -1

        text.draw(rfont, vx + 4, map_top + 3, 150, 150, 164, 255, L.location)

        draw.rect(vx, vy, vx + S, vy + S, 12, 13, 18, 255)

        local ready = players.map_ensure()
        local path  = players.map_path()
        local blips = players.map_blips()

        local mx, my = input.mouse_x(), input.mouse_y()
        local inside = mx >= vx and mx <= vx + S and my >= vy and my <= vy + S

        local side_now = S * map_zoom
        local dxn = vx + S * 0.5 - map_cu * side_now
        local dyn = vy + S * 0.5 - map_cv * side_now

        if inside then
            local hit = nil
            for i = 1, #blips do
                local b = blips[i]
                local sx = dxn + (MAP_UVSX * b.x + MAP_UVOX) * side_now
                local sy = dyn + (MAP_UVSY * b.y + MAP_UVOY) * side_now
                if (sx - mx) * (sx - mx) + (sy - my) * (sy - my) <= 64 then hit = b end
            end
            if input.mouse_clicked(0) then
                if hit then
                    map_focus = hit.id
                    map_tcu = MAP_UVSX * hit.x + MAP_UVOX
                    map_tcv = MAP_UVSY * hit.y + MAP_UVOY
                    map_tzoom = 4.0
                else
                    map_drag = true; map_dpx, map_dpy = mx, my
                end
            end
            local w = input.mouse_wheel()
            if w ~= 0 then
                local ucur = (mx - dxn) / side_now
                local vcur = (my - dyn) / side_now
                map_tzoom = mclamp(map_tzoom * (w > 0 and 1.25 or (1 / 1.25)), 1.0, 8.0)
                local side_t = S * map_tzoom
                map_tcu = ucur + (vx + S * 0.5 - mx) / side_t
                map_tcv = vcur + (vy + S * 0.5 - my) / side_t
            end
        end
        if map_drag then
            if input.mouse_down(0) then
                map_tcu = map_tcu - (mx - map_dpx) / side_now
                map_tcv = map_tcv - (my - map_dpy) / side_now
                map_dpx, map_dpy = mx, my
            else
                map_drag = false
            end
        end

        if map_tzoom <= 1.0 then
            map_tcu, map_tcv = 0.5, 0.5
        else
            local th = 0.5 / map_tzoom
            map_tcu = mclamp(map_tcu, th, 1 - th); map_tcv = mclamp(map_tcv, th, 1 - th)
        end
        local k = mease(14.0, dt)
        map_zoom = map_zoom + (map_tzoom - map_zoom) * k
        map_cu   = map_cu + (map_tcu - map_cu) * k
        map_cv   = map_cv + (map_tcv - map_cv) * k

        draw.push_clip(vx, vy, vx + S, vy + S)
        local side = S * map_zoom
        local dx0 = vx + S * 0.5 - map_cu * side
        local dy0 = vy + S * 0.5 - map_cv * side
        local drawn = ready and draw.preview_image(path, dx0, dy0, dx0 + side, dy0 + side, 1.0, false)
        if drawn then
            local hov, hov_x, hov_y
            for i = 1, #blips do
                local b = blips[i]
                local sx = dx0 + (MAP_UVSX * b.x + MAP_UVOX) * side
                local sy = dy0 + (MAP_UVSY * b.y + MAP_UVOY) * side
                if sx >= vx and sx <= vx + S and sy >= vy and sy <= vy + S then
                    local cr, cg, cb = 240, 240, 240
                    if b["local"] then
                        cr, cg, cb = 90, 200, 255
                    elseif b.selected or b.id == hi_id or b.id == map_focus then
                        cr, cg, cb = ar, ag, ab
                    end
                    draw.circle(sx, sy, 4.0, 0, 0, 0, 200)
                    draw.circle(sx, sy, 2.6, cr, cg, cb, 255)
                    if b.id == map_focus then draw.circle_outline(sx, sy, 6.0, ar, ag, ab, 1.5) end
                    if (sx - mx) * (sx - mx) + (sy - my) * (sy - my) <= 49 then
                        hov = (b.name and b.name ~= "") and b.name or ("Player " .. tostring(b.id))
                        hov_x, hov_y = sx, sy
                    end
                end
            end
            draw.pop_clip()
            if hov then
                local tw = text.width(font.tiny, hov) + 10
                local tx = mclamp(hov_x + 8, vx, vx + S - tw)
                local ty = mclamp(hov_y - 16, vy, vy + S - 14)
                draw.rect(tx, ty, tx + tw, ty + 14, 0, 0, 0, 215, 3)
                text.draw(font.tiny, tx + 5, ty + 2, 235, 235, 235, 255, hov)
            end
        else
            draw.pop_clip()
            local s = L.loading_map
            text.draw(font.tiny, vx + (S - text.width(font.tiny, s)) * 0.5, vy + S * 0.5 - 6, 150, 154, 165, 255, s)
        end
        draw.rect_outline(vx, vy, vx + S, vy + S, ar, ag, ab, 255, 0, 1)
    end
end)
