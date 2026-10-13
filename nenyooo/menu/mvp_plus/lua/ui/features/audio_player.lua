-- Audio Player now-playing HUD. Published by audio_player::draw:
--   enabled (bool), playing (bool), position/duration (seconds), volume (0..1),
--   title/artist/source/art (strings), repeat_mode (0..2), shuffle (bool),
--   spectrum_peak, spectrum_00..spectrum_31.
--
-- TWELVE LAYOUTS, chosen by Settings > Theme > Audio Player > Player Design. The DESIGNS table at
-- the bottom of this file must stay in the same ORDER as AUDIO_DESIGNS in theme.lua -- the setting
-- stores an index, not a name. Each design is a draw(c) that lays out inside the panel rect; all
-- the shared machinery (position, drag, resize, fold, seek, buttons, art, meter) lives above it, so
-- a layout is mostly geometry.
--
-- Interaction hit-tests with RAW input, exactly as panel_kit drags its panels. The theme never
-- routes through ui_input, and ui.hovered would veto us whenever a higher layer was hovered on the
-- previous frame. Everything is drawn inside a push_clip of the panel rect, so nothing escapes it.
--
-- Only nine font roles exist: title / item / breadcrumb / desc / label / tagline / value / small /
-- tiny. An unknown key arrives as nil, which the binding reads as font_id 0 -- the 36px Pricedown
-- menu title. Never invent a role.
--
-- Transport is IPC into C++: the HUD writes an intent to "audio_hud_cmd" plus a rising counter to
-- "audio_hud_cmd_t"; the feature's tick() services each new sequence once.

local floor, min, max, abs = math.floor, math.min, math.max, math.abs
local sin, cos, pi         = math.sin, math.cos, math.pi

local SCALE_LO, SCALE_HI = 0.7, 2.2
local GRIP = 14
local FOLD_SLOT = 16                -- right-hand strip slot owned by the fold chevron

-- Pre-computed spectrum key names so we don't build 32 strings per frame.
local SPEC_KEYS = {}
for i = 0, 31 do SPEC_KEYS[i] = string.format("spectrum_%02d", i) end

local function get_num(k, def)
    local v = menu.get_setting(k)
    if v == nil or v == "" then return def end
    return tonumber(v) or def
end
local function set_num(k, v) menu.set_setting(k, tostring(floor(v * 1000) / 1000)) end
local function set_str(k, v) menu.set_setting(k, v) end

-- ---------------------------------------------------------------- persistent state
local pos_x  = get_num("audio_hud_x", 32)
local pos_y  = get_num("audio_hud_y", 220)
local scale  = get_num("audio_hud_scale", 1.0)
local folded = get_num("audio_hud_fold", 0) > 0
local muted  = get_num("audio_hud_mute", 0) > 0
local last_vol = get_num("audio_hud_last_vol", 100) / 100

local own = nil                     -- nil | "drag" | "resize"
local drag_dx, drag_dy = 0, 0
local tap_x, tap_y, tap_ok = 0, 0, false   -- a click on a round design's disc that never moved
local rz_mx, rz_my, rz_s = 0, 0, 1
local last_t = ctx.time and ctx.time() or 0

local sm_play, sm_prog, sm_sleep = 0, 0, 0
local sm_spec = {}
for i = 0, 31 do sm_spec[i] = 0 end
local marquee_off, last_title = 0, ""
local spin, cmd_seq = 0, 0

local g_fade = 1
local function A(v) return floor(v * g_fade) end

-- Immediate-mode hit registry. Controls are hit-tested while DRAWING, which is after the drag
-- check has already run, so the drag would otherwise start under every button press. Each button
-- records its rect here; next frame's drag check consults the previous frame's set. Stored flat --
-- a table per button per frame would be pure GC churn on the render thread.
local hot, hot_n = {}, 0
local function hot_add(x, y, w, h)
    local i = hot_n * 4
    hot[i + 1], hot[i + 2], hot[i + 3], hot[i + 4] = x, y, w, h
    hot_n = hot_n + 1
end
local function over_hot(px, py)
    for i = 0, hot_n - 1 do
        local j = i * 4
        if px >= hot[j + 1] and py >= hot[j + 2]
           and px <= hot[j + 1] + hot[j + 3] and py <= hot[j + 2] + hot[j + 4] then
            return true
        end
    end
    return false
end

-- ---------------------------------------------------------------- helpers
local function approach(cur, target, rate, dt) return cur + (target - cur) * min(1, rate * dt) end
local function clamp(v, lo, hi) if v < lo then return lo elseif v > hi then return hi end return v end
local function inside(px, py, x, y, w, h)
    return px >= x and py >= y and px <= x + w and py <= y + h
end
local function fmt_time(sec)
    sec = floor(sec or 0); if sec < 0 then sec = 0 end
    return string.format("%d:%02d", floor(sec / 60), sec % 60)
end

-- Proportional first guess then walk to the exact fit: a 90-character stream title used to cost
-- ~80 text.width calls per frame with a naive one-character-at-a-time loop.
local function fit(s, fnt, w)
    if not s or s == "" or w <= 6 then return "" end
    local full = text.width(fnt, s)
    if full <= w then return s end
    local n = clamp(floor(#s * w / full), 1, #s)
    while n > 1 and text.width(fnt, s:sub(1, n) .. "..") > w do n = n - 1 end
    while n < #s and text.width(fnt, s:sub(1, n + 1) .. "..") <= w do n = n + 1 end
    return s:sub(1, n) .. ".."
end

local function send_cmd(cmd)
    cmd_seq = cmd_seq + 1
    set_str("audio_hud_cmd", cmd)
    set_str("audio_hud_cmd_t", tostring(cmd_seq))
end
local function save_rect()
    set_num("audio_hud_x", pos_x); set_num("audio_hud_y", pos_y)
    set_num("audio_hud_scale", scale)
end

-- ---------------------------------------------------------------- glyphs
-- Drawn from primitives, never from font glyphs: the panel font is whatever the theme picked and
-- cannot be relied on to carry an arrow, a heart or a shuffle mark.
local function ic_play(x, y, s, r, g, b, a)
    draw.line(x - s * .32, y - s * .5, x - s * .32, y + s * .5, r, g, b, a, s * .17)
    draw.line(x - s * .32, y - s * .5, x + s * .48, y,          r, g, b, a, s * .17)
    draw.line(x - s * .32, y + s * .5, x + s * .48, y,          r, g, b, a, s * .17)
end
local function ic_pause(x, y, s, r, g, b, a)
    draw.rect(x - s * .38, y - s * .5, x - s * .1, y + s * .5, r, g, b, a, 0)
    draw.rect(x + s * .1,  y - s * .5, x + s * .38, y + s * .5, r, g, b, a, 0)
end
local function ic_playpause(x, y, s, t, r, g, b, a)
    if t > 0.5 then ic_pause(x, y, s, r, g, b, a) else ic_play(x, y, s, r, g, b, a) end
end
local function ic_prev(x, y, s, r, g, b, a)
    draw.rect(x - s * .5, y - s * .45, x - s * .32, y + s * .45, r, g, b, a, 0)
    draw.line(x - s * .26, y - s * .45, x - s * .26, y + s * .45, r, g, b, a, s * .15)
    draw.line(x - s * .26, y - s * .45, x + s * .45, y,           r, g, b, a, s * .15)
    draw.line(x - s * .26, y + s * .45, x + s * .45, y,           r, g, b, a, s * .15)
end
local function ic_next(x, y, s, r, g, b, a)
    draw.line(x - s * .45, y - s * .45, x + s * .26, y,           r, g, b, a, s * .15)
    draw.line(x - s * .45, y + s * .45, x + s * .26, y,           r, g, b, a, s * .15)
    draw.line(x - s * .45, y - s * .45, x - s * .45, y + s * .45, r, g, b, a, s * .15)
    draw.rect(x + s * .32, y - s * .45, x + s * .5, y + s * .45,  r, g, b, a, 0)
end
local function ic_shuffle(x, y, s, r, g, b, a)
    local t = s * .13
    draw.line(x - s * .5, y - s * .3, x - s * .1, y - s * .3, r, g, b, a, t)
    draw.line(x - s * .1, y - s * .3, x + s * .3, y + s * .3, r, g, b, a, t)
    draw.line(x - s * .5, y + s * .3, x - s * .1, y + s * .3, r, g, b, a, t)
    draw.line(x - s * .1, y + s * .3, x + s * .3, y - s * .3, r, g, b, a, t)
    draw.line(x + s * .16, y - s * .44, x + s * .38, y - s * .3, r, g, b, a, t)
    draw.line(x + s * .16, y - s * .16, x + s * .38, y - s * .3, r, g, b, a, t)
    draw.line(x + s * .16, y + s * .44, x + s * .38, y + s * .3, r, g, b, a, t)
    draw.line(x + s * .16, y + s * .16, x + s * .38, y + s * .3, r, g, b, a, t)
end
local function ic_repeat(x, y, s, one, r, g, b, a)
    local t = s * .13
    draw.line(x - s * .42, y - s * .3, x + s * .42, y - s * .3, r, g, b, a, t)
    draw.line(x + s * .42, y - s * .3, x + s * .42, y,          r, g, b, a, t)
    draw.line(x + s * .24, y - s * .14, x + s * .42, y,         r, g, b, a, t)
    draw.line(x + s * .5,  y - s * .14, x + s * .42, y,         r, g, b, a, t)
    draw.line(x - s * .42, y + s * .3, x + s * .42, y + s * .3, r, g, b, a, t)
    draw.line(x - s * .42, y + s * .3, x - s * .42, y,          r, g, b, a, t)
    draw.line(x - s * .24, y + s * .14, x - s * .42, y,         r, g, b, a, t)
    draw.line(x - s * .5,  y + s * .14, x - s * .42, y,         r, g, b, a, t)
    if one then draw.rect(x - s * .07, y - s * .1, x + s * .07, y + s * .1, r, g, b, a, 0) end
end
local function ic_vol(x, y, s, vol, mute, r, g, b, a)
    draw.rect(x - s * .5, y - s * .17, x - s * .28, y + s * .17, r, g, b, a, 0)
    draw.line(x - s * .28, y - s * .17, x - s * .05, y - s * .5, r, g, b, a, s * .13)
    draw.line(x - s * .05, y - s * .5,  x - s * .05, y + s * .5, r, g, b, a, s * .13)
    draw.line(x - s * .05, y + s * .5,  x - s * .28, y + s * .17, r, g, b, a, s * .13)
    if mute then
        local rr, gg, bb = theme.red()
        draw.line(x + s * .1, y - s * .3, x + s * .48, y + s * .3, rr, gg, bb, a, s * .14)
        draw.line(x + s * .48, y - s * .3, x + s * .1, y + s * .3, rr, gg, bb, a, s * .14)
    else
        for i = 1, 3 do
            local on = vol >= (i - 1) * 0.33 + 0.08
            local xx = x + s * (0.02 + i * 0.16)
            local hh = s * (0.1 + i * 0.11)
            draw.line(xx, y - hh, xx, y + hh, r, g, b, on and a or floor(a * 0.22), s * .11)
        end
    end
end
local function chevron(x, y, s, up, r, g, b, a)
    if up then
        draw.line(x - s, y + s * .45, x, y - s * .45, r, g, b, a, 1.5)
        draw.line(x, y - s * .45, x + s, y + s * .45, r, g, b, a, 1.5)
    else
        draw.line(x - s, y - s * .45, x, y + s * .45, r, g, b, a, 1.5)
        draw.line(x, y + s * .45, x + s, y - s * .45, r, g, b, a, 1.5)
    end
end

-- ---------------------------------------------------------------- shared widgets
-- A button that draws AND hit-tests. Every layout places these; the click plumbing lives here once.
local function btn(c, x, y, w, h, kind)
    hot_add(x, y, w, h)
    local hov = c.idle and inside(c.mx, c.my, x, y, w, h)
    local cx, cy, s = x + w * 0.5, y + h * 0.5, min(w, h) * 0.62
    local tr, tg, tb = c.txt[1], c.txt[2], c.txt[3]
    local a = A(hov and 255 or 215)
    if kind == "play" then
        draw.circle(cx, cy, min(w, h) * 0.5, c.ar, c.ag, c.ab, A(hov and 255 or 235))
        ic_playpause(cx, cy, s * .78, sm_play, c.bg[1], c.bg[2], c.bg[3], 255)
    elseif kind == "prev" then ic_prev(cx, cy, s, tr, tg, tb, a)
    elseif kind == "next" then ic_next(cx, cy, s, tr, tg, tb, a)
    elseif kind == "pp"   then ic_playpause(cx, cy, s, sm_play, tr, tg, tb, a)
    elseif kind == "shuffle" then
        local on = c.s.shuffle
        if on then ic_shuffle(cx, cy, s, c.ar, c.ag, c.ab, A(255))
        else       ic_shuffle(cx, cy, s, tr, tg, tb, A(hov and 235 or 120)) end
    elseif kind == "repeat" then
        local rm = c.s.rmode
        if rm > 0 then ic_repeat(cx, cy, s, rm == 2, c.ar, c.ag, c.ab, A(255))
        else           ic_repeat(cx, cy, s, false, tr, tg, tb, A(hov and 235 or 120)) end
    elseif kind == "vol" then
        ic_vol(cx, cy, s, muted and 0 or c.s.volume, muted, tr, tg, tb, a)
    end
    if hov and c.click then
        c.used = true
        if kind == "play" or kind == "pp" then send_cmd("play_pause")
        elseif kind == "prev" then send_cmd("prev")
        elseif kind == "next" then send_cmd("next")
        elseif kind == "shuffle" then send_cmd("shuffle")
        elseif kind == "repeat" then send_cmd("repeat")
        elseif kind == "vol" then
            muted = not muted
            set_num("audio_hud_mute", muted and 1 or 0)
            if muted then
                if c.s.volume > 0.001 then
                    last_vol = c.s.volume
                    set_num("audio_hud_last_vol", floor(last_vol * 100))
                end
                send_cmd("volume:0")
            else
                if last_vol < 0.01 then last_vol = 0.7 end
                send_cmd(string.format("volume:%.3f", last_vol))
            end
        end
    end
    return hov
end

-- Control row. `set` picks how many controls fit: "full" 6, "mid" 4, "tiny" 3.
-- Returns the width it occupied so a layout can right-align around it.
local CTRL_SETS = {
    full = { "shuffle", "prev", "play", "next", "repeat", "vol" },
    mid  = { "prev", "play", "next", "repeat" },
    tiny = { "prev", "play", "next" },
}
local function ctrl_w(c, set, u)
    local n = #CTRL_SETS[set]
    return n * (u * 1.5) + (n - 1) * (u * 0.35) + u * 0.6   -- play button is wider
end
local function ctrls(c, x, y, set, u)
    local list = CTRL_SETS[set]
    local bw, gap = u * 1.5, u * 0.35
    local cx = x
    for _, k in ipairs(list) do
        local w = (k == "play") and (u * 2.1) or bw
        btn(c, cx, y, w, u * 1.7, k)
        cx = cx + w + gap
    end
    return cx - gap - x
end

-- Cover art. Cover-crops so a 16:9 browser thumbnail fills a square instead of letterboxing; falls
-- back to a tinted plate built from the accent when the source publishes nothing.
local function art(c, x, y, w, h, round)
    local drew = false
    if c.s.art ~= "" then
        draw.push_clip(x, y, x + w, y + h)
        local iw, ih = draw.preview_image_size(c.s.art)
        if iw and iw > 0 and ih and ih > 0 then
            local sc = max(w / iw, h / ih)
            local dw, dh = iw * sc, ih * sc
            local ox, oy = x + (w - dw) * 0.5, y + (h - dh) * 0.5
            drew = draw.preview_image(c.s.art, ox, oy, ox + dw, oy + dh, 1.0, false)
        else
            drew = draw.preview_image(c.s.art, x, y, x + w, y + h, 1.0, true)
        end
        draw.pop_clip()
    end
    if not drew then
        draw.rect(x, y, x + w, y + h, c.track[1], c.track[2], c.track[3], A(235), round or 0)
        draw.circle(x + w * 0.5, y + h * 0.5, min(w, h) * 0.19, c.ar, c.ag, c.ab, A(150))
        draw.circle(x + w * 0.5, y + h * 0.5, min(w, h) * 0.07, c.bg[1], c.bg[2], c.bg[3], A(255))
    end
    draw.rect_outline(x, y, x + w, y + h, 0, 0, 0, A(120), round or 0, 1)
    return drew
end

-- Vinyl: black disc, grooves, cover art on the label, spindle.
local function disc(c, cx, cy, rad)
    draw.circle(cx, cy, rad, 10, 12, 15, A(255))
    for i = 1, 3 do
        draw.circle_outline(cx, cy, rad * (0.55 + i * 0.14), 34, 36, 42, A(110), 0.8)
    end
    local lab = rad * 0.46
    draw.push_clip(cx - lab, cy - lab, cx + lab, cy + lab)
    art(c, cx - lab, cy - lab, lab * 2, lab * 2, lab)
    draw.pop_clip()
    draw.circle_outline(cx, cy, lab, 0, 0, 0, A(140), 0.9)
    local hx = cx + cos(spin + pi * 0.25) * rad * 0.72
    local hy = cy + sin(spin + pi * 0.25) * rad * 0.72
    draw.circle(hx, hy, rad * 0.1, 255, 255, 255, A(38))
    draw.circle(cx, cy, rad * 0.09, 12, 14, 17, A(255))
end

-- Progress ring. draw has no arc primitive, so the ring is short chords around the circumference.
local function ring(c, cx, cy, rad, frac, thick)
    local segs = 44
    draw.circle_outline(cx, cy, rad, c.track[1], c.track[2], c.track[3], A(235), thick)
    local n = floor(segs * clamp(frac, 0, 1) + 0.5)
    for i = 0, n - 1 do
        local a0 = -pi * 0.5 + (i / segs) * pi * 2
        local a1 = -pi * 0.5 + ((i + 1) / segs) * pi * 2
        draw.line(cx + cos(a0) * rad, cy + sin(a0) * rad,
                  cx + cos(a1) * rad, cy + sin(a1) * rad, c.ar, c.ag, c.ab, A(255), thick)
    end
end

local function spectrum(c, x, y, w, h, n, alpha)
    local peak = c.s.peak
    local gap = max(1, w / n * 0.14)
    local bw = (w - gap * (n - 1)) / n
    if bw < 0.6 then return end
    local inv = peak > 0.001 and (1 / peak) or 0
    for i = 0, n - 1 do
        local v
        if inv > 0 then v = (c.s.spec[i % 32] or 0) * inv
        else v = (0.5 + 0.5 * sin(c.now * 3.1 - i * 0.32)) * (c.s.playing and (0.3 + 0.6 * c.s.volume) or 0.06) end
        if v > sm_spec[i % 32] then sm_spec[i % 32] = v
        else sm_spec[i % 32] = max(v, sm_spec[i % 32] - c.dt * 2.6) end
        local bh = max(1, h * sm_spec[i % 32])
        local bx = x + i * (bw + gap)
        draw.rect(bx, y + h - bh, bx + bw, y + h, c.ar, c.ag, c.ab, A(alpha or 230), 1)
    end
end

-- Scrub bar. Hover previews, click seeks, and the tooltip only shows when there is a duration.
local function scrub(c, x, y, w, thick, knob)
    local hov = c.idle and inside(c.mx, c.my, x, y - 4, w, thick + 8)
    local frac = c.s.dur > 0.01 and clamp(c.s.pos / c.s.dur, 0, 1) or 0
    draw.rect(x, y, x + w, y + thick, c.track[1], c.track[2], c.track[3], A(255), thick * 0.5)
    if c.s.dur > 0.01 then
        if hov then
            local hf = clamp((c.mx - x) / w, 0, 1)
            draw.rect(x, y - 1, x + w * hf, y + thick + 1, c.ar, c.ag, c.ab, A(95), thick * 0.5)
            if c.click then send_cmd(string.format("seek:%.4f", hf)) end
        end
        draw.rect(x, y, x + w * sm_prog, y + thick, c.ar, c.ag, c.ab, A(255), thick * 0.5)
        if knob then draw.circle(x + w * sm_prog, y + thick * 0.5, thick * 1.35, c.ar, c.ag, c.ab, A(255)) end
    else
        -- live stream: an indeterminate sweep instead of a position
        local ph = (c.now * 0.55) % 1
        local sw = w * 0.28
        local sx = x + (w + sw) * ph - sw
        local l, r = max(x, sx), min(x + w, sx + sw)
        if r > l then draw.rect(l, y, r, y + thick, c.ar, c.ag, c.ab, A(255), thick * 0.5) end
    end
    return frac
end

-- Title that marquees inside its own clip rather than painting past the panel edge.
local function title_mq(c, fnt, x, y, w, str)
    local tw = text.width(fnt, str)
    draw.push_clip(x, y - 2, x + w, y + text.height(fnt) + 2)
    if tw <= w then
        text.draw(fnt, x, y, c.txt[1], c.txt[2], c.txt[3], A(255), str)
    else
        local over = tw - w + 20
        marquee_off = marquee_off + c.dt * 30
        if marquee_off > over + 36 then marquee_off = -26 end
        text.draw(fnt, x - clamp(marquee_off, 0, over), y, c.txt[1], c.txt[2], c.txt[3], A(255), str)
    end
    draw.pop_clip()
end
-- Baseline for the line under `fnt` at `y`, `gap` design-units below it. Fonts do not scale
-- with the panel, so a fixed u-offset closes up and overlaps at the low end of the scale range;
-- taking the larger of the two leaves every layout untouched wherever the offset already cleared.
local function under(y, fnt, gap)
    return y + max(gap, text.height(fnt))
end
local function sub(c, fnt, x, y, w, str, alpha)
    text.draw(fnt, x, y, c.dim[1], c.dim[2], c.dim[3], A(alpha or 220), fit(str, fnt, w))
end
local function times(c, fnt, x, y, w)
    text.draw(fnt, x, y, c.dim[1], c.dim[2], c.dim[3], A(215), fmt_time(c.s.pos))
    local d = c.s.dur > 0.01 and fmt_time(c.s.dur) or "LIVE"
    text.draw(fnt, x + w - text.width(fnt, d), y, c.dim[1], c.dim[2], c.dim[3], A(215), d)
end
local function shell(c, x, y, w, h, rail)
    draw.rect(x + 2, y + 4, x + w + 2, y + h + 4, 0, 0, 0, A(85), 8)
    draw.rect(x, y, x + w, y + h, c.bg[1], c.bg[2], c.bg[3], A(242), 7)
    if rail then
        draw.push_clip(x, y, x + 3 * c.u * 0.25 + 2, y + h)
        draw.rect(x, y, x + w, y + h, c.ar, c.ag, c.ab, 255, 7)
        draw.pop_clip()
    end
end

-- =============================================================== layouts
-- Each gets c: { x,y,w,h,u (unit=scale), s (snapshot), colours, mx,my, click, idle, now, dt }.

local function L_vinyl(c)
    local u, x, y, w = c.u, c.x, c.y, c.w
    shell(c, x, y, w, c.h, true)
    local pad = 7 * u
    local hy = y + pad
    text.draw(font.tiny, x + pad + 3 * u, hy, c.ar, c.ag, c.ab, A(255), c.s.source:upper())
    local r = 15 * u
    disc(c, x + pad + 3 * u + r, y + 26 * u + r, r)
    local bx = x + pad + 3 * u + r * 2 + 7 * u
    local bw = x + w - pad - bx
    local ty = y + 24 * u
    local ay = under(ty, font.item, 14 * u)
    title_mq(c, font.item, bx, ty, bw, c.s.title)
    sub(c, font.small, bx, ay, bw, c.s.artist)
    local sy = max(y + 50 * u, ay + text.height(font.small) + 1 * u)
    local by = y + c.h - 30 * u
    spectrum(c, bx, sy, bw, max(2 * u, (by - 4 * u) - sy), 22)
    scrub(c, x + pad, by, w - pad * 2, 3 * u, true)
    -- the duration is right-aligned, so it has to stop short of the resize grip in the corner
    times(c, font.tiny, x + pad, by + 5 * u, w - pad * 2 - 7 * u)
    local cw = ctrl_w(c, "full", 9 * u)
    ctrls(c, x + (w - cw) * 0.5, y + c.h - 16 * u, "full", 9 * u)
end

local function L_slim(c)
    local u, x, y, w, h = c.u, c.x, c.y, c.w, c.h
    shell(c, x, y, w, h, true)
    local pad = 5 * u
    local a = h - pad * 2 - 3 * u
    art(c, x + pad + 3 * u, y + pad, a, a, 3 * u)
    local cw = ctrl_w(c, "mid", 8 * u)
    local cx0 = x + w - 13 * u - cw          -- clear of the resize grip in the corner
    local bx = x + pad + 3 * u + a + 6 * u
    local bw = cx0 - 6 * u - bx
    -- A 36-unit bar cannot hold two unscaled text lines at the bottom of the scale range, so the
    -- artist drops out and the title centres rather than being pushed through the floor.
    local ty = y + pad + 1 * u
    local ay = under(ty, font.small, 11 * u)
    local ah = (c.s.artist ~= "") and text.height(font.tiny) or 0
    if ah > 0 and ay + ah <= y + h - 3 * u then
        title_mq(c, font.small, bx, ty, bw, c.s.title)
        sub(c, font.tiny, bx, ay, bw, c.s.artist)
    else
        title_mq(c, font.small, bx, y + (h - text.height(font.small)) * 0.5 - 1 * u, bw, c.s.title)
    end
    ctrls(c, cx0, y + (h - 8 * 1.7 * u) * 0.5, "mid", 8 * u)
    scrub(c, x, y + h - 2 * u, w, 2 * u, false)
end

local function L_album(c)
    local u, x, y, w, h = c.u, c.x, c.y, c.w, c.h
    shell(c, x, y, w, h, false)

    -- The art is inset as a card rather than bled to the panel edge: it is drawn rounded on all
    -- four sides, so flush against a rounded shell it read as a tile hanging off the left instead
    -- of part of the panel.
    local pad = 6 * u
    local a   = h - pad * 2
    art(c, x + pad, y + pad, a, a, 5 * u)

    local bx = x + pad + a + 8 * u
    local bw = (x + w - 12 * u) - bx          -- right pad clears the fold chevron

    -- The transport row is the fixed anchor and everything above flows off it, so no row can be
    -- pushed through the panel floor. Fonts are a fixed pixel size while the layout scales with u,
    -- so the stack is measured with text.height rather than assumed from u-multiples.
    local cu = 8 * u
    local ch = cu * 1.7
    local by = y + h - pad - ch
    local cy = by + ch * 0.5

    local tf   = font.tiny
    local pstr = fmt_time(c.s.pos)
    local dstr = c.s.dur > 0.01 and fmt_time(c.s.dur) or "LIVE"
    local pw, dw = text.width(tf, pstr), text.width(tf, dstr)
    local tiy  = cy - text.height(tf) * 0.5
    local rx   = x + w - 14 * u               -- keeps the duration clear of the resize grip
    text.draw(tf, bx, tiy, c.dim[1], c.dim[2], c.dim[3], A(215), pstr)
    text.draw(tf, rx - dw, tiy, c.dim[1], c.dim[2], c.dim[3], A(215), dstr)

    -- transport centred in whatever the two time labels leave behind, dropping to a smaller set
    -- rather than growing under them when the panel is scaled down
    local cs, ce = bx + pw + 7 * u, rx - dw - 7 * u
    local set = "full"
    if ce - cs < ctrl_w(c, "full", cu) then
        set = (ce - cs < ctrl_w(c, "mid", cu)) and "tiny" or "mid"
    end
    local cw = ctrl_w(c, set, cu)
    ctrls(c, cs + max(0, (ce - cs - cw) * 0.5), by, set, cu)

    local sy = by - 8 * u
    scrub(c, bx, sy, bw, 3 * u, true)

    -- The spectrum sits behind the text instead of taking a row of its own, and only while there is
    -- audio to show: its bars are floored at one pixel, so a stopped source painted a line of stubs
    -- directly above the scrub that read as a second, broken progress bar.
    local top  = y + pad
    local sbot = sy - 5 * u
    if c.s.playing or c.s.peak > 0.001 then
        draw.push_clip(bx, top, bx + bw, sbot)
        spectrum(c, bx, sbot - 16 * u, bw, 16 * u, 28, 55)
        draw.pop_clip()
    end

    local th  = text.height(font.item)
    local ah  = (c.s.artist ~= "") and text.height(font.small) or 0
    local blk = th + (ah > 0 and (ah + 1 * u) or 0)
    local tty = top + max(0, (sbot - top - blk) * 0.5)
    title_mq(c, font.item, bx, tty, bw, c.s.title)
    if ah > 0 then sub(c, font.small, bx, tty + th + 1 * u, bw, c.s.artist) end
end

local function L_portrait(c)
    local u, x, y, w, h = c.u, c.x, c.y, c.w, c.h
    shell(c, x, y, w, h, false)
    local pad = 6 * u
    local iw  = w - pad * 2

    -- Laid out from the floor up, then the art takes whatever is left: a full-width square left
    -- the four text/control rows 62px to share in a 206px panel and they stacked on each other.
    local cu = 9 * u
    local cw = ctrl_w(c, "tiny", cu)
    local ch = cu * 1.7
    local by = y + h - pad - ch
    ctrls(c, x + (w - cw) * 0.5, by, "tiny", cu)

    local tf  = font.tiny
    local tiy = by - 4 * u - text.height(tf)
    times(c, tf, x + pad, tiy, iw)
    local sy = tiy - 6 * u
    scrub(c, x + pad, sy, iw, 3 * u, false)

    local th  = text.height(font.item)
    local ah  = (c.s.artist ~= "") and text.height(font.small) or 0
    local blk = th + (ah > 0 and (ah + 1 * u) or 0)
    local a   = max(0, min(iw, (sy - 6 * u) - blk - 5 * u - (y + pad)))
    art(c, x + (w - a) * 0.5, y + pad, a, a, 4 * u)

    local tty = y + pad + a + 5 * u
    title_mq(c, font.item, x + pad, tty, iw, c.s.title)
    if ah > 0 then sub(c, font.small, x + pad, tty + th + 1 * u, iw, c.s.artist) end
end

local function L_bare(c)
    local u, x, y, w = c.u, c.x, c.y, c.w
    -- no shell: a soft plate under the text instead of a box, so it stays readable over bright ground
    draw.rect(x - 2, y - 2, x + w + 2, y + c.h + 2, 0, 0, 0, A(70), 5)
    local a = 22 * u
    art(c, x, y, a, a, 3 * u)
    local bx = x + a + 6 * u
    local bw = w - a - 6 * u
    text.draw(font.tiny, bx, y, c.ar, c.ag, c.ab, A(255), c.s.source:upper())
    local ty = under(y, font.tiny, 9 * u)
    title_mq(c, font.item, bx, ty, bw, c.s.title)
    sub(c, font.small, bx, under(ty, font.item, 14 * u), bw, c.s.artist)
    scrub(c, x, y + 40 * u, w, 2 * u, false)
    times(c, font.tiny, x, y + 45 * u, w)
    ctrls(c, x, y + c.h - 13 * u, "full", 8 * u)
end

local function L_wave(c)
    local u, x, y, w, h = c.u, c.x, c.y, c.w, c.h
    shell(c, x, y, w, h, true)
    draw.push_clip(x, y, x + w, y + h)
    spectrum(c, x, y + h - 24 * u, w, 24 * u, 40)
    draw.pop_clip()
    local pad = 6 * u
    local a = 16 * u
    art(c, x + pad + 3 * u, y + pad, a, a, 2 * u)
    local cw = ctrl_w(c, "mid", 8 * u)
    local bx = x + pad + 3 * u + a + 5 * u
    local bw = x + w - pad - cw - 6 * u - bx
    title_mq(c, font.item, bx, y + pad, bw, c.s.title)
    sub(c, font.tiny, bx, under(y + pad, font.item, 13 * u), bw, c.s.artist)
    ctrls(c, x + w - pad - cw, y + pad + 1 * u, "mid", 8 * u)
    -- anchored off the panel floor rather than a fixed offset, which dropped the row through it
    local ty = y + h - 4 * u - text.height(font.tiny)
    text.draw(font.tiny, x + pad, ty, c.dim[1], c.dim[2], c.dim[3], A(230), fmt_time(c.s.pos))
    local dstr = c.s.dur > 0.01 and fmt_time(c.s.dur) or "LIVE"
    local dw = text.width(font.tiny, dstr)
    local dx = x + w - 13 * u - dw          -- clear of the resize grip in the corner
    local sx = x + pad + text.width(font.tiny, fmt_time(c.s.pos)) + 5 * u
    scrub(c, sx, ty + 4 * u, (dx - 5 * u) - sx, 3 * u, true)
    text.draw(font.tiny, dx, ty, c.dim[1], c.dim[2], c.dim[3], A(230), dstr)
end

local function L_capsule(c)
    local u, x, y, w, h = c.u, c.x, c.y, c.w, c.h
    draw.rect(x + 2, y + 4, x + w + 2, y + h + 4, 0, 0, 0, A(85), h * 0.5)
    draw.rect(x, y, x + w, y + h, c.bg[1], c.bg[2], c.bg[3], A(242), h * 0.5)
    local rad = (h - 5 * u) * 0.5
    local cx, cy = x + 3 * u + rad, y + h * 0.5
    disc(c, cx, cy, rad - 2 * u)
    ring(c, cx, cy, rad, c.frac, 2 * u)
    local cw = ctrl_w(c, "mid", 8 * u)
    local bx = cx + rad + 6 * u
    local bw = x + w - 7 * u - cw - 6 * u - bx
    local ty = y + 7 * u
    title_mq(c, font.small, bx, ty, bw, c.s.title)
    sub(c, font.tiny, bx, under(ty, font.small, 11 * u), bw, c.s.artist)
    ctrls(c, x + w - 7 * u - cw, y + (h - 13 * u) * 0.5, "mid", 8 * u)
end

local function L_ticker(c)
    local u, x, y, w, h = c.u, c.x, c.y, c.w, c.h
    shell(c, x, y, w, h, true)
    local a = h - 6 * u
    art(c, x + 5 * u, y + 3 * u, a, a, 2 * u)
    local cw = ctrl_w(c, "tiny", 7 * u)
    local cx0 = x + w - 16 * u - cw         -- the fold chevron owns the top-right corner
    local bx = x + 5 * u + a + 4 * u
    local bw = cx0 - 5 * u - bx
    -- The text never stops, so a title of any length arrives in full instead of being truncated.
    local line = c.s.title .. "   \194\183   " .. c.s.artist .. "   \194\183   " .. c.s.source .. "   \194\183   "
    local lw = text.width(font.small, line)
    if lw > 0 then
        marquee_off = (marquee_off + c.dt * 34) % lw
        draw.push_clip(bx, y, bx + bw, y + h)
        text.draw(font.small, bx - marquee_off, y + 3 * u, c.txt[1], c.txt[2], c.txt[3], A(255), line)
        text.draw(font.small, bx - marquee_off + lw, y + 3 * u, c.txt[1], c.txt[2], c.txt[3], A(255), line)
        draw.pop_clip()
    end
    ctrls(c, cx0, y + (h - 12 * u) * 0.5, "tiny", 7 * u)
    scrub(c, x, y + h - 2 * u, w, 2 * u, false)
end

local function L_cassette(c)
    local u, x, y, w, h = c.u, c.x, c.y, c.w, c.h
    shell(c, x, y, w, h, true)
    local pad = 6 * u
    local wx, wy = x + pad + 3 * u, y + pad
    local ww, wh = w - pad * 2 - 3 * u, 34 * u
    draw.rect(wx, wy, wx + ww, wy + wh, 8, 9, 12, A(255), 3 * u)
    draw.rect(wx + ww * 0.12, wy + wh * 0.44, wx + ww * 0.88, wy + wh * 0.56, 62, 44, 28, A(255), 1)
    -- the supply reel slows as the take-up fills, so the reels encode position rather than decorate
    local rad = wh * 0.34
    for i, cxr in ipairs({ wx + ww * 0.28, wx + ww * 0.72 }) do
        local rate = (i == 1) and (0.6 + c.frac * 1.1) or (1.7 - c.frac * 1.1)
        local ang = (spin * rate) % (pi * 2)
        draw.circle(cxr, wy + wh * 0.5, rad, 20, 23, 28, A(255))
        draw.circle(cxr, wy + wh * 0.5, rad * 0.4, c.ar, c.ag, c.ab, A(235))
        for k = 0, 3 do
            local t = ang + k * pi * 0.5
            draw.line(cxr + cos(t) * rad * 0.45, wy + wh * 0.5 + sin(t) * rad * 0.45,
                      cxr + cos(t) * rad * 0.92, wy + wh * 0.5 + sin(t) * rad * 0.92,
                      210, 214, 224, A(120), 1.1)
        end
    end
    local ly = wy + wh + 5 * u
    local a = 15 * u
    art(c, wx, ly, a, a, 2 * u)
    title_mq(c, font.small, wx + a + 5 * u, ly, ww - a - 5 * u, c.s.title)
    sub(c, font.tiny, wx + a + 5 * u, under(ly, font.small, 11 * u), ww - a - 5 * u, c.s.artist)
    -- the duration is right-aligned, so it has to stop short of the resize grip in the corner
    times(c, font.tiny, wx, y + h - 22 * u, ww - 7 * u)
    local cw = ctrl_w(c, "full", 8 * u)
    ctrls(c, x + (w - cw) * 0.5, y + h - 15 * u, "full", 8 * u)
end

local function L_panel(c)
    -- Built out of the panel kit's language so it sits next to Pools and Session as a peer.
    local u, x, y, w, h = c.u, c.x, c.y, c.w, c.h
    shell(c, x, y, w, h, true)
    local pad = 8 * u
    local bx = x + pad + 2 * u
    local bw = x + w - pad - bx
    text.draw_spaced(font.label, bx, y + 6 * u, c.txt[1], c.txt[2], c.txt[3], A(255), "NOW PLAYING", 2)
    local hy = y + 19 * u
    draw.line(bx, hy, x + w - pad, hy, c.dim[1], c.dim[2], c.dim[3], A(60), 1)
    local a = 20 * u
    local ty = hy + 5 * u
    art(c, bx, ty, a, a, 2 * u)
    title_mq(c, font.small, bx + a + 5 * u, ty, bw - a - 5 * u, c.s.title)
    local ay = under(ty, font.small, 11 * u)
    sub(c, font.tiny, bx + a + 5 * u, ay, bw - a - 5 * u, c.s.artist)
    local ry = max(hy + a + 9 * u, ay + text.height(font.tiny) + 2 * u)
    local function row(label, value)
        text.draw(font.small, bx, ry, c.dim[1], c.dim[2], c.dim[3], A(255), label)
        local v = fit(value, font.small, bw - text.width(font.small, label) - 12 * u)
        text.draw(font.small, bx + bw - text.width(font.small, v), ry, c.txt[1], c.txt[2], c.txt[3], A(255), v)
        ry = under(ry, font.small, 12 * u)
    end
    row("Source", c.s.source ~= "" and c.s.source or "-")
    row("Time", fmt_time(c.s.pos) .. " / " .. (c.s.dur > 0.01 and fmt_time(c.s.dur) or "LIVE"))
    -- the same twenty-segment gauge the pool bars use
    local n, gap = 20, 1.5
    local sw = (bw - gap * (n - 1)) / n
    local on = floor(c.frac * n + 0.5)
    for i = 0, n - 1 do
        local sx = bx + i * (sw + gap)
        if i < on then draw.rect(sx, ry, sx + sw, ry + 3 * u, c.ar, c.ag, c.ab, A(245), 1)
        else draw.rect(sx, ry, sx + sw, ry + 3 * u, c.track[1], c.track[2], c.track[3], A(255), 1) end
    end
    local cw = ctrl_w(c, "full", 8 * u)
    ctrls(c, x + (w - cw) * 0.5, y + h - 14 * u, "full", 8 * u)
end

local function L_lower(c)
    local u, x, y, w, h = c.u, c.x, c.y, c.w, c.h
    shell(c, x, y, w, h, true)
    local pad = 6 * u
    local a = h - pad * 2 - 2 * u
    art(c, x + pad + 3 * u, y + pad, a, a, 3 * u)
    local cw = ctrl_w(c, "full", 8 * u)
    local tstr = fmt_time(c.s.pos) .. " / " .. (c.s.dur > 0.01 and fmt_time(c.s.dur) or "LIVE")
    local tw = text.width(font.small, tstr)
    local cx0 = x + w - 14 * u - cw         -- clear of the resize grip in the corner
    local bx = x + pad + 3 * u + a + 7 * u
    local bw = cx0 - tw - 12 * u - bx
    local ty = y + pad + 1 * u
    title_mq(c, font.item, bx, ty, bw, c.s.title)
    sub(c, font.small, bx, under(ty, font.item, 14 * u), bw, c.s.artist)
    ctrls(c, cx0, y + (h - 8 * 1.7 * u) * 0.5, "full", 8 * u)
    text.draw(font.small, cx0 - tw - 6 * u, y + (h - 8 * u) * 0.5,
              c.dim[1], c.dim[2], c.dim[3], A(220), tstr)
    scrub(c, x, y + h - 2.5 * u, w, 2.5 * u, false)
end

local function L_orb(c)
    local u, x, y, w = c.u, c.x, c.y, c.w
    local rad = w * 0.5
    local cx, cy = x + rad, y + rad
    draw.circle(cx, cy, rad, c.bg[1], c.bg[2], c.bg[3], A(230))
    draw.push_clip(cx - rad * 0.78, cy - rad * 0.78, cx + rad * 0.78, cy + rad * 0.78)
    art(c, cx - rad * 0.78, cy - rad * 0.78, rad * 1.56, rad * 1.56, rad)
    draw.pop_clip()
    ring(c, cx, cy, rad - 1.5 * u, c.frac, 2.5 * u)
    local cw = ctrl_w(c, "tiny", 7 * u)
    ctrls(c, x + (w - cw) * 0.5, y + w + 3 * u, "tiny", 7 * u)
    local ty = y + w + 16 * u
    text.draw(font.tiny, x + (w - text.width(font.tiny, fit(c.s.title, font.tiny, w * 2))) * 0.5, ty,
              c.txt[1], c.txt[2], c.txt[3], A(230), fit(c.s.title, font.tiny, w * 2))
end

-- ORDER MUST MATCH AUDIO_DESIGNS in theme.lua -- the setting stores an index.
local DESIGNS = {
    { n = "Vinyl Deck",   w = 300, h = 108, fw = 236, fh = 34, draw = L_vinyl },
    { n = "Slim Bar",     w = 300, h = 36,  fw = 236, fh = 36, draw = L_slim },
    { n = "Album Card",   w = 282, h = 72,  fw = 236, fh = 34, draw = L_album },
    { n = "Portrait",     w = 150, h = 206, fw = 200, fh = 34, draw = L_portrait },
    { n = "Bare",         w = 246, h = 100, fw = 236, fh = 30, draw = L_bare, bare = true },
    { n = "Waveform",     w = 292, h = 74,  fw = 292, fh = 22, draw = L_wave },
    { n = "Capsule",      w = 278, h = 44,  fw = 44,  fh = 44, draw = L_capsule, pill = true },
    { n = "Ticker",       w = 252, h = 26,  fw = 236, fh = 28, draw = L_ticker },
    { n = "Cassette",     w = 226, h = 132, fw = 226, fh = 34, draw = L_cassette },
    { n = "Panel Native", w = 226, h = 126, fw = 226, fh = 34, draw = L_panel },
    { n = "Lower Third",  w = 400, h = 50,  fw = 400, fh = 10, draw = L_lower },
    { n = "Orb",          w = 58,  h = 84,  fw = 38,  fh = 38, draw = L_orb, bare = true, pill = true },
}

-- Folded strip. One implementation for every design except the three whose fold IS their own shape
-- (Capsule and Orb keep their ring; Lower Third keeps its line), which are handled inline below.
local function draw_folded(c, d)
    local u, x, y, w, h = c.u, c.x, c.y, c.w, c.h
    if d.n == "Capsule" or d.n == "Orb" then
        local rad = w * 0.5
        local cx, cy = x + rad, y + rad
        draw.circle(cx, cy, rad, c.bg[1], c.bg[2], c.bg[3], A(235))
        draw.push_clip(cx - rad * 0.76, cy - rad * 0.76, cx + rad * 0.76, cy + rad * 0.76)
        art(c, cx - rad * 0.76, cy - rad * 0.76, rad * 1.52, rad * 1.52, rad)
        draw.pop_clip()
        ring(c, cx, cy, rad - 1.5 * u, c.frac, 2.2 * u)
        return
    end
    if d.n == "Lower Third" then
        draw.rect(x, y, x + w, y + h, c.track[1], c.track[2], c.track[3], A(235), 0)
        draw.rect(x, y, x + w * c.frac, y + h, c.ar, c.ag, c.ab, A(255), 0)
        return
    end
    -- The right-hand FOLD_SLOT belongs to the fold chevron (drawn by the main pass); nothing else is
    -- placed there, so the chevron never lands on top of a button.
    local slot = FOLD_SLOT * u
    if d.n == "Waveform" then
        shell(c, x, y, w, h, true)
        draw.push_clip(x, y, x + w - slot, y + h)
        spectrum(c, x + 5 * u, y + 3 * u, w - slot - 8 * u, h - 6 * u, 40)
        draw.pop_clip()
        return
    end
    if not d.bare then shell(c, x, y, w, h, true) end

    local pad = 4 * u
    local a = h - pad * 2 - 2 * u                 -- leave room for the progress line underneath
    local ax = x + pad + 3 * u
    art(c, ax, y + pad, a, a, 3 * u)

    -- prev / play-pause / next, right-aligned against the chevron slot
    local bs = clamp(h - 12 * u, 10 * u, 16 * u)
    local by = y + (h - 2 * u - bs) * 0.5
    local nx = x + w - slot - bs
    local px = nx - bs - 3 * u
    local vx = px - bs - 3 * u
    btn(c, vx, by, bs, bs, "prev")
    btn(c, px, by, bs, bs, "pp")
    btn(c, nx, by, bs, bs, "next")
    draw.line(x + w - slot + 1 * u, y + 7 * u, x + w - slot + 1 * u, y + h - 8 * u,
              c.dim[1], c.dim[2], c.dim[3], A(60), 1)

    -- title, then artist and time underneath when the strip is tall enough for two lines
    local bx = ax + a + 6 * u
    local bw = vx - 5 * u - bx
    if bw > 12 then
        local th, sh = text.height(font.small), text.height(font.tiny)
        local tstr = fmt_time(c.s.pos)
        if c.s.dur > 0.01 then tstr = tstr .. " / " .. fmt_time(c.s.dur) end
        if h - 2 * u >= th + sh + 4 * u then
            local ty = y + (h - 2 * u - th - sh - 1 * u) * 0.5
            text.draw(font.small, bx, ty, c.txt[1], c.txt[2], c.txt[3], A(255), fit(c.s.title, font.small, bw))
            local tw = text.width(font.tiny, tstr)
            local line = c.s.artist
            local lw = bw - tw - 6 * u
            if line ~= "" and lw > 20 then
                text.draw(font.tiny, bx, ty + th + 1 * u, c.dim[1], c.dim[2], c.dim[3], A(220), fit(line, font.tiny, lw))
                text.draw(font.tiny, bx + bw - tw, ty + th + 1 * u, c.dim[1], c.dim[2], c.dim[3], A(200), tstr)
            else
                text.draw(font.tiny, bx, ty + th + 1 * u, c.dim[1], c.dim[2], c.dim[3], A(200), fit(tstr, font.tiny, bw))
            end
        else
            text.draw(font.small, bx, y + (h - 2 * u - th) * 0.5,
                      c.txt[1], c.txt[2], c.txt[3], A(255), fit(c.s.title, font.small, bw))
        end
    end

    -- progress line along the bottom edge
    local lx0, lx1 = x + 7 * u, x + w - 7 * u
    local ly = y + h - 3.5 * u
    draw.rect(lx0, ly, lx1, ly + 1.5 * u, c.track[1], c.track[2], c.track[3], A(200), 1)
    if c.frac > 0 then
        draw.rect(lx0, ly, lx0 + (lx1 - lx0) * c.frac, ly + 1.5 * u, c.ar, c.ag, c.ab, A(255), 1)
    end
end

-- Reused across frames: a fresh table per frame would be pure GC churn on the render thread.
local C = { s = { spec = {} } }

-- =============================================================== main draw
features.on_draw("Audio Player", function(f)
    if not f.enabled then return end

    local now = ctx.time and ctx.time() or 0
    local dt = min(0.1, max(0.001, now - last_t))
    last_t = now

    -- which layout
    local st = menu.get_setting("Player Design")
    local di = 2
    if type(st) == "table" and st.value_index then di = st.value_index end
    local d = DESIGNS[di + 1] or DESIGNS[3]

    -- ---- snapshot ----
    local s = C.s
    s.title  = f.title  or ""
    s.artist = f.artist or ""
    s.source = f.source or ""
    s.art    = f.art    or ""
    s.pos    = f.position or 0
    s.dur    = f.duration or 0
    s.volume = f.volume or 0
    s.playing = f.playing and true or false
    s.shuffle = f.shuffle and true or false
    s.rmode  = floor(f.repeat_mode or 0)
    s.peak   = f.spectrum_peak or 0
    for i = 0, 31 do s.spec[i] = f[SPEC_KEYS[i]] or 0 end
    if s.title == "" then s.title = "No track playing" end
    if s.source == "" then s.source = "Offline" end

    local has_track = (f.title or "") ~= "" or (f.source or "") ~= ""
    sm_play  = approach(sm_play, s.playing and 1 or 0, 6, dt)
    sm_sleep = approach(sm_sleep, has_track and 1 or 0, 4, dt)
    g_fade   = 0.85 + 0.15 * sm_sleep
    if sm_play > 0.02 then spin = (spin + dt * 0.9 * sm_play) % (pi * 2) end
    if s.title ~= last_title then marquee_off = -26; last_title = s.title end

    local frac = s.dur > 0.01 and clamp(s.pos / s.dur, 0, 1) or 0
    if abs(frac - sm_prog) > 0.2 then sm_prog = frac else sm_prog = approach(sm_prog, frac, 6, dt) end

    -- ---- geometry ----
    local sw, sh = ctx.screen_w(), ctx.screen_h()
    scale = clamp(scale, SCALE_LO, SCALE_HI)
    local u = scale
    local w = (folded and d.fw or d.w) * u
    local h = (folded and d.fh or d.h) * u
    pos_x = clamp(pos_x, 0, max(0, sw - w))
    pos_y = clamp(pos_y, 0, max(0, sh - h))

    -- ---- interaction: raw input, only while the menu is up (the game hides the cursor otherwise) ----
    local live = menu.is_visible() and not menu.overlay_active()
    local mx, my = input.mouse_x(), input.mouse_y()
    local click = live and input.mouse_clicked(0)
    local held  = live and input.mouse_down(0)

    local grip = GRIP * u
    local gx, gy = pos_x + w - grip, pos_y + h - grip
    -- folded, the whole strip is the drag handle (its buttons are excluded through the hot set)
    local head_h = folded and h or min(h, 20 * u)
    local idle = live and own == nil
    local can_resize = not folded
    local hover_grip = live and can_resize and (own == "resize" or (idle and inside(mx, my, gx, gy, grip, grip)))

    -- Round designs (Capsule, Orb) have no room for a chevron: tapping the disc folds / unfolds.
    local tx, ty, tw, th
    if d.pill then
        if folded or d.n == "Orb" then tx, ty, tw, th = pos_x, pos_y, w, w
        else
            local rad = (h - 5 * u) * 0.5
            tx, ty, tw, th = pos_x + 3 * u, pos_y + h * 0.5 - rad, rad * 2, rad * 2
        end
    end

    if click and own == nil then
        local on_disc = tx and inside(mx, my, tx, ty, tw, th) and not over_hot(mx, my)
        if can_resize and inside(mx, my, gx, gy, grip, grip) then
            own = "resize"
            rz_mx, rz_my, rz_s = mx, my, scale
        elseif on_disc or (inside(mx, my, pos_x, pos_y, w, head_h) and not over_hot(mx, my)) then
            own = "drag"
            drag_dx, drag_dy = mx - pos_x, my - pos_y
            tap_x, tap_y, tap_ok = mx, my, on_disc and true or false
        end
    end
    if own == "resize" then
        if held then
            -- one scale factor rather than free width/height: twelve layouts with twelve aspect
            -- ratios cannot all survive an arbitrary box, and scaling keeps every one correct.
            local dpx = ((mx - rz_mx) + (my - rz_my)) * 0.5
            scale = clamp(rz_s + dpx / 160, SCALE_LO, SCALE_HI)
        else own = nil; save_rect() end
    elseif own == "drag" then
        if held then
            if abs(mx - tap_x) + abs(my - tap_y) > 4 then tap_ok = false end
            pos_x = clamp(mx - drag_dx, 0, max(0, sw - w))
            pos_y = clamp(my - drag_dy, 0, max(0, sh - h))
        else
            own = nil; save_rect()
            if tap_ok then
                folded = not folded
                set_num("audio_hud_fold", folded and 1 or 0)
            end
            tap_ok = false
        end
    end

    -- re-derive after this frame's input
    u = scale
    w = (folded and d.fw or d.w) * u
    h = (folded and d.fh or d.h) * u
    pos_x = clamp(pos_x, 0, max(0, sw - w))
    pos_y = clamp(pos_y, 0, max(0, sh - h))
    gx, gy = pos_x + w - grip, pos_y + h - grip

    -- ---- context ----
    C.x, C.y, C.w, C.h, C.u = pos_x, pos_y, w, h, u
    C.mx, C.my, C.click, C.idle, C.live = mx, my, click, idle, live
    C.now, C.dt, C.frac = now, dt, frac
    C.ar, C.ag, C.ab = theme.accent()
    C.txt   = { theme.item_name_normal() }
    C.dim   = { theme.item_desc_normal() }
    C.track = { theme.toggle_off_bg() }
    C.bg    = { theme.menu_bg() }

    -- ---- draw, clipped to the panel so nothing can escape it ----
    C.used = false
    hot_n = 0                       -- the drag check above has had its look at last frame's rects
    draw.push_clip(pos_x - 3, pos_y - 3, pos_x + w + 4, pos_y + h + 6)
    if folded then draw_folded(C, d) else d.draw(C) end
    draw.pop_clip()

    -- fold chevron, top-right of the header band; and the resize grip, bottom-right
    if not d.pill then
        local cx = folded and (pos_x + w - FOLD_SLOT * u * 0.5) or (pos_x + w - 7 * u)
        local cy = pos_y + (folded and (h - (d.n == "Lower Third" and 0 or 2 * u)) * 0.5 or 8 * u)
        chevron(cx, cy, 4 * u, folded, C.txt[1], C.txt[2], C.txt[3], A(200))
        hot_add(cx - 8 * u, cy - 8 * u, 16 * u, 16 * u)
        -- a control row can reach the top-right corner in the short layouts, so the chevron only
        -- takes a click no button already used
        if idle and not C.used and inside(mx, my, cx - 8 * u, cy - 8 * u, 16 * u, 16 * u) and click then
            folded = not folded
            set_num("audio_hud_fold", folded and 1 or 0)
        end
    end
    if not folded then
        local ga = (hover_grip or own == "resize") and 235 or (live and 110 or 45)
        for i = 1, 3 do
            local o = i * 3.4 * u
            draw.line(pos_x + w - o, pos_y + h - 2 * u, pos_x + w - 2 * u, pos_y + h - o,
                      C.txt[1], C.txt[2], C.txt[3], A(ga), 1.2)
        end
    end
end)
