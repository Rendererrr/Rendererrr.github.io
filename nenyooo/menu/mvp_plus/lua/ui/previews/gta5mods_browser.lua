-- GTA5-Mods Browser side panel. Published by gta5mods_browser::draw only while the menu is on the
-- "GTA5-Mods Browser" page or a mod's page, so no page check is needed here.
--   mode        : "browse" | "mod"
--   status      : translated status line;  status_kind : "busy" | "ok" | "err" | "idle";  busy : bool
--   count, sel  : result count and the highlighted card (1-based);  page, max_page
--   cat, sort, since, query : current filters (since/query only when set)
--   detail      : "loading" | "ok" | "failed" for the highlighted card;  file_count, file_sel (1-based)
--   install, install_kind : install status of the highlighted card (only when known)
--   dl_active, dl_title, dl_text, dl_kind ("busy"|"ok"|"err"), dl_pct (0..1, -1 = unknown) : download box
--   blob        : one record per line, tab separated:
--                 C idx title author thumb kind edition state downloads likes rating version tags thumb_loading
--                 D description ("\r" = line break)      F idx file_label
local cache_blob, cards, desc, files = nil, {}, nil, {}
local wrap_cache = {}

local function split_tabs(line)
    local out = {}
    for field in (line .. "\t"):gmatch("([^\t]*)\t") do out[#out + 1] = field end
    return out
end

local function parse(blob)
    if blob == cache_blob then return end
    cache_blob = blob
    cards, desc, files = {}, nil, {}
    for line in (blob or ""):gmatch("[^\n]+") do
        local t = line:sub(1, 1)
        if t == "C" then
            local f = split_tabs(line)
            cards[#cards + 1] = {
                title = f[3] or "", author = f[4] or "", thumb = f[5] or "", kind = f[6] or "",
                edition = f[7] or "", state = f[8] or "", downloads = tonumber(f[9]) or -1,
                likes = tonumber(f[10]) or -1, rating = tonumber(f[11]) or -1, version = f[12] or "",
                tags = f[13] or "", thumb_loading = f[14] == "1",
            }
        elseif t == "D" then
            desc = line:sub(3):gsub("\r", "\n")
        elseif t == "F" then
            local f = split_tabs(line)
            files[#files + 1] = f[3] or ""
        end
    end
end

local function wrap(fnt, value, max_width, max_lines)
    local key = tostring(fnt) .. "|" .. max_width .. "|" .. (max_lines or 0) .. "|" .. (value or "")
    local hit = wrap_cache[key]
    if hit then return hit end
    local lines = {}
    for para in tostring(value or ""):gmatch("[^\n]+") do
        local line = ""
        for word in para:gmatch("%S+") do
            local candidate = line == "" and word or line .. " " .. word
            if line ~= "" and text.width(fnt, candidate) > max_width then
                lines[#lines + 1] = line
                line = word
            else
                line = candidate
            end
        end
        if line ~= "" then lines[#lines + 1] = line end
        if max_lines and #lines > max_lines then break end
    end
    if max_lines and #lines > max_lines then
        while #lines > max_lines do table.remove(lines) end
        lines[max_lines] = lines[max_lines] .. " ..."
    end
    local n = 0
    for _ in pairs(wrap_cache) do n = n + 1 end
    if n > 64 then wrap_cache = {} end
    wrap_cache[key] = lines
    return lines
end

local function fmt_count(n)
    if not n or n < 0 then return nil end
    if n >= 1000000 then return string.format("%.1fM", n / 1000000) end
    if n >= 10000 then return string.format("%.0fK", n / 1000) end
    if n >= 1000 then return string.format("%.1fK", n / 1000) end
    return tostring(math.floor(n))
end

-- Image scaled to COVER the box (aspect kept, overflow clipped). Returns false until the bitmap is ready.
local function cover(path, x1, y1, x2, y2, alpha)
    if not path or path == "" then return false end
    local w, h = draw.preview_image_size(path)
    if not w or w <= 0 or h <= 0 then
        return draw.preview_image(path, x1, y1, x2, y2, alpha or 1.0, true)
    end
    local bw, bh = x2 - x1, y2 - y1
    local s = math.max(bw / w, bh / h)
    local dw, dh = w * s, h * s
    local ox, oy = x1 + (bw - dw) * 0.5, y1 + (bh - dh) * 0.5
    draw.push_clip(x1, y1, x2, y2)
    local ok = draw.preview_image(path, ox, oy, ox + dw, oy + dh, alpha or 1.0)
    draw.pop_clip()
    return ok
end

local function spinner(cx, cy, radius, r, g, b)
    local t = ctx.time()
    for i = 0, 7 do
        local a = (i / 8) * math.pi * 2
        local phase = (t * 1.6 - i / 8) % 1
        local alpha = math.floor(60 + 195 * (1 - phase))
        draw.circle(cx + math.cos(a) * radius, cy + math.sin(a) * radius, radius * 0.22, r, g, b, alpha)
    end
end

local KIND_COLORS = {
    addon = { 58, 186, 118 }, replace = { 226, 152, 52 }, skin = { 164, 112, 226 },
    fivem = { 214, 84, 84 }, unverified = { 104, 106, 118 },
}
local EDITION_COLORS = { legacy = { 74, 132, 224 }, enhanced = { 46, 178, 190 } }
local STATE_COLORS = {
    lib = { 58, 186, 118 }, queued = { 222, 178, 62 }, installing = { 222, 178, 62 },
    dl = nil, fail = { 214, 84, 84 },
}
local STATE_KEYS = { lib = "st_lib", queued = "st_queued", installing = "st_installing", dl = "st_dl", fail = "st_fail" }

local function pill(fnt, x, y, label, r, g, b, a)
    local h = text.height(fnt) + 6
    local w = text.width(fnt, label) + 14
    draw.rect(x, y, x + w, y + h, r, g, b, a or 225, h * 0.5)
    text.draw(fnt, x + 7, y + 3, 255, 255, 255, 255, label)
    return w, h
end

local function kind_color(f, ar, ag, ab)
    if f.status_kind == "err" then return 214, 84, 84 end
    if f.status_kind == "ok" then return 58, 186, 118 end
    if f.status_kind == "busy" then return ar, ag, ab end
    return 140, 140, 150
end

features.on_draw("GTA5-Mods Browser", function(f)
    if not f.mode then return end
    -- Feature HUDs draw before overlays: this tells overlays\dlc_panel.lua to step aside this frame.
    __gta5mods_panel_frame = ctx.frame()
    parse(f.blob)
    local L = str.panel_gta5mods()
    local ar, ag, ab = theme.accent()

    local sw, sh = ctx.screen_w(), ctx.screen_h()
    local W, pad, gap = 540, 14, 8
    local inner = W - pad * 2
    local is_mod = f.mode == "mod"
    local sel = math.floor(f.sel or 0)
    local card = cards[sel]

    local fh_item, fh_small, fh_tiny = text.height(font.item), text.height(font.small), text.height(font.tiny)
    local header_h, chips_h = 48, fh_tiny + 8
    local hero_h = math.floor(inner * 0.5)
    local strip_cols, strip_rows = 4, 2
    local tile_w = math.floor((inner - gap * (strip_cols - 1)) / strip_cols)
    local tile_h = math.floor(tile_w * 0.6)
    local desc_lines = is_mod and 6 or 4
    local file_rows = 0
    if is_mod then file_rows = math.min(#files, 4) end
    local has_dl = f.dl_text ~= nil

    local function total_height()
        local h = header_h + gap + chips_h + gap + hero_h + gap
        h = h + fh_item + 4 + fh_small + 8 + (fh_tiny + 6) + gap
        h = h + desc_lines * (fh_small + 3) + gap
        if f.install then h = h + fh_small + gap end
        if file_rows > 0 then h = h + fh_tiny + 6 + file_rows * (fh_small + 8) + gap end
        if #cards > 1 then h = h + fh_tiny + 6 + strip_rows * (tile_h + gap) end
        if has_dl then h = h + fh_small * 2 + 26 end
        h = h + fh_small + pad * 2
        return h
    end

    -- Fit tall layouts on short screens: shrink the hero, then the strip, then the description.
    local H = total_height()
    local room = sh - 16
    if H > room then hero_h = math.max(140, hero_h - (H - room)); H = total_height() end
    if H > room then strip_rows = 1; H = total_height() end
    if H > room then desc_lines = 2; H = total_height() end

    local bx, by, bw = menu.bounds()
    local x, y
    if bw and bw > 0 then
        if (bx + bw * 0.5) < sw * 0.5 then x = bx + bw + 12 else x = bx - 12 - W end
        y = by
    else
        x, y = sw - W - 24, 80
    end
    if x < 8 then x = 8 elseif x + W > sw - 8 then x = sw - 8 - W end
    if y < 8 then y = 8 elseif y + H > sh - 8 then y = math.max(8, sh - 8 - H) end

    -- Frame + header.
    draw.rect(x, y, x + W, y + H, 13, 13, 18, 244, 10)
    draw.rect(x, y, x + W, y + header_h, ar, ag, ab, 255, 10)
    draw.rect(x, y + header_h - 10, x + W, y + header_h, ar, ag, ab, 255)
    draw.rect_gradient(x, y, x + W, y + header_h,
        255, 255, 255, 46, 255, 255, 255, 46, 0, 0, 0, 30, 0, 0, 0, 30)
    draw.rect_outline(x, y, x + W, y + H, ar, ag, ab, 120, 10)
    text.draw(font.item, x + pad, y + 8, 255, 255, 255, 255, string.upper(L.title))
    local sub = f.cat or ""
    if f.query then sub = sub .. "  /  " .. L.search .. ": \"" .. f.query .. "\"" end
    text.draw_ellipsis(font.small, x + pad, y + 10 + fh_item, 255, 255, 255, 200, sub, inner - 120)
    if (f.count or 0) > 0 then
        local pg = L.page .. " " .. math.floor(f.page or 1) .. " / " .. math.floor(f.max_page or 1)
        local pw = text.width(font.small, pg) + 16
        local px, py = x + W - pad - pw, y + (header_h - (fh_small + 8)) * 0.5
        draw.rect(px, py, px + pw, py + fh_small + 8, 0, 0, 0, 70, (fh_small + 8) * 0.5)
        text.draw(font.small, px + 8, py + 4, 255, 255, 255, 255, pg)
    end

    local cy = y + header_h + gap

    -- Filter chips.
    local chip_x = x + pad
    local function chip(label)
        if not label or label == "" then return end
        local w = text.width(font.tiny, label) + 16
        if chip_x + w > x + W - pad then return end
        draw.rect(chip_x, cy, chip_x + w, cy + chips_h, 30, 30, 38, 255, chips_h * 0.5)
        draw.rect_outline(chip_x, cy, chip_x + w, cy + chips_h, ar, ag, ab, 150, chips_h * 0.5)
        text.draw(font.tiny, chip_x + 8, cy + 4, 225, 225, 232, 255, string.upper(label))
        chip_x = chip_x + w + 6
    end
    chip(f.cat); chip(f.sort); chip(f.since)
    if (f.count or 0) > 0 then chip(math.floor(f.count) .. " " .. L.results) end
    cy = cy + chips_h + gap

    -- Hero image.
    local hx1, hy1, hx2, hy2 = x + pad, cy, x + W - pad, cy + hero_h
    draw.rect(hx1, hy1, hx2, hy2, 24, 24, 31, 255, 6)
    local shown = false
    if card and card.thumb ~= "" then shown = cover(card.thumb, hx1, hy1, hx2, hy2, 1.0) end
    if not shown then
        local mx, my = (hx1 + hx2) * 0.5, (hy1 + hy2) * 0.5
        if not card then
            if f.busy or f.status_kind == "busy" then spinner(mx, my - 14, 14, ar, ag, ab) end
            local lines = wrap(font.small, f.status or L.empty, inner - 60, 3)
            local ty = my + 10
            for _, ln in ipairs(lines) do
                text.draw(font.small, mx - text.width(font.small, ln) * 0.5, ty, 210, 210, 218, 255, ln)
                ty = ty + fh_small + 3
            end
        elseif card.thumb_loading then
            spinner(mx, my, 12, ar, ag, ab)
        else
            text.draw(font.small, mx - text.width(font.small, L.no_preview) * 0.5, my - fh_small * 0.5, 150, 150, 160, 255, L.no_preview)
        end
    end
    if card then
        -- Bottom scrim so the badges always read.
        draw.rect_gradient(hx1, hy2 - 46, hx2, hy2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 190, 0, 0, 0, 190)
        local bxp = hx1 + 8
        local kc = KIND_COLORS[card.kind] or KIND_COLORS.unverified
        if card.kind ~= "" and L[card.kind] then
            local w = pill(font.tiny, bxp, hy2 - fh_tiny - 14, string.upper(L[card.kind]), kc[1], kc[2], kc[3])
            bxp = bxp + w + 6
        end
        if card.edition ~= "" then
            local ec = EDITION_COLORS[card.edition] or { ar, ag, ab }
            local w = pill(font.tiny, bxp, hy2 - fh_tiny - 14, string.upper(L[card.edition] or card.edition), ec[1], ec[2], ec[3])
            bxp = bxp + w + 6
        end
        if card.state ~= "" and STATE_KEYS[card.state] then
            local label = string.upper(L[STATE_KEYS[card.state]])
            local sc = STATE_COLORS[card.state] or { ar, ag, ab }
            local w = text.width(font.tiny, label) + 14
            pill(font.tiny, hx2 - 8 - w, hy1 + 8, label, sc[1], sc[2], sc[3], 235)
        end
    end
    draw.rect_outline(hx1, hy1, hx2, hy2, 255, 255, 255, 28, 6)
    cy = hy2 + gap

    -- Title, author, stats.
    if card then
        text.draw_ellipsis(font.item, x + pad, cy, 245, 245, 250, 255, card.title, inner)
        cy = cy + fh_item + 4
        local by_line = card.author ~= "" and (L.by .. " " .. card.author) or ""
        text.draw_ellipsis(font.small, x + pad, cy, ar, ag, ab, 255, by_line, inner * 0.55)
        local stats = {}
        local d, l = fmt_count(card.downloads), fmt_count(card.likes)
        if d then stats[#stats + 1] = d .. " " .. L.downloads end
        if l then stats[#stats + 1] = l .. " " .. L.likes end
        if card.rating and card.rating > 0 then stats[#stats + 1] = string.format("%s %.1f", L.rating, card.rating) end
        if card.version ~= "" then stats[#stats + 1] = "v" .. card.version end
        if not is_mod and (f.file_count or 0) > 1 then stats[#stats + 1] = math.floor(f.file_count) .. " " .. L.file_count end
        local st = table.concat(stats, "   ")
        text.draw(font.small, x + W - pad - text.width(font.small, st), cy, 165, 165, 175, 255, st)
        cy = cy + fh_small + 8
        if card.tags ~= "" then
            text.draw_ellipsis(font.tiny, x + pad, cy, 140, 140, 152, 255, string.upper(card.tags), inner)
        end
        cy = cy + fh_tiny + 6 + gap
    else
        cy = cy + fh_item + 4 + fh_small + 8 + fh_tiny + 6 + gap
    end

    -- Description.
    local dtext
    if card then
        if desc and desc ~= "" then dtext = desc
        elseif f.detail == "failed" then dtext = L.no_details
        else dtext = L.loading_details end
    end
    local lines = dtext and wrap(font.small, dtext, inner, desc_lines) or {}
    for i = 1, desc_lines do
        local ln = lines[i]
        if ln then text.draw(font.small, x + pad, cy, 210, 210, 218, desc and 235 or 150, ln) end
        cy = cy + fh_small + 3
    end
    cy = cy + gap

    -- Install status of this mod.
    if f.install then
        local kr, kg, kb = 222, 178, 62
        if f.install_kind == "ok" then kr, kg, kb = 58, 186, 118 elseif f.install_kind == "err" then kr, kg, kb = 214, 84, 84 end
        draw.circle(x + pad + 4, cy + fh_small * 0.5 + 1, 4, kr, kg, kb, 255)
        text.draw_ellipsis(font.small, x + pad + 14, cy, kr, kg, kb, 255, f.install, inner - 14)
        cy = cy + fh_small + gap
    end

    -- Files (mod page): the picked one is what "Download to DLC Inbox" fetches.
    if file_rows > 0 then
        text.draw(font.tiny, x + pad, cy, ar, ag, ab, 255, string.upper(L.files))
        cy = cy + fh_tiny + 6
        local fsel = math.floor(f.file_sel or 1)
        local first = math.max(1, math.min(fsel - file_rows + 1, #files - file_rows + 1))
        for i = first, first + file_rows - 1 do
            local active = i == fsel
            local ry2 = cy + fh_small + 6
            draw.rect(x + pad, cy, x + W - pad, ry2, active and 34 or 22, active and 34 or 22, active and 44 or 28, 255, 4)
            if active then draw.rect(x + pad, cy, x + pad + 3, ry2, ar, ag, ab, 255, 1) end
            text.draw_ellipsis(font.small, x + pad + 10, cy + 3, 230, 230, 236, active and 255 or 190, files[i] or "", inner - 20)
            cy = ry2 + 2
        end
        cy = cy + gap
    end

    -- Result strip: thumbnails around the highlighted card.
    if #cards > 1 then
        local per = strip_cols * strip_rows
        local first = math.max(1, math.min(sel - math.floor(per / 2) + 1, #cards - per + 1))
        local label = string.upper(L.results) .. "  " .. sel .. " / " .. #cards
        text.draw(font.tiny, x + pad, cy, ar, ag, ab, 255, label)
        cy = cy + fh_tiny + 6
        for i = 0, per - 1 do
            local ci = first + i
            local c = cards[ci]
            if not c then break end
            local col, row = i % strip_cols, math.floor(i / strip_cols)
            local tx = x + pad + col * (tile_w + gap)
            local ty = cy + row * (tile_h + gap)
            draw.rect(tx, ty, tx + tile_w, ty + tile_h, 24, 24, 31, 255, 5)
            local ok = c.thumb ~= "" and cover(c.thumb, tx, ty, tx + tile_w, ty + tile_h, ci == sel and 1.0 or 0.72)
            if not ok and c.thumb_loading then spinner(tx + tile_w * 0.5, ty + tile_h * 0.5, 7, ar, ag, ab) end
            if not ok and not c.thumb_loading then
                text.draw_ellipsis(font.tiny, tx + 6, ty + 6, 170, 170, 180, 255, c.title, tile_w - 12)
            end
            local sc = STATE_COLORS[c.state] or (c.state == "dl" and { ar, ag, ab }) or nil
            if sc then
                draw.circle(tx + tile_w - 9, ty + 9, 5, 0, 0, 0, 160)
                draw.circle(tx + tile_w - 9, ty + 9, 4, sc[1], sc[2], sc[3], 255)
            end
            if ci == sel then
                draw.rect_outline(tx - 1, ty - 1, tx + tile_w + 1, ty + tile_h + 1, ar, ag, ab, 255, 6, 2)
            else
                draw.rect_outline(tx, ty, tx + tile_w, ty + tile_h, 255, 255, 255, 20, 5)
            end
        end
        cy = cy + strip_rows * (tile_h + gap)
    end

    -- Download box.
    if has_dl then
        local kr, kg, kb = ar, ag, ab
        if f.dl_kind == "ok" then kr, kg, kb = 58, 186, 118 elseif f.dl_kind == "err" then kr, kg, kb = 214, 84, 84 end
        local box_h = fh_small * 2 + 20
        draw.rect(x + pad, cy, x + W - pad, cy + box_h, 22, 22, 29, 255, 6)
        draw.rect(x + pad, cy, x + pad + 3, cy + box_h, kr, kg, kb, 255, 1)
        text.draw_ellipsis(font.small, x + pad + 12, cy + 5, 240, 240, 245, 255, f.dl_title or "", inner - 24)
        local bar_y = cy + fh_small + 9
        local bx1, bx2 = x + pad + 12, x + W - pad - 12
        local pct = f.dl_pct or -1
        draw.rect(bx1, bar_y, bx2, bar_y + 4, 44, 44, 54, 255, 2)
        if pct >= 0 then
            draw.rect(bx1, bar_y, bx1 + (bx2 - bx1) * math.min(1, pct), bar_y + 4, kr, kg, kb, 255, 2)
        elseif f.dl_active then
            local seg = (bx2 - bx1) * 0.25
            local p = (ctx.time() * 0.8) % 1
            local s1 = bx1 + (bx2 - bx1 - seg) * p
            draw.rect(s1, bar_y, s1 + seg, bar_y + 4, kr, kg, kb, 255, 2)
        end
        local tline = f.dl_text or ""
        if pct >= 0 and f.dl_active then tline = string.format("%d%%   %s", math.floor(pct * 100 + 0.5), tline) end
        text.draw_ellipsis(font.small, bx1, bar_y + 8, 200, 200, 210, 255, tline, bx2 - bx1)
        cy = cy + box_h + 6
    end

    -- Status line.
    local sr, sg, sb = kind_color(f, ar, ag, ab)
    local sy = y + H - pad - fh_small
    draw.line(x + pad, sy - 8, x + W - pad, sy - 8, 255, 255, 255, 18, 1)
    if f.status_kind == "busy" then
        spinner(x + pad + 5, sy + fh_small * 0.5, 5, sr, sg, sb)
    else
        draw.circle(x + pad + 5, sy + fh_small * 0.5, 4, sr, sg, sb, 255)
    end
    local footer = f.status or ""
    if f.teaser and f.status_kind ~= "err" and f.status_kind ~= "busy" then footer = L.open_hint end
    text.draw_ellipsis(font.small, x + pad + 16, sy, 205, 205, 214, 255, footer, inner - 16)
end)
