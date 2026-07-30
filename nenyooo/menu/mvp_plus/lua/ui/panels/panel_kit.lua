
-- Shared framework for the HUD overlay panels: dragging, edge snapping, group-move of attached
-- panels, a glowing "will attach here" indicator, and position persistence to a file.
-- Defines a global __panelkit at load; panels call __panelkit.move(name, default_x, default_y, w, h)
-- inside their on_draw and use the returned x,y. The kit OWNS each panel's position.
__panelkit = {
    rects   = {}, drags = {}, pos = {}, saved = {}, natw = {}, nath = {}, dock = {}, render = {},
    GUTTER  = 10, SNAP = 12, EPS = 3, ANCHOR = "info_panel", SMOOTH = 18,
    LAYOUT_FILE = "panel_layout.ini",
}
do
    local data = file.read(__panelkit.LAYOUT_FILE)
    if data then
        for line in data:gmatch("[^\r\n]+") do
            -- "name=x,y" (free) or "name=x,y,col,row" (docked into the anchor grid). A legacy
            -- "name=x,y,parent,L|R" line fails the numeric match -> loads FREE (tolerated).
            local n, xs, ys, rest = line:match("^(.-)=(-?%d+%.?%d*),(-?%d+%.?%d*)(.*)$")
            if n then
                __panelkit.saved[n] = { x = tonumber(xs), y = tonumber(ys) }
                local cs, rs = rest:match("^,(%d+),(%d+)$")
                if cs then __panelkit.dock[n] = { col = tonumber(cs), row = tonumber(rs) } end
            end
        end
    end
end
function __panelkit.save()
    local out = {}
    for n, p in pairs(__panelkit.pos) do
        local d = __panelkit.dock[n]
        if d then out[#out + 1] = string.format("%s=%.0f,%.0f,%d,%d", n, p.x, p.y, d.col, d.row)
        else out[#out + 1] = string.format("%s=%.0f,%.0f", n, p.x, p.y) end
    end
    file.write(__panelkit.LAYOUT_FILE, table.concat(out, "\n"))
end
local function nearest(p, cands, snap)
    local bp, bd = p, snap
    for _, c in ipairs(cands) do
        local d = math.abs(c - p)
        if d < bd then bd = d; bp = c end
    end
    return bp
end
function __panelkit.snap(name, px, py, bw, bh, skip)
    local k = __panelkit
    local sw, sh = ctx.screen_w(), ctx.screen_h()
    local bx, by = { 0, sw - bw }, { 0, sh - bh }
    for n, r in pairs(k.rects) do
        if n ~= name and not (skip and skip[n]) then
            bx[#bx + 1] = r.x;                  bx[#bx + 1] = r.x + r.w - bw
            bx[#bx + 1] = r.x + r.w + k.GUTTER; bx[#bx + 1] = r.x - bw - k.GUTTER
            by[#by + 1] = r.y;                  by[#by + 1] = r.y + r.h - bh
            by[#by + 1] = r.y + r.h + k.GUTTER; by[#by + 1] = r.y - bh - k.GUTTER
        end
    end
    return nearest(px, bx, k.SNAP), nearest(py, by, k.SNAP)
end
local function overlap(a0, a1, b0, b1) return math.min(a1, b1) - math.max(a0, b0) end
-- GRID DOCKING: the top bar (k.ANCHOR) is the single dock host. Panels attach beneath it into a
-- fixed 2-column grid; every docked panel is exactly half the anchor's width (cellW). col 0 = left,
-- col 1 = right; panels fill a column top-to-bottom, and row r is shared by both columns. All sizing
-- is computed from natw/nath + the dock graph (never a panel's own last-frame rect.w) -> no thrash.

-- the anchor's effective width: its natural width, grown so neither half-cell clips its widest child.
function __panelkit.anchor_eff_width()
    local k = __panelkit
    local nat, cmax = k.natw[k.ANCHOR] or 0, 0
    for n in pairs(k.dock) do
        local w = k.natw[n] or 0
        if w > cmax then cmax = w end
    end
    if cmax > 0 then
        local need = cmax * 2 + k.GUTTER
        if need > nat then return need end
    end
    return nat
end

-- width of one grid cell (half the anchor, minus the gutter between the two columns).
local function cell_w()
    return math.floor((__panelkit.anchor_eff_width() - __panelkit.GUTTER) / 2)
end

-- top Y of the cell at (col,row): anchor bottom + GUTTER + sum(height + GUTTER) of the panels ABOVE
-- it in the SAME column. Columns stack independently by their own heights, so a short panel's lower
-- neighbour sits directly under it regardless of how tall the other column is (no row-gap).
local function cell_top(a, col, row, exclude)
    local k = __panelkit
    local y = a.y + a.h + k.GUTTER
    for n, d in pairs(k.dock) do
        if n ~= exclude and d.col == col and d.row < row then
            y = y + (k.nath[n] or (k.rects[n] and k.rects[n].h) or 0) + k.GUTTER
        end
    end
    return y
end

-- computed (x, y, w) cell for an already-docked panel; nil if the anchor isn't drawn this frame.
local function cell_rect(name)
    local k = __panelkit
    local a, d = k.rects[k.ANCHOR], k.dock[name]
    if not a or not d then return nil end
    local w = cell_w()
    return a.x + (d.col == 1 and (w + k.GUTTER) or 0), cell_top(a, d.col, d.row, nil), w
end

-- reindex one column's rows densely (0..n-1) after a move/undock so there are no gaps.
function __panelkit.recompact(col)
    local k, list = __panelkit, {}
    for n, d in pairs(k.dock) do if d.col == col then list[#list + 1] = { n, d.row } end end
    table.sort(list, function(p, q) return p[2] < q[2] end)
    for i, p in ipairs(list) do k.dock[p[1]].row = i - 1 end
end

-- dock hit-test against the anchor's grid region, on the RAW cursor. Returns {col,row,x,y,w} or nil.
-- The new panel appends to the BOTTOM of the column the cursor is over (col by cursor vs anchor mid).
local function dock_target(name, mx, my)
    local k = __panelkit
    if name == k.ANCHOR then return nil end
    local a = k.rects[k.ANCHOR]; if not a then return nil end
    if mx < a.x or mx > a.x + a.w then return nil end     -- horizontally within the anchor span
    if my < a.y + a.h then return nil end                 -- at/below the anchor bottom
    local col = (mx < a.x + a.w * 0.5) and 0 or 1
    local count = 0
    for n, d in pairs(k.dock) do if n ~= name and d.col == col then count = count + 1 end end
    local w = cell_w()
    local x = a.x + (col == 1 and (w + k.GUTTER) or 0)
    return { col = col, row = count, x = x, y = cell_top(a, col, count, name), w = w }
end

-- Resolve a panel's render width: record its natural width; docked -> one cell, else its own width.
function __panelkit.resolve_width(name, nat)
    __panelkit.natw[name] = nat
    if __panelkit.dock[name] then return cell_w() end
    return nat
end

-- The anchor (top bar) records its natural width and renders grown so two cells fit without clipping.
function __panelkit.anchor_width(nat)
    __panelkit.natw[__panelkit.ANCHOR] = nat
    return __panelkit.anchor_eff_width()
end

local function draw_indicator(name, r)
    local k = __panelkit
    local ar, ag, ab = theme.accent()
    for n, o in pairs(k.rects) do
        if n ~= name then
            if overlap(r.y, r.y + r.h, o.y, o.y + o.h) > 0 then
                local y0, y1 = math.max(r.y, o.y), math.min(r.y + r.h, o.y + o.h)
                if math.abs((r.x + r.w + k.GUTTER) - o.x) <= k.EPS then draw.rect(r.x + r.w + 1, y0, o.x - 1, y1, ar, ag, ab, 255)
                elseif math.abs((o.x + o.w + k.GUTTER) - r.x) <= k.EPS then draw.rect(o.x + o.w + 1, y0, r.x - 1, y1, ar, ag, ab, 255) end
            end
            if overlap(r.x, r.x + r.w, o.x, o.x + o.w) > 0 then
                local x0, x1 = math.max(r.x, o.x), math.min(r.x + r.w, o.x + o.w)
                if math.abs((r.y + r.h + k.GUTTER) - o.y) <= k.EPS then draw.rect(x0, r.y + r.h + 1, x1, o.y - 1, ar, ag, ab, 255)
                elseif math.abs((o.y + o.h + k.GUTTER) - r.y) <= k.EPS then draw.rect(x0, o.y + o.h + 1, x1, r.y - 1, ar, ag, ab, 255) end
            end
        end
    end
end
function __panelkit.move(name, dx, dy, bw, bh)
    local k = __panelkit
    k.nath[name] = bh                      -- record natural height for ALL callers (incl. the anchor)
    local sw, sh = ctx.screen_w(), ctx.screen_h()
    local pos = k.pos[name]
    if not pos then
        local s = k.saved[name]
        pos = s and { x = s.x, y = s.y } or { x = dx, y = dy }
        k.pos[name] = pos
    end
    if pos.x < 0 then pos.x = 0 elseif pos.x > sw - bw then pos.x = sw - bw end
    if pos.y < 0 then pos.y = 0 elseif pos.y > sh - bh then pos.y = sh - bh end
    local d = k.drags[name]
    if not d then d = {}; k.drags[name] = d end
    local can = menu.is_visible()
    local mx, my = input.mouse_x(), input.mouse_y()
    -- only ONE panel may own a drag at a time (k.active) -> two overlapping panels can't both grab
    -- the same click and fight / get stuck behind one another.
    if can and not k.active and input.mouse_clicked(0)
        and mx >= pos.x and mx <= pos.x + bw and my >= pos.y and my <= pos.y + bh then
        d.active = true; k.active = name
        d.gx, d.gy = mx - pos.x, my - pos.y; d.moved = false
    end
    if d.active and can and input.mouse_down(0) then
        local nx, ny = mx - d.gx, my - d.gy
        -- dock takes priority and is tested on the RAW cursor pos (not snapped) so it never fights
        -- the generic edge-snap; generic snap only runs when we're NOT docking into the anchor grid.
        local tgt, prev = dock_target(name, mx, my), k.dock[name]
        if tgt then
            if prev and prev.col ~= tgt.col then k.dock[name] = nil; k.recompact(prev.col) end
            k.dock[name] = { col = tgt.col, row = tgt.row }
            k.recompact(tgt.col)
            nx, ny = tgt.x, tgt.y
        else
            if prev then k.dock[name] = nil; k.recompact(prev.col) end   -- undock -> collapse column
            nx, ny = k.snap(name, nx, ny, bw, bh, { [name] = true })
        end
        d.dtgt = tgt
        if nx ~= pos.x or ny ~= pos.y then d.moved = true end
        pos.x, pos.y = nx, ny
    else
        if d.active then
            if d.moved then k.save() end
            d.active = false; d.dtgt = nil
            if k.active == name then k.active = nil end
        end
        if k.dock[name] and name ~= k.ANCHOR then     -- docked + idle: glue to the computed grid cell
            local x, y = cell_rect(name)
            if x then pos.x, pos.y = x, y end           -- anchor absent this frame -> keep pos, re-glue later
        end
    end
    k.rects[name] = { x = pos.x, y = pos.y, w = bw, h = bh }
    -- Ease only the DRAWN position toward the logical target (k.rects/hit-tests stay exact), so
    -- attaching, reflow (a sibling inserted/removed), and dragging all glide instead of snapping.
    -- Frame-rate-independent exponential smoothing; the held panel eases faster to stay glued to the
    -- cursor while siblings reflow gently. Snap to target within 0.5px to kill endless micro-drift.
    local rp = k.render[name]
    if not rp then rp = { x = pos.x, y = pos.y }; k.render[name] = rp end
    local rate = (name == k.active) and (k.SMOOTH * 2.4) or k.SMOOTH
    local t = 1 - math.exp(-math.max(ctx.delta(), 0.0001) * rate)
    rp.x = rp.x + (pos.x - rp.x) * t
    rp.y = rp.y + (pos.y - rp.y) * t
    if math.abs(rp.x - pos.x) < 0.5 then rp.x = pos.x end
    if math.abs(rp.y - pos.y) < 0.5 then rp.y = pos.y end
    if d.active then
        if d.dtgt then
            local ar, ag, ab = theme.accent()
            draw.rect(d.dtgt.x, d.dtgt.y, d.dtgt.x + d.dtgt.w, d.dtgt.y + bh, ar, ag, ab, 70)
        else
            draw_indicator(name, k.rects[name])
        end
    end
    return rp.x, rp.y
end
function __panelkit.hide(name)
    __panelkit.rects[name] = nil
    __panelkit.render[name] = nil          -- re-init in place on reshow (no slide-in from old pos)
    local d = __panelkit.drags[name]
    if d then d.active = false end
    if __panelkit.active == name then __panelkit.active = nil end
end

-- â”€â”€ shared "card" chrome â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
-- Techy-HUD look (square corners): faked drop shadow, subtle vertical gradient body, thin themed
-- accent outline, accent corner ticks, an accent block + UPPERCASE letter-spaced title, a thin
-- header divider, and optional per-row usage fill bars. ALL panel styling lives here -- edit once.
__panelkit.style = {
    tfont = font.label, vfont = font.value, tspacing = 2,
    padx = 11, pady = 8, rgap = 6, colgap = 24, tick = 7, sh = 4, blk = 3,
    bg_top = { 24, 25, 32 }, bg_bot = { 15, 15, 21 }, bg_a = 238,
    title_c = { 236, 238, 245 }, label_c = { 140, 143, 156 }, value_c = { 234, 236, 244 },
    track = { 38, 39, 48 }, outline_a = 110, shadow_a = 90, divider_a = 70, bar_h = 3,
}

-- header band height (y -> first row). Lazy: fonts may not be bound when this file first loads.
function __panelkit.header_h()
    local s = __panelkit.style
    return s.pady + text.height(s.tfont) + 9
end

-- card width/height from rows ({label,value} pairs). opts.bar reserves a fill-bar row per row.
function __panelkit.card_size(title, rows, opts)
    local s = __panelkit.style
    local lh = text.height(s.vfont) + s.rgap
    local content = text.width_spaced(s.tfont, string.upper(title), s.tspacing)
    for _, r in ipairs(rows) do
        local rw = text.width(s.vfont, r[1]) + s.colgap + text.width(s.vfont, r[2])
        if rw > content then content = rw end
    end
    local bw = content + s.padx * 2
    local body = #rows * lh - s.rgap
    if opts and opts.bar then body = body + #rows * (s.bar_h + 3) end
    return bw, __panelkit.header_h() + body + s.pady
end

local function corner_ticks(x, y, bw, bh, r, g, b)
    local t = __panelkit.style.tick
    draw.line(x, y, x + t, y, r, g, b, 255, 1);                draw.line(x, y, x, y + t, r, g, b, 255, 1)
    draw.line(x + bw - t, y, x + bw, y, r, g, b, 255, 1);      draw.line(x + bw, y, x + bw, y + t, r, g, b, 255, 1)
    draw.line(x, y + bh - t, x, y + bh, r, g, b, 255, 1);      draw.line(x, y + bh, x + t, y + bh, r, g, b, 255, 1)
    draw.line(x + bw - t, y + bh, x + bw, y + bh, r, g, b, 255, 1); draw.line(x + bw, y + bh - t, x + bw, y + bh, r, g, b, 255, 1)
end

local function card_body(x, y, bw, bh)
    local s = __panelkit.style
    local ar, ag, ab = theme.accent()
    draw.rect(x + s.sh, y + s.sh, x + bw + s.sh, y + bh + s.sh, 0, 0, 0, s.shadow_a)   -- shadow
    draw.rect_gradient(x, y, x + bw, y + bh,                                            -- body gradient
        s.bg_top[1], s.bg_top[2], s.bg_top[3], s.bg_a, s.bg_top[1], s.bg_top[2], s.bg_top[3], s.bg_a,
        s.bg_bot[1], s.bg_bot[2], s.bg_bot[3], s.bg_a, s.bg_bot[1], s.bg_bot[2], s.bg_bot[3], s.bg_a)
    corner_ticks(x, y, bw, bh, ar, ag, ab)
    return ar, ag, ab
end

-- draw bg + header. returns content origin (cx, cy) and inner width.
function __panelkit.card_chrome(x, y, bw, bh, title)
    local s = __panelkit.style
    local ar, ag, ab = card_body(x, y, bw, bh)
    local ty = y + s.pady
    text.draw_spaced(s.tfont, x + s.padx, ty,
        s.title_c[1], s.title_c[2], s.title_c[3], 255, string.upper(title), s.tspacing)
    local cy = y + __panelkit.header_h()
    draw.line(x + s.padx, cy - 6, x + bw - s.padx, cy - 6, ar, ag, ab, s.divider_a, 1)  -- divider
    return x + s.padx, cy, bw - s.padx * 2
end

function __panelkit.card_row(cx, cy, inner, label, value)
    local s = __panelkit.style
    if label ~= "" then text.draw(s.vfont, cx, cy, s.label_c[1], s.label_c[2], s.label_c[3], 255, label) end
    text.draw(s.vfont, cx + inner - text.width(s.vfont, value), cy, s.value_c[1], s.value_c[2], s.value_c[3], 255, value)
    return cy + text.height(s.vfont) + s.rgap
end

function __panelkit.card_bar(cx, cy, inner, label, value, frac)
    local s = __panelkit.style
    local ar, ag, ab = theme.accent()
    if label ~= "" then text.draw(s.vfont, cx, cy, s.label_c[1], s.label_c[2], s.label_c[3], 255, label) end
    text.draw(s.vfont, cx + inner - text.width(s.vfont, value), cy, s.value_c[1], s.value_c[2], s.value_c[3], 255, value)
    local by = cy + text.height(s.vfont) + 2
    draw.rect(cx, by, cx + inner, by + s.bar_h, s.track[1], s.track[2], s.track[3], 255)
    if frac < 0 then frac = 0 elseif frac > 1 then frac = 1 end
    if frac > 0 then draw.rect(cx, by, cx + inner * frac, by + s.bar_h, ar, ag, ab, 235) end
    return cy + text.height(s.vfont) + s.rgap + s.bar_h + 3
end

function __panelkit.card(name, def_x, def_y, title, rows, opts)
    local nat, bh = __panelkit.card_size(title, rows, opts)
    __panelkit.natw[name] = nat
    local bw = __panelkit.resolve_width(name, nat)   -- half-width if docked; else match vertical stack
    local px, py = __panelkit.move(name, def_x, def_y, bw, bh)
    return __panelkit.card_chrome(px, py, bw, bh, title)
end

-- All-in-one convenience: size + position (drag/dock/snap) + draw chrome AND every row. Use this from a
-- panel's on_draw instead of card()+card_row loop. rows = { {label, value}, ... }; opts.bar => each row
-- carries a fill fraction as rows[i][3]. Fully Lua (edit card_chrome/card_row/card_bar to restyle).
function __panelkit.panel(name, def_x, def_y, title, rows, opts)
    local nat, bh = __panelkit.card_size(title, rows, opts)
    __panelkit.natw[name] = nat
    local bw = __panelkit.resolve_width(name, nat)
    local px, py = __panelkit.move(name, def_x, def_y, bw, bh)
    local cx, cy, inner = __panelkit.card_chrome(px, py, bw, bh, title)
    if opts and opts.bar then for _, r in ipairs(rows) do cy = __panelkit.card_bar(cx, cy, inner, r[1], r[2], r[3] or 0) end
    else for _, r in ipairs(rows) do cy = __panelkit.card_row(cx, cy, inner, r[1], r[2]) end end
end

-- All-in-one horizontal strip (info_panel anchor): chrome + a coloured token run.
-- toks = { {text, {r,g,b}}, ... }. Returns the final px,py used (for callers that care).
function __panelkit.info_strip(name, def_x, def_y, toks, fh)
    local s = __panelkit.style
    local total = 0
    for _, t in ipairs(toks) do total = total + text.width(s.vfont, t[1]) end
    local bw = total + s.padx * 2
    local bh = fh + s.pady * 2
    bw = __panelkit.anchor_width(bw)                 -- record natural width; grow so docked cells never clip
    local px, py = __panelkit.move(name, def_x, def_y, bw, bh)
    local cx, vy = __panelkit.strip_chrome(px, py, bw, bh, fh)
    for _, t in ipairs(toks) do local c = t[2]; text.draw(s.vfont, cx, vy, c[1], c[2], c[3], 255, t[1]); cx = cx + text.width(s.vfont, t[1]) end
    return px, py
end

-- horizontal strip chrome (info_panel): same look, no title band. returns content x + centered text y.
function __panelkit.strip_chrome(x, y, bw, bh, fh)
    local s = __panelkit.style
    local ar, ag, ab = card_body(x, y, bw, bh)
    local yc = y + (bh - fh) * 0.5
    return x + s.padx, yc
end
