
-- First-run onboarding wizard. Full-screen, shown once, and while it is up NOTHING else draws --
-- the renderer suppresses the theme menu, feature HUDs, Spooner, Stand and every other overlay
-- (only the cursor overlay is kept), and block_input.lua locks out all game controls.
--
-- The state machine lives in C++ (src/widgets/welcome.*) and is exposed through `welcome`
-- (src/lua/lua_welcome.cpp). This file owns nothing but the look -- edit it freely, you cannot
-- desync the flow:
--   welcome.steps()      -> { {id, title, subtitle}, ... }   ids: intro|language|hotkeys|done
--   welcome.step()       -> 0-based index of the current step
--   welcome.hotkeys()    -> { {key, desc}, ... }
--   welcome.fade()       -> 0..1 whole-screen fade-in
--   welcome.step_fade()  -> 0..1 current step's own fade
--   welcome.step_dir()   -> +1 arrived going forward, -1 going back (slide direction)
--   welcome.next/back/skip/finish/go_to(i)
--   welcome.select(code) / welcome.pending() / welcome.error()
--   welcome.set_grid(cols, count) / welcome.focus()   -- lets the arrow keys walk the flag grid
-- Titles, subtitles and hotkey labels come from C++ so they are translated -- picking a language
-- on step 2 re-translates the wizard itself on the very next frame.
--
-- Language "flags" are 1-3 flat colour bands (no image assets) from lang.list(); see lang_meta.hpp.
--
-- LAYOUT: full-bleed, no panel. Backdrop (wash + tint + three drifting orbs + vignette), ghosted
-- ring emblem on the right third, and a single left-anchored content column: brand block, step
-- heading, step body, then progress segments + buttons pinned to the bottom of the column. All
-- of it is resolution-relative -- nothing is a fixed-size box.
--
-- ENGINE LIMITS worth knowing before editing: no blur / shadow / glow / radial gradient (fake
-- them with stacked translucent fills), draw.rect_gradient is 2-stop only (4 distinct corners
-- silently collapse), every colour arg must be an int (fl() it), and geometry is pixel-snapped
-- so keep motion amplitudes above ~2px.
local COLS_MAX  = 3      -- language chips per row (reduced automatically on narrow columns)
local CHIP_W_MIN= 210
local CHIP_H    = 46
local GAP       = 10
local COL_MIN_X = 96     -- content column never hugs the left edge closer than this

local scroll = 0.0
local anim   = {}        -- eased 0..1 hover values, keyed by element

-- Translated copy. tools/extract_translations.py only scans .cpp/.hpp and skips THIS file, so a
-- literal written here could never enter a language pack. Every user-facing word the overlay
-- draws therefore comes from str.welcome() (src/lua/lua_strings.cpp), refreshed once per frame
-- below so picking a language on step 2 re-translates it on the very next frame. If you add copy,
-- add it there, not here. The wordmark and the step counter format are the only exceptions.
local L = nil

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
local function ease_out(p) p = clamp(p, 0, 1); local q = 1 - p; return 1 - q * q * q end
local function fl(v) return math.floor(v) end

local function hit(x, y, w, h)
    local mx, my = input.mouse_x(), input.mouse_y()
    return mx >= x and mx <= x + w and my >= y and my <= y + h
end

-- Frame-rate independent approach toward a target. Keyed so any number of elements can each
-- keep their own hover state without the caller storing anything.
local function ease_to(key, target, speed)
    local v = anim[key] or 0
    v = v + (target - v) * math.min(1, ctx.delta() * (speed or 12))
    anim[key] = v
    return v
end

-- Child `i` of a group gets its own 0..1 out of the group's 0..1, so rows cascade in instead
-- of popping together. The index is capped: without it, item 20 of the language list would
-- start so late that it never becomes visible.
local function stagger(i, p)
    i = math.min(i, 6)
    return ease_out(clamp((p - i * 0.055) / 0.6, 0, 1))
end

-- â”€â”€ chrome helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
local function accent() return theme.accent() end

-- "primary" = accent pill with a chevron and a slow halo pulse. "link" = text with an accent
-- underline that wipes in on hover. There is no boxed/ghost button anywhere any more.
local function button(x, y, w, h, label, kind, alpha, enabled, key)
    if enabled == nil then enabled = true end
    local ar, ag, ab = accent()
    local hov = enabled and hit(x, y, w, h)
    local hv  = ease_to(key or label, hov and 1 or 0, 14)
    local a   = fl(255 * alpha * (enabled and 1.0 or 0.4))
    if kind == "primary" then
        local rr    = h * 0.5
        local pulse = 0.5 + 0.5 * math.sin(ctx.time() * 1.8)
        draw.rect_outline(x - 4, y - 4, x + w + 4, y + h + 4, ar, ag, ab,
                          fl(a * (0.06 + pulse * 0.08 + hv * 0.28)), rr + 4, 1.4)
        draw.rect(x, y, x + w, y + h, ar, ag, ab, fl(a * (0.86 + hv * 0.14)), rr)
        local tw = text.width(font.item, label)
        local tx = x + (w - tw - 16) * 0.5
        text.draw(font.item, tx, y + h * 0.5 - 7, 14, 14, 18, a, label)
        local kx = tx + tw + 12 + hv * 3
        local ky = y + h * 0.5
        draw.line(kx - 3, ky - 4, kx + 1, ky, 14, 14, 18, a, 1.8)
        draw.line(kx + 1, ky, kx - 3, ky + 4, 14, 14, 18, a, 1.8)
    else -- link
        local g = 148 + fl(hv * 70)
        text.draw_centered(font.item, x, y + h * 0.5 - 7, x + w, g, g + 3, g + 14, a, label)
        local uw = text.width(font.item, label)
        local ux = x + (w - uw) * 0.5
        draw.line(ux, y + h * 0.5 + 11, ux + uw * hv, y + h * 0.5 + 11, ar, ag, ab, fl(a * hv * 0.8), 1.0)
    end
    return hov and input.mouse_clicked(0)
end

-- Real flag PNGs live in %LOCALAPPDATA%\Nenyoo\Plus\textures\flag_<CODE>.png, provisioned by
-- texture_assets::ensure() from the menu_assets CDN manifest at startup. Filename = language
-- code with the "LANG_" prefix stripped (LANG_EN -> flag_EN.png -> US flag PNG). If the image
-- hasn't landed yet (first launch before the async download completes, or a manifest miss),
-- fall back to the coloured-band vector representation so the picker still renders.
local function draw_flag(x, y, w, h, entry)
    local code = entry.code or ""
    if code:sub(1, 5) == "LANG_" then code = code:sub(6) end
    local img = code ~= "" and draw.load_image("textures/flag_"..code..".png") or 0
    if img > 0 then
        draw.push_clip(x, y, x + w, y + h)
        draw.image(img, x, y, x + w, y + h)
        draw.pop_clip()
        draw.rect_outline(x, y, x + w, y + h, 0, 0, 0, 150, 3, 1)
        return
    end
    local bands = entry.bands
    local n = #bands
    draw.push_clip(x, y, x + w, y + h)
    if n == 0 then
        draw.rect(x, y, x + w, y + h, 90, 90, 100, 255, 3)
    elseif entry.vertical then
        local bw = w / n
        for i, c in ipairs(bands) do
            local bx = x + (i - 1) * bw
            draw.rect(bx, y, bx + bw + 1, y + h, c[1], c[2], c[3], 255, 0)
        end
    else
        local bh = h / n
        for i, c in ipairs(bands) do
            local by = y + (i - 1) * bh
            draw.rect(x, by, x + w, by + bh + 1, c[1], c[2], c[3], 255, 0)
        end
    end
    draw.pop_clip()
    draw.rect_outline(x, y, x + w, y + h, 0, 0, 0, 150, 3, 1)
end

-- Small orbiting dot -- the async language-pack fetch is the only thing in the wizard that waits.
local function spinner(cx, cy, r, a)
    a = math.floor(a)
    local ar, ag, ab = accent()
    local t = ctx.time() * 4.2
    draw.circle_outline(cx, cy, r, ar, ag, ab, math.floor(a * 0.22), 1.4)
    draw.circle(cx + math.cos(t) * r, cy + math.sin(t) * r, 2.2, ar, ag, ab, math.floor(a))
end

-- A label/value line with a hairline rule under it -- the intro step's only furniture.
local function spec_row(x, y, w, label, value, a)
    a = fl(a)
    if a <= 0 then return end
    local ar, ag, ab = accent()
    text.draw(font.small, x, y + 3, 118, 121, 133, a, label)
    text.draw(font.item, x + w - text.width(font.item, value), y, ar, ag, ab, a, value)
    draw.line(x, y + 26, x + w, y + 26, 255, 255, 255, fl(a * 0.08), 1)
end

-- The engine has no blur and no radial gradient, so a soft orb is faked with concentric
-- fills whose alphas accumulate toward the middle. 14 circles each, three orbs, ~42 fills.
local function blob(cx, cy, r, a)
    if a <= 0 then return end
    local ar, ag, ab = accent()
    for i = 14, 1, -1 do
        draw.circle(cx, cy, r * (i / 14), ar, ag, ab, a)
    end
end

-- Full-screen backdrop: flat wash, one 2-stop tint (4-corner gradients silently collapse to
-- 2 stops in draw.cpp, so it is written as one), three drifting orbs, then a vignette.
local function draw_background(sw, sh, fade)
    local dr, dg, db = theme.accent_dark()
    local t = ctx.time()

    draw.rect(0, 0, sw, sh, 6, 7, 11, fl(246 * fade), 0)
    local wash = fl(34 * fade)
    draw.rect_gradient(0, 0, sw, sh,
        dr, dg, db, wash, dr, dg, db, wash,
        4, 5, 8, 0, 4, 5, 8, 0)

    -- Periods are coprime-ish (17/23/31s) so the drift never visibly loops.
    local ba = fl(3 * fade)
    blob(sw * (0.20 + 0.05 * math.sin(t / 17.0)), sh * (0.28 + 0.06 * math.cos(t / 23.0)),
         sh * 0.55 * (1 + 0.06 * math.sin(t / 11.0)), ba)
    blob(sw * (0.78 + 0.04 * math.cos(t / 23.0)), sh * (0.62 + 0.05 * math.sin(t / 31.0)),
         sh * 0.40 * (1 + 0.07 * math.cos(t / 13.0)), ba)
    blob(sw * (0.52 + 0.06 * math.sin(t / 31.0)), sh * (0.88 + 0.04 * math.cos(t / 17.0)),
         sh * 0.30 * (1 + 0.08 * math.sin(t / 19.0)), ba)

    local vh, vw = sh * 0.20, sw * 0.16
    local va, ha = fl(150 * fade), fl(120 * fade)
    draw.rect_gradient(0, 0, sw, vh, 0, 0, 0, va, 0, 0, 0, va, 0, 0, 0, 0, 0, 0, 0, 0)
    draw.rect_gradient(0, sh - vh, sw, sh, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, va + 20, 0, 0, 0, va + 20)
    draw.rect_gradient(0, 0, vw, sh, 0, 0, 0, ha, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, ha)
    draw.rect_gradient(sw - vw, 0, sw, sh, 0, 0, 0, 0, 0, 0, 0, ha, 0, 0, 0, ha, 0, 0, 0, 0)
end

-- Ghosted concentric rings on the right third, each with its own orbiting dot. On the last
-- step the innermost ring fills and a check mark scales in -- that is the "done" flourish.
-- `k` scales the whole thing so the outermost ring always clears the content column -- at 1280x720
-- the gap to the right of the column is only ~225px and full-size rings would sit under the text.
local function draw_emblem(cx, cy, a, done_p, k)
    if a <= 0.01 then return end
    local ar, ag, ab = accent()
    local t = ctx.time()
    local rings = { { 210, 10, 0.35 }, { 150, 16, -0.5 }, { 96, 24, 0.8 } }
    for _, r in ipairs(rings) do
        local rad = r[1] * k
        draw.circle_outline(cx, cy, rad, ar, ag, ab, fl(r[2] * a), 1.2)
        local ang = t * r[3]
        draw.circle(cx + math.cos(ang) * rad, cy + math.sin(ang) * rad, 2.6, ar, ag, ab, fl(150 * a))
    end
    if done_p > 0 then
        local p = ease_out(done_p)
        draw.circle(cx, cy, 96 * k * p, ar, ag, ab, fl(26 * a * p))
        draw.circle_outline(cx, cy, 62 * k * p, ar, ag, ab, fl(200 * a * p), 2.4)
        local s = 30 * k * p
        draw.line(cx - s * 0.55, cy, cx - s * 0.15, cy + s * 0.45, ar, ag, ab, fl(255 * a * p), 3.4)
        draw.line(cx - s * 0.15, cy + s * 0.45, cx + s * 0.6, cy - s * 0.5, ar, ag, ab, fl(255 * a * p), 3.4)
    end
end

-- â”€â”€ step bodies â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
-- `a` is 0..255 for the whole body, `p` is the step's own 0..1 (drives the per-row cascade).
-- Every colour arg crossing into C++ is an int; a fraction raises, hence fl() everywhere.
local function body_intro(x, y, w, h, a, p)
    local rows = {
        { L.edition,  ctx.edition() },
        { L.build,    "v" .. str.version },
        { L.compiled, str.build_date },
    }
    local rw = math.min(w, 420)
    local ry = y + 6
    for i, r in ipairs(rows) do
        local s = stagger(i - 1, p)
        spec_row(x + (1 - s) * 18, ry, rw, r[1], r[2], a * s)
        ry = ry + 38
    end
    local s = stagger(3, p)
    text.draw(font.small, x + (1 - s) * 18, ry + 12, 118, 121, 133, fl(a * s * 0.85), L.intro_note)
end


local function body_language(x, y, w, h, a, p)
    local ar, ag, ab = accent()
    local entries = lang.list()

    -- Columns are derived from the available width, then published so the C++ arrow-key
    -- navigation walks the same grid we drew. This MUST happen every frame.
    local cols = clamp(fl((w + GAP) / (CHIP_W_MIN + GAP)), 1, COLS_MAX)
    welcome.set_grid(cols, #entries)

    local chip_w  = (w - GAP * (cols - 1)) / cols
    local rows    = math.max(1, math.ceil(#entries / cols))
    local grid_h  = rows * CHIP_H + math.max(0, rows - 1) * GAP
    local view_h  = h - 4
    local focus   = welcome.focus()
    local pending = welcome.pending()
    local current = lang.current()

    if hit(x, y, w, view_h) then
        local wh = input.mouse_wheel()
        if wh ~= 0 then scroll = scroll - wh * 44 end
    end
    -- Keep the keyboard focus cell on screen when the arrows walk off the visible rows.
    local frow = math.floor(focus / cols)
    local ftop = frow * (CHIP_H + GAP)
    if ftop < scroll then scroll = ftop end
    if ftop + CHIP_H > scroll + view_h then scroll = ftop + CHIP_H - view_h end
    scroll = clamp(scroll, 0, math.max(0, grid_h - view_h))

    draw.push_clip(x - 6, y, x + w + 6, y + view_h)
    for i, e in ipairs(entries) do
        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)
        local cx  = x + col * (chip_w + GAP)
        local cy  = y + row * (CHIP_H + GAP) - scroll
        if cy + CHIP_H >= y and cy <= y + view_h then
            local is_current = e.code == current
            local is_focus   = (i - 1) == focus
            local hov        = hit(cx, cy, chip_w, CHIP_H) and pending == ""
            local hv         = ease_to("chip" .. i, (hov or is_focus) and 1 or 0, 14)
            local ox         = hv * 3
            local sa         = a * stagger(row, p)

            if sa > 1 then
                draw.rect(cx + ox, cy, cx + chip_w, cy + CHIP_H, 255, 255, 255, fl(sa * 0.08 * hv), 8)
                draw.line(cx + ox, cy + CHIP_H, cx + chip_w, cy + CHIP_H, 255, 255, 255,
                          fl(sa * (0.08 + 0.16 * hv)), 1)
                local tick = is_current and 1.0 or hv
                if tick > 0.01 then
                    draw.rect(cx + ox, cy + 9, cx + ox + 3, cy + CHIP_H - 9, ar, ag, ab, fl(sa * tick), 2)
                end

                draw_flag(cx + ox + 16, cy + CHIP_H * 0.5 - 8.5, 26, 17, e)

                local nr, ng, nb = 205, 207, 216
                if is_current then nr, ng, nb = ar, ag, ab end
                text.draw_ellipsis(font.item, cx + ox + 52, cy + CHIP_H * 0.5 - 7, nr, ng, nb, fl(sa),
                                   e.name, chip_w - 120)

                if pending == e.code then
                    spinner(cx + chip_w - 22, cy + CHIP_H * 0.5, 6.5, sa)
                elseif is_current then
                    -- Published in natural case and upper-cased here; see the CASE note in
                    -- lua_strings.cpp -- TR'ing the caps form would collide with the same hash.
                    local act = string.upper(L.active)
                    local tw  = text.width(font.tiny, act)
                    text.draw(font.tiny, cx + chip_w - 16 - tw, cy + CHIP_H * 0.5 - 5, ar, ag, ab,
                              fl(sa * 0.8), act)
                end
            end

            if hov and input.mouse_clicked(0) and not is_current then welcome.select(e.code) end
        end
    end
    draw.pop_clip()

    -- Scroll hint: a thin rule down the right edge when there is more below.
    if grid_h > view_h then
        local tx = x + w + 8
        local th = view_h * (view_h / grid_h)
        local ty = y + (view_h - th) * (scroll / math.max(1, grid_h - view_h))
        draw.rect(tx, y, tx + 2, y + view_h, 255, 255, 255, fl(a * 0.06), 1)
        draw.rect(tx, ty, tx + 2, ty + th, ar, ag, ab, fl(a * 0.55), 1)
    end
end

local function body_hotkeys(x, y, w, h, a, p)
    local ar, ag, ab = accent()
    local rows = welcome.hotkeys()
    local rw   = math.min(w, 440)
    local ry   = y + 4
    for i, r in ipairs(rows) do
        local s  = stagger(i - 1, p)
        local rx = x + (1 - s) * 18
        local sa = a * s
        if sa > 1 then
            draw.rect(rx, ry + 5, rx + 56, ry + 29, ar, ag, ab, fl(sa * 0.14), 6)
            draw.rect_outline(rx, ry + 5, rx + 56, ry + 29, ar, ag, ab, fl(sa * 0.40), 6, 1.0)
            text.draw_centered(font.small, rx, ry + 11, rx + 56, ar, ag, ab, fl(sa), r.key)
            text.draw(font.item, rx + 72, ry + 10, 205, 207, 216, fl(sa), r.desc)
            draw.line(rx, ry + 38, rx + rw, ry + 38, 255, 255, 255, fl(sa * 0.06), 1)
        end
        ry = ry + 46
    end
    local s = stagger(#rows, p)
    text.draw(font.small, x + (1 - s) * 18, ry + 12, 118, 121, 133, fl(a * s * 0.85), L.hotkey_note)
end

-- The check-mark flourish lives on the right-hand emblem (draw_emblem), so this side only
-- carries the closing copy.
local function body_done(x, y, w, h, a, p)
    local s1 = stagger(0, p)
    local s2 = stagger(1, p)
    text.draw(font.item, x + (1 - s1) * 18, y + 10, 226, 228, 236, fl(a * s1), L.done_line1)
    text.draw(font.small, x + (1 - s2) * 18, y + 34, 130, 133, 146, fl(a * s2 * 0.9), L.done_line2)
end

-- â”€â”€ the wizard â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
overlay.on_draw("welcome_screen", function()
    if not welcome.active() then return end

    local sw, sh = ctx.screen_w(), ctx.screen_h()
    local fade   = welcome.fade()
    local sfade  = welcome.step_fade()
    local ar, ag, ab = accent()

    local steps = welcome.steps()
    local idx   = welcome.step()
    local cur   = steps[idx + 1]
    if not cur then return end

    -- Refreshed every frame, not cached at load: translations::select_language() swaps the whole
    -- string map on a background thread, so a snapshot taken once would go stale the instant the
    -- user picks a language on step 2.
    L = str.welcome()
    if not L then return end

    -- Full-bleed backdrop -- there is no panel, no card and no dialog chrome anywhere.
    draw_background(sw, sh, fade)

    local a255 = fl(255 * fade)
    local ef   = ease_out(fade)
    local colx = math.max(COL_MIN_X, sw * 0.13)
    local colw = math.min(720, sw * 0.52)
    local rise = (1 - ef) * 30

    -- Decorative rings, centred in whatever space is left to the right of the column and scaled
    -- to fit it; quieter while the language list needs attention, and they carry the check-mark
    -- flourish on the last step.
    local gap_l = colx + colw
    local em_a  = fade * ((cur.id == "language") and 0.4 or 1.0)
    local em_k  = clamp((sw - gap_l) * 0.5 / 230, 0.45, 1.0)
    draw_emblem((gap_l + sw) * 0.5, sh * 0.5, em_a, (cur.id == "done") and sfade or 0, em_k)

    -- The single vertical rule is the only "frame" left; it grows down on entry.
    draw.line(colx - 30, sh * 0.19, colx - 30, sh * 0.19 + sh * 0.64 * ef, ar, ag, ab, fl(26 * fade), 1)

    -- â”€â”€ brand block (persistent across every step) â”€â”€
    local brandy = sh * 0.19 + rise
    text.draw_spaced(font.title, colx, brandy, 235, 237, 244, a255, "NENYOO", 6.0)
    local wmw = text.width_spaced(font.title, "NENYOO", 6.0)
    local uy  = brandy + text.height(font.title) + 4
    draw.rect(colx, uy, colx + wmw * ef, uy + 3, ar, ag, ab, a255, 2)
    text.draw(font.small, colx, uy + 15, 118, 121, 133, fl(a255 * 0.9),
        ctx.edition() .. "   /   v" .. str.version)

    -- â”€â”€ step heading â”€â”€
    local hy = uy + 58
    text.draw_spaced(font.label, colx, hy, ar, ag, ab, a255,
        string.format("%02d / %02d", idx + 1, #steps), 2.0)
    local ty = hy + 24
    text.draw(font.title, colx, ty, 226, 228, 236, a255, cur.title)
    local sy = ty + text.height(font.title) + 8
    text.draw(font.desc, colx, sy, 148, 151, 164, fl(a255 * 0.95), cur.subtitle)

    -- â”€â”€ body â”€â”€
    local footer_y = sh - 96
    local bx = colx
    local by = sy + text.height(font.desc) + 28
    local bw = colw
    local bh = footer_y - by - 28
    local slide = (1 - sfade) * 34 * welcome.step_dir()
    local ba = 255 * fade * sfade

    if bh > 40 then
        draw.push_clip(bx - 10, by - 6, bx + bw + 16, by + bh + 6)
        if cur.id == "intro" then
            body_intro(bx - slide, by, bw, bh, ba, sfade)
        elseif cur.id == "language" then
            body_language(bx - slide, by, bw, bh, ba, sfade)
        elseif cur.id == "hotkeys" then
            body_hotkeys(bx - slide, by, bw, bh, ba, sfade)
        else
            body_done(bx - slide, by, bw, bh, ba, sfade)
        end
        draw.pop_clip()
    end

    -- â”€â”€ footer: progress segments left, buttons right â”€â”€
    -- Everything down here goes inert while a language pack is in flight. C++ refuses the nav
    -- anyway, but a segment that still lights up on hover reads as clickable when it is not.
    local busy = welcome.pending() ~= ""
    local ry = sh - 58
    local seg_w, seg_gap = 44, 6
    for i = 1, #steps do
        local sx = colx + (i - 1) * (seg_w + seg_gap)
        if i - 1 == idx then
            draw.rect(sx, ry, sx + seg_w, ry + 3, 255, 255, 255, fl(a255 * 0.12), 2)
            draw.rect(sx, ry, sx + seg_w * ease_out(sfade), ry + 3, ar, ag, ab, a255, 2)
        elseif i - 1 < idx then
            local hov = (not busy) and hit(sx, ry - 9, seg_w, 21)
            local hv  = ease_to("seg" .. i, hov and 1 or 0, 14)
            draw.rect(sx, ry, sx + seg_w, ry + 3, ar, ag, ab,
                      fl(a255 * (0.5 + 0.5 * hv) * (busy and 0.4 or 1.0)), 2)
            if hov and input.mouse_clicked(0) then welcome.go_to(i - 1) end
        else
            draw.rect(sx, ry, sx + seg_w, ry + 3, 255, 255, 255, fl(a255 * 0.12), 2)
        end
    end

    local err = welcome.error()
    if err ~= "" then
        text.draw(font.small, colx, ry - 28, 232, 96, 96, a255, err)
    end

    local bh2  = 40
    local byy  = ry - 20

    -- Widths follow the translated label; a German "Get Started" is a lot wider than the English
    -- one, so nothing here may assume a fixed button size. The ease_to keys stay English
    -- identifiers on purpose -- keying the hover animation on the label would reset it mid-fade
    -- the moment the language changes.
    local next_label = welcome.is_last() and L.start or L.cont
    local nw = text.width(font.item, next_label) + 66
    local nx = colx + colw - nw
    if button(nx, byy, nw, bh2, next_label, "primary", fade, not busy, "next") then welcome.next() end

    local lx = nx
    if not welcome.is_last() then
        local skw = text.width(font.item, L.skip) + 34
        lx = nx - 16 - skw
        if button(lx, byy, skw, bh2, L.skip, "link", fade, not busy, "skip") then welcome.skip() end
    end
    if welcome.can_back() then
        local bkw = text.width(font.item, L.back) + 34
        if button(lx - 8 - bkw, byy, bkw, bh2, L.back, "link", fade, not busy, "back") then welcome.back() end
    end
end)
