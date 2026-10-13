
-- Interactive World Map. Opened by the Teleport -> World Map toggle. Pan (left-drag), zoom (scroll),
-- and left-click a spot to drop a pin -> choose Teleport here or Set Waypoint. Right-click / ESC / the X
-- button closes it. Actual teleport/waypoint natives run on the script thread (world_map::tick) via
-- teleport.map_click(x, y, mode); this script only draws + collects input. Input hit-testing and drawing
-- share one set of view coords per frame (dx0/side); pan/zoom move the *target*, animated at the end.
local MAP_UVSX, MAP_UVOX =  0.0000809375, 0.458203125
local MAP_UVSY, MAP_UVOY = -0.0000800781, 0.675

local wm_zoom, wm_cu, wm_cv    = 1.0, 0.5, 0.5
local wm_tzoom, wm_tcu, wm_tcv = 1.0, 0.5, 0.5
local wm_down, wm_moved, wm_dx, wm_dy = false, false, 0, 0
local pin_on, pin_wx, pin_wy = false, 0, 0

local function clampn(v, lo, hi) if v < lo then return lo elseif v > hi then return hi else return v end end
local function ease(speed, dt) local k = 1 - math.exp(-speed * (dt > 0 and dt or 0.016)); if k > 1 then k = 1 end; return k end

overlay.on_draw("world_map", function()
    -- Driven purely by teleport.map_is_open() (the Teleport -> World Map button sets it and hides the
    -- GUI), NOT by menu visibility, so the map stays open and interactive after the GUI is closed.
    -- Closing it (X/ESC/right-click/teleport) calls teleport.map_close(), the only thing that hides it.
    if not teleport.map_is_open() then
        wm_down, wm_moved, pin_on = false, false, false
        return
    end

    local sw, sh = ctx.screen_w(), ctx.screen_h()
    local dt = ctx.delta()
    local ar, ag, ab = theme.accent()
    local mx, my = input.mouse_x(), input.mouse_y()

    -- Dim the screen behind the map (modal feel).
    draw.rect(0, 0, sw, sh, 0, 0, 0, 150)

    -- Centered square map + a title strip above it.
    local S    = math.floor(math.min(sw, sh) * 0.8)
    local hh   = text.height(font.item) + 12
    local x0   = math.floor((sw - S) * 0.5)
    local y0   = math.floor((sh - S - hh) * 0.5)
    local vx, vy = x0, y0 + hh

    -- One set of view coords for BOTH input and draw this frame (current zoom/center, not the target).
    local side = S * wm_zoom
    local dx0  = vx + S * 0.5 - wm_cu * side
    local dy0  = vy + S * 0.5 - wm_cv * side
    local function w2s(wx, wy) return dx0 + (MAP_UVSX * wx + MAP_UVOX) * side, dy0 + (MAP_UVSY * wy + MAP_UVOY) * side end
    local inside = mx >= vx and mx <= vx + S and my >= vy and my <= vy + S

    -- Frame + title bar.
    draw.rect(x0, y0, x0 + S, y0 + S + hh, 14, 15, 20, 245, 6)
    draw.rect(x0, y0, x0 + S, y0 + 2, ar, ag, ab, 255, 0)
    text.draw(font.item, x0 + 12, y0 + 7, 235, 235, 240, 255, "WORLD MAP")
    local hint = "Left-click: pin   Scroll: zoom   Drag: pan   Right-click/ESC: close"
    text.draw(font.tiny, x0 + S - 12 - text.width(font.tiny, hint), y0 + 9, 150, 152, 164, 255, hint)

    -- Close (X) button.
    local cx2, cy2 = x0 + S - 22, y0 + 4
    local over_x = mx >= cx2 and mx <= cx2 + 18 and my >= cy2 and my <= cy2 + 18
    draw.rect(cx2, cy2, cx2 + 18, cy2 + 18, over_x and 60 or 32, 32, 38, 255, 3)
    text.draw(font.item, cx2 + 5, cy2 + 1, 235, 235, 240, 255, "x")
    local close = input.key_just_pressed(27) or (over_x and input.mouse_clicked(0))

    -- Pin prompt geometry (computed once, used for hit-test + draw).
    local prompt_hit = false
    local bx, by, bw, bh, bg = 0, 0, 100, 22, 4
    if pin_on then
        local psx, psy = w2s(pin_wx, pin_wy)
        bx = clampn(psx + 10, vx + 4, vx + S - bw - 4)
        by = clampn(psy - bh - 4, vy + 4, vy + S - (bh * 2 + bg) - 4)
        local function hit(yy) return mx >= bx and mx <= bx + bw and my >= yy and my <= yy + bh and input.mouse_clicked(0) end
        if hit(by) then
            teleport.map_click(pin_wx, pin_wy, 0); pin_on = false; prompt_hit = true
            teleport.map_close()                                         -- close on teleport
        elseif hit(by + bh + bg) then
            teleport.map_click(pin_wx, pin_wy, 1); pin_on = false; prompt_hit = true
        elseif input.mouse_clicked(1) then
            pin_on = false; prompt_hit = true                            -- right-click cancels pin
        end
    end

    -- Map interaction (skipped while a prompt or the X is being clicked).
    if inside and not prompt_hit and not over_x then
        local w = input.mouse_wheel()
        if w ~= 0 then
            local ucur = (mx - dx0) / side
            local vcur = (my - dy0) / side
            wm_tzoom = clampn(wm_tzoom * (w > 0 and 1.25 or (1 / 1.25)), 1.0, 8.0)
            local side_t = S * wm_tzoom
            wm_tcu = ucur + (vx + S * 0.5 - mx) / side_t
            wm_tcv = vcur + (vy + S * 0.5 - my) / side_t
        end
        if input.mouse_clicked(0) then wm_down, wm_moved, wm_dx, wm_dy = true, false, mx, my end
    end
    if wm_down then
        if input.mouse_down(0) then
            if (mx - wm_dx) * (mx - wm_dx) + (my - wm_dy) * (my - wm_dy) > 25 then wm_moved = true end
            if wm_moved then
                wm_tcu = clampn(wm_tcu - (mx - wm_dx) / side, 0, 1)
                wm_tcv = clampn(wm_tcv - (my - wm_dy) / side, 0, 1)
                wm_dx, wm_dy = mx, my
            end
        else
            if not wm_moved and not prompt_hit and inside and not over_x then  -- click (no drag) drops a pin
                pin_wx = ((mx - dx0) / side - MAP_UVOX) / MAP_UVSX
                pin_wy = ((my - dy0) / side - MAP_UVOY) / MAP_UVSY
                pin_on = true
            end
            wm_down, wm_moved = false, false
        end
    end

    -- ---- draw map ----
    draw.rect(vx, vy, vx + S, vy + S, 12, 13, 18, 255)
    local ready = players.map_ensure()
    local path  = players.map_path()
    draw.push_clip(vx, vy, vx + S, vy + S)
    local drawn = ready and draw.preview_image(path, dx0, dy0, dx0 + side, dy0 + side, 1.0, false)
    if drawn then
        -- Other session players (cyan = you, accent = highlighted/selected, white = everyone else).
        local blips = players.map_blips()
        local hov, hov_x, hov_y
        for i = 1, #blips do
            local b = blips[i]
            local bsx, bsy = w2s(b.x, b.y)
            if bsx >= vx and bsx <= vx + S and bsy >= vy and bsy <= vy + S then
                local cr, cg, cb = 240, 240, 240
                if b["local"] then cr, cg, cb = 90, 200, 255
                elseif b.selected then cr, cg, cb = ar, ag, ab end
                draw.circle(bsx, bsy, 4.0, 0, 0, 0, 200)
                draw.circle(bsx, bsy, 2.6, cr, cg, cb, 255)
                if (bsx - mx) * (bsx - mx) + (bsy - my) * (bsy - my) <= 49 then
                    hov = (b.name and b.name ~= "") and b.name or ("Player " .. tostring(b.id))
                    hov_x, hov_y = bsx, bsy
                end
            end
        end
        local wp = teleport.waypoint()
        if wp and wp.valid then
            local wsx, wsy = w2s(wp.x, wp.y)
            draw.circle(wsx, wsy, 5.0, 0, 0, 0, 200)
            draw.circle(wsx, wsy, 3.2, 90, 200, 255, 255)
        end
        if pin_on then
            local psx, psy = w2s(pin_wx, pin_wy)
            draw.line(psx - 9, psy, psx + 9, psy, ar, ag, ab, 1.5)
            draw.line(psx, psy - 9, psx, psy + 9, ar, ag, ab, 1.5)
            draw.circle(psx, psy, 3.5, ar, ag, ab, 255)
        end
        draw.pop_clip()
        if hov then
            local tw = text.width(font.tiny, hov) + 10
            local tx = clampn(hov_x + 8, vx, vx + S - tw)
            local ty = clampn(hov_y - 16, vy, vy + S - 14)
            draw.rect(tx, ty, tx + tw, ty + 14, 0, 0, 0, 215, 3)
            text.draw(font.tiny, tx + 5, ty + 2, 235, 235, 235, 255, hov)
        end
    else
        draw.pop_clip()
        local s = "Loading map..."
        text.draw(font.item, vx + (S - text.width(font.item, s)) * 0.5, vy + S * 0.5 - 8, 150, 154, 165, 255, s)
    end
    draw.rect_outline(vx, vy, vx + S, vy + S, ar, ag, ab, 255, 0, 1)

    -- Prompt buttons drawn on top (same bx/by used for the hit-test above).
    if pin_on then
        local function btn(label, yy)
            local hov = mx >= bx and mx <= bx + bw and my >= yy and my <= yy + bh
            draw.rect(bx, yy, bx + bw, yy + bh, hov and 46 or 28, hov and 48 or 30, hov and 56 or 38, 245, 4)
            if hov then draw.rect(bx, yy, bx + 2, yy + bh, ar, ag, ab, 255, 0) end
            text.draw(font.small, bx + 8, yy + 3, 235, 235, 240, 255, label)
        end
        btn("Teleport here", by)
        btn("Set Waypoint", by + bh + bg)
    end

    -- Smooth zoom/pan toward the target for next frame.
    if wm_tzoom <= 1.0 then
        wm_tcu, wm_tcv = 0.5, 0.5
    else
        local th = 0.5 / wm_tzoom
        wm_tcu = clampn(wm_tcu, th, 1 - th); wm_tcv = clampn(wm_tcv, th, 1 - th)
    end
    local k = ease(14.0, dt)
    wm_zoom = wm_zoom + (wm_tzoom - wm_zoom) * k
    wm_cu = wm_cu + (wm_tcu - wm_cu) * k
    wm_cv = wm_cv + (wm_tcv - wm_cv) * k

    if close then teleport.map_close() end
end)
