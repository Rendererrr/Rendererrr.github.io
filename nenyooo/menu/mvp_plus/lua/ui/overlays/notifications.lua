-- Compact notification cards. Long titles are ellipsized and messages wrap to at
-- most three clipped lines, so user/script text can never escape the card.
local GAP, MARGIN = 6, 12
local MIN_W, MAX_W = 190, 270
local ENTER, EXIT, DISTANCE, MAX_LINES = 0.340, 0.180, 18, 3
local positions = {}

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
    if count == 0 then positions = {}; return end
    local sw, now, dt = ctx.screen_w(), ctx.time(), math.max(0, ctx.delta())
    local gr, gg, gb = theme.green()
    local er, eg, eb = theme.red()
    local yr, yg, yb = theme.yellow()
    local TFONT = font.overlay_heading or font.small
    local MFONT = font.overlay_body or font.tiny
    local TIMEFONT = font.tiny
    local title_h, line_h = text.height(TFONT), text.height(MFONT) + 2
    local next_positions, cursor = {}, MARGIN

    for i = 0, count - 1 do
        local n = notify.get(i)
        if n then
            local age = math.max(0, now - n.create_time)
            local entry = ease_out(age / ENTER)
            local opacity, offset, space = entry, DISTANCE * (1 - entry), 1
            if n.closing then
                local p = clamp((now - n.close_time) / EXIT, 0, 1)
                local eased = p * p * (3 - 2 * p)
                -- Closing during entry continues from its current opacity and position.
                local at_close = ease_out((n.close_time - n.create_time) / ENTER)
                opacity = at_close * (1 - eased)
                offset = DISTANCE * (1 - at_close) + 8 * eased
                space = 1 - eased
            elseif age >= math.max(0, n.duration - EXIT) then
                notify.close(n.index)
            end

            local stamp = n.timestamp or "--:--"
            local time_w = text.width(TIMEFONT, stamp)
            local text_pad, right_pad = 32, 10
            local natural = math.max(text.width(TFONT, n.title or ""), text.width(MFONT, n.message or ""))
                + text_pad + right_pad + time_w + 8
            local w = math.min(clamp(natural, MIN_W, MAX_W), math.max(100, sw - MARGIN * 2 - DISTANCE))
            local content_w = math.max(1, w - text_pad - right_pad - time_w - 8)
            local lines = wrap(MFONT, n.message, content_w)
            local h = math.max(38, 12 + title_h + #lines * line_h + 2)
            local previous = positions[n.index]
            -- Native slots are reused; a fresh notification must not inherit the old slot's position.
            local y = previous and previous.created == n.create_time and previous.y or cursor
            y = y + (cursor - y) * (1 - math.exp(-14 * dt))
            next_positions[n.index] = { y = y, created = n.create_time }
            cursor = cursor + (h + GAP) * space

            local alpha = math.floor(opacity * 255)
            if alpha > 0 then
                local ar, ag, ab = yr, yg, yb
                if n.color_type == 1 then ar, ag, ab = gr, gg, gb
                elseif n.color_type == 2 then ar, ag, ab = er, eg, eb end
                local x = sw - w - MARGIN + offset
                draw.rect(x, y, x + w, y + h, 17, 19, 23, alpha, 5)
                draw.rect_outline(x, y, x + w, y + h, 69, 72, 79, alpha, 5, 1)

                draw.push_clip(x + 1, y + 1, x + w - 1, y + h - 1)
                draw.with_scale(x + 16, y + h * 0.5, 0.85, function()
                    status_icon(x + 16, y + h * 0.5, n.color_type, ar, ag, ab, alpha)
                end)
                local tx = x + text_pad
                local block_h = title_h + 2 + #lines * line_h
                local ty = y + (h - block_h) * 0.5
                text.draw_ellipsis(TFONT, tx, ty, 242, 243, 246, alpha, n.title or "", content_w)
                local my = ty + title_h + 2
                for li = 1, #lines do
                    text.draw(MFONT, tx, my, 174, 180, 193, alpha, lines[li])
                    my = my + line_h
                end
                text.draw(TIMEFONT, x + w - right_pad - time_w,
                    y + (h - text.height(TIMEFONT)) * 0.5, 156, 163, 175, alpha, stamp)
                draw.pop_clip()
            end
        end
    end
    positions = next_positions
end)
