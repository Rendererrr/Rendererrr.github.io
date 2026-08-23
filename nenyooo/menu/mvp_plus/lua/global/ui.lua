-- Nenyoo click-GUI layout core.
--
-- WHY THIS EXISTS
-- Before this, a theme could only know a row's height by DRAWING it: the draw function returned
-- `row_h + extra`, where `extra` depended on the item's live state (a slider adds a track, a
-- float_toggle adds one only while it is on). Anything that must be sized before it is filled -- a
-- group-box card, a pixel-balanced column -- was therefore impossible. Themes worked around it by
-- balancing columns on item COUNT (a card of 5 sliders and a card of 5 toggles both counted as 5, so
-- the columns visibly desynced) or by hand-maintaining a second copy of every widget's height math,
-- which drifted from the first copy within one release.
--
-- THE CONTRACT: a widget declares its height exactly once, in `measure`, and RECEIVES that height as
-- an argument to `draw`. It cannot invent height at draw time. Everything else here follows from
-- that: cards get auto height, columns balance on real pixels, and a scrollbar is correct on the
-- first frame because the container knows its content height before it positions anything.
--
-- Loaded into _G by load_api_foundation() before any theme runs. Sorts before util.lua/v3.lua/etc,
-- so nothing here may CALL those at load time (call time is fine).

ui = ui or {}
-- set by ui_widgets once its helpers exist
ui._fill_grad = ui._fill_grad

ui.strict = false          -- dev aid: verify widgets draw within their declared height
ui._frame = -1
ui._deferred = {}
ui._state = {}
ui._widgets = {}
ui._id_seq = 0

-- ── ids ──────────────────────────────────────────────────────────────────────
-- Capture/focus/scroll ids must be stable across frames and across a registry rebuild. Derive them
-- from something that identifies the thing (an item hash, a page id, a literal name) -- never from a
-- loop index, which shifts the moment the content changes.
function ui.id(...)
    local parts = { ... }
    for i = 1, #parts do parts[i] = tostring(parts[i]) end
    return ui.hash(table.concat(parts, ":"))
end

-- Per-widget scratch that survives frames without the theme keeping a pile of file-scope globals.
-- Pruned when untouched for a while so a page with hundreds of transient rows does not grow forever.
function ui.state(id)
    local s = ui._state[id]
    if not s then
        s = { _seen = ui._frame }
        ui._state[id] = s
    end
    s._seen = ui._frame
    return s
end

local function prune_state()
    if (ui._frame % 600) ~= 0 then return end
    local cutoff = ui._frame - 600
    for k, v in pairs(ui._state) do
        if (v._seen or 0) < cutoff then ui._state[k] = nil end
    end
end

-- ── frame ────────────────────────────────────────────────────────────────────

function ui.begin_frame()
    ui._frame = ctx.frame()
    ui._deferred = {}
    ui._id_seq = 0
    ui._hover_hash = nil
    ui._focus_list = {}
    ui.begin_frame_native()                       -- C++: republish overlay-block, reset layer
    menu.set_text_editing(ui.focused() ~= 0)      -- keep the script thread suppressing game input
    if ui.sync_theme then ui.sync_theme() end     -- track the live accent (ui_skin.lua loads after us)
    prune_state()
end

-- Runs the deferred layers (dropdown bodies, colour pickers, tooltips) after the main pass, with the
-- clip stack unwound. That is what lets a popup be DECLARED where its control lives while still
-- drawing on top of everything and outside every container clip -- previously each theme stashed the
-- popup's rect into globals and re-drew it by hand at the very end of draw_menu.
function ui.end_frame()
    -- Publish the ring built during THIS draw. handle_input runs before the next begin_frame, so
    -- rotating here is what lets the very first arrow press act on what is actually on screen.
    ui._focus_prev = ui._focus_list
    local queue = ui._deferred
    ui._deferred = {}
    table.sort(queue, function(a, b) return a.z < b.z end)
    for i = 1, #queue do
        local prev = ui.layer(queue[i].z)
        queue[i].fn()
        ui.layer(prev)
    end
    ui.layer(0)
end

-- ── keyboard focus ───────────────────────────────────────────────────────────
-- Widgets register themselves in DRAW order as they paint, so the ring follows the visual layout
-- (column 1 top-to-bottom, then column 2) without the containers having to know anything about it.
-- handle_input runs before draw, so it walks the PREVIOUS frame's ring -- one frame stale, which is
-- invisible and avoids a second layout pass.
function ui.focusable(hash, x, y, w, h)
    if not hash then return false end
    local l = ui._focus_list
    l[#l + 1] = { hash = hash, x = x, y = y, w = w, h = h }
    return ui._focus_hash == hash
end

function ui.focus_index()
    for i, e in ipairs(ui._focus_prev) do
        if e.hash == ui._focus_hash then return i end
    end
    return 0
end

function ui.focus_move(dir)
    local l = ui._focus_prev
    if #l == 0 then return end
    local i = ui.focus_index() + dir
    if i < 1 then i = #l elseif i > #l then i = 1 end
    ui._focus_hash = l[i].hash
    ui._focus_kbd = true          -- only a keyboard move should paint the ring
    ui._focus_scroll_to = l[i]
end

-- Call from the theme's handle_input(). Arrows move, Enter activates, Backspace/Escape go back.
-- Enter routes through ui.activate, so keyboard and mouse take the identical path.
function ui.keyboard_nav()
    if ui.focused() ~= 0 then return end       -- a text field owns the keyboard
    if input.key_repeat(VK.DOWN) or input.key_just_pressed(VK.DOWN) then ui.focus_move(1) end
    if input.key_repeat(VK.UP)   or input.key_just_pressed(VK.UP)   then ui.focus_move(-1) end
    if input.key_just_pressed(VK.RETURN) and ui._focus_hash then
        local h = items.get(ui._focus_hash)
        if h then ui.activate(h) end
    end
    if input.key_just_pressed(VK.ESCAPE) or input.key_just_pressed(VK.BACK) then menu.go_back() end
end

function ui.defer(z, fn)
    ui._deferred[#ui._deferred + 1] = { z = z or 100, fn = fn }
end

-- Place a popup of w x h anchored under (ax, ay_bottom), flipping above the anchor when it would
-- fall off the bottom and clamping into the viewport. Every theme reimplemented this; it is one
-- function because getting it wrong is invisible until a dropdown lands near a screen edge.
function ui.popup_place(ax, ay_top, ay_bottom, w, h)
    local sw, sh = ctx.screen_w(), ctx.screen_h()
    local x, y = ax, ay_bottom
    if y + h > sh - 4 then y = ay_top - h end     -- flip up
    if y < 4 then y = 4 end
    if y + h > sh - 4 then y = sh - 4 - h end
    if x + w > sw - 4 then x = sw - 4 - w end
    if x < 4 then x = 4 end
    return x, y
end

-- ── widget registry ──────────────────────────────────────────────────────────
-- def = { measure = function(node, w, sk) -> h,
--         draw    = function(node, x, y, w, h, sk) }
-- A theme overrides one widget's look by re-registering it; layout, clipping, hit-testing and
-- scrolling continue to come from here.
function ui.widget(kind, def)
    ui._widgets[kind] = def
    return def
end

function ui.measure(node, w, sk)
    if not node then return 0 end
    sk = sk or ui.skin
    -- Memoised per (frame, width): a card measures its children to size itself, then the column
    -- measures the card, then the draw pass asks again. Without this that is O(depth^2) per frame.
    if node._mf == ui._frame and node._mw == w then return node._h end
    local def = ui._widgets[node.kind]
    local h = 0
    if def and def.measure then h = def.measure(node, w, sk) or 0 end
    node._mf, node._mw, node._h = ui._frame, w, h
    return h
end

function ui.draw(node, x, y, w, sk)
    if not node then return 0 end
    sk = sk or ui.skin
    local h = node._force_h or ui.measure(node, w, sk)
    local def = ui._widgets[node.kind]
    if def and def.draw then def.draw(node, x, y, w, h, sk) end
    return h
end

-- ── leaf helpers ─────────────────────────────────────────────────────────────

-- Escape hatch for hand-painted content: an explicitly declared height plus a raw draw callback.
-- Keeps bespoke elements inside the contract instead of punching a hole in it.
ui.widget("fixed", {
    measure = function(n) return n.h or 0 end,
    draw    = function(n, x, y, w, h, sk) if n.fn then n.fn(x, y, w, h, sk) end end,
})
function ui.fixed(h, fn) return { kind = "fixed", h = h, fn = fn } end

ui.widget("spacer", { measure = function(n) return n.h or 0 end, draw = function() end })
function ui.spacer(h) return { kind = "spacer", h = h or 6 } end

ui.widget("separator", {
    measure = function(n, w, sk) return (n.h or sk.sep_h) end,
    draw = function(n, x, y, w, h, sk)
        local c = n.color or sk.col.div
        draw.line(x + (n.inset or sk.sep_inset), y + h * 0.5,
                  x + w - (n.inset or sk.sep_inset), y + h * 0.5, c[1], c[2], c[3], c[4] or 90)
    end,
})
function ui.separator(t) t = t or {}; t.kind = "separator"; return t end

-- ── containers ───────────────────────────────────────────────────────────────

local function children_of(t)
    -- Containers take their children as the array part of the same table that carries their options,
    -- so `ui.column{ gap = 4, a, b, c }` reads naturally. nil entries are skipped so a theme can write
    -- `cond and widget or nil` inline.
    local out = {}
    for i = 1, #t do if t[i] then out[#out + 1] = t[i] end end
    return out
end

ui.widget("column", {
    measure = function(n, w, sk)
        local gap = n.gap or sk.gap
        local pad = n.pad or 0
        local inner = w - pad * 2
        local h, first = pad * 2, true
        for _, c in ipairs(n.kids) do
            if not first then h = h + gap end
            h = h + ui.measure(c, inner, sk)
            first = false
        end
        return h
    end,
    draw = function(n, x, y, w, h, sk)
        local gap = n.gap or sk.gap
        local pad = n.pad or 0
        local inner = w - pad * 2
        local cy = y + pad
        -- Skip children entirely outside the enclosing scroll viewport. Heights are already known
        -- from the measure pass, so this is exact and free -- and it is why a 400-row page costs the
        -- ~20 rows you can see rather than all 400 (clipping alone hides them but still draws them).
        local c1, c2 = ui._cull_y1, ui._cull_y2
        for _, c in ipairs(n.kids) do
            local ch = ui.measure(c, inner, sk)
            if (not c1) or (cy + ch >= c1 and cy <= c2) then
                ui.draw(c, x + pad, cy, inner, sk)
            end
            cy = cy + ch + gap
        end
        if ui.strict and cy - gap > y + h + 0.5 then
            ui._overflow("column", cy - gap - (y + h))
        end
    end,
})
function ui.column(t) t.kind = "column"; t.kids = children_of(t); return t end

-- weights: per-child, either a fraction of the free space (<= 1) or a fixed pixel width (> 1).
-- Missing entries default to an equal share. This is what replaces the hand-rolled "pack two action
-- buttons per row" look-ahead loops.
ui.widget("row", {
    measure = function(n, w, sk)
        local widths = ui._row_widths(n, w, sk)
        local h = 0
        for i, c in ipairs(n.kids) do
            local ch = ui.measure(c, widths[i], sk)
            if ch > h then h = ch end
        end
        return h
    end,
    draw = function(n, x, y, w, h, sk)
        local widths = ui._row_widths(n, w, sk)
        local gap = n.gap or sk.gap
        local cx = x
        for i, c in ipairs(n.kids) do
            ui.draw(c, cx, y, widths[i], sk)
            cx = cx + widths[i] + gap
        end
    end,
})

function ui._row_widths(n, w, sk)
    local gap = n.gap or sk.gap
    local kids = n.kids
    local avail = w - gap * math.max(0, #kids - 1)
    local widths, fixed, frac_total = {}, 0, 0
    for i = 1, #kids do
        local wt = n.weights and n.weights[i]
        if wt and wt > 1 then
            widths[i] = wt
            fixed = fixed + wt
        else
            widths[i] = false
            frac_total = frac_total + (wt or 1)
        end
    end
    local free = math.max(0, avail - fixed)
    for i = 1, #kids do
        if widths[i] == false then
            local wt = (n.weights and n.weights[i]) or 1
            widths[i] = frac_total > 0 and (free * wt / frac_total) or 0
        end
    end
    return widths
end

function ui.row(t) t.kind = "row"; t.kids = children_of(t); return t end

-- N-column masonry. `n` is a value, not a divisor baked into variable names, so 2, 3 or 4 columns is
-- one argument. Children are measured, then each is placed into the currently-shortest column
-- (balancing on real pixels, not item count). Cards fully outside the viewport are not drawn.
--
--   independent_scroll = true  -> one scroll region and one scrollbar PER column (the Cherax look)
--   independent_scroll = false -> a single shared scroll over the whole grid (the Bento look)
ui.widget("columns", {
    measure = function(n, w, sk)
        ui._columns_layout(n, w, sk)
        -- `h` given => a fixed viewport that scrolls (the usual case: the grid fills the window).
        -- Omitted => the grid is as tall as its tallest column and nothing scrolls.
        return n.h or n._content_h
    end,
    draw = function(n, x, y, w, h, sk)
        ui._columns_layout(n, w, sk)
        local gap = n.gap or sk.gap
        local cw, iw = n._col_w, n._item_w
        local id = n.id or ui.id("columns")

        -- One panel behind the WHOLE content area. Cards are sections of a continuous surface in the
        -- reference, not floating boxes, so anything not covered by a card -- the lane between the two
        -- columns, the strip beside the rail, the space under a short column -- must carry the same
        -- tint. Painting it once here and letting the cards draw without their own fill is what stops
        -- those gaps reading as brighter bare background.
        if n.panel and sk.col.card then
            local top, bot = sk.col.card, sk.col.card_bot_col or sk.col.card
            ui._panel_active = true
            ui._fill_grad(x, y, x + w, y + h, top, bot, 0, true)
        end

        if n.independent_scroll then
            for ci = 1, n.n do
                local cx = x + (ci - 1) * (cw + gap)
                local sid = ui.id(id, "col", ci)
                ui.scroll_begin(sid, cx, y, cx + cw, y + h)
                ui.scroll_content(sid, n._col_h[ci])
                local off = ui.scroll_offset(sid)
                local p1, p2 = ui.push_cull(y, y + h)
                for _, p in ipairs(n._placed) do
                    if p.col == ci then
                        local py = y + p.top - off
                        -- Cull cards fully outside the viewport: with a big page most of them are.
                        -- Cards that straddle the edge still draw, and their column culls per row.
                        if py + p.h >= y and py <= y + h then ui.draw(p.node, cx, py, iw, sk) end
                    end
                end
                ui.pop_cull(p1, p2)
                ui.scrollbar(cx + cw - sk.scrollbar_w, y, sk.scrollbar_w, h, off, ui.scroll_max(sid), sk)
                ui.scroll_end()
            end
        else
            ui.scroll_begin(id, x, y, x + w, y + h)
            ui.scroll_content(id, n._content_h)
            local off = ui.scroll_offset(id)
            local p1, p2 = ui.push_cull(y, y + h)
            for _, p in ipairs(n._placed) do
                local px = x + (p.col - 1) * (cw + gap)
                local py = y + p.top - off
                if py + p.h >= y and py <= y + h then ui.draw(p.node, px, py, iw, sk) end
            end
            ui.pop_cull(p1, p2)
            ui.scrollbar(x + w - sk.scrollbar_w, y, sk.scrollbar_w, h, off, ui.scroll_max(id), sk)
            ui.scroll_end()
        end
        ui._panel_active = false
    end,
})

function ui._columns_layout(n, w, sk)
    if n._lf == ui._frame and n._lw == w then return end
    local cols = math.max(1, n.n or 2)
    local gap = n.gap or sk.gap
    -- The scrollbar gets its own lane so cards never sit underneath it. Per column when each column
    -- scrolls on its own, once at the far right when they share a scroll. Reserved BEFORE measuring,
    -- so the width children are measured at is the width they are drawn at.
    local bar = sk.scrollbar_w + 4
    local grid_w = n.independent_scroll and w or (w - bar)
    local col_w = (grid_w - gap * (cols - 1)) / cols
    local item_w = n.independent_scroll and (col_w - bar) or col_w

    -- Vertical spacing between stacked cards is separate from the gap BETWEEN columns. The reference
    -- stacks its cards flush -- one card's last row meets the next card's title band directly -- so a
    -- vertical gap there shows untinted background through every join.
    local vgap = n.vgap or gap

    local coltop = {}
    for i = 1, cols do coltop[i] = 0 end
    local placed = {}
    local last = {}
    for _, c in ipairs(n.kids) do
        local ci = 1
        for i = 2, cols do if coltop[i] < coltop[ci] then ci = i end end
        local ch = ui.measure(c, item_w, sk)
        c._force_h = nil
        placed[#placed + 1] = { node = c, col = ci, top = coltop[ci], h = ch }
        last[ci] = placed[#placed]
        coltop[ci] = coltop[ci] + ch + vgap
    end

    local content = 0
    for i = 1, cols do
        coltop[i] = math.max(0, coltop[i] - vgap)     -- drop the trailing gap
        if coltop[i] > content then content = coltop[i] end
    end

    -- Stretch the last card of any column that falls short of the viewport, so a column with less
    -- content does not expose a block of bare, untinted background beneath it.
    if n.fill_column and n.h then
        for i = 1, cols do
            local e = last[i]
            if e and coltop[i] < n.h then
                local extra = n.h - coltop[i]
                e.h = e.h + extra
                e.node._force_h = e.h
                coltop[i] = n.h
            end
        end
        if n.h > content then content = n.h end
    end

    n.n, n._col_w, n._item_w = cols, col_w, item_w
    n._placed, n._col_h, n._content_h = placed, coltop, content
    n._lf, n._lw = ui._frame, w
end

function ui.columns(t) t.kind = "columns"; t.kids = children_of(t); return t end

-- A standalone scroll region for a single child.
ui.widget("scroll", {
    measure = function(n, w, sk) return n.h or 0 end,
    draw = function(n, x, y, w, h, sk)
        local id = n.id or ui.id("scroll")
        ui.scroll_begin(id, x, y, x + w, y + h)
        local inner = w - (n.hide_bar and 0 or (sk.scrollbar_w + 4))
        ui.scroll_content(id, ui.measure(n.kids[1], inner, sk))
        local off = ui.scroll_offset(id)
        local p1, p2 = ui.push_cull(y, y + h)
        ui.draw(n.kids[1], x, y - off, inner, sk)
        ui.pop_cull(p1, p2)
        if not n.hide_bar then
            ui.scrollbar(x + w - sk.scrollbar_w, y, sk.scrollbar_w, h, off, ui.scroll_max(id), sk)
        end
        ui.scroll_end()
    end,
})

-- Cull band in screen space, saved/restored by the caller so nested scrolls behave.
function ui.push_cull(y1, y2)
    local p1, p2 = ui._cull_y1, ui._cull_y2
    ui._cull_y1, ui._cull_y2 = y1, y2
    return p1, p2
end

function ui.pop_cull(p1, p2)
    ui._cull_y1, ui._cull_y2 = p1, p2
end
function ui.scroll(t) t.kind = "scroll"; t.kids = children_of(t); return t end

-- Shared scrollbar rendering. Drawn by the scroll containers themselves so a theme never has to
-- track "how far along am I" -- that state belongs to the container.
function ui.scrollbar(x, y, w, h, offset, max, sk)
    sk = sk or ui.skin
    if max <= 0 then return end
    local c = sk.col.scrollbar
    local frac = h / (h + max)
    local th = math.max(24, h * frac)
    local ty = y + (h - th) * (offset / max)
    draw.rect(x, ty, x + w, ty + th, c[1], c[2], c[3], c[4] or 160, w * 0.5)
end

function ui._overflow(what, by)
    -- Only reachable with ui.strict on. A widget drawing past its declared height is the exact class
    -- of bug the measure/draw split exists to prevent, so say which one and by how much.
    notify.push("UI", string.format("%s overflowed by %.1fpx", what, by), 2, 4.0)
end
