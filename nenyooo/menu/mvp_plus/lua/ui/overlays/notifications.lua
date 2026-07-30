
-- Global notifications overlay. Draws the toast stack (top-right) once on top of
-- every theme, so notifications share one consistent look regardless of the active
-- theme. Status colours follow the theme palette (theme.green/red/yellow); neutral
-- toasts use white title + soft-grey message. Edit freely.
--
-- Toasts slide in from the right edge while fading in, dock, then slide back out +
-- fade on close. Cards auto-size to their text (clamped MIN_W..MAX_W); long messages
-- wrap onto multiple lines and the card grows taller to fit. When a toast above is
-- dismissed, the ones below glide up smoothly instead of snapping.
--
-- Toast feed comes from C++ via the `notify` table:
--   notify.count()                -> number of active toasts
--   notify.get(i)                 -> { title, message, color_type, create_time,
--                                       duration, closing, close_time, index }
--   notify.close(raw_index)       -> begin the fade-out for a toast
-- color_type: 0 neutral, 1 success, 2 error, 3 warning.
local GAP    = 7
local MARGIN = 14
local MIN_W  = 190
local MAX_W  = 380
local SLIDE  = 0.28
local stack_y = {}
local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
local function ease_out(p) p = clamp(p, 0, 1); local q = 1 - p; return 1 - q * q * q end
local function wrap_lines(font, str, max_px)
    local lines = {}
    if not str or str == "" then return lines end
    local line = nil
    for word in string.gmatch(str, "%S+") do
        local cand = line and (line .. " " .. word) or word
        if line and text.width(font, cand) > max_px then
            lines[#lines + 1] = line
            line = word
        else
            line = cand
        end
    end
    if line then lines[#lines + 1] = line end
    return lines
end
-- Accent corner ticks, matching the HUD panels (panel_kit.lua) -- 8 short L-strokes in the corners.
local function corner_ticks(x, y, w, h, t, r, g, b, a)
    draw.line(x, y, x + t, y, r, g, b, a, 1);                 draw.line(x, y, x, y + t, r, g, b, a, 1)
    draw.line(x + w - t, y, x + w, y, r, g, b, a, 1);         draw.line(x + w, y, x + w, y + t, r, g, b, a, 1)
    draw.line(x, y + h - t, x, y + h, r, g, b, a, 1);         draw.line(x, y + h, x + t, y + h, r, g, b, a, 1)
    draw.line(x + w - t, y + h, x + w, y + h, r, g, b, a, 1); draw.line(x + w, y + h - t, x + w, y + h, r, g, b, a, 1)
end
overlay.on_draw("notifications", function()
    local count = notify.count()
    if count == 0 then stack_y = {}; return end
    local sw = ctx.screen_w()
    local t  = ctx.time()
    local dt = ctx.delta()
    -- Match the HUD panel chrome (panel_kit.lua): drop shadow + vertical gradient body + accent corner
    -- ticks, square corners. Read the panel kit's own style so the look stays in sync; bake-in fallbacks
    -- if it isn't loaded. (Steady-state toasts reuse the panels' cached gradient brush -> ~free.)
    local PS   = __panelkit and __panelkit.style
    local BTOP = PS and PS.bg_top or { 24, 25, 32 }
    local BBOT = PS and PS.bg_bot or { 15, 15, 21 }
    local BGA  = PS and PS.bg_a or 238
    local SHA  = PS and PS.shadow_a or 90
    local SH   = PS and PS.sh or 4
    local TICK = PS and PS.tick or 7
    -- Match the HUD panel header treatment (panel_kit.lua): uppercase letter-spaced title in the panel
    -- font, a thin accent divider, and grey body rows. Pull the metrics straight from the panel kit's
    -- style so the two stay in sync; status colour (green/red/yellow/white) drives the ticks + divider.
    local TFONT = PS and PS.tfont or font.label
    local VFONT = PS and PS.vfont or font.value
    local TSP   = PS and PS.tspacing or 2
    local PADX  = PS and PS.padx or 11
    local PADY  = PS and PS.pady or 8
    local LBL   = PS and PS.label_c or { 140, 143, 156 }
    local DIVA  = PS and PS.divider_a or 70
    local gr, gg, gb = theme.green()
    local er, eg, eb = theme.red()
    local yr, yg, yb = theme.yellow()
    local titleH = text.height(TFONT)
    local lineH  = text.height(VFONT) + 3
    local content_max = MAX_W - PADX * 2
    local next_tbl = {}
    local cursor   = MARGIN
    for i = 0, count - 1 do
        local n = notify.get(i)
        if n then
            local age = t - n.create_time
            local a, p
            if n.closing then
                local k = clamp(1 - (t - n.close_time) / SLIDE, 0, 1)
                a = math.floor(k * 255)
                p = ease_out(k)
            else
                local k = clamp(age / SLIDE, 0, 1)
                a = math.floor(k * 255)
                p = ease_out(k)
                if age > n.duration - SLIDE then notify.close(n.index) end
            end
            if a > 0 then
                local ar, ag, ab = 255, 255, 255
                if     n.color_type == 1 then ar, ag, ab = gr, gg, gb
                elseif n.color_type == 2 then ar, ag, ab = er, eg, eb
                elseif n.color_type == 3 then ar, ag, ab = yr, yg, yb end
                local lines = wrap_lines(VFONT, n.message, content_max)
                local nmsg  = #lines
                local msg_w = 0
                for li = 1, nmsg do
                    local w = text.width(VFONT, lines[li])
                    if w > msg_w then msg_w = w end
                end
                local tw    = text.width_spaced(TFONT, string.upper(n.title), TSP)
                local inner = clamp(math.max(tw, msg_w), MIN_W - PADX * 2, content_max)
                local nw    = inner + PADX * 2
                local nh    = PADY + titleH + (nmsg > 0 and (8 + nmsg * lineH) or 0) + PADY
                local final_x = sw - nw - MARGIN
                local nx = final_x + (1 - p) * (nw + MARGIN)
                local target = cursor
                local cy = stack_y[n.index] or target
                cy = cy + (target - cy) * (1 - math.exp(-18 * dt))
                next_tbl[n.index] = cy
                local tx = nx + PADX
                local bga = math.floor(BGA * a / 255)
                local sha = math.floor(SHA * a / 255)
                draw.rect(nx + SH, cy + SH, nx + nw + SH, cy + nh + SH, 0, 0, 0, sha)   -- drop shadow
                draw.rect_gradient(nx, cy, nx + nw, cy + nh,                            -- gradient body
                    BTOP[1], BTOP[2], BTOP[3], bga, BTOP[1], BTOP[2], BTOP[3], bga,
                    BBOT[1], BBOT[2], BBOT[3], bga, BBOT[1], BBOT[2], BBOT[3], bga)
                corner_ticks(nx, cy, nw, nh, TICK, ar, ag, ab, a)                       -- accent corner ticks
                -- header: uppercase letter-spaced title (matches the RENDER/pool/etc. panels)
                text.draw_spaced(TFONT, tx, cy + PADY, ar, ag, ab, a, string.upper(n.title), TSP)
                if nmsg > 0 then
                    local hy = cy + PADY + titleH + 5
                    draw.line(tx, hy, nx + nw - PADX, hy, ar, ag, ab, math.floor(DIVA * a / 255), 1)  -- divider
                    local my = hy + 6
                    for li = 1, nmsg do
                        text.draw(VFONT, tx, my, LBL[1], LBL[2], LBL[3], math.floor(a * 0.9), lines[li], inner)
                        my = my + lineH
                    end
                end
                cursor = cursor + nh + GAP
            else
                next_tbl[n.index] = stack_y[n.index] or cursor
            end
        end
    end
    stack_y = next_tbl
end)
