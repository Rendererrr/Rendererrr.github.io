local DLC_PAGES = {
    [util.joaat("Custom DLCs")] = true,
    [util.joaat("DLC Peds")] = true,
    [util.joaat("DLC Weapons")] = true,
    [util.joaat("DLC Vehicles")] = true,
    [util.joaat("DLC Overrides")] = true,
    [util.joaat("DLC Pack")] = true,
    [util.joaat("Spoofing")] = true,
}

local function wrap(fnt, value, max_width)
    local lines = {}
    local line = ""
    for word in tostring(value or ""):gmatch("%S+") do
        local candidate = line == "" and word or line .. " " .. word
        if line ~= "" and text.width(fnt, candidate) > max_width then
            lines[#lines + 1] = line
            line = word
        else
            line = candidate
        end
    end
    if line ~= "" then lines[#lines + 1] = line end
    return lines
end

overlay.on_draw("dlc_panel", function()
    if not menu.is_visible() or not DLC_PAGES[menu.page_id()] then return end
    local data = dlc.info()
    if not data then return end

    local L = str.panel_dlc()
    local rows = {
        { L.edition, data.edition or "-" },
        { L.packs, data.packs or 0 },
        { L.enabled, data.enabled or 0 },
        { L.mounted, data.mounted or 0 },
        { L.models, data.models or 0 },
        { L.peds, data.peds or 0 },
        { L.vehicles, data.vehicles or 0 },
        { L.weapons, data.weapons or 0 },
        { L.props, data.props or 0 },
        { L.overrides, data.overrides or 0 },
    }
    local steps = { L.step1, L.step2, L.step3, L.step4, L.step5, L.step6 }

    local width = 370
    local pad = 14
    local title_h = 36
    local section_h = text.height(font.tiny) + 12
    local row_h = text.height(font.small) + 7
    local line_h = text.height(font.small) + 4
    local inner_width = width - pad * 2
    local wrapped = {}
    local instruction_lines = 0
    for i, step in ipairs(steps) do
        wrapped[i] = wrap(font.small, tostring(i) .. ".  " .. step, inner_width)
        instruction_lines = instruction_lines + #wrapped[i]
    end

    local warning_lines = {}
    if data.disabled then warning_lines = wrap(font.small, L.disabled, inner_width) end
    local height = title_h + pad + section_h + #rows * row_h + section_h
        + instruction_lines * line_h + (#steps - 1) * 5 + #warning_lines * line_h + pad

    local sw, sh = ctx.screen_w(), ctx.screen_h()
    local bx, by, bw = menu.bounds()
    local gap = 12
    local x = bx + bw + gap
    local y = by
    if not bw or bw <= 0 then x, y = sw - width - 24, 80 end
    if x + width > sw - 8 then x = bx - gap - width end
    if x < 8 then x = 8 end
    if y < 8 then y = 8 elseif y + height > sh - 8 then y = sh - 8 - height end

    local ar, ag, ab = theme.accent()
    draw.rect(x, y, x + width, y + height, 13, 13, 18, 242, 9)
    draw.rect(x, y, x + width, y + title_h, ar, ag, ab, 255, 9)
    draw.rect(x, y + title_h - 9, x + width, y + title_h, ar, ag, ab, 255)
    draw.rect_gradient(x, y, x + width, y + title_h,
        255, 255, 255, 42, 255, 255, 255, 42, 255, 255, 255, 0, 255, 255, 255, 0)
    draw.rect_outline(x, y, x + width, y + height, ar, ag, ab, 135, 9)
    text.draw(font.item, x + pad, y + (title_h - text.height(font.item)) * 0.5,
        255, 255, 255, 255, string.upper(L.title))

    local cursor_y = y + title_h + pad
    local function section(label)
        text.draw(font.tiny, x + pad, cursor_y + 2, ar, ag, ab, 255, string.upper(label))
        cursor_y = cursor_y + section_h
    end

    section(L.library)
    for _, row in ipairs(rows) do
        local value = tostring(row[2])
        text.draw(font.small, x + pad, cursor_y, 255, 255, 255, 135, row[1])
        text.draw(font.small, x + width - pad - text.width(font.small, value), cursor_y,
            245, 245, 248, 255, value)
        cursor_y = cursor_y + row_h
    end

    section(L.installation)
    for i, lines in ipairs(wrapped) do
        for _, line in ipairs(lines) do
            text.draw(font.small, x + pad, cursor_y, 235, 235, 240, 225, line)
            cursor_y = cursor_y + line_h
        end
        if i < #wrapped then cursor_y = cursor_y + 5 end
    end

    for _, line in ipairs(warning_lines) do
        text.draw(font.small, x + pad, cursor_y, 255, 110, 110, 255, line)
        cursor_y = cursor_y + line_h
    end
end)
