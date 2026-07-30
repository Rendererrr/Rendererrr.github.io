
-- Wardrobe > Advanced Editor. A browsable grid of every item the target ped can wear, drawn INSIDE
-- the menu's item-list band (menu.content_rect) so the header, breadcrumb and footer chrome stay
-- visible around it. Opened by the "Advanced Editor" row; C++ suppresses menu keyboard nav while
-- wardrobe.is_open(), so this script owns the mouse and ESC.
--
-- Everything here is drawing + input. Wearing an item runs on the script thread via wardrobe.apply().
-- IMPORTANT: wardrobe.tile() is what triggers a thumbnail download, so it is only ever called for
-- tiles actually on screen -- the cache queue is shallow and asking for a whole category drops most.
local RAIL_W   = 104
local PAD      = 8
local SEARCH_H = 22
local FOOT_H   = 28
local GAP      = 6
local MIN_TILE = 62

local scroll, scroll_t = 0, 0
local search_focus = false
local built_for = -1
-- Keyboard cursor over the tile grid (1-based; 0 = no cursor, mouse-only). Moving the mouse hands the
-- highlight back to the pointer, so the two never fight over which tile looks selected.
local cur = 0
local kb = false
local last_mx, last_my = -1, -1
local VK = { LEFT = 37, UP = 38, RIGHT = 39, DOWN = 40, ENTER = 13, PGUP = 33, PGDN = 34,
             HOME = 36, ENDK = 35, TAB = 9 }

local function clampn(v, lo, hi) if v < lo then return lo elseif v > hi then return hi else return v end end
local function inside(mx, my, x0, y0, x1, y1) return mx >= x0 and mx <= x1 and my >= y0 and my <= y1 end

-- Trim a string until it fits maxw, so a long label can't run into whatever sits beside it
-- ("Accessories" + its count were overlapping in the rail).
local function fit_text(fnt, s, maxw)
    if maxw <= 0 then return "" end
    if text.width(fnt, s) <= maxw then return s end
    local out = s
    while #out > 1 and text.width(fnt, out .. "..") > maxw do out = string.sub(out, 1, #out - 1) end
    return out .. ".."
end

overlay.on_draw("wardrobe_editor", function()
    -- Also refuse to draw off the wardrobe page. C++ closes the editor on a page change, but that
    -- happens on the script thread and this runs on the render thread, so without this check the grid
    -- paints over the page you just moved to for a frame or two.
    local pg = menu.page_name()
    if not wardrobe.is_open() or (pg ~= "Self Wardrobe" and pg ~= "Spooner Wardrobe") then
        search_focus, scroll, scroll_t, built_for = false, 0, 0, -1
        cur, kb = 0, false
        return
    end

    local sw, shh = ctx.screen_w(), ctx.screen_h()
    local mx, my  = input.mouse_x(), input.mouse_y()
    local ar, ag, ab = theme.accent()

    -- The menu's item-list band. Themes that never publish one get a centred panel instead.
    local cx, cy, cw, ch = menu.content_rect()
    if not ch or ch <= 0 then
        cw = math.min(560, sw - 80); ch = math.min(420, shh - 160)
        cx = math.floor((sw - cw) * 0.5); cy = math.floor((shh - ch) * 0.5)
    end

    -- ESC and Backspace both close. Menu nav is suppressed while the editor is up, so the theme never
    -- sees its own back key -- this is the only way out from the keyboard.
    local close = input.key_just_pressed(27) or input.key_just_pressed(8)

    -- Opaque backing: this covers the rows underneath, which are still there and still the live page.
    draw.rect(cx, cy, cx + cw, cy + ch, 14, 15, 20, 255)

    -- --- category rail ---
    local cats = wardrobe.categories()
    local sel_cat = wardrobe.category()
    draw.rect(cx, cy, cx + RAIL_W, cy + ch, 18, 19, 26, 255)
    local row_h = math.floor((ch - FOOT_H) / math.max(1, #cats))
    if row_h > 26 then row_h = 26 end
    for i = 1, #cats do
        local ry = cy + (i - 1) * row_h
        if ry + row_h <= cy + ch - FOOT_H then
            local over = inside(mx, my, cx, ry, cx + RAIL_W, ry + row_h)
            if i == sel_cat then
                draw.rect(cx, ry, cx + RAIL_W, ry + row_h, ar, ag, ab, 45)
                draw.rect(cx, ry, cx + 2, ry + row_h, ar, ag, ab, 255)
            elseif over then
                draw.rect(cx, ry, cx + RAIL_W, ry + row_h, 255, 255, 255, 14)
            end
            local tr, tg, tb = 175, 178, 190
            if i == sel_cat then tr, tg, tb = 235, 235, 240 end
            local ty = ry + math.floor((row_h - text.height(font.small)) * 0.5)
            -- Count first, then give the label only the room that's left.
            local n = tostring(cats[i].count or 0)
            local nw = text.width(font.tiny, n)
            text.draw(font.tiny, cx + RAIL_W - 8 - nw, ty + 1, 130, 133, 146, 255, n)
            text.draw(font.small, cx + 9, ty, tr, tg, tb, 255,
                      fit_text(font.small, cats[i].label, RAIL_W - 9 - 8 - nw - 6))
            if over and input.mouse_clicked(0) and i ~= sel_cat then
                wardrobe.set_category(i)
                scroll, scroll_t = 0, 0
            end
        end
    end

    -- --- search box ---
    local gx = cx + RAIL_W
    local gw = cw - RAIL_W
    local bx0, by0 = gx + PAD, cy + PAD
    local bx1, by1 = gx + gw - PAD, cy + PAD + SEARCH_H
    local over_search = inside(mx, my, bx0, by0, bx1, by1)
    if input.mouse_clicked(0) then search_focus = over_search end
    draw.rect(bx0, by0, bx1, by1, 24, 25, 33, 255, 3)
    if search_focus then draw.rect_outline(bx0, by0, bx1, by1, ar, ag, ab, 255, 3, 1) end

    local query = wardrobe.search()
    if search_focus then
        local typed = input.get_chars()
        if typed and typed ~= "" then query = query .. typed end
        if input.key_repeat(8) and #query > 0 then query = string.sub(query, 1, #query - 1) end
        wardrobe.search(query)
    end
    -- Set every frame, not just while focused: leaving it latched would keep the player frozen after
    -- the box loses focus or the editor closes.
    menu.set_text_editing(search_focus)
    local label = (query ~= "" and query) or ("search " .. string.lower(cats[sel_cat] and cats[sel_cat].label or "items") .. "...")
    local qr, qg, qb = 120, 123, 136
    if query ~= "" then qr, qg, qb = 225, 225, 232 end
    text.draw(font.small, bx0 + 8, by0 + math.floor((SEARCH_H - text.height(font.small)) * 0.5), qr, qg, qb, 255, label)
    if query ~= "" then
        local clr_x = bx1 - 18
        local over_clr = inside(mx, my, clr_x, by0, bx1, by1)
        text.draw(font.small, clr_x + 4, by0 + 3, over_clr and 235 or 150, 150, 160, 255, "x")
        if over_clr and input.mouse_clicked(0) then wardrobe.search(""); query = "" end
    end

    -- --- grid ---
    local tx0, ty0 = gx + PAD, by1 + PAD
    local tx1, ty1 = gx + gw - PAD, cy + ch - FOOT_H - PAD
    local avail = tx1 - tx0
    local cols = math.max(3, math.floor((avail + GAP) / (MIN_TILE + GAP)))
    local tile = math.floor((avail - (cols - 1) * GAP) / cols)
    local step = tile + GAP
    local cap  = text.height(font.tiny) + 2
    local cell = tile + cap

    local count = wardrobe.count()
    if sel_cat ~= built_for then built_for = sel_cat; scroll, scroll_t = 0, 0; if kb then cur = 1 end end

    local rows = math.ceil(count / cols)
    local view_h = ty1 - ty0
    local scroll_max = math.max(0, rows * (cell + GAP) - view_h)
    if inside(mx, my, tx0, ty0, tx1, ty1) then
        local wh = input.mouse_wheel()
        if wh ~= 0 then scroll_t = clampn(scroll_t - wh * (cell + GAP), 0, scroll_max) end
    end

    -- --- keyboard ---
    -- Menu nav is suppressed while the editor is up, so these keys are ours. Any mouse movement hands
    -- the highlight back to the pointer so both schemes can be used without them fighting.
    if mx ~= last_mx or my ~= last_my then kb = false end
    last_mx, last_my = mx, my

    if not search_focus and count > 0 then
        local function step(d)
            kb = true
            if cur == 0 then cur = 1 else cur = clampn(cur + d, 1, count) end
        end
        if input.key_repeat(VK.RIGHT) then step(1) end
        if input.key_repeat(VK.LEFT)  then step(-1) end
        if input.key_repeat(VK.DOWN)  then step(cols) end
        if input.key_repeat(VK.UP)    then step(-cols) end
        if input.key_repeat(VK.PGDN)  then step(cols * 4) end
        if input.key_repeat(VK.PGUP)  then step(-cols * 4) end
        if input.key_just_pressed(VK.HOME) then kb = true; cur = 1 end
        if input.key_just_pressed(VK.ENDK) then kb = true; cur = count end
        if input.key_just_pressed(VK.ENTER) and kb and cur >= 1 then wardrobe.apply(cur) end
        -- Tab cycles the category rail, so the whole editor is reachable without the mouse.
        if input.key_just_pressed(VK.TAB) then
            kb = true
            local n = #cats
            local nxt = sel_cat + 1; if nxt > n then nxt = 1 end
            wardrobe.set_category(nxt)
            scroll, scroll_t, cur = 0, 0, 1
        end

        -- Keep the cursor on screen.
        if kb and cur >= 1 then
            local r = math.floor((cur - 1) / cols)
            local top = r * (cell + GAP)
            if top < scroll_t then scroll_t = top
            elseif top + cell > scroll_t + view_h then scroll_t = top + cell - view_h end
        end
    end
    scroll_t = clampn(scroll_t, 0, scroll_max)
    scroll = scroll + (scroll_t - scroll) * clampn(ctx.delta() * 18, 0, 1)
    if math.abs(scroll - scroll_t) < 0.5 then scroll = scroll_t end

    local hover_name, hover_ids = nil, nil
    draw.push_clip(tx0, ty0, tx1, ty1)
    local first_row = math.max(0, math.floor(scroll / (cell + GAP)))
    local last_row  = math.min(rows - 1, first_row + math.ceil(view_h / (cell + GAP)) + 1)
    for r = first_row, last_row do
        for c = 0, cols - 1 do
            local idx = r * cols + c + 1
            if idx <= count then
                local ix = tx0 + c * step
                local iy = ty0 + r * (cell + GAP) - scroll
                local t = wardrobe.tile(idx)          -- only on-screen tiles are ever requested
                local over = inside(mx, my, ix, iy, ix + tile, iy + tile)

                draw.rect(ix, iy, ix + tile, iy + tile, 26, 27, 35, 255, 4)
                local shown = false
                if t.state == "ready" then shown = draw.preview_image(t.path, ix, iy, ix + tile, iy + tile, 1.0, true) end
                if not shown then
                    local msg = (t.state == "loading") and "..." or "no preview"
                    text.draw(font.tiny, ix + (tile - text.width(font.tiny, msg)) * 0.5,
                              iy + (tile - text.height(font.tiny)) * 0.5, 110, 112, 124, 255, msg)
                end
                local cursor = kb and idx == cur
                if cursor then
                    draw.rect_outline(ix - 2, iy - 2, ix + tile + 2, iy + tile + 2, 255, 255, 255, 255, 5, 2)
                end
                if t.worn then
                    draw.rect_outline(ix, iy, ix + tile, iy + tile, ar, ag, ab, 255, 4, 2)
                elseif over or cursor then
                    draw.rect_outline(ix, iy, ix + tile, iy + tile, 225, 225, 232, 200, 4, 1)
                else
                    draw.rect_outline(ix, iy, ix + tile, iy + tile, 52, 54, 64, 255, 4, 1)
                end

                local id = "#" .. tostring(t.drawable or 0)
                if (t.texture or 0) > 0 then id = id .. "." .. tostring(t.texture) end
                text.draw(font.tiny, ix + (tile - text.width(font.tiny, id)) * 0.5, iy + tile + 1,
                          t.worn and ar or 140, t.worn and ag or 143, t.worn and ab or 156, 255, id)

                if over then
                    hover_name = t.name
                    hover_ids = id
                    if input.mouse_clicked(0) then kb = false; wardrobe.apply(idx) end
                elseif cursor then
                    hover_name = t.name
                    hover_ids = id
                end
            end
        end
    end
    draw.pop_clip()

    if count == 0 then
        local msg = wardrobe.ready() and ((query ~= "") and "No item matches that search." or "Nothing in this category.")
                                      or "Select a ped first."
        text.draw(font.small, tx0 + (avail - text.width(font.small, msg)) * 0.5,
                  ty0 + view_h * 0.5, 150, 152, 164, 255, msg)
    end

    -- scrollbar
    if scroll_max > 0 then
        local track = view_h
        local th = math.max(20, track * (view_h / (rows * (cell + GAP))))
        local tp = ty0 + (track - th) * (scroll / scroll_max)
        draw.rect(tx1 + 2, tp, tx1 + 5, tp + th, ar, ag, ab, 170, 2)
    end

    -- --- footer strip ---
    local fy = cy + ch - FOOT_H
    draw.rect(cx, fy, cx + cw, cy + ch, 18, 19, 26, 255)
    draw.rect(cx, fy, cx + cw, fy + 1, 44, 46, 56, 255)

    local caption = hover_name or hover_ids
    if not caption then
        caption = string.format("%s  %d", cats[sel_cat] and cats[sel_cat].label or "", count)
    end
    text.draw(font.small, cx + 10, fy + math.floor((FOOT_H - text.height(font.small)) * 0.5),
              200, 202, 212, 255, caption)


    -- Right-aligned button ending at `bx`. Returns its left edge (so the next one can butt up against
    -- it) and whether it was clicked this frame.
    local function button(bx, label_, r, g, b)
        local x0 = bx - (text.width(font.tiny, label_) + 16)
        local y0, y1 = fy + 5, cy + ch - 5
        local over = inside(mx, my, x0, y0, bx, y1)
        draw.rect(x0, y0, bx, y1, r, g, b, over and 220 or 150, 3)
        text.draw(font.tiny, x0 + 8, y0 + math.floor((y1 - y0 - text.height(font.tiny)) * 0.5), 245, 245, 250, 255, label_)
        return x0, over and input.mouse_clicked(0)
    end

    local edge = cx + cw - 8
    local rx, rev_hit = button(edge, "Revert", 120, 48, 52)
    local _,  keep_hit = button(rx - 6, "Keep Outfit", 46, 110, 66)
    if rev_hit then wardrobe.revert() end
    if keep_hit then wardrobe.keep() end

    -- --- ped preview, docked beside the menu like the other preview panels ---
    local bx, by, bw = menu.bounds()
    local pw, ph = 200, 300
    local px, py
    if bw and bw > 0 then
        if (bx + bw * 0.5) < sw * 0.5 then px = bx + bw + 12 else px = bx - 12 - pw end
        py = by
    else
        px = sw - pw - 24; py = 120
    end
    px = clampn(px, 8, sw - 8 - pw)
    -- Leave room under the panel for the key hints, or they fall off the bottom of the screen.
    local hint_h = 4 * (text.height(font.tiny) + 2) + 8
    py = clampn(py, 8, shh - 8 - ph - hint_h)

    -- The ped is composited by the GAME (UI3D) and its backdrop is a game DRAW_RECT, both of which
    -- render underneath this overlay. So the viewport must be left UNFILLED -- a draw.rect over it
    -- paints straight over the ped. Only the chrome around it is ours; player_panel.lua does the same.
    local hdr = text.height(font.item) + 6
    local vx0, vy0 = px + 10, py + hdr + 4
    local vx1, vy1 = px + pw - 10, py + ph - 10
    draw.rect(px, py, px + pw, vy0, 16, 16, 22, 240, 0)                 -- header strip
    draw.rect(px, vy1, px + pw, py + ph, 16, 16, 22, 240, 0)            -- bottom margin
    draw.rect(px, vy0, vx0, vy1, 16, 16, 22, 240, 0)                    -- left margin
    draw.rect(vx1, vy0, px + pw, vy1, 16, 16, 22, 240, 0)               -- right margin
    draw.rect(px, py, px + pw, py + 2, ar, ag, ab, 255, 0)
    text.draw(font.item, px + 10, py + 5, 235, 235, 240, 255, "PREVIEW")
    local ok = wardrobe.draw_ped(vx0 / sw, vy0 / shh, (vx1 - vx0) / sw, (vy1 - vy0) / shh)
    if not ok then
        local msg = "No preview"
        text.draw(font.small, vx0 + ((vx1 - vx0) - text.width(font.small, msg)) * 0.5,
                  vy0 + ((vy1 - vy0) - text.height(font.small)) * 0.5, 140, 142, 154, 255, msg)
    end
    draw.rect_outline(vx0, vy0, vx1, vy1, 60, 60, 70, 255, 4, 1)

    -- Key hints under the preview panel. They used to sit under the editor, which is the menu's own
    -- footer strip -- version, nav arrows and the row counter all landed on top of each other.
    local hints = { "Arrows  move", "Enter  wear", "Tab  category", "Backspace  exit" }
    local hy = py + ph + 6
    for i, h in ipairs(hints) do
        text.draw(font.tiny, px + 2, hy + (i - 1) * (text.height(font.tiny) + 2), 140, 142, 156, 220, h)
    end

    if close then
        if search_focus then
            search_focus = false
            menu.set_text_editing(false)
        else
            menu.set_text_editing(false)
            wardrobe.close()
        end
    end
end)
