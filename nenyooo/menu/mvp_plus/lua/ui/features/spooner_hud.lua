-- Spooner editor HUD.
--
-- Published by spooner_mode::render_hud: active, held, hover, hover_indb, creator, snapped,
-- precision, sel_valid, sel_label, edit_mode (0 off, 1 position, 2 rotation), edit_line,
-- total / props / peds / vehs, manip, hint_count and hintN_label / hintN_key.
--
-- This is a TOOL, not a power fantasy: no wordmarks, no pulsing, nothing that moves in the corner
-- of your eye while you are trying to place a prop by hand. Quiet greys, one accent that only
-- appears to tell you something changed, and a crosshair that carries the state you need most.

local min, max, floor = math.min, math.max, math.floor

local INK_R,  INK_G,  INK_B  =   9,  11,  15   -- panel ink
local TXT_R,  TXT_G,  TXT_B  = 228, 232, 238
local DIM_R,  DIM_G,  DIM_B  = 150, 160, 175
local ACC_R,  ACC_G,  ACC_B  =  96, 186, 255   -- neutral tool accent
local OK_R,   OK_G,   OK_B   =  70, 220, 130   -- entity under the crosshair
local DB_R,   DB_G,   DB_B   =  60, 220, 250   -- already in the database
local HOLD_R, HOLD_G, HOLD_B = 255, 150,  40   -- carrying something
local WARN_R, WARN_G, WARN_B = 255, 208,  70   -- keyboard-edit mode

local function right_text(fnt, x2, y, r, g, b, a, str)
    text.draw(fnt, x2 - text.width(fnt, str), y, r, g, b, a, str)
end

features.on_draw("Spooner", function(f)
    if not f.active then return end

    local sw, sh = ctx.screen_w(), ctx.screen_h()
    local s = max(0.72, min(1.7, sh / 1080))
    local fnt, small, tiny = font.item, font.small, font.tiny
    local fh = text.height(fnt)

    ------------------------------------------------------------------ crosshair
    -- The single most-read element in the editor: it answers "will a click do anything?" without
    -- moving your eyes off the target. Orange while carrying, cyan if the entity is already in the
    -- database, green for a fresh entity, white for empty space.
    local cx, cy = sw * 0.5, sh * 0.5
    if f.held then
        local w, h = 5 * s, 9 * s
        draw.rect(cx - w, cy - h, cx + w, cy + h, HOLD_R, HOLD_G, HOLD_B, 255, 1)
        draw.rect_outline(cx - w - 3 * s, cy - h - 3 * s, cx + w + 3 * s, cy + h + 3 * s,
                          HOLD_R, HOLD_G, HOLD_B, 130, 2, 1.0)
    else
        local r, g, b = TXT_R, TXT_G, TXT_B
        if f.hover then
            if f.hover_indb then r, g, b = DB_R, DB_G, DB_B else r, g, b = OK_R, OK_G, OK_B end
        end
        local gap, arm, th = 5 * s, 13 * s, 1.6
        draw.line(cx - gap - arm, cy, cx - gap, cy, r, g, b, 240, th)
        draw.line(cx + gap, cy, cx + gap + arm, cy, r, g, b, 240, th)
        draw.line(cx, cy - gap - arm, cx, cy - gap, r, g, b, 240, th)
        draw.line(cx, cy + gap, cx, cy + gap + arm, r, g, b, 240, th)
        draw.rect(cx - 1 * s, cy - 1 * s, cx + 1 * s, cy + 1 * s, r, g, b, 255, 0)
    end

    ------------------------------------------------------------------ entity counts (top-left)
    -- A card rather than loose text: the old version sat directly on the world and was unreadable
    -- over bright ground.
    local pad = 12 * s
    local cw, ch = 152 * s, fh * 4 + pad * 2 + 10 * s
    local x1, y1 = 18 * s, 18 * s
    draw.rect(x1, y1, x1 + cw, y1 + ch, INK_R, INK_G, INK_B, 200, 5)
    draw.rect(x1, y1, x1 + 3 * s, y1 + ch, ACC_R, ACC_G, ACC_B, 235, 3)

    local ty = y1 + pad
    text.draw(small, x1 + pad, ty, DIM_R, DIM_G, DIM_B, 220, "ENTITIES")
    right_text(fnt, x1 + cw - pad, ty - 2 * s, TXT_R, TXT_G, TXT_B, 255,
               string.format("%d", floor(f.total or 0)))
    ty = ty + fh + 8 * s
    local rows = { { "Objects", f.props }, { "Peds", f.peds }, { "Vehicles", f.vehs } }
    for i = 1, #rows do
        text.draw(small, x1 + pad, ty, DIM_R, DIM_G, DIM_B, 210, rows[i][1])
        right_text(small, x1 + cw - pad, ty, TXT_R, TXT_G, TXT_B, 235,
                   string.format("%d", floor(rows[i][2] or 0)))
        ty = ty + fh
    end

    ------------------------------------------------------------------ selection + edit banner
    local by = sh * 0.84
    if f.sel_valid and f.sel_label then
        local w = text.width(fnt, f.sel_label)
        draw.rect(cx - w * 0.5 - 10 * s, by - 4 * s, cx + w * 0.5 + 10 * s, by + fh + 4 * s,
                  INK_R, INK_G, INK_B, 175, 4)
        text.draw_centered(fnt, cx - w * 0.5, by, cx + w * 0.5, OK_R, OK_G, OK_B, 245, f.sel_label)
    end

    -- Keyboard edit is a MODE -- while it is on, your keys mean something different, so it gets the
    -- one loud element in this HUD.
    if (f.edit_mode or 0) ~= 0 and f.edit_line then
        local ly = by + fh + 10 * s
        local w = text.width(small, f.edit_line)
        draw.rect(cx - w * 0.5 - 12 * s, ly - 4 * s, cx + w * 0.5 + 12 * s, ly + fh + 4 * s,
                  WARN_R, WARN_G, WARN_B, 38, 4)
        draw.rect_outline(cx - w * 0.5 - 12 * s, ly - 4 * s, cx + w * 0.5 + 12 * s, ly + fh + 4 * s,
                          WARN_R, WARN_G, WARN_B, 190, 4, 1.0)
        text.draw_centered(small, cx - w * 0.5, ly, cx + w * 0.5, WARN_R, WARN_G, WARN_B, 250, f.edit_line)
    end

    ------------------------------------------------------------------ control bar (bottom)
    -- "Label [KEY]" pairs. Measured first so the bar is exactly as wide as its contents and can be
    -- centred; the old one was right-anchored and ran off narrow screens with the Menyoo set.
    local n = floor(f.hint_count or 0)
    if n > 0 then
        local gap_lk, gap_item, key_pad = 6 * s, 20 * s, 8 * s
        local bar_pad_x, bar_pad_y = 14 * s, 8 * s
        local key_h = fh + 8 * s
        local bar_h = key_h + bar_pad_y * 2

        local lw, kw, total = {}, {}, 0
        for i = 0, n - 1 do
            local lab = f["hint" .. i .. "_label"] or ""
            local k   = f["hint" .. i .. "_key"] or ""
            lw[i] = text.width(small, lab)
            kw[i] = text.width(small, k) + key_pad * 2
            total = total + lw[i] + gap_lk + kw[i]
            if i < n - 1 then total = total + gap_item end
        end

        local bar_w = total + bar_pad_x * 2
        local bx1 = max(8 * s, cx - bar_w * 0.5)
        local by2 = sh - 14 * s
        local by1 = by2 - bar_h
        draw.rect(bx1, by1, bx1 + bar_w, by2, INK_R, INK_G, INK_B, 205, 6)

        local x = bx1 + bar_pad_x
        local text_y = by1 + (bar_h - fh) * 0.5
        for i = 0, n - 1 do
            local lab = f["hint" .. i .. "_label"] or ""
            local k   = f["hint" .. i .. "_key"] or ""
            text.draw(small, x, text_y, TXT_R, TXT_G, TXT_B, 245, lab)
            x = x + lw[i] + gap_lk
            draw.rect(x, by1 + bar_pad_y, x + kw[i], by2 - bar_pad_y, 232, 236, 242, 240, 3)
            text.draw_centered(small, x, text_y, x + kw[i], 18, 20, 26, 255, k)
            x = x + kw[i] + gap_item
        end

        -- Manipulation hint sits directly above the bar, matching its left edge.
        if f.manip then
            text.draw(small, bx1 + bar_pad_x, by1 - fh - 7 * s,
                      ACC_R, ACC_G, ACC_B, 220, f.manip)
        end
    end
end)
