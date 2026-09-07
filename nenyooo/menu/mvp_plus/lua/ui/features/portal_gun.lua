-- Portal Gun control guide and crosshair. The guide follows the menu hotkeys and can be hidden
-- independently; orange/blue side arcs show which portals exist while aiming.
local function key_name(value)
    local code = math.floor(tonumber(value) or 0)
    local special = {
        [0] = "Unbound", [1] = "LMB", [2] = "RMB", [4] = "MMB", [8] = "Backspace",
        [9] = "Tab", [13] = "Enter", [16] = "Shift", [17] = "Ctrl", [18] = "Alt",
        [20] = "Caps Lock", [27] = "Esc", [32] = "Space", [33] = "Page Up",
        [34] = "Page Down", [35] = "End", [36] = "Home", [37] = "Left",
        [38] = "Up", [39] = "Right", [40] = "Down", [45] = "Insert", [46] = "Delete",
    }
    if special[code] then return special[code] end
    if code >= 48 and code <= 57 or code >= 65 and code <= 90 then return string.char(code) end
    if code >= 112 and code <= 123 then return "F" .. tostring(code - 111) end
    return "Key " .. tostring(code)
end

local function draw_controls(f)
    local orange = { 255, 115, 20 }
    local blue = { 30, 130, 255 }
    local white = { 232, 234, 241 }
    local rows = {}
    local function add(key, action, colour)
        rows[#rows + 1] = { key = key, action = action, colour = colour or white }
    end

    add("LMB", "Place orange portal", orange)
    local blue_key = key_name(f.blue_key)
    if f.hold_blue then add(blue_key .. " + LMB", "Place blue portal", blue)
    else add(blue_key, "Place blue portal at aim", blue) end
    if f.grab_enabled then add(key_name(f.grab_key), "Grab / release aimed entity") end
    add(key_name(f.teleport_blue_key) .. " / " .. key_name(f.teleport_orange_key),
        "Teleport to blue / orange")
    if f.moon_enabled then
        add(key_name(f.moon_key), "Orange portal on moon", orange)
        add(blue_key .. " + " .. key_name(f.moon_key), "Blue portal on moon", blue)
        add(key_name(f.moon_self_key), "Toggle moon suction for self")
    end
    add(key_name(f.long_fall_key), "Toggle Long Fall Boots")
    add(key_name(f.spawn_key), "Spawn test pedestrian")

    local pad, gap = 12, 14
    local title_h = text.height(font.item)
    local row_h = text.height(font.tiny) + 8
    local key_w, action_w = 0, 0
    for _, row in ipairs(rows) do
        key_w = math.max(key_w, text.width(font.tiny, row.key))
        action_w = math.max(action_w, text.width(font.tiny, row.action))
    end
    local w = math.max(330, pad * 2 + key_w + gap + action_w)
    local h = pad * 2 + title_h + 8 + row_h * #rows
    local x = 24
    local y = ctx.screen_h() * 0.5 - h * 0.5

    draw.rect(x, y, x + w, y + h, 9, 11, 17, 218, 7)
    draw.rect(x, y, x + w * 0.5, y + 3, orange[1], orange[2], orange[3], 255, 7)
    draw.rect(x + w * 0.5, y, x + w, y + 3, blue[1], blue[2], blue[3], 255, 7)
    draw.circle(x + pad + 5, y + pad + title_h * 0.5, 5, orange[1], orange[2], orange[3], 255)
    draw.circle(x + pad + 17, y + pad + title_h * 0.5, 5, blue[1], blue[2], blue[3], 255)
    text.draw(font.item, x + pad + 30, y + pad, 245, 245, 250, 255, "PORTAL GUN")

    local row_y = y + pad + title_h + 8
    for i, row in ipairs(rows) do
        if i % 2 == 0 then
            draw.rect(x + 5, row_y - 2, x + w - 5, row_y + row_h - 2, 255, 255, 255, 8, 3)
        end
        local c = row.colour
        text.draw(font.tiny, x + pad, row_y, c[1], c[2], c[3], 255, row.key)
        text.draw(font.tiny, x + pad + key_w + gap, row_y, 224, 226, 234, 245, row.action)
        row_y = row_y + row_h
    end
end

features.on_draw("Portal Gun", function(f)
    if not f.enabled then return end
    if f.controls then draw_controls(f) end
    if not f.aiming then return end
    local cx, cy = ctx.screen_w() * 0.5, ctx.screen_h() * 0.5
    local valid = f.valid == true
    local cr, cg, cb = valid and 245 or 115, valid and 245 or 115, valid and 250 or 120
    local gap, arm, thick = 7, 12, 2

    draw.rect(cx - gap - arm, cy - thick * 0.5, cx - gap, cy + thick * 0.5, cr, cg, cb, 240, 0)
    draw.rect(cx + gap, cy - thick * 0.5, cx + gap + arm, cy + thick * 0.5, cr, cg, cb, 240, 0)
    draw.rect(cx - thick * 0.5, cy - gap - arm, cx + thick * 0.5, cy - gap, cr, cg, cb, 240, 0)
    draw.rect(cx - thick * 0.5, cy + gap, cx + thick * 0.5, cy + gap + arm, cr, cg, cb, 240, 0)

    local oa = f.orange and 255 or 65
    local ba = f.blue and 255 or 65
    draw.circle_outline(cx - 27, cy, 8, 255, 115, 20, oa, 2)
    draw.circle_outline(cx + 27, cy, 8, 30, 130, 255, ba, 2)
    if f.grabbed then draw.circle(cx, cy, 3, 255, 255, 255, 255) end

    local state = (f.orange and f.blue) and "PORTALS LINKED"
        or (f.orange and "ORANGE READY") or (f.blue and "BLUE READY") or "PLACE BOTH PORTALS"
    local w = text.width(font.tiny, state)
    text.draw(font.tiny, cx - w * 0.5, cy + 34, 225, 225, 235, 210, state)
end)
