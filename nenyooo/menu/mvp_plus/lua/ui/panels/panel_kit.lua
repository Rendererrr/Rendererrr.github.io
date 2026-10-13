-- Shared framework for the HUD overlay panels: dragging, edge snapping, docking into a virtual
-- top panel, folding, per-panel refresh throttling, and position persistence to a file.
-- Defines a global __panelkit at load; panels call __panelkit.gate() to decide whether to draw and
-- __panelkit.panel() to size + position + render themselves. The kit OWNS each panel's position.
__panelkit = {
    rects   = {}, drags = {}, pos = {}, saved = {}, natw = {}, nath = {}, dock = {}, render = {},
    folded  = {}, cbox = {}, hist = {}, hslot = {}, dprev = {}, dval = {}, dslot = {},
    GUTTER  = 1, SNAP = 12, EPS = 3, ANCHOR = "info_panel", SMOOTH = 18,
    LAYOUT_FILE = "panel_layout.ini",
}
do
    local data = file.read(__panelkit.LAYOUT_FILE)
    if data then
        for line in data:gmatch("[^\r\n]+") do
            -- "~folded=a,b,c" carries the collapsed set. It cannot collide with a panel line
            -- because the position pattern below requires two numbers after the '='.
            local fl = line:match("^~folded=(.*)$")
            if fl then
                for n in fl:gmatch("[^,]+") do __panelkit.folded[n] = true end
            else
                -- "name=x,y" (free) or "name=x,y,col,row" (docked into the rail grid). A legacy
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
end
function __panelkit.save()
    local out, fold = {}, {}
    for n, p in pairs(__panelkit.pos) do
        local d = __panelkit.dock[n]
        if d then out[#out + 1] = string.format("%s=%.0f,%.0f,%d,%d", n, p.x, p.y, d.col, d.row)
        else out[#out + 1] = string.format("%s=%.0f,%.0f", n, p.x, p.y) end
    end
    for n, on in pairs(__panelkit.folded) do if on then fold[#fold + 1] = n end end
    if #fold > 0 then out[#out + 1] = "~folded=" .. table.concat(fold, ",") end
    file.write(__panelkit.LAYOUT_FILE, table.concat(out, "\n"))
end

-- ── visibility gate ───────────────────────────────────────────────────────────────────────────
-- Every panel opened with the same five-line dance: read the setting, honour the Always/In-Menu
-- mode, hide on the way out, and bail if its data source is missing. That rule now lives here, so
-- a new panel cannot get it subtly wrong. `dep` is the panel's data source (pools, session, ...);
-- pass true when it has none.
function __panelkit.gate(name, setting, dep)
    local st = menu.get_setting(setting)
    local on = st and st.on and (st.value_index ~= 1 or menu.is_visible())
    if not on or not dep then
        __panelkit.hide(name)
        return false
    end
    return true
end

-- ── refresh throttling ────────────────────────────────────────────────────────────────────────
-- A panel rebuilding its rows every frame runs a dozen string.format calls for values that change
-- once a minute. Each panel gets a rate (Hz) from Settings > Theme > Panel Refresh; the row table
-- it builds is cached until the next tick is due. The watermark is deliberately absent from this
-- table -- its whole point is a live frame rate.
__panelkit.RATE = {
    pool_panel       = { "Pools Refresh",     30 },
    render_panel     = { "Render Refresh",    30 },
    coords_panel     = { "Coords Refresh",    30 },
    session_panel    = { "Session Refresh",    5 },
    protection_panel = { "Security Refresh",   5 },
    modders_panel    = { "Modders Refresh",    5 },
    hotkeys_panel    = { "Hotkeys Refresh",    5 },
}
function __panelkit.rate(name)
    local d = __panelkit.RATE[name]
    if not d then return 60 end
    local s = menu.get_setting(d[1])
    local v = (s and s.f_val) or d[2]
    if v < 1 then return 1 elseif v > 60 then return 60 end
    return v
end
-- Returns the cached row table while it is still fresh, or nil when the panel should rebuild.
function __panelkit.cached(name)
    local c = __panelkit.cbox[name]
    if not c then return nil end
    if (ctx.time() - c.t) >= (1.0 / __panelkit.rate(name)) then return nil end
    return c.rows
end
function __panelkit.cache(name, rows)
    __panelkit.cbox[name] = { t = ctx.time(), rows = rows }
    return rows
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
                if math.abs((r.x + r.w + k.GUTTER) - o.x) <= k.EPS then draw.line(o.x, y0, o.x, y1, ar, ag, ab, 255, 1)
                elseif math.abs((o.x + o.w + k.GUTTER) - r.x) <= k.EPS then draw.line(r.x, y0, r.x, y1, ar, ag, ab, 255, 1) end
            end
            if overlap(r.x, r.x + r.w, o.x, o.x + o.w) > 0 then
                local x0, x1 = math.max(r.x, o.x), math.min(r.x + r.w, o.x + o.w)
                if math.abs((r.y + r.h + k.GUTTER) - o.y) <= k.EPS then draw.line(x0, o.y, x1, o.y, ar, ag, ab, 255, 1)
                elseif math.abs((o.y + o.h + k.GUTTER) - r.y) <= k.EPS then draw.line(x0, r.y, x1, r.y, ar, ag, ab, 255, 1) end
            end
        end
    end
end

function __panelkit.move(name, dx, dy, bw, bh)
    local k = __panelkit
    k.nath[name] = bh                      -- record natural height for ALL callers
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
        -- Remember whether the press landed in the title band: a press there that never moves is a
        -- fold, not a drag. Anywhere else is drag-only, so folding can't fire from a body click.
        d.hdr = (my - pos.y) <= k.header_h() * k.scale()
    end
    if d.active and can and input.mouse_down(0) then
        local nx, ny = mx - d.gx, my - d.gy
        -- dock takes priority and is tested on the RAW cursor pos (not snapped) so it never fights
        -- the generic edge-snap; generic snap only runs when we're NOT docking into the rail grid.
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
            if d.moved then k.save()
            elseif d.hdr then                       -- a click on the title, not a drag -> fold
                k.folded[name] = not k.folded[name]
                k.save()
            end
            d.active = false; d.dtgt = nil; d.hdr = false
            if k.active == name then k.active = nil end
        end
        if k.dock[name] and name ~= k.ANCHOR then   -- docked + idle: glue to the computed grid cell
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

-- ── shared "card" chrome ──────────────────────────────────────────────────────────────────────
-- Compact chrome: flat square panels, neutral title bands, and a thin shared dock gutter.
-- ALL panel styling lives here -- edit once.
__panelkit.style = {
    tfont = font.overlay_heading or font.label, vfont = font.overlay_body or font.value, tspacing = 0,
    padx = 12, pady = 6, rgap = 4, colgap = 18, blk = 3,
    bg_top = { 16, 17, 21 }, bg_bot = { 16, 17, 21 }, bg_a = 255,
    header = { 27, 28, 34 }, border = { 58, 59, 68 },
    title_c = { 243, 244, 247 }, label_c = { 167, 172, 184 }, value_c = { 243, 244, 247 },
    track = { 45, 48, 58 }, divider_a = 100,
    radius = 0, element_radius = 0,
    good = { 92, 214, 145 }, warn = { 235, 182, 70 }, bad = { 245, 83, 91 },
    seg_h = 2,                                         -- continuous usage gauge
    warn_at = 0.70, bad_at = 0.90,
    spark_w = 34, spark_h = 8, spark_gap = 6, spark_n = 32,
    tri_w = 5, tri_h = 5, delta_gap = 5,
    sig_w = 11, sig_h = 8, sig_gap = 5,
    chev_w = 10,
}

function __panelkit.scale()
    local value = ctx.panel_scale and ctx.panel_scale() or 1.0
    if value < 0.5 then value = 0.5 elseif value > 2.0 then value = 2.0 end
    return value
end

-- header band height (y -> first row). Lazy: fonts may not be bound when this file first loads.
function __panelkit.header_h()
    local s = __panelkit.style
    return s.pady * 2 + math.max(text.height(s.tfont), text.height(s.vfont)) + 4
end
local function folded_h()
    local s = __panelkit.style
    return __panelkit.header_h() - 4
end

local function row_visible(row)
    local label = row and row[1]
    return row and (row.allow_empty or (type(label) == "string" and label:find("%S") ~= nil))
end

local function tone_of(frac)
    local s = __panelkit.style
    if frac >= s.bad_at then return s.bad end
    if frac >= s.warn_at then return s.warn end
    return s.good
end

-- Width the extras on a row need to the right of its value.
local function extra_w(r)
    local s = __panelkit.style
    local w = 0
    if r.spark  then w = w + s.spark_w + s.spark_gap end
    if r.signal then w = w + s.sig_w + s.sig_gap end
    if r.delta then
        local d = __panelkit.dval[r.dkey or ""] or 0
        if d ~= 0 then w = w + s.tri_w + 2 + text.width(s.vfont, tostring(math.abs(d))) + s.delta_gap end
    end
    return w
end

-- card width/height from rows ({label,value} pairs). opts.bar reserves a gauge row per row.
function __panelkit.card_size(title, rows, opts)
    local s = __panelkit.style
    local lh = text.height(s.vfont) + s.rgap
    local content = text.width_spaced(s.tfont, title, s.tspacing)
    if opts and opts.folded then
        -- Header-only: title, the digest that replaces the body, and the chevron.
        if opts.digest then
            content = content + s.colgap
                    + text.width(s.vfont, opts.digest[1] or "") + 4
                    + text.width(s.vfont, opts.digest[2] or "")
        end
        return content + s.padx * 2 + s.chev_w + 8, folded_h()
    end
    local visible = 0
    for _, r in ipairs(rows) do
        if row_visible(r) then
            visible = visible + 1
            local rw
            if r.section then
                rw = text.width(s.vfont, string.upper(r[1]))
            else
                local label_w = text.width(s.vfont, r[1]) + (r.keycap and 10 or 0)
                rw = label_w + s.colgap + text.width(s.vfont, r[2]) + extra_w(r)
            end
            if rw > content then content = rw end
        end
    end
    content = content + s.chev_w + 8                 -- room for the fold chevron in the title band
    local bw = content + s.padx * 2
    local body = visible > 0 and (visible * lh - s.rgap) or 0
    if opts and opts.bar then body = body + visible * (s.seg_h + 3) end
    return bw, __panelkit.header_h() + body + s.pady
end

-- draw.rect_gradient has square corners, so clip rounded end-caps over a square centre band.
local function rounded_gradient(x1, y1, x2, y2, top, bot, alpha, radius)
    local r = math.max(0, math.min(radius or 0, (y2 - y1) * 0.5, (x2 - x1) * 0.5))
    if r <= 0.5 then
        draw.rect_gradient(x1, y1, x2, y2,
            top[1], top[2], top[3], alpha, top[1], top[2], top[3], alpha,
            bot[1], bot[2], bot[3], alpha, bot[1], bot[2], bot[3], alpha)
        return
    end
    ui.push_clip(x1, y1, x2, y1 + r)
    draw.rect(x1, y1, x2, y1 + r * 2, top[1], top[2], top[3], alpha, r)
    ui.pop_clip()
    ui.push_clip(x1, y2 - r, x2, y2)
    draw.rect(x1, y2 - r * 2, x2, y2, bot[1], bot[2], bot[3], alpha, r)
    ui.pop_clip()
    draw.rect_gradient(x1, y1 + r, x2, y2 - r,
        top[1], top[2], top[3], alpha, top[1], top[2], top[3], alpha,
        bot[1], bot[2], bot[3], alpha, bot[1], bot[2], bot[3], alpha)
end

local function card_body(x, y, bw, bh)
    local s = __panelkit.style
    local ar, ag, ab = theme.accent()
    rounded_gradient(x, y, x + bw, y + bh, s.bg_top, s.bg_bot, s.bg_a, s.radius)
    draw.rect_outline(x, y, x + bw, y + bh,
        s.border[1], s.border[2], s.border[3], 255, 0, 1)
    return ar, ag, ab
end

-- fold chevron, drawn at the right of the title band
local function chevron(cx, cy, up, r, g, b, a)
    if up then
        draw.line(cx - 4, cy + 2, cx, cy - 2, r, g, b, a, 1.5)
        draw.line(cx, cy - 2, cx + 4, cy + 2, r, g, b, a, 1.5)
    else
        draw.line(cx - 4, cy - 2, cx, cy + 2, r, g, b, a, 1.5)
        draw.line(cx, cy + 2, cx + 4, cy - 2, r, g, b, a, 1.5)
    end
end

-- draw bg + header. returns content origin (cx, cy) and inner width.
function __panelkit.card_chrome(x, y, bw, bh, title, opts)
    local s = __panelkit.style
    local ar, ag, ab = card_body(x, y, bw, bh)
    local folded = opts and opts.folded
    local hh = folded_h()
    draw.rect(x + 1, y + 1, x + bw - 1, y + hh,
        s.header[1], s.header[2], s.header[3], 255)
    local ty = y + (hh - text.height(s.tfont)) * 0.5
    text.draw_spaced(s.tfont, x + s.padx, ty,
        s.title_c[1], s.title_c[2], s.title_c[3], 255, title, s.tspacing)

    local right = x + bw - s.padx
    if opts and opts.foldable then
        chevron(right - s.chev_w * 0.5, ty + text.height(s.tfont) * 0.5, not folded,
                s.title_c[1], s.title_c[2], s.title_c[3], 215)
        right = right - s.chev_w - 6
    end
    -- A folded panel keeps the one number that matters, so it still earns its pixels.
    if folded and opts.digest then
        local dy = y + (hh - text.height(s.vfont)) * 0.5
        local dv = tostring(opts.digest[2] or "")
        local vx = right - text.width(s.vfont, dv)
        text.draw(s.vfont, vx, dy, s.value_c[1], s.value_c[2], s.value_c[3], 255, dv)
        local dl = tostring(opts.digest[1] or "")
        if dl ~= "" then
            text.draw(s.vfont, vx - 4 - text.width(s.vfont, dl), dy,
                      s.label_c[1], s.label_c[2], s.label_c[3], 255, dl)
        end
    end
    if folded then return x + s.padx, y + folded_h(), bw - s.padx * 2 end

    local cy = y + __panelkit.header_h()
    return x + s.padx, cy, bw - s.padx * 2
end

-- ── row extras ────────────────────────────────────────────────────────────────────────────────
-- Inline sparkline: the trend renderer that already existed for the FPS strip, shrunk to sit
-- between a row's label and its value. Costs the panel no extra height.
local function draw_spark(x, y, w, h, hist, r, g, b)
    local n = #hist
    if n < 2 then return end
    local lo, hi = hist[1], hist[1]
    for i = 2, n do
        if hist[i] < lo then lo = hist[i] end
        if hist[i] > hi then hi = hist[i] end
    end
    local span = hi - lo
    if span < 1e-6 then span = 1 end
    local pad = span * 0.16
    lo, hi = lo - pad, hi + pad
    span = hi - lo
    local px, py
    for i = 1, n do
        local xx = x + ((i - 1) / (n - 1)) * w
        local yy = y + h - ((hist[i] - lo) / span) * h
        if px then draw.line(px, py, xx, yy, r, g, b, 225, 1.2) end
        px, py = xx, yy
    end
end

-- Delta triangle. Drawn from stacked hairlines rather than a glyph, because the panel font is
-- whatever the theme picked and cannot be relied on to carry an arrow.
local function triangle(x, y, w, h, up, r, g, b, a)
    local steps = math.max(3, math.floor(h))
    for i = 0, steps - 1 do
        local t = i / (steps - 1)
        local half = (up and (1 - t) or t) * w * 0.5
        local yy = y + (up and (h - i) or (i + 1))
        draw.line(x + w * 0.5 - half, yy, x + w * 0.5 + half, yy, r, g, b, a, 1.0)
    end
end

-- Four-bar signal glyph for a link-quality row.
local function signal(x, y, w, h, bars, r, g, b)
    local s = __panelkit.style
    local bw = (w - 3 * 1.5) / 4
    for i = 0, 3 do
        local bh = h * (0.28 + i * 0.24)
        local on = i < bars
        local xx = x + i * (bw + 1.5)
        if on then draw.rect(xx, y + h - bh, xx + bw, y + h, r, g, b, 255, 1)
        else       draw.rect(xx, y + h - bh, xx + bw, y + h, s.track[1], s.track[2], s.track[3], 235, 1) end
    end
end

function __panelkit.card_row(cx, cy, inner, label, value, value_color, keycap, r)
    local s = __panelkit.style
    local c = value_color or s.value_c
    local th = text.height(s.vfont)
    if label ~= "" then
        if keycap then
            local ar, ag, ab = theme.accent()
            local kw = text.width(s.vfont, label) + 10
            draw.rect(cx, cy - 1, cx + kw, cy + th + 1, s.track[1], s.track[2], s.track[3], 235, s.element_radius)
            draw.rect_outline(cx, cy - 1, cx + kw, cy + th + 1, ar, ag, ab, 145, s.element_radius, 1)
            text.draw(s.vfont, cx + 5, cy, ar, ag, ab, 255, label)
        else
            text.draw(s.vfont, cx, cy, s.label_c[1], s.label_c[2], s.label_c[3], 255, label)
        end
    end

    local right = cx + inner
    -- delta sits furthest right, so the value never jitters horizontally when it appears
    if r and r.delta then
        local d = __panelkit.dval[r.dkey or ""] or 0
        if d ~= 0 then
            local up = d > 0
            local col = up and s.good or s.bad
            local mag = tostring(math.abs(d))
            local mw = text.width(s.vfont, mag)
            text.draw(s.vfont, right - mw, cy, col[1], col[2], col[3], 255, mag)
            triangle(right - mw - 2 - s.tri_w, cy + (th - s.tri_h) * 0.5, s.tri_w, s.tri_h, up,
                     col[1], col[2], col[3], 255)
            right = right - mw - 2 - s.tri_w - s.delta_gap
        end
    end
    text.draw(s.vfont, right - text.width(s.vfont, value), cy, c[1], c[2], c[3], 255, value)
    right = right - text.width(s.vfont, value)

    if r and r.signal then
        local sg = r.signal
        local col = sg.tone or s.good
        right = right - s.sig_gap - s.sig_w
        signal(right, cy + (th - s.sig_h) * 0.5, s.sig_w, s.sig_h, sg.bars or 0, col[1], col[2], col[3])
    end
    if r and r.spark then
        local hist = __panelkit.hist[r.hkey or ""]
        if hist then
            local ar, ag, ab = theme.accent()
            right = right - s.spark_gap - s.spark_w
            draw_spark(right, cy + (th - s.spark_h) * 0.5, s.spark_w, s.spark_h, hist, ar, ag, ab)
        end
    end
    return cy + th + s.rgap
end

function __panelkit.card_section(cx, cy, inner, label, no_line)
    local s = __panelkit.style
    local ar, ag, ab = s.title_c[1], s.title_c[2], s.title_c[3]
    local title = string.upper(label)
    text.draw(s.vfont, cx, cy, ar, ag, ab, 255, title)
    local line_x = cx + text.width(s.vfont, title) + 8
    local line_y = cy + math.floor(text.height(s.vfont) * 0.5)
    if not no_line and line_x < cx + inner then draw.line(line_x, line_y, cx + inner, line_y, ar, ag, ab, s.divider_a, 1) end
    return cy + text.height(s.vfont) + s.rgap
end

-- Continuous usage gauge, coloured by proximity to the pool's capacity.
function __panelkit.card_bar(cx, cy, inner, label, value, frac, r)
    local s = __panelkit.style
    if frac < 0 then frac = 0 elseif frac > 1 then frac = 1 end
    local col = tone_of(frac)
    local th = text.height(s.vfont)
    if label ~= "" then text.draw(s.vfont, cx, cy, s.label_c[1], s.label_c[2], s.label_c[3], 255, label) end

    local right = cx + inner
    text.draw(s.vfont, right - text.width(s.vfont, value), cy, col[1], col[2], col[3], 255, value)
    right = right - text.width(s.vfont, value)
    if r and r.spark then
        local hist = __panelkit.hist[r.hkey or ""]
        if hist then
            local ar, ag, ab = theme.accent()
            right = right - s.spark_gap - s.spark_w
            draw_spark(right, cy + (th - s.spark_h) * 0.5, s.spark_w, s.spark_h, hist, ar, ag, ab)
        end
    end

    local by = cy + th + 2
    draw.rect(cx, by, cx + inner, by + s.seg_h, s.track[1], s.track[2], s.track[3], 255)
    if frac > 0 then
        draw.rect(cx, by, cx + inner * frac, by + s.seg_h, col[1], col[2], col[3], 255)
    end
    return cy + th + s.rgap + s.seg_h + 3
end

function __panelkit.card(name, def_x, def_y, title, rows, opts)
    local nat, bh = __panelkit.card_size(title, rows, opts)
    __panelkit.natw[name] = nat
    local bw = __panelkit.resolve_width(name, nat)
    local px, py = __panelkit.move(name, def_x, def_y, bw, bh)
    return __panelkit.card_chrome(px, py, bw, bh, title, opts)
end

-- Track the history + one-second delta a row asked for. Sampled at the panel's refresh rate, not
-- per frame, so a throttled panel's sparkline reflects what it actually sampled.
local function track(name, rows)
    local k, s = __panelkit, __panelkit.style
    local now = ctx.time()

    local hs = k.hslot[name]
    if not hs then hs = { t = -1 }; k.hslot[name] = hs end
    local hdue = (now - hs.t) >= (1.0 / k.rate(name))

    local ds = k.dslot[name]
    if not ds then ds = { t = now }; k.dslot[name] = ds end
    local ddue = (now - ds.t) >= 1.0

    for _, r in ipairs(rows) do
        if r.spark then
            r.hkey = name .. "\1" .. tostring(r[1])
            local h = k.hist[r.hkey]
            if not h then h = {}; k.hist[r.hkey] = h end
            if hdue then
                h[#h + 1] = r.spark
                while #h > s.spark_n do table.remove(h, 1) end
            end
        end
        if r.delta then
            r.dkey = name .. "\2" .. tostring(r[1])
            if ddue then
                local prev = k.dprev[r.dkey]
                k.dval[r.dkey] = prev and (r.delta - prev) or 0
                k.dprev[r.dkey] = r.delta
            end
        end
    end
    if hdue then hs.t = now end
    if ddue then ds.t = now end
end

-- All-in-one: size + position (drag/dock/snap/fold) + draw chrome AND every row. Use this from a
-- panel's on_draw instead of card()+card_row loop. rows = { {label, value}, ... }; opts.bar => each
-- row carries a usage fraction as rows[i][3]. opts.digest = {label, value} shown while folded.
function __panelkit.panel(name, def_x, def_y, title, rows, opts)
    opts = opts or {}
    opts.foldable = opts.foldable ~= false
    opts.folded = opts.foldable and __panelkit.folded[name] or false
    track(name, rows)

    local scale = __panelkit.scale()
    local nat, bh = __panelkit.card_size(title, rows, opts)
    local actual_nat = nat * scale
    __panelkit.natw[name] = actual_nat
    local actual_bw = __panelkit.resolve_width(name, actual_nat)
    local actual_bh = bh * scale
    local px, py = __panelkit.move(name, def_x, def_y, actual_bw, actual_bh)
    local bw = actual_bw / scale
    local ok, err = draw.with_scale(px, py, scale, function()
        local cx, cy, inner = __panelkit.card_chrome(px, py, bw, bh, title, opts)
        if opts.folded then return end
        if opts.bar then
            for _, r in ipairs(rows) do
                if row_visible(r) then cy = __panelkit.card_bar(cx, cy, inner, r[1], r[2], r[3] or 0, r) end
            end
        else
            for _, r in ipairs(rows) do
                if row_visible(r) then
                    if r.section then cy = __panelkit.card_section(cx, cy, inner, r[1], r.no_line)
                    else cy = __panelkit.card_row(cx, cy, inner, r[1], r[2], r.color, r.keycap, r) end
                end
            end
        end
    end)
    if not ok then error(err, 0) end
end

-- All-in-one horizontal strip (the performance watermark): chrome + a coloured token run.
-- toks = { {text, {r,g,b}}, ... }. Returns the final px,py used (for callers that care).
function __panelkit.info_strip(name, def_x, def_y, toks, fh, opts)
    local s = __panelkit.style
    local total = 0
    for _, t in ipairs(toks) do total = total + text.width(s.vfont, t[1]) end
    local graph = opts and opts.graph
    local graph_w = graph and (opts.graph_w or 108) or 0
    local graph_h = graph and (opts.graph_h or 20) or 0
    local graph_gap = graph and (opts.graph_gap or 12) or 0
    local nat_w = total + s.padx * 2 + graph_gap + graph_w
    local bh = math.max(fh, graph_h) + s.pady * 2
    local scale = __panelkit.scale()
    local actual_w = __panelkit.anchor_width(nat_w * scale)
    local px, py = __panelkit.move(name, def_x, def_y, actual_w, bh * scale)
    local bw = actual_w / scale
    local ok, err = draw.with_scale(px, py, scale, function()
    local cx, vy = __panelkit.strip_chrome(px, py, bw, bh, fh)
    for _, t in ipairs(toks) do local c = t[2]; text.draw(s.vfont, cx, vy, c[1], c[2], c[3], 255, t[1]); cx = cx + text.width(s.vfont, t[1]) end

    if graph then
        local gx = px + bw - s.padx - graph_w
        local gy = py + (bh - graph_h) * 0.5
        local ar, ag, ab = theme.accent()
        draw.line(gx, gy + graph_h * 0.5, gx + graph_w, gy + graph_h * 0.5,
            s.track[1], s.track[2], s.track[3], 180, 1)

        local count = #graph
        if count > 1 then
            local lo, hi = graph[1], graph[1]
            for i = 2, count do
                lo = math.min(lo, graph[i])
                hi = math.max(hi, graph[i])
            end
            local min_span = math.max(10, hi * 0.15)
            if hi - lo < min_span then
                local mid = (hi + lo) * 0.5
                lo = math.max(0, mid - min_span * 0.5)
                hi = lo + min_span
            else
                local pad = (hi - lo) * 0.1
                lo = math.max(0, lo - pad)
                hi = hi + pad
            end
            if hi <= lo then hi = lo + 1 end

            local last_x = gx
            local last_y = gy + graph_h - ((graph[1] - lo) / (hi - lo)) * graph_h
            for i = 2, count do
                local nx = gx + ((i - 1) / (count - 1)) * graph_w
                local ny = gy + graph_h - ((graph[i] - lo) / (hi - lo)) * graph_h
                draw.line(last_x, last_y, nx, ny, ar, ag, ab, 235, 1.5)
                last_x, last_y = nx, ny
            end
        end
    end
    end)
    if not ok then error(err, 0) end
    return px, py
end

-- horizontal strip chrome: same look, no title band. returns content x + centered text y.
function __panelkit.strip_chrome(x, y, bw, bh, fh)
    local s = __panelkit.style
    card_body(x, y, bw, bh)
    local yc = y + (bh - fh) * 0.5
    return x + s.padx, yc
end
