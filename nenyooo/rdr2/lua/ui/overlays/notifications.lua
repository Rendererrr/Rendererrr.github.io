-- Compact notifications with a theme accent that tracks their remaining time.
local GAP, MARGIN = 6, 12
local MIN_W, MAX_W = 240, 320
local ENTER, EXIT, DISTANCE = 0.340, 0.180, 18
local positions = {}

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
local function ease_out(p) p = clamp(p, 0, 1); local q = 1 - p; return 1 - q * q * q end

local function notification_text(n)
    local title = tostring(n.title or ""):gsub("%s+", " ")
    local message = tostring(n.message or ""):gsub("%s+", " ")
    if message == "" then return title end
    if title == "" or title == message then return message end
    return title .. ": " .. message
end

local function wrap_text(fnt, value, width)
    local lines, line = {}, ""
    for word in value:gmatch("%S+") do
        local candidate = line == "" and word or (line .. " " .. word)
        if text.width(fnt, candidate) <= width then
            line = candidate
        else
            if line ~= "" then lines[#lines + 1] = line end
            line = ""
            -- Split oversized words at UTF-8 character boundaries.
            for character in word:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
                if line ~= "" and text.width(fnt, line .. character) > width then
                    lines[#lines + 1] = line
                    line = ""
                end
                line = line .. character
            end
        end
    end
    if line ~= "" or #lines == 0 then lines[#lines + 1] = line end
    return lines
end

local function timed_accent(x, y, w, h, progress, r, g, b, a)
    local top, side, bottom = w - 14, h, w - 14
    local first = progress * (top + side + bottom - 24)
    local last = first + 24
    local lo, hi = math.max(0, first), math.min(top, last)
    if hi > lo then
        draw.rect(x + 14 + lo, y, x + 14 + hi, y + 2, r, g, b, a, 0)
    end
    lo, hi = math.max(0, first - top), math.min(side, last - top)
    if hi > lo then
        draw.rect(x + w - 2, y + lo, x + w, y + hi, r, g, b, a, 0)
    end
    lo, hi = math.max(0, first - top - side), math.min(bottom, last - top - side)
    if hi > lo then
        draw.rect(x + w - hi, y + h - 2, x + w - lo, y + h, r, g, b, a, 0)
    end
end

overlay.on_draw("notifications", function()
    local count = notify.count()
    if count == 0 then positions = {}; return end
    local sw, now, dt = ctx.screen_w(), ctx.time(), math.max(0, ctx.delta())
    local ar, ag, ab = theme.accent()
    local er, eg, eb = theme.red()
    local MFONT = font.overlay_body or font.tiny
    local text_h = text.height(MFONT)
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

            local text_pad, right_pad = 14, 14
            local label = notification_text(n)
            local natural = text.width(MFONT, label) + text_pad + right_pad
            local w = math.min(clamp(natural, MIN_W, MAX_W), math.max(100, sw - MARGIN * 2 - DISTANCE))
            local content_w = math.max(1, w - text_pad - right_pad)
            local lines = wrap_text(MFONT, label, content_w)
            local line_h = text_h + 3
            local h = text_h + (#lines - 1) * line_h + 22
            local previous = positions[n.index]
            -- Native slots are reused; a fresh notification must not inherit the old slot's position.
            local y = previous and previous.created == n.create_time and previous.y or cursor
            y = y + (cursor - y) * (1 - math.exp(-14 * dt))
            next_positions[n.index] = { y = y, created = n.create_time }
            cursor = cursor + (h + GAP) * space

            local alpha = math.floor(opacity * 255)
            if alpha > 0 then
                local cr, cg, cb = ar, ag, ab
                if n.color_type == 2 then cr, cg, cb = er, eg, eb end
                local x = sw - w - MARGIN + offset
                draw.rect(x, y, x + w, y + h, 11, 11, 14, alpha, 0)
                local timer_age = n.closing and math.max(0, n.close_time - n.create_time) or age
                local progress = clamp(timer_age / math.max(0.001, n.duration - EXIT), 0, 1)
                timed_accent(x, y, w, h, progress, cr, cg, cb, alpha)

                draw.push_clip(x + 1, y + 1, x + w - 1, y + h - 1)
                for li, line in ipairs(lines) do
                    text.draw(MFONT, x + text_pad, y + 11 + (li - 1) * line_h,
                        238, 238, 242, alpha, line)
                end
                draw.pop_clip()
            end
        end
    end
    positions = next_positions
end)
