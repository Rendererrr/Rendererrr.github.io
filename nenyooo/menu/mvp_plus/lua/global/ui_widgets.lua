-- Click-GUI widget set: everything needed to render a menu page as multi-column group-box cards.
--
-- Two rules hold throughout:
--   1. Height is declared in `measure` and handed to `draw`. Nothing computes its own height while
--      drawing, so cards and balanced columns are possible at all.
--   2. Hit targets ARE the drawn rects. Themes used to draw a caret at a measured position but
--      hit-test `mouse_x > x + w * 0.5`, so the arrow the user aimed at was not the control. Every
--      sub-rect below is computed once and used for both the paint and the click.
--
-- Rows bind to a menu item by its registry HASH, never by handle or index: handles are registry
-- indices and the registry is rebuilt on every reindex (theme load, catalog change, search submit),
-- so a captured handle silently starts pointing at a different row. The hash is stable, and
-- items.get(hash) is a binary search.

-- ── binding helpers ──────────────────────────────────────────────────────────

local function resolve(node)
    local h = items.get(node.hash)
    if not h then return nil, nil end
    return h, items.at(h)
end

local function text_col(sk, it, hov)
    if it and it.disabled then return sk.col.disabled end
    return hov and sk.col.txt or sk.col.txt_dim
end

-- Widgets report the row under the cursor here, so a theme can draw a description bar without
-- threading a "hovered index" out of the draw pass by side effect (which only worked as long as the
-- bar happened to be drawn after the list).
function ui.hovered_item()
    return ui._hover_hash
end

local function mark_hover(n, hov)
    if hov then ui._hover_hash = n.hash end
    return hov
end

-- Register the row in the keyboard ring and report whether it currently holds focus. Mouse hover
-- also takes focus, so pointer and keyboard never disagree about which row is "current".
local function mark(n, hov, x, y, w, h)
    if hov then
        ui._hover_hash = n.hash
        ui._focus_hash = n.hash
        ui._focus_kbd = false     -- pointing at a row is its own feedback; no ring needed
    end
    local foc = ui.focusable(n.hash, x, y, w, h) and ui._focus_kbd
    return hov, foc
end

local function focus_ring(foc, x, y, w, h, sk)
    if not foc then return end
    local a = sk.col.acc
    draw.rect_outline(x - 2, y - 1, x + w + 2, y + h + 1, a[1], a[2], a[3], 220,
                      sk.focus_radius or 8, 1)
end

-- Activate a row exactly as pressing Enter on it does.
--
-- ONE path: items.activate(handle) -> menu::activate(item, page_index, hash) in C++, which is the
-- same function activate_item() calls. Named actions, Stand targets, edition guards, toggle side
-- effects and the popups all come from there, for any row on any page.
--
-- Deliberately no Lua-side fallback: shimming this by hijacking the selection made behaviour depend
-- on which build was running and left two paths that could drift.
function ui.activate(handle)
    items.activate(handle)
end

local function label_of(it)
    return (it and it.name) or ""
end

-- Vertically centred baseline for a line of text in a row of height h.
local function ty(y, h, f)
    return y + (h - text.height(f)) * 0.5
end

local function fill(x1, y1, x2, y2, c, r)
    draw.rect(x1, y1, x2, y2, c[1], c[2], c[3], c[4] or 255, r or 0)
end

-- Vertical gradient with rounded corners. draw.rect_gradient has no rounding parameter, so paint a
-- rounded cap at each end in that end's colour and run the square gradient between them; the seams
-- land exactly where the gradient already equals the cap colour, so they are invisible.
local function fill_grad(x1, y1, x2, y2, ctop, cbot, r, square_bottom)
    r = math.max(0, math.min(r or 0, (y2 - y1) * 0.5, (x2 - x1) * 0.5))
    if r <= 0.5 then
        draw.rect_gradient(x1, y1, x2, y2,
            ctop[1], ctop[2], ctop[3], ctop[4] or 255, ctop[1], ctop[2], ctop[3], ctop[4] or 255,
            cbot[1], cbot[2], cbot[3], cbot[4] or 255, cbot[1], cbot[2], cbot[3], cbot[4] or 255)
        return
    end
    -- Each cap is CLIPPED to its own r-tall band. Without the clip the caps (2r tall, so their corners
    -- can round) overlap the gradient, and with a translucent fill that band composites twice and comes
    -- out roughly double-dark -- a black bar across the top of every card, right where the title sits.
    ui.push_clip(x1, y1, x2, y1 + r)
    draw.rect(x1, y1, x2, y1 + r * 2, ctop[1], ctop[2], ctop[3], ctop[4] or 255, r)
    ui.pop_clip()
    if square_bottom then
        draw.rect(x1, y2 - r, x2, y2, cbot[1], cbot[2], cbot[3], cbot[4] or 255, 0)
    else
        ui.push_clip(x1, y2 - r, x2, y2)
        draw.rect(x1, y2 - r * 2, x2, y2, cbot[1], cbot[2], cbot[3], cbot[4] or 255, r)
        ui.pop_clip()
    end
    draw.rect_gradient(x1, y1 + r, x2, y2 - r,
        ctop[1], ctop[2], ctop[3], ctop[4] or 255, ctop[1], ctop[2], ctop[3], ctop[4] or 255,
        cbot[1], cbot[2], cbot[3], cbot[4] or 255, cbot[1], cbot[2], cbot[3], cbot[4] or 255)
end

local function stroke(x1, y1, x2, y2, c, r, t)
    draw.rect_outline(x1, y1, x2, y2, c[1], c[2], c[3], c[4] or 255, r or 0, t or 1)
end

ui._fill_grad = fill_grad   -- ui.lua's columns container paints its panel with this

-- ── card (group box) ─────────────────────────────────────────────────────────
-- The container the whole exercise is for: a titled box whose height is the sum of its children.
-- Previously these existed only for pages named in a hardcoded table, and everything else fell back
-- to slicing a flat list in half.

ui.widget("card", {
    measure = function(n, w, sk)
        local head = (n.title and n.title ~= "") and sk.card_head or sk.card_pad
        local inner = w - sk.card_pad * 2
        local body, first = 0, true
        for _, c in ipairs(n.kids) do
            if not first then body = body + sk.gap end
            body = body + ui.measure(c, inner, sk)
            first = false
        end
        return head + body + sk.card_bot
    end,
    draw = function(n, x, y, w, h, sk)
        local hov = ui.hovered(x, y, x + w, y + h)
        local base = hov and sk.col.card_hover or sk.col.card
        local bot = hov and (sk.col.card_hover_bot or sk.col.card_bot_col) or sk.col.card_bot_col
        local sq = sk.card_square_bottom
        local cr = sk.card_radius or sk.radius
        if ui._panel_active then
            bot = nil            -- the column's panel is the surface; a second fill would double-tint
            base = nil
        end
        if base and bot then
            fill_grad(x, y, x + w, y + h, base, bot, cr, sq)
        elseif base then
            fill(x, y, x + w, y + h, base, cr)
        end

        -- Border: rounded across the top, square down the sides and along the bottom. draw.rect can
        -- only round all four corners, so the top curve is a rounded outline clipped to its own band
        -- and the rest is drawn as three straight edges.
        local bdr = sk.col.card_bdr
        local g = sk.card_glow or 0
        for i = g, 1, -1 do
            local t = i / (g + 1)
            local av = math.floor((bdr[4] or 255) * (1 - t) * (1 - t))
            if av > 1 then
                local c = { bdr[1], bdr[2], bdr[3], av }
                stroke(x - i, y - i, x + w + i, y + h + i, c, sk.radius + i, 1)
                if i * 2 < w and i * 2 < h then
                    stroke(x + i, y + i, x + w - i, y + h - i, c, math.max(0, sk.radius - i), 1)
                end
            end
        end
        if sq then
            local r = cr
            ui.push_clip(x - 1, y - 1, x + w + 1, y + r)
            stroke(x, y, x + w, y + r * 2, bdr, r, 1)
            ui.pop_clip()
            draw.line(x, y + r, x, y + h, bdr[1], bdr[2], bdr[3], bdr[4] or 255, 1)
            draw.line(x + w, y + r, x + w, y + h, bdr[1], bdr[2], bdr[3], bdr[4] or 255, 1)
            -- The bottom edge is optional. A card whose fill fades toward transparent has nothing to
            -- close off, and drawing it puts a dark horizontal line across the card -- very visible
            -- against the bright lower background, and the reference has none.
            if sk.card_bottom_edge ~= false then
                draw.line(x, y + h, x + w, y + h, bdr[1], bdr[2], bdr[3], bdr[4] or 255, 1)
            end
        else
            stroke(x, y, x + w, y + h, bdr, cr, 1)
        end

        local cy = y
        if n.title and n.title ~= "" then
            -- The title band is a DARK slab, not part of the body gradient: measured down a card at
            -- the top of the window it reads #020202 against a body that is much lighter. Rounded on
            -- its top corners only -- clip a 2r-tall rounded rect to its top half, then square below.
            local tb = sk.col.card_title_bg
            if tb then
                local rr = math.min(sk.card_radius or sk.radius, sk.card_head * 0.5)
                ui.push_clip(x, y, x + w, y + rr)
                draw.rect(x, y, x + w, y + rr * 2, tb[1], tb[2], tb[3], tb[4] or 255, rr)
                ui.pop_clip()
                draw.rect(x, y + rr, x + w, y + sk.card_head, tb[1], tb[2], tb[3], tb[4] or 255, 0)
            end
            local f = sk.font.card
            if sk.card_top_edge then
                local a = sk.col.acc
                draw.line(x + sk.radius, y + 1, x + w - sk.radius, y + 1, a[1], a[2], a[3], 150, 1)
            end
            text.draw_centered(f, x, ty(y, sk.card_head, f), x + w,
                               sk.col.txt[1], sk.col.txt[2], sk.col.txt[3], 255, n.title)

            -- A card expands a submenu inline, which otherwise makes that page unreachable: you can
            -- never navigate INTO Load Theme, a catalog, or a Stand tree, and anything those pages
            -- need on entry (their tick_fn, a rescan) never runs. The title bar doubles as the way in.
            -- The whole title bar is the way in. The chevron only appears while the card is hovered:
            -- drawn always, it puts a mark on every single card that the reference does not have.
            if n.page_id and n.page_id ~= 0 then
                local bh = sk.card_head
                local over = ui.hovered(x, y, x + w, y + bh)
                if over then
                    local bw = 24
                    local cx2, cy2 = x + w - bw * 0.5 - 6, y + bh * 0.5
                    local c = sk.col.txt
                    draw.line(cx2 - 3, cy2 - 5, cx2 + 3, cy2, c[1], c[2], c[3], 200, 1.6)
                    draw.line(cx2 + 3, cy2, cx2 - 3, cy2 + 5, c[1], c[2], c[3], 200, 1.6)
                end
                if ui.clicked(x, y, x + w, y + bh, 0) then
                    if n.enter_handle then ui.activate(n.enter_handle)
                    else menu.navigate(n.page_id) end
                end
            end
            if sk.card_rule ~= false then
                local d = sk.col.div
                local dy = y + sk.card_head - (sk.card_rule_lift or 14)
                draw.line(x + 8, dy, x + w - 8, dy, d[1], d[2], d[3], d[4] or 90)
            end
            cy = y + sk.card_head
        else
            cy = y + sk.card_pad
        end

        local inner = w - sk.card_pad * 2
        for _, c in ipairs(n.kids) do
            cy = cy + ui.draw(c, x + sk.card_pad, cy, inner, sk) + sk.gap
        end
    end,
})
function ui.card(t) t.kind = "card"; t.kids = {}; for i = 1, #t do if t[i] then t.kids[#t.kids + 1] = t[i] end end; return t end

-- ── section label ────────────────────────────────────────────────────────────

ui.widget("section_label", {
    measure = function(n, w, sk) return sk.row_h * 0.8 end,
    draw = function(n, x, y, w, h, sk)
        local f = sk.font.small
        text.draw(f, x, ty(y, h, f), sk.col.txt_off[1], sk.col.txt_off[2], sk.col.txt_off[3], 255,
                  n.text or label_of(select(2, resolve(n))))
    end,
})

-- ── toggle pill ──────────────────────────────────────────────────────────────

ui.widget("toggle_pill", {
    measure = function(n, w, sk) return sk.row_h end,
    draw = function(n, x, y, w, h, sk)
        local handle, it = resolve(n)
        if not it then return end
        local hov, foc = mark(n, ui.hovered(x, y, x + w, y + h), x, y, w, h)
        focus_ring(foc, x, y, w, h, sk)
        -- items.activate, not items.toggle: activate is the same path Enter takes, so the toggle's
        -- side effects (Scripts-tab enable/disable, DLC pack auto-load, the notification) actually run.
        if hov and not it.disabled and ui.clicked(x, y, x + w, y + h, 0) then ui.activate(handle) end

        local st = ui.state(n.id)
        st.k = st.k or (it.on and 1 or 0)
        st.k = st.k + ((it.on and 1 or 0) - st.k) * math.min(1, ctx.delta() * 16)

        local lead
        if sk.toggle_style == "circle" then
            -- Filled disc when on, hollow well when off.
            local r = sk.toggle_r or 9
            local cx, cy = x + r, y + h * 0.5
            local off = sk.col.toggle_off
            draw.circle(cx, cy, r, off[1], off[2], off[3], 255)
            if st.k > 0.02 then
                local a = sk.col.acc
                draw.circle(cx, cy, r * (0.55 + 0.45 * st.k), a[1], a[2], a[3],
                            math.floor(255 * st.k))
            end
            lead = r * 2
        else
            local tw, th = sk.toggle_w, sk.toggle_h
            local tyy = y + (h - th) * 0.5
            local base = it.on and sk.col.acc or sk.col.toggle_off
            fill(x, tyy, x + tw, tyy + th, base, th * 0.5)
            local r = sk.toggle_knob
            local kx = x + r + 3 + (tw - (r + 3) * 2) * st.k
            draw.circle(kx, tyy + th * 0.5, r, sk.col.knob[1], sk.col.knob[2], sk.col.knob[3], 255)
            lead = tw
        end

        local f = sk.font.label
        local c = text_col(sk, it, hov)
        text.draw_ellipsis(f, x + lead + 10, ty(y, h, f), c[1], c[2], c[3], 255,
                           label_of(it), w - lead - 14)
    end,
})

-- ── pill button ──────────────────────────────────────────────────────────────

ui.widget("pill_button", {
    measure = function(n, w, sk) return sk.btn_h end,
    draw = function(n, x, y, w, h, sk)
        local handle, it = resolve(n)
        if not it then return end
        local f0 = sk.font.btn or sk.font.label
        local hw = w
        if sk.btn_fit then
            hw = math.min(w, text.width(f0, label_of(it)) + (sk.btn_pad or 10) * 2)
        end
        local hov, foc = mark(n, ui.hovered(x, y, x + hw, y + h), x, y, hw, h)
        focus_ring(foc, x, y, hw, h, sk)
        if hov and not it.disabled and ui.clicked(x, y, x + hw, y + h, 0) then ui.activate(handle) end

        local f = sk.font.btn or sk.font.label
        local pad = sk.btn_pad or 10
        -- btn_fit: size the chip to its text instead of the full row. The reference GUI does this --
        -- "Set LSCM Level" and "Unlock Car Meet Rewards" are visibly different widths -- and a row of
        -- identical full-width bars reads as a completely different control.
        local bw = w
        if sk.btn_fit then
            bw = math.min(w, text.width(f, label_of(it)) + pad * 2)
        end
        local r = math.min(sk.btn_radius or sk.pill_radius, h * 0.5)
        fill(x, y, x + bw, y + h, hov and sk.col.pill_hover or sk.col.pill, r)
        local c = it.disabled and sk.col.disabled or sk.col.txt
        text.draw_ellipsis(f, x + pad, ty(y, h, f), c[1], c[2], c[3], 255, label_of(it), bw - pad * 2)
    end,
})

-- ── slider ───────────────────────────────────────────────────────────────────
-- The track is declared in the height, so a slider is simply taller than a plain row -- no "extra"
-- returned from the draw call for the container to discover after the fact.

ui.widget("slider", {
    measure = function(n, w, sk) return sk.row_h + sk.track_h + 6 end,
    draw = function(n, x, y, w, h, sk)
        local handle, it = resolve(n)
        if not it then return end
        local row = sk.row_h
        local hov, foc = mark(n, ui.hovered(x, y, x + w, y + row), x, y, w, row)
        focus_ring(foc, x, y, w, row, sk)
        local f, fv = sk.font.label, sk.font.value
        local c = text_col(sk, it, hov)
        text.draw(f, x, ty(y, row, f), c[1], c[2], c[3], 255, label_of(it))
        local vs = string.format("%.2f", it.f_val or 0)
        text.draw(fv, x + w - text.width(fv, vs), ty(y, row, fv),
                  sk.col.acc[1], sk.col.acc[2], sk.col.acc[3], 255, vs)

        local tyy = y + row + 2
        local mn, mx = it.f_min or 0, it.f_max or 1
        local span = (mx > mn) and (mx - mn) or 1
        local frac = math.max(0, math.min(1, ((it.f_val or 0) - mn) / span))
        fill(x, tyy, x + w, tyy + sk.track_h, sk.col.track, sk.track_h * 0.5)
        fill(x, tyy, x + w * frac, tyy + sk.track_h, sk.col.acc, sk.track_h * 0.5)
        draw.circle(x + w * frac, tyy + sk.track_h * 0.5, sk.knob_r,
                    sk.col.knob[1], sk.col.knob[2], sk.col.knob[3], 255)

        -- Grab is clip-tested (ui.clicked), so a slider scrolled out of its container cannot start a
        -- drag -- the bug that made off-screen sliders steal clicks. Capture then keeps the drag alive
        -- while the cursor wanders off the track.
        local grab_y1, grab_y2 = tyy - 6, tyy + sk.track_h + 6
        if ui.clicked(x, grab_y1, x + w, grab_y2, 0) then ui.capture(n.id, 0) end
        if ui.captured() == n.id then
            local t = math.max(0, math.min(1, (input.mouse_x() - x) / math.max(1, w)))
            items.set_f_val(handle, mn + t * span)
        end
    end,
})

-- ── int stepper (value field with round -/+ buttons) ─────────────────────────

ui.widget("stepper", {
    measure = function(n, w, sk) return sk.row_h + sk.stepper_btn + 6 end,
    draw = function(n, x, y, w, h, sk)
        local handle, it = resolve(n)
        if not it then return end
        local _h, foc = mark(n, ui.hovered(x, y, x + w, y + h), x, y, w, h)
        focus_ring(foc, x, y, w, h, sk)
        local f, fv = sk.font.label, sk.font.value
        text.draw(f, x, ty(y, sk.row_h, f), sk.col.txt_dim[1], sk.col.txt_dim[2], sk.col.txt_dim[3], 255,
                  label_of(it))

        local b = sk.stepper_btn
        local by = y + sk.row_h + 2
        local fw = w - (b + sk.gap) * 2
        -- Field
        fill(x, by, x + fw, by + b, sk.col.field, 6)
        stroke(x, by, x + fw, by + b, sk.col.field_bdr, 6, 1)

        local editing = ui.focused() == n.id
        local shown
        if editing then
            local s, _, status = ui.text_edit(n.id)
            shown = s
            if status == 1 then items.set_i_val(handle, math.floor(tonumber(s) or it.i_val or 0)) end
        else
            shown = tostring(it.i_val or 0)
        end
        ui.push_clip(x + 4, by, x + fw - 4, by + b)
        text.draw(fv, x + 6, ty(by, b, fv), sk.col.txt[1], sk.col.txt[2], sk.col.txt[3], 255,
                  editing and (shown .. ((math.floor(ctx.time() * 2) % 2 == 0) and "|" or "")) or shown)
        ui.pop_clip()
        if ui.clicked(x, by, x + fw, by + b, 0) then
            ui.focus(n.id, tostring(it.i_val or 0), text_flag.numeric)
        end

        -- The two round buttons ARE the hit rects: same centre, same radius, both ways.
        local step = (it.i_step and it.i_step ~= 0) and it.i_step or 1
        local mx1 = x + fw + sk.gap
        local px1 = mx1 + b + sk.gap
        local function round_btn(bx, sign, glyph)
            local hov = ui.hovered(bx, by, bx + b, by + b)
            fill(bx, by, bx + b, by + b, hov and sk.col.pill_hover or sk.col.pill, b * 0.5)
            local g = sk.font.value
            text.draw_centered(g, bx, ty(by, b, g), bx + b, sk.col.txt[1], sk.col.txt[2], sk.col.txt[3], 255, glyph)
            if ui.clicked(bx, by, bx + b, by + b, 0) then
                items.set_i_val(handle, (it.i_val or 0) + sign * step)
            end
        end
        round_btn(mx1, -1, "-")
        round_btn(px1, 1, "+")
    end,
})

-- ── combo (dropdown) ─────────────────────────────────────────────────────────
-- The body is queued with ui.defer, so it draws after everything, outside every container clip, and
-- takes input priority via its layer. No stashing the rect in globals and redrawing it by hand at the
-- bottom of draw_menu, and no "ignore the click that opened me" frame guard.

ui.widget("combo", {
    measure = function(n, w, sk) return sk.row_h end,
    draw = function(n, x, y, w, h, sk)
        local handle, it = resolve(n)
        if not it then return end
        local st = ui.state(n.id)

        -- Box on the left, row label to its right (the reference layout: "[Jackpot v] Override Wheel 1").
        local bw = math.floor(w * (sk.combo_frac or 0.52))
        local hov, foc = mark(n, ui.hovered(x, y, x + bw, y + h), x, y, bw, h)
        focus_ring(foc, x, y, bw, h, sk)
        local base = hov and (sk.col.combo_hover or sk.col.pill_hover) or (sk.col.combo or sk.col.field)
        fill(x, y, x + bw, y + h, base, sk.combo_radius or 6)
        if sk.col.combo_bdr then stroke(x, y, x + bw, y + h, sk.col.combo_bdr, sk.combo_radius or 6, 1) end

        local f = sk.font.value
        local cv = it.current_value or ""
        text.draw_ellipsis(f, x + 8, ty(y, h, f), sk.col.txt[1], sk.col.txt[2], sk.col.txt[3], 255,
                           cv, bw - 8 - sk.caret_w - 12)
        -- caret glyph, drawn from the same numbers the box's hit rect uses
        local cx, cy2 = x + bw - sk.caret_w - 8, y + h * 0.5 - 1
        local cc = sk.col.txt_dim
        draw.line(cx, cy2, cx + sk.caret_w * 0.5, cy2 + 4, cc[1], cc[2], cc[3], 255, 1.4)
        draw.line(cx + sk.caret_w * 0.5, cy2 + 4, cx + sk.caret_w, cy2, cc[1], cc[2], cc[3], 255, 1.4)

        local lf = sk.font.label
        local lc = text_col(sk, it, hov)
        text.draw_ellipsis(lf, x + bw + 10, ty(y, h, lf), lc[1], lc[2], lc[3], 255,
                           label_of(it), w - bw - 12)

        if ui.clicked(x, y, x + bw, y + h, 0) then st.open = not st.open end
        if not st.open then return end

        local vals = items.values(handle) or {}
        local rows = math.min(#vals, 10)
        local bh = rows * sk.row_h + 6
        local bx, by = ui.popup_place(x, y, y + h, bw, bh)
        ui.defer(100, function()
            fill(bx, by, bx + bw, by + bh, sk.col.panel, 8)
            stroke(bx, by, bx + bw, by + bh, sk.col.acc, 8, 1)
            ui.push_clip(bx, by, bx + bw, by + bh)
            for i = 1, rows do
                local ry = by + 3 + (i - 1) * sk.row_h
                local rh = sk.row_h
                if ui.hovered(bx, ry, bx + bw, ry + rh) then
                    fill(bx + 2, ry, bx + bw - 2, ry + rh, sk.col.pill, 5)
                end
                local sel = (i - 1) == (it.value_index or 0)
                local c = sel and sk.col.acc or sk.col.txt_dim
                text.draw_ellipsis(f, bx + 8, ty(ry, rh, f), c[1], c[2], c[3], 255, vals[i], bw - 16)
                if ui.clicked(bx, ry, bx + bw, ry + rh, 0) then
                    items.set_value_index(handle, i - 1)
                    st.open = false
                end
            end
            ui.pop_clip()
            -- Click anywhere else closes. Safe to test here because the body has already consumed any
            -- click that landed inside it -- no "ignore the click that opened me" frame guard needed.
            if ui.click_available(0) and input.mouse_clicked(0) then st.open = false end
        end)
    end,
})

-- ── colour swatch ────────────────────────────────────────────────────────────

ui.widget("swatch", {
    measure = function(n, w, sk) return sk.row_h end,
    draw = function(n, x, y, w, h, sk)
        local handle, it = resolve(n)
        if not it then return end
        local hov, foc = mark(n, ui.hovered(x, y, x + w, y + h), x, y, w, h)
        focus_ring(foc, x, y, w, h, sk)
        local f = sk.font.label
        local c = text_col(sk, it, hov)
        text.draw_ellipsis(f, x, ty(y, h, f), c[1], c[2], c[3], 255, label_of(it), w - sk.swatch_w - 12)
        local sx = x + w - sk.swatch_w
        local sy, sh2 = y + 4, h - 8
        draw.rect(sx, sy, sx + sk.swatch_w, sy + sh2, it.r or 255, it.g or 255, it.b or 255, it.a or 255, 4)
        stroke(sx, sy, sx + sk.swatch_w, sy + sh2, sk.col.field_bdr, 4, 1)
        if ui.clicked(x, y, x + w, y + h, 0) then items.begin_color_edit(handle) end
    end,
})

-- ── text field ───────────────────────────────────────────────────────────────

-- Label above, field below -- the same shape as the stepper, so a card of mixed value rows lines up.
ui.widget("text_field", {
    measure = function(n, w, sk) return sk.row_h + sk.stepper_btn + 6 end,
    draw = function(n, x, y, w, h, sk)
        local handle, it = resolve(n)
        if not it then return end
        local lf = sk.font.label
        text.draw_ellipsis(lf, x, ty(y, sk.row_h, lf),
                           sk.col.txt_dim[1], sk.col.txt_dim[2], sk.col.txt_dim[3], 255,
                           label_of(it), w)

        local fh = sk.stepper_btn
        local fy = y + sk.row_h + 2
        local editing = ui.focused() == n.id
        fill(x, fy, x + w, fy + fh, sk.col.field, 6)
        stroke(x, fy, x + w, fy + fh, editing and sk.col.acc or sk.col.field_bdr, 6, 1)

        local f = sk.font.value
        local shown, status
        if editing then
            shown, _, status = ui.text_edit(n.id)
            if status == 1 then items.set_text(handle, shown, true) end
        else
            shown = (it.text ~= "" and it.text) or it.empty_value or ""
        end

        ui.push_clip(x + 4, fy, x + w - 4, fy + fh)
        local c = (it.text == "" and not editing) and sk.col.txt_off or sk.col.txt
        text.draw(f, x + 8, ty(fy, fh, f), c[1], c[2], c[3], 255, shown)
        if editing then
            -- Real caret: measure the bytes before it rather than parking a bar at the end.
            local cw = text.width(f, string.sub(shown, 1, ui.caret()))
            if math.floor(ctx.time() * 2) % 2 == 0 then
                draw.line(x + 8 + cw, fy + 4, x + 8 + cw, fy + fh - 4,
                          sk.col.txt[1], sk.col.txt[2], sk.col.txt[3], 255, 1)
            end
        end
        ui.pop_clip()

        if ui.clicked(x, fy, x + w, fy + fh, 0) then ui.focus(n.id, it.text or "", 0) end
    end,
})

-- ── type -> widget binding ───────────────────────────────────────────────────

ui.binding = {
    [item_type.toggle]        = "toggle_pill",
    [item_type.float_toggle]  = "toggle_pill",
    [item_type.int_toggle]    = "toggle_pill",
    [item_type.array_toggle]  = "toggle_pill",
    [item_type.loop_toggle]   = "toggle_pill",
    [item_type.action]        = "pill_button",
    [item_type.selected_tick] = "pill_button",
    [item_type.sub_menu]      = "pill_button",
    [item_type.slider]        = "slider",
    [item_type.int_option]    = "stepper",
    [item_type.input_int]     = "stepper",
    [item_type.input_float]   = "stepper",
    [item_type.array_option]  = "combo",
    [item_type.loop_option]   = "combo",
    [item_type.color]         = "swatch",
    [item_type.input_text]    = "text_field",
    [item_type.search]        = "text_field",
}

-- Build a node for one item handle. Captures the HASH (see the file header) and derives a stable
-- capture/focus id from it.
function ui.bind(handle)
    local it = items.at(handle)
    if not it then return nil end
    local kind = it.is_header and "section_label" or ui.binding[it.type]
    if not kind then return nil end
    local hash = items.hash_of(handle)
    return { kind = kind, hash = hash, id = ui.id("w", hash), text = it.is_header and it.name or nil }
end

-- Bind a list of handles, pairing consecutive buttons two-per-row. That pairing used to be a
-- look-ahead with `goto` inside a while loop in every theme; here it is a row with two weights.
function ui.bind_all(handles, opts)
    opts = opts or {}
    local out, i = {}, 1
    local pair = opts.pair_buttons ~= false
    while i <= #handles do
        local a = ui.bind(handles[i])
        if a and pair and a.kind == "pill_button" and i < #handles then
            local b = ui.bind(handles[i + 1])
            if b and b.kind == "pill_button" then
                out[#out + 1] = ui.row{ weights = { 1, 1 }, a, b }
                i = i + 2
                goto continue
            end
        end
        if a then out[#out + 1] = a end
        i = i + 1
        ::continue::
    end
    return out
end

-- Turn the current page into a list of cards: every submenu row becomes a card of that page's items,
-- and the loose rows collect into typed cards.
--
-- The submenu's page is resolved by ROUTING ID (items.submenu_page_id), not by feeding its display
-- name back into a name-keyed lookup -- display names are translated, so the name round-trip returns
-- an empty list under every non-English pack.
function ui.cards_for_page(opts)
    opts = opts or {}
    local cards, loose = {}, {}
    for i = 0, menu.item_count() - 1 do
        local h = menu.handle_at(i)          -- m_order/layout aware: the row actually shown at i
        if h and h >= 0 then
            local it = items.at(h)
            if it then
                if it.type == item_type.sub_menu and not opts.flat then
                    local pid = items.submenu_page_id(h)
                    local kids = pid ~= 0 and items.page_items(pid) or {}
                    if #kids > 0 then
                        -- page_id/enter_handle give the card an "open the real page" affordance;
                        -- enter_handle activates the submenu ROW so its tick_fn still fires.
                        local card = ui.card{ title = it.name, page_id = pid,
                                              enter_handle = h }
                        card.kids = ui.bind_all(kids, opts)
                        cards[#cards + 1] = card
                    else
                        loose[#loose + 1] = h        -- empty page: keep it as a button
                    end
                else
                    loose[#loose + 1] = h
                end
            end
        end
    end
    if #loose > 0 then
        local card = ui.card{ title = opts.loose_title or menu.page_name() }
        card.kids = ui.bind_all(loose, opts)
        table.insert(cards, 1, card)
    end
    -- Never hand back an empty list. Plenty of pages are filled at runtime by their tick_fn (the ped
    -- and vehicle catalogs, Stand script trees), so the first frames after navigating into one have no
    -- rows at all -- and a card grid with nothing in it is an empty window the user cannot tell from a
    -- broken one.
    if #cards == 0 then
        local card = ui.card{ title = menu.page_name() }
        card.kids = { ui.fixed(28, function(x, y, w, h, sk)
            local f = sk.font.small
            text.draw_centered(f, x, y + (h - text.height(f)) * 0.5, x + w,
                               sk.col.txt_off[1], sk.col.txt_off[2], sk.col.txt_off[3], 255,
                               (opts and opts.empty_text) or "Loading...")
        end) }
        cards[1] = card
    end
    return cards
end

-- Variant of cards_for_page that additionally buckets the page's LOOSE rows by control type
-- ("Toggles" / "Options" / "Actions" / "Colours") instead of putting them all in one card. Good for
-- a masonry grid, where several small cards balance far better than one tall one.
local BUCKET = {
    [item_type.toggle] = "Toggles", [item_type.float_toggle] = "Toggles",
    [item_type.int_toggle] = "Toggles", [item_type.array_toggle] = "Toggles",
    [item_type.loop_toggle] = "Toggles",
    [item_type.action] = "Actions", [item_type.selected_tick] = "Actions",
    [item_type.color] = "Colours",
}
local BUCKET_ORDER = { "Toggles", "Options", "Actions", "Colours" }

function ui.cards_bucketed()
    local subs, buckets = {}, { Toggles = {}, Options = {}, Actions = {}, Colours = {} }
    for i = 0, menu.item_count() - 1 do
        local h = menu.handle_at(i)
        if h and h >= 0 then
            local it = items.at(h)
            if it then
                local pid = (it.type == item_type.sub_menu) and items.submenu_page_id(h) or 0
                local kids = pid ~= 0 and items.page_items(pid) or nil
                if kids and #kids > 0 then
                    subs[#subs + 1] = { title = it.name, list = kids, pid = pid, h = h }
                else
                    local b = buckets[BUCKET[it.type] or "Options"]
                    b[#b + 1] = h
                end
            end
        end
    end
    local cards = {}
    for _, nm in ipairs(BUCKET_ORDER) do
        if #buckets[nm] > 0 then
            local card = ui.card{ title = nm }
            card.kids = ui.bind_all(buckets[nm])
            cards[#cards + 1] = card
        end
    end
    for _, s in ipairs(subs) do
        local card = ui.card{ title = s.title, page_id = s.pid, enter_handle = s.h }
        card.kids = ui.bind_all(s.list)
        cards[#cards + 1] = card
    end
    return cards
end

-- Search results as cards, grouped by the page each hit belongs to. Uses page_id for grouping (not
-- the display name) so grouping is identical under any language pack.
function ui.cards_for_search(query)
    if not query or query == "" then return {} end
    local hits = items.search(query) or {}
    local order, by_page = {}, {}
    for _, h in ipairs(hits) do
        local it = items.at(h)
        if it then
            local pid = it.page_id
            if not by_page[pid] then
                by_page[pid] = { title = it.page, list = {} }
                order[#order + 1] = pid
            end
            local l = by_page[pid].list
            l[#l + 1] = h
        end
    end
    local cards = {}
    for _, pid in ipairs(order) do
        local g = by_page[pid]
        local card = ui.card{ title = g.title }
        card.kids = ui.bind_all(g.list)
        cards[#cards + 1] = card
    end
    return cards
end

-- ── chrome ───────────────────────────────────────────────────────────────────

-- Vertical icon rail driven by the menu's own tabs, so a theme no longer hardcodes its own category
-- list (which silently rots whenever a top-level page is added or renamed).
ui.widget("icon_rail", {
    measure = function(n, w, sk) return n.h or 0 end,
    draw = function(n, x, y, w, h, sk)
        -- The rail sits on the window's left edge, so it has to carry the window's corner radius on
        -- ITS left corners or it squares off the top-left and bottom-left of the whole window. Painted
        -- as a fully-rounded rect, then the right-hand side is squared back off, since draw.rect can
        -- only round all four corners at once.
        local r = n.radius or sk.radius
        local rc = sk.col.rail
        if (rc[4] or 255) > 0 then
            fill(x, y, x + w, y + h, rc, r)
            if w > r then fill(x + r, y, x + w, y + h, rc, 0) end
        end
        -- Divider between the rail and the content. Measured as a translucent WHITE line: it reads
        -- grey (#676568) over the dark top and bright pink (#E65AFF) over the lit bottom -- that is the
        -- window gradient showing through it, not a coloured line.
        -- The rail is much brighter at the foot than the window centre is (measured #9A09D9 vs
        -- #420560). Rather than build a 2D corner glow out of a primitive that only does 2-stop
        -- linear gradients -- every seam between calls banded -- the rail simply gets its OWN single
        -- vertical gradient. One draw call, no seams, and the step against the content area lands
        -- exactly under the divider drawn below, which hides it.
        local rg = sk.col.rail_glow
        if rg then
            -- Starts partway down: a linear ramp from the very top makes the upper rail far brighter
            -- than the reference, which stays near-black for its first third. Beginning the gradient
            -- lower costs nothing at the join because it starts at alpha 0 -- nothing to seam against.
            local gy = y + h * (sk.rail_glow_top or 0.0)
            draw.rect_gradient(x, gy, x + w, y + h,
                rg[1], rg[2], rg[3], 0,   rg[1], rg[2], rg[3], 0,
                rg[1], rg[2], rg[3], rg[4] or 255,  rg[1], rg[2], rg[3], rg[4] or 255)
        end

        local dv = sk.col.rail_div
        if dv then
            -- Starts BELOW the header, not at the window top: in the reference the divider column is
            -- identical to the rail either side of it until y=98, which is where the content begins.
            -- Running it full height draws a line straight through the title bar.
            local dy = y + (n.top or 0)
            draw.rect(x + w, dy, x + w + (sk.rail_div_w or 2), y + h,
                      dv[1], dv[2], dv[3], dv[4] or 255, 0)
        end
        local count = menu.tab_count()
        if count <= 0 then return end
        -- Fixed cell packed from the top, NOT h/count: dividing the full height spreads a dozen tabs
        -- into a sparse ladder instead of the tight icon strip these layouts want.
        local cell = n.cell or sk.rail_cell
        local active = menu.tab_active()
        local f = n.icon_font or sk.font.icon
        local pad = n.cell_pad or 4
        -- Icons begin BELOW the header, not at the window top: the rail spans the full height for its
        -- background, but its first cell is level with the content, as in the reference.
        local top = y + (n.top or 0)
        for i = 0, count - 1 do
            local iy = top + i * cell
            if iy + cell > y + h then break end
            local sel = (i == active)
            local hov = ui.hovered(x, iy, x + w, iy + cell - pad)
            -- rail_indicator = false: the selected tab is shown by the icon's colour alone -- no accent
            -- bar, no tinted cell. The reference has neither.
            if sel and sk.rail_indicator ~= false then
                fill(x, iy, x + 3, iy + cell - pad, sk.col.rail_sel, 0)
                local a = sk.col.acc
                draw.rect(x + 3, iy, x + w, iy + cell - pad, a[1], a[2], a[3], 40, 0)
            elseif hov then
                local c = sk.col.card_hover
                draw.rect(x, iy, x + w, iy + cell - pad, c[1], c[2], c[3], 160, 0)
            end
            -- Icons are keyed by PAGE ID, not by tab name: names are translated, so a name-keyed
            -- table silently loses every icon under a non-English pack.
            local pid = menu.tab_page_id(i)
            local glyph = n.icons and n.icons[pid]
            local c = sel and sk.col.acc or sk.col.txt_dim
            if glyph then
                text.draw_centered(f, x, ty(iy, cell - pad, f), x + w, c[1], c[2], c[3], 255, glyph)
            else
                text.draw_centered(sk.font.label, x, ty(iy, cell - pad, sk.font.label), x + w,
                                   c[1], c[2], c[3], 255, string.sub(menu.tab_name(i), 1, 1))
            end
            if ui.clicked(x, iy, x + w, iy + cell - pad, 0) then menu.switch_tab(i) end
        end
    end,
})
function ui.icon_rail(t) t = t or {}; t.kind = "icon_rail"; return t end

-- Horizontal tab strip, same source of truth as the rail. A theme that hardcodes its own category
-- list silently rots whenever a top-level page is added or renamed -- this cannot.
ui.widget("tab_bar", {
    measure = function(n, w, sk) return n.h or sk.row_h end,
    draw = function(n, x, y, w, h, sk)
        local count = menu.tab_count()
        if count <= 0 then return end
        fill(x, y, x + w, y + h, n.bg or sk.col.panel, 0)
        local tw = w / count
        local active = menu.tab_active()
        local f = sk.font.label
        for i = 0, count - 1 do
            local tx = x + i * tw
            local sel = (i == active)
            local hov = ui.hovered(tx, y, tx + tw, y + h)
            if sel then
                fill(tx, y + h - 2, tx + tw, y + h, sk.col.acc, 0)
            elseif hov then
                fill(tx, y, tx + tw, y + h, sk.col.card, 0)
            end
            local c = sel and sk.col.acc or (hov and sk.col.txt or sk.col.txt_dim)
            text.draw_centered(f, tx, ty(y, h, f), tx + tw, c[1], c[2], c[3], 255, menu.tab_name(i))
            if ui.clicked(tx, y, tx + tw, y + h, 0) then menu.switch_tab(i) end
        end
    end,
})
function ui.tab_bar(t) t = t or {}; t.kind = "tab_bar"; return t end

-- Bottom description strip for the row under the cursor. Reads ui.hovered_item(), which the widgets
-- publish, so it works no matter where in the tree it is drawn.
ui.widget("desc_bar", {
    measure = function(n, w, sk) return n.h or sk.row_h end,
    draw = function(n, x, y, w, h, sk)
        fill(x, y, x + w, y + h, n.bg or sk.col.panel, 0)
        local hash = ui.hovered_item()
        if not hash then return end
        local handle = items.get(hash)
        if not handle then return end
        local it = items.at(handle)
        if not it or it.desc == "" then return end
        local f = sk.font.small
        text.draw_ellipsis(f, x + 8, ty(y, h, f),
                           sk.col.txt_dim[1], sk.col.txt_dim[2], sk.col.txt_dim[3], 255, it.desc, w - 16)
    end,
})
function ui.desc_bar(t) t = t or {}; t.kind = "desc_bar"; return t end

-- Every row of the current page as a flat list of widgets (no cards). This is what a classic
-- single-column theme wants, and it still goes through menu.handle_at so the m_order/layout mapping
-- is respected.
function ui.rows_for_page(opts)
    local handles = {}
    for i = 0, menu.item_count() - 1 do
        local h = menu.handle_at(i)
        if h and h >= 0 then handles[#handles + 1] = h end
    end
    return ui.bind_all(handles, opts)
end

ui.widget("header", {
    measure = function(n, w, sk) return n.h or sk.header_h end,
    draw = function(n, x, y, w, h, sk)
        local f = n.font or sk.font.title
        if n.wordmark then
            text.draw_centered(f, x, ty(y, h, f), x + w,
                               sk.col.txt[1], sk.col.txt[2], sk.col.txt[3], 255, n.wordmark)
        end
        if n.back ~= false then ui.back_button(x, y, h, sk) end
        if n.right then n.right(x, y, w, h, sk) end
    end,
})

-- Back chevron + current page name, drawn at the header's left edge and shown only when there is
-- somewhere to go back to. Without this a card layout is a one-way trip: rows that navigate (Model
-- Changer, Wardrobe, any Stand tree) drop you on a page with no mouse route back, which reads as the
-- click having broken the menu.
function ui.back_button(x, y, h, sk)
    -- Nothing to go back to from a tab root, or from Home (which is the root even when the theme
    -- shows tabs rather than a Home page).
    local pid = menu.page_id()
    if pid == 0x2245B5AE then return false end
    local ti = menu.tab_active()
    if ti and ti >= 0 and ti < menu.tab_count() and pid == menu.tab_page_id(ti) then
        return false
    end

    local bw = 26
    local hov = ui.hovered(x + 4, y, x + 4 + bw, y + h)
    local c = hov and sk.col.txt or sk.col.txt_dim
    local cx, cy = x + 4 + bw * 0.5, y + h * 0.5
    draw.line(cx + 3, cy - 6, cx - 3, cy, c[1], c[2], c[3], 255, 1.8)
    draw.line(cx - 3, cy, cx + 3, cy + 6, c[1], c[2], c[3], 255, 1.8)

    local f = sk.font.small
    text.draw_ellipsis(f, x + 4 + bw, ty(y, h, f), sk.col.txt_dim[1], sk.col.txt_dim[2],
                       sk.col.txt_dim[3], 255, menu.page_name(), 150)
    if ui.clicked(x + 4, y, x + 4 + bw, y + h, 0) then menu.go_back() end
    return true
end
function ui.header(t) t = t or {}; t.kind = "header"; return t end

-- Window frame: panel + border + the drag handle, in one call. drag_header takes the NATURAL
-- (un-offset) origin and returns the live offset, and C++ clamps it so the header can never end up
-- off-screen.
function ui.window(id, w, h, sk, drag_h)
    sk = sk or ui.skin
    local x = math.floor((ctx.screen_w() - w) * 0.5)
    local y = math.floor((ctx.screen_h() - h) * 0.5)
    local dx, dy = menu.drag_header(x, y, w, drag_h or sk.header_h)
    x, y = x + dx, y + dy
    -- The window itself can carry a vertical gradient. Measured off the reference: the background
    -- between cards ramps from near-black at the top (#0D0813) to a bright violet at the bottom
    -- (#40045F). Painting it flat is what made ours read as darker and deader than the original.
    if sk.col.bg_bot then
        -- Seamless by construction: fill_grad's caps are exactly the gradient's end colours, so there
        -- is no step where they meet. The previous four-corner version banded visibly along the bottom
        -- because its solid bottom cap did not match the gradient's brighter outer edges.
        -- The corner glow comes from draw_glow instead, which is what produces it in the original.
        fill_grad(x, y, x + w, y + h, sk.col.bg, sk.col.bg_bot, sk.radius)

        -- The reference is bright at BOTH bottom corners and dimmer through the middle. A 2-stop
        -- primitive cannot express that horizontally in one call, so the base ramps to the bright
        -- EDGE colour everywhere and the middle is then knocked back by two horizontal gradients --
        -- transparent at each window edge, equal alpha where they meet at the centre. Meeting at the
        -- same value is what keeps the join invisible.
        local dim = sk.col.bg_center_dim
        if dim then
            local a = dim[4] or 255
            local mx = x + w * 0.5
            draw.rect_gradient(x, y, mx, y + h,
                dim[1], dim[2], dim[3], 0,  dim[1], dim[2], dim[3], a,
                dim[1], dim[2], dim[3], a,  dim[1], dim[2], dim[3], 0)
            draw.rect_gradient(mx, y, x + w, y + h,
                dim[1], dim[2], dim[3], a,  dim[1], dim[2], dim[3], 0,
                dim[1], dim[2], dim[3], 0,  dim[1], dim[2], dim[3], a)
        end

    else
        fill(x, y, x + w, y + h, sk.col.bg, sk.radius)
    end
    -- The window's edge is a DARK line, not an accent one: measured across the top edge the glow falls
    -- straight into black (#988EBA -> #2E2D42 -> #030510) with no bright rim between them. Stroking it
    -- in the accent colour puts a pink line between the panel and its glow, which the original has not.
    local wb = sk.col.window_bdr or sk.col.acc
    local sh = sk.window_shadow or 0
    for i = sh, 1, -1 do
        local t = i / (sh + 1)
        local a = math.floor((wb[4] or 255) * (1 - t))
        if a > 2 then
            stroke(x - i, y - i, x + w + i, y + h + i, { wb[1], wb[2], wb[3], a }, sk.radius + i, 1)
        end
    end
    stroke(x, y, x + w, y + h, wb, sk.radius, 1)
    return x, y
end
