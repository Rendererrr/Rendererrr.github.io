-- Compact notification cards. Long titles are ellipsized and messages wrap to at
-- most three clipped lines, so user/script text can never escape the card.
local GAP, MARGIN = 6, 12
local MIN_W, MAX_W = 245, 340
local SLIDE, MAX_LINES = 0.24, 3
local stack_y = {}

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
local function ease_out(p) p = clamp(p, 0, 1); local q = 1 - p; return 1 - q * q * q end

local function utf8_prefix(s, n)
    if #s <= n then return s end
    local k = n
    while k > 0 do
        local b = string.byte(s, k)
        if not b or b < 128 then break end
        if b >= 192 then k = k - 1; break end
        k = k - 1
    end
    return string.sub(s, 1, math.max(k, 0))
end

local function fit(fnt, value, maxw)
    local s = tostring(value or "")
    if text.width(fnt, s) <= maxw then return s end
    local n = #s
    while n > 0 do
        n = n - 1
        local v = utf8_prefix(s, n) .. "..."
        if text.width(fnt, v) <= maxw then return v end
    end
    return "..."
end

local function wrap(fnt, value, maxw)
    local out, line, overflow = {}, "", false
    local s = tostring(value or "")
    for word in string.gmatch(s, "%S+") do
        local candidate = line == "" and word or (line .. " " .. word)
        if text.width(fnt, candidate) <= maxw then
            line = candidate
        else
            if line ~= "" then out[#out + 1] = line end
            if #out >= MAX_LINES then overflow = true; line = ""; break end
            if text.width(fnt, word) > maxw then
                out[#out + 1] = fit(fnt, word, maxw)
                line = ""
            else
                line = word
            end
            if #out >= MAX_LINES then overflow = true; line = ""; break end
        end
    end
    if line ~= "" and #out < MAX_LINES then out[#out + 1] = line end
    if #out == 0 then out[1] = "" end
    if overflow then out[#out] = fit(fnt, out[#out] .. "...", maxw) end
    return out
end

local function status_icon(cx, cy, kind, r, g, b, a)
    if kind == 1 then
        draw.circle_outline(cx, cy, 7, r, g, b, a, 1.3)
        draw.line(cx - 3, cy, cx - 1, cy + 3, r, g, b, a, 1.4)
        draw.line(cx - 1, cy + 3, cx + 4, cy - 3, r, g, b, a, 1.4)
    elseif kind == 0 then
        draw.circle_outline(cx, cy, 7, r, g, b, a, 1.3)
        text.draw_centered(font.tiny, cx - 7, cy - 6, cx + 7, r, g, b, a, "i")
    else
        draw.line(cx, cy - 8, cx - 8, cy + 6, r, g, b, a, 1.3)
        draw.line(cx - 8, cy + 6, cx + 8, cy + 6, r, g, b, a, 1.3)
        draw.line(cx + 8, cy + 6, cx, cy - 8, r, g, b, a, 1.3)
        text.draw_centered(font.tiny, cx - 7, cy - 5, cx + 7, r, g, b, a, "!")
    end
end

overlay.on_draw("notifications", function()
    local count = notify.count()
    if count == 0 then stack_y = {}; return end
    local sw, now, dt = ctx.screen_w(), ctx.time(), ctx.delta()
    local gr, gg, gb = theme.green()
    local er, eg, eb = theme.red()
    local yr, yg, yb = theme.yellow()
    local TFONT, MFONT, TIMEFONT = font.small, font.tiny, font.tiny
    local title_h, line_h = text.height(TFONT), text.height(MFONT) + 1
    local next_y, cursor = {}, MARGIN

    for i = 0, count - 1 do
        local n = notify.get(i)
        if n then
            local age, alpha, progress = now - n.create_time, 255, 1
            if n.closing then
                local k = clamp(1 - (now - n.close_time) / SLIDE, 0, 1)
                alpha, progress = math.floor(k * 255), ease_out(k)
            else
                local k = clamp(age / SLIDE, 0, 1)
                alpha, progress = math.floor(k * 255), ease_out(k)
                if age > n.duration - SLIDE then notify.close(n.index) end
            end

            if alpha > 0 then
                local ar, ag, ab = yr, yg, yb
                if n.color_type == 1 then ar, ag, ab = gr, gg, gb
                elseif n.color_type == 2 then ar, ag, ab = er, eg, eb end

                local natural = math.max(text.width(TFONT, n.title or ""), text.width(MFONT, n.message or "")) + 77
                local w = clamp(natural, MIN_W, MAX_W)
                local text_x_pad, right_pad, time_space = 43, 10, 39
                local content_w = w - text_x_pad - right_pad - time_space
                local lines = wrap(MFONT, n.message, content_w)
                local h = 14 + title_h + #lines * line_h + 7
                local target_y = cursor
                local y = stack_y[n.index] or target_y
                y = y + (target_y - y) * (1 - math.exp(-18 * dt))
                next_y[n.index] = y
                local final_x = sw - w - MARGIN
                local x = final_x + (1 - progress) * (w + MARGIN)
                local aa = math.floor(alpha * 0.96)

                draw.rect(x + 2, y + 3, x + w + 2, y + h + 3, 0, 0, 0, math.floor(alpha * 0.35), 6)
                draw.rect(x, y, x + w, y + h, 14, 14, 17, aa, 6)
                draw.rect_outline(x, y, x + w, y + h, 48, 48, 56, math.floor(alpha * 0.72), 6, 1)
                draw.rect(x, y, x + 4, y + h, ar, ag, ab, alpha, 4)

                draw.push_clip(x + 4, y + 1, x + w - 1, y + h - 1)
                status_icon(x + 22, y + h * 0.5, n.color_type, ar, ag, ab, alpha)
                local tx = x + text_x_pad
                local title_max = w - text_x_pad - right_pad
                text.draw_ellipsis(TFONT, tx, y + 7, 238, 238, 242, alpha, n.title or "", title_max)
                local my = y + 8 + title_h
                for li = 1, #lines do
                    text.draw(MFONT, tx, my, 166, 166, 174, math.floor(alpha * 0.92), lines[li])
                    my = my + line_h
                end
                local stamp = n.timestamp or "--:--"
                text.draw(TIMEFONT, x + w - right_pad - text.width(TIMEFONT, stamp), y + h - text.height(TIMEFONT) - 6,
                    137, 137, 146, math.floor(alpha * 0.9), stamp)
                draw.pop_clip()
                cursor = cursor + h + GAP
            else
                next_y[n.index] = stack_y[n.index] or cursor
            end
        end
    end
    stack_y = next_y
end)
