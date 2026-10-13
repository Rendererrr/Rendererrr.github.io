local history = {}
local occupied = {}
local active_frame
local last_clock = -1
local last_width, last_height = 0, 0

features.on_draw("ESP", function(f)
    local payload = f.payload or ""
    if payload == "" then return end
    local sw, sh = ctx.screen_w(), ctx.screen_h()
    local cfg = nil
    local entities = {}
    local label_jobs = {}
    local now = ctx.time()
    if now < last_clock or sw ~= last_width or sh ~= last_height then history = {} end
    if f.frame == nil or f.frame ~= active_frame then
        occupied = {}
        active_frame = f.frame
        for key, item in pairs(history) do
            if now - item.time > 0.5 then history[key] = nil end
        end
    end
    last_clock, last_width, last_height = now, sw, sh

    local function fields(row)
        local out = {}
        for value in string.gmatch(row, "[^|]+") do out[#out + 1] = value end
        return out
    end

    local function colour(value)
        local out = {}
        for part in string.gmatch(value or "", "[^,]+") do out[#out + 1] = tonumber(part) or 0 end
        return { out[1] or 255, out[2] or 255, out[3] or 255, out[4] or 255 }
    end

    local function point(value)
        local out = {}
        for part in string.gmatch(value or "", "[^,]+") do out[#out + 1] = tonumber(part) or 0 end
        return { (out[1] or 0) * sw, (out[2] or 0) * sh, out[3] or 0 }
    end

    for row in string.gmatch(payload, "[^\n]+") do
        local v = fields(row)
        if v[1] == "C" then
            cfg = {
                enabled = tonumber(v[2]) == 1,
                outline = tonumber(v[3]) == 1, box_shape = tonumber(v[4]) or 0,
                outline_style = tonumber(v[5]) or 0, outline_thickness = tonumber(v[6]) or 1.5,
                corner_length = (tonumber(v[7]) or 25) * 0.01, fill_mode = tonumber(v[8]) or 0,
                names = tonumber(v[9]) == 1, distance = tonumber(v[10]) == 1,
                weapon = tonumber(v[11]) == 1, ammo = tonumber(v[12]) == 1,
                vehicle = tonumber(v[13]) == 1, wanted = tonumber(v[14]) == 1,
                speaking = tonumber(v[15]) == 1, god = tonumber(v[16]) == 1,
                invisible = tonumber(v[17]) == 1, model = tonumber(v[18]) == 1,
                entity_id = tonumber(v[19]) == 1,
                health = tonumber(v[20]) == 1, armour = tonumber(v[21]) == 1,
                bar_position = tonumber(v[22]) or 0, bar_thickness = tonumber(v[23]) or 4,
                bar_values = tonumber(v[24]) == 1,
                tracers = tonumber(v[25]) == 1, tracer_origin = tonumber(v[26]) or 2,
                origin_x = tonumber(v[27]) or 50, origin_y = tonumber(v[28]) or 100,
                tracer_endpoint = tonumber(v[29]) or 2, tracer_thickness = tonumber(v[30]) or 1,
                skeleton = tonumber(v[31]) == 1, skeleton_style = tonumber(v[32]) or 0,
                skeleton_thickness = tonumber(v[33]) or 1.2,
                head_marker = tonumber(v[34]) == 1, head_style = tonumber(v[35]) or 1,
                head_size = tonumber(v[36]) or 5, arrows = tonumber(v[37]) == 1,
                arrow_size = tonumber(v[38]) or 12, arrow_margin = tonumber(v[39]) or 28,
                fade = tonumber(v[40]) == 1, fade_start = tonumber(v[41]) or 250,
                max_distance = tonumber(v[42]) or 500,
                visible_colour = colour(v[43]), hidden_colour = colour(v[44]),
                mission_colour = colour(v[45]), friend_colour = colour(v[46]),
                solid_fill = colour(v[47]), gradient_top = colour(v[48]),
                gradient_bottom = colour(v[49]), health_low = colour(v[50]),
                health_full = colour(v[51]), armour_colour = colour(v[52]),
                name_gradient = tonumber(v[53]) == 1, name_start = colour(v[54]), name_end = colour(v[55]),
                label_gradient = tonumber(v[56]) == 1, label_start = colour(v[57]), label_end = colour(v[58]),
                tracer_gradient = tonumber(v[59]) == 1, tracer_start = colour(v[60]), tracer_end = colour(v[61]),
                skeleton_gradient = tonumber(v[62]) == 1, skeleton_start = colour(v[63]), skeleton_end = colour(v[64]),
                box_rgb = tonumber(v[65]) == 1, box_cycle = tonumber(v[66]) or 8, box_spread = (tonumber(v[67]) or 15) * 0.01,
                name_rgb = tonumber(v[68]) == 1, name_cycle = tonumber(v[69]) or 8, name_spread = (tonumber(v[70]) or 15) * 0.01,
                label_rgb = tonumber(v[71]) == 1, label_cycle = tonumber(v[72]) or 8, label_spread = (tonumber(v[73]) or 15) * 0.01,
                tracer_rgb = tonumber(v[74]) == 1, tracer_cycle = tonumber(v[75]) or 8, tracer_spread = (tonumber(v[76]) or 15) * 0.01,
                skeleton_rgb = tonumber(v[77]) == 1, skeleton_cycle = tonumber(v[78]) or 8, skeleton_spread = (tonumber(v[79]) or 15) * 0.01,
                avoid_overlap = tonumber(v[80]) == 1, distance_detail = tonumber(v[81]) == 1,
                full_distance = tonumber(v[82]) or 100, compact_distance = tonumber(v[83]) or 200,
                smooth = tonumber(v[84]) == 1, smooth_time = tonumber(v[85]) or 60,
            }
        elseif v[1] == "E" and #v >= 58 and cfg and cfg.enabled then
            local bones = {}
            for i = 1, 26 do bones[i] = point(v[22 + i]) end
            local box = {}
            for i = 1, 8 do box[i] = point(v[50 + i]) end
            entities[#entities + 1] = {
                cfg = cfg, category = tonumber(v[49]) or 0,
                mission = tonumber(v[50]) == 1, box = box,
                player = tonumber(v[2]) == 1, player_id = tonumber(v[3]) or -1,
                entity_id = tonumber(v[4]) or 0, visible = tonumber(v[5]) == 1,
                dead = tonumber(v[6]) == 1, friend = tonumber(v[7]) == 1,
                on_screen = tonumber(v[8]) == 1, speaking = tonumber(v[9]) == 1,
                god = tonumber(v[10]) == 1, invisible = tonumber(v[11]) == 1,
                distance = tonumber(v[12]) or 0, health = tonumber(v[13]) or 0,
                armour = tonumber(v[14]) or 0, arrow_x = tonumber(v[15]) or 0,
                arrow_y = tonumber(v[16]) or -1, name = v[17] or "",
                weapon = v[18] or "", vehicle = v[19] or "", model = v[20] or "",
                ammo = tonumber(v[21]) or 0, wanted = tonumber(v[22]) or 0, bones = bones,
            }
        end
    end
    if #entities == 0 then return end

    local function clamp(v, lo, hi)
        if v < lo then return lo end
        if v > hi then return hi end
        return v
    end

    local function mix(a, b, t)
        return math.floor(a + (b - a) * clamp(t, 0, 1) + 0.5)
    end

    local function faded(c, factor)
        return { c[1], c[2], c[3], math.floor(c[4] * factor) }
    end

    local function smooth_entity(e)
        local key = tostring(e.category) .. ":" .. tostring(e.entity_id)
        local old = history[key]
        local dt = old and now - old.time or 0
        local can_smooth = cfg.smooth and old and dt > 0 and dt < 0.25
            and old.name == e.name and old.on_screen == e.on_screen and not e.dead and not old.dead
        if can_smooth then
            -- Discontinuous camera/target movement should remain immediate.
            for i, p in ipairs(e.box) do
                local q = old.box[i]
                if p[3] == 1 and q[3] == 1 and ((p[1]-q[1])^2 + (p[2]-q[2])^2) > (math.min(sw,sh)*0.15)^2 then
                    can_smooth = false
                    break
                end
            end
        end
        if can_smooth then
            local alpha = 1 - math.exp(-dt / math.max(0.02, cfg.smooth_time / 1000))
            for _, name in ipairs({"bones","box"}) do
                for i, p in ipairs(e[name]) do
                    local q = old[name][i]
                    if p[3] == 1 and q[3] == 1 then
                        p[1],p[2] = q[1]+(p[1]-q[1])*alpha, q[2]+(p[2]-q[2])*alpha
                    end
                end
            end
            e.health = old.health + (e.health-old.health)*alpha
            e.armour = old.armour + (e.armour-old.armour)*alpha
        end
        history[key] = {time=now, name=e.name, on_screen=e.on_screen, dead=e.dead,
            bones=e.bones, box=e.box, health=e.health, armour=e.armour}
    end

    local function rainbow(phase, alpha)
        local function channel(offset)
            local v = clamp(math.abs(((phase + offset) % 1) * 6 - 3) - 1, 0, 1)
            return math.floor(255 * v * v * (3 - 2 * v) + 0.5)
        end
        return { channel(0), channel(2/3), channel(1/3), alpha }
    end

    local function animate_colours()
        if cfg.animated then return end
        cfg.animated = true
        for _, key in ipairs({"name", "label", "tracer", "skeleton"}) do
            if cfg[key .. "_rgb"] then
                local phase = now / math.max(1, cfg[key .. "_cycle"])
                local a, b = cfg[key .. "_start"], cfg[key .. "_end"]
                cfg[key .. "_start"] = rainbow(phase, a[4])
                cfg[key .. "_end"] = rainbow(phase + cfg[key .. "_spread"], b[4])
                cfg[key .. "_gradient"] = true
            end
        end
        if cfg.box_rgb then
            local phase = now / math.max(1, cfg.box_cycle)
            cfg.box_colour = rainbow(phase, cfg.visible_colour[4])
            cfg.gradient_top = rainbow(phase, cfg.gradient_top[4])
            cfg.gradient_bottom = rainbow(phase + cfg.box_spread, cfg.gradient_bottom[4])
            cfg.solid_fill = rainbow(phase, cfg.solid_fill[4])
            cfg.outline_style = 1
        end
    end

    local function blend(a, b, t, factor)
        return { mix(a[1], b[1], t), mix(a[2], b[2], t), mix(a[3], b[3], t),
            math.floor(mix(a[4], b[4], t) * factor) }
    end

    local function gradient_line(x1, y1, x2, y2, a, b, t1, t2, factor, thickness)
        local length = math.sqrt((x2-x1)^2 + (y2-y1)^2)
        local segments = math.max(1, math.min(24, math.ceil(length / 10)))
        for i = 1, segments do
            local u, v = (i-1)/segments, i/segments
            local c = blend(a, b, t1 + (t2-t1) * (u+v)*0.5, factor)
            draw.line(x1+(x2-x1)*u, y1+(y2-y1)*u, x1+(x2-x1)*v, y1+(y2-y1)*v,
                c[1], c[2], c[3], c[4], thickness)
        end
    end

    local function target_colour(e, factor)
        local c
        c = e.visible and cfg.visible_colour or cfg.hidden_colour
        if e.mission then c = cfg.mission_colour end
        if e.friend and e.category == 0 then c = cfg.friend_colour end
        if e.dead then
            c = { mix(c[1], 140, 0.65), mix(c[2], 140, 0.65), mix(c[3], 145, 0.65), c[4] }
        end
        return faded(c, factor)
    end

    local function alpha_factor(distance)
        if not cfg.fade or distance <= cfg.fade_start then return 1 end
        local span = math.max(1, cfg.max_distance - cfg.fade_start)
        return 1 - clamp((distance - cfg.fade_start) / span, 0, 1) * 0.75
    end

    local function bounds(points, vehicle)
        local left, top, right, bottom = sw, sh, 0, 0
        local count = 0
        for i = 1, #points do
            local p = points[i]
            if p[3] == 1 then
                left, top = math.min(left, p[1]), math.min(top, p[2])
                right, bottom = math.max(right, p[1]), math.max(bottom, p[2])
                count = count + 1
            end
        end
        if count < 2 then return nil end
        local h = math.max(18, bottom - top)
        local center = (left + right) * 0.5
        local min_width = vehicle and 0 or h * 0.43
        if right - left < min_width then left, right = center - min_width * 0.5, center + min_width * 0.5 end
        if vehicle then return left, top, right, bottom end
        return left - 3, top - h * 0.08 - 2, right + 3, bottom + 2
    end

    local function gradient_strip(x1, y1, x2, y2, top_c, bottom_c)
        draw.rect_gradient(x1, y1, x2, y2,
            top_c[1], top_c[2], top_c[3], top_c[4], top_c[1], top_c[2], top_c[3], top_c[4],
            bottom_c[1], bottom_c[2], bottom_c[3], bottom_c[4], bottom_c[1], bottom_c[2], bottom_c[3], bottom_c[4])
    end

    local box_edges = { {1,2}, {1,3}, {2,4}, {3,4}, {5,6}, {5,7}, {6,8}, {7,8}, {1,5}, {2,6}, {3,7}, {4,8} }
    local function draw_box(left, top, right, bottom, c, factor, points)
        local thickness = cfg.outline_thickness
        local gt, gb = faded(cfg.gradient_top, factor), faded(cfg.gradient_bottom, factor)
        local outline_gt, outline_gb = gt, gb
        if cfg.box_rgb then
            outline_gt = { gt[1], gt[2], gt[3], c[4] }
            outline_gb = { gb[1], gb[2], gb[3], c[4] }
        end
        if cfg.box_shape == 2 then
            if not cfg.outline then return end
            for _, edge in ipairs(box_edges) do
                local a, b = points[edge[1]], points[edge[2]]
                if a[3] == 1 and b[3] == 1 then
                    local lc = c
                    if cfg.outline_style == 1 then
                        local t = clamp(((a[2] + b[2]) * 0.5 - top) / math.max(1, bottom - top), 0, 1)
                        lc = blend(outline_gt, outline_gb, t, 1)
                    end
                    draw.line(a[1], a[2], b[1], b[2], 8, 10, 16, math.floor(190 * factor), thickness + 2)
                    draw.line(a[1], a[2], b[1], b[2], lc[1], lc[2], lc[3], lc[4], thickness)
                end
            end
            return
        end
        if cfg.fill_mode == 1 then
            local fc = faded(cfg.solid_fill, factor)
            draw.rect(left, top, right, bottom, fc[1], fc[2], fc[3], fc[4], 0)
        elseif cfg.fill_mode == 2 then
            gradient_strip(left, top, right, bottom, gt, gb)
        end
        if not cfg.outline then return end
        gt, gb = outline_gt, outline_gb

        if cfg.box_shape == 0 then
            draw.rect_outline(left, top, right, bottom, 8, 10, 16, math.floor(190 * factor), 0, thickness + 2)
            if cfg.outline_style == 0 then
                draw.rect_outline(left, top, right, bottom, c[1], c[2], c[3], c[4], 0, thickness)
            else
                draw.rect(left, top, right, top + thickness, gt[1], gt[2], gt[3], gt[4], 0)
                draw.rect(left, bottom - thickness, right, bottom, gb[1], gb[2], gb[3], gb[4], 0)
                gradient_strip(left, top, left + thickness, bottom, gt, gb)
                gradient_strip(right - thickness, top, right, bottom, gt, gb)
            end
            return
        end

        local cw = (right - left) * cfg.corner_length
        local ch = (bottom - top) * cfg.corner_length
        local function line(x1, y1, x2, y2, lc)
            draw.line(x1, y1, x2, y2, 8, 10, 16, math.floor(190 * factor), thickness + 2)
            draw.line(x1, y1, x2, y2, lc[1], lc[2], lc[3], lc[4], thickness)
        end
        local top_c, bottom_c = c, c
        if cfg.outline_style == 1 then top_c, bottom_c = gt, gb end
        line(left, top, left + cw, top, top_c); line(right - cw, top, right, top, top_c)
        line(left, bottom, left + cw, bottom, bottom_c); line(right - cw, bottom, right, bottom, bottom_c)
        line(left, top, left, top + ch, top_c); line(right, top, right, top + ch, top_c)
        line(left, bottom - ch, left, bottom, bottom_c); line(right, bottom - ch, right, bottom, bottom_c)
    end

    local body_links = {
        {1,2}, {2,3}, {3,4},
        {2,5}, {5,6}, {6,7},
        {2,13}, {13,14}, {14,15},
        {4,21}, {21,22},
        {4,24}, {24,25},
    }
    local detail_links = {
        {7,8}, {7,9}, {7,10}, {7,11}, {7,12},
        {15,16}, {15,17}, {15,18}, {15,19}, {15,20},
        {22,23}, {25,26},
    }
    local function skeleton(points, c, distance, top, bottom, factor)
        local function draw_link(link)
            local a, b = points[link[1]], points[link[2]]
            if a[3] == 1 and b[3] == 1 then
                if cfg.skeleton_gradient then
                    local span = math.max(1, bottom-top)
                    gradient_line(a[1], a[2], b[1], b[2], cfg.skeleton_start, cfg.skeleton_end,
                        clamp((a[2]-top)/span,0,1), clamp((b[2]-top)/span,0,1), factor, cfg.skeleton_thickness)
                else
                draw.line(a[1], a[2], b[1], b[2], c[1], c[2], c[3], c[4], cfg.skeleton_thickness)
                end
            end
        end
        for i = 1, #body_links do draw_link(body_links[i]) end
        if cfg.skeleton_style == 1 and distance <= 200 then
            for i = 1, #detail_links do draw_link(detail_links[i]) end
        end
    end

    local function head_marker(p, c)
        if p[3] ~= 1 then return end
        local size = cfg.head_size
        if cfg.head_style == 0 then
            draw.circle(p[1], p[2], size * 0.55, c[1], c[2], c[3], c[4])
        elseif cfg.head_style == 1 then
            draw.circle_outline(p[1], p[2], size, c[1], c[2], c[3], c[4], cfg.outline_thickness)
        else
            draw.line(p[1] - size, p[2], p[1] + size, p[2], c[1], c[2], c[3], c[4], cfg.outline_thickness)
            draw.line(p[1], p[2] - size, p[1], p[2] + size, c[1], c[2], c[3], c[4], cfg.outline_thickness)
        end
    end

    local function tracer_origin()
        if cfg.tracer_origin == 0 then return sw * 0.5, 1 end
        if cfg.tracer_origin == 1 then return sw * 0.5, sh * 0.5 end
        if cfg.tracer_origin == 2 then return sw * 0.5, sh - 1 end
        return sw * cfg.origin_x * 0.01, sh * cfg.origin_y * 0.01
    end

    local function draw_arrow(e, c)
        local dx, dy = e.arrow_x, e.arrow_y
        local len = math.sqrt(dx * dx + dy * dy)
        if len < 0.001 then return end
        dx, dy = dx / len, dy / len
        local half_w = math.max(1, sw * 0.5 - cfg.arrow_margin)
        local half_h = math.max(1, sh * 0.5 - cfg.arrow_margin)
        local tx = math.abs(dx) > 0.001 and half_w / math.abs(dx) or 100000
        local ty = math.abs(dy) > 0.001 and half_h / math.abs(dy) or 100000
        local scale = math.min(tx, ty)
        local tip_x, tip_y = sw * 0.5 + dx * scale, sh * 0.5 + dy * scale
        local base_x, base_y = tip_x - dx * cfg.arrow_size, tip_y - dy * cfg.arrow_size
        local px, py = -dy * cfg.arrow_size * 0.55, dx * cfg.arrow_size * 0.55
        draw.line(tip_x, tip_y, base_x + px, base_y + py, c[1], c[2], c[3], c[4], cfg.outline_thickness)
        draw.line(tip_x, tip_y, base_x - px, base_y - py, c[1], c[2], c[3], c[4], cfg.outline_thickness)
        draw.line(base_x + px, base_y + py, base_x - px, base_y - py, c[1], c[2], c[3], c[4], cfg.outline_thickness)
    end

    local function draw_bars(e, left, top, right, bottom, factor)
        local enabled = {}
        if cfg.health then enabled[#enabled + 1] = { value = clamp(e.health, 0, 1), health = true } end
        if cfg.armour then enabled[#enabled + 1] = { value = clamp(e.armour, 0, 1), health = false } end
        if #enabled == 0 then return end
        local gap, thick = 3, cfg.bar_thickness
        for i = 1, #enabled do
            local bar = enabled[i]
            local c
            if bar.health then
                c = { mix(cfg.health_low[1], cfg.health_full[1], bar.value),
                      mix(cfg.health_low[2], cfg.health_full[2], bar.value),
                      mix(cfg.health_low[3], cfg.health_full[3], bar.value),
                      math.floor(mix(cfg.health_low[4], cfg.health_full[4], bar.value) * factor) }
            else c = faded(cfg.armour_colour, factor) end
            if cfg.bar_position ~= 2 then
                local x
                local on_left = cfg.bar_position == 0 or (cfg.bar_position == 3 and bar.health)
                local offset = cfg.bar_position == 3 and 0 or (i - 1) * (thick + 2)
                if on_left then x = left - gap - thick - offset
                else x = right + gap + offset end
                draw.rect_outline(x - 1, top - 1, x + thick + 1, bottom + 1, 5, 7, 12, math.floor(230 * factor), 0, 1)
                draw.rect(x, top, x + thick, bottom, 18, 18, 22, math.floor(210 * factor), 0)
                draw.rect(x, bottom - (bottom - top) * bar.value, x + thick, bottom, c[1], c[2], c[3], c[4], 0)
                if cfg.bar_values then
                    local value = string.format("%d", math.floor(bar.value * 100 + 0.5))
                    local txp = on_left and (x - text.width(font.small, value) - 2) or (x + thick + 2)
                    text.draw(font.small, txp, bottom - text.height(font.small), c[1], c[2], c[3], c[4], value)
                end
            else
                local y = bottom + gap + (i - 1) * (thick + 2)
                draw.rect_outline(left - 1, y - 1, right + 1, y + thick + 1, 5, 7, 12, math.floor(230 * factor), 0, 1)
                draw.rect(left, y, right, y + thick, 18, 18, 22, math.floor(210 * factor), 0)
                draw.rect(left, y, left + (right - left) * bar.value, y + thick, c[1], c[2], c[3], c[4], 0)
                if cfg.bar_values then
                    local value = string.format("%d", math.floor(bar.value * 100 + 0.5))
                    text.draw(font.small, right + 3, y - 1, c[1], c[2], c[3], c[4], value)
                end
            end
        end
    end

    local function labels(e, left, top, right, bottom, c, factor, full_detail)
        local function label(value, y, gradient, first, last, primary)
            label_jobs[#label_jobs+1] = {value=value, y=y,
                x=(left+right-text.width(font.small,value))*0.5,
                gradient=gradient, first=first, last=last, c=c, factor=factor,
                primary=primary, priority=e.mission and 2 or e.friend and 1 or 0,
                distance=e.distance, order=#label_jobs+1, avoid_overlap=cfg.avoid_overlap}
        end
        local above = ""
        if cfg.names then above = e.name end
        if cfg.distance then
            local d = string.format("%.0fm", e.distance)
            above = above ~= "" and (above .. "  " .. d) or d
        end
        if cfg.speaking and e.speaking then above = above .. (above ~= "" and "  MIC" or "MIC") end
        if above ~= "" then
            label(above, top - text.height(font.small) - 3, cfg.name_gradient, cfg.name_start, cfg.name_end, true)
        end

        if not full_detail then return end
        local rows = {}
        if e.category == 3 then
            if cfg.weapon then rows[#rows + 1] = e.weapon end
            if cfg.ammo then rows[#rows + 1] = tostring(e.ammo) .. " km/h" end
        elseif cfg.weapon then
            local value = e.weapon
            if cfg.ammo then value = value .. "  [" .. tostring(e.ammo) .. "]" end
            rows[#rows + 1] = value
        elseif cfg.ammo then rows[#rows + 1] = tostring(e.ammo) end
        if cfg.vehicle and e.vehicle ~= "-" then rows[#rows + 1] = e.vehicle end
        if cfg.wanted and e.player and e.wanted > 0 then rows[#rows + 1] = "Wanted: " .. tostring(e.wanted) end
        local flags = ""
        if cfg.god and e.god then flags = "GOD" end
        if cfg.invisible and e.invisible then flags = flags .. (flags ~= "" and "  INV" or "INV") end
        if flags ~= "" then rows[#rows + 1] = flags end
        if cfg.model then rows[#rows + 1] = e.model end
        if cfg.entity_id then rows[#rows + 1] = "Entity: " .. tostring(e.entity_id) end
        local y = bottom + 4
        if cfg.bar_position == 2 and (cfg.health or cfg.armour) then
            local count = (cfg.health and 1 or 0) + (cfg.armour and 1 or 0)
            y = y + count * (cfg.bar_thickness + 2) + 2
        end
        for i = 1, #rows do
            local row = rows[i]
            label(row, y, cfg.label_gradient, cfg.label_start, cfg.label_end, false)
            y = y + text.height(font.small) + 1
        end
    end

    local function render_labels()
        table.sort(label_jobs, function(a,b)
            if a.primary ~= b.primary then return a.primary end
            if a.priority ~= b.priority then return a.priority > b.priority end
            if a.distance ~= b.distance then return a.distance < b.distance end
            return a.order < b.order
        end)
        for _, job in ipairs(label_jobs) do
            local value, gradient, first, last = job.value, job.gradient, job.first, job.last
            local c, factor = job.c, job.factor
            local width, height = text.width(font.small,value), text.height(font.small)
            local x = clamp(job.x, 4, math.max(4, sw-width-4))
            local y, placed = job.y, not job.avoid_overlap
            if job.avoid_overlap and width <= sw-8 then
                for attempt=0,3 do
                    y = job.y + (job.primary and -1 or 1)*attempt*(height+4)
                    local free = y >= 2 and y+height+2 <= sh
                    if free then
                        for _, r in ipairs(occupied) do
                            if x-2 < r[3] and x+width+2 > r[1] and y-2 < r[4] and y+height+2 > r[2] then free=false; break end
                        end
                    end
                    if free then placed=true; break end
                end
            end
            if placed then
                occupied[#occupied+1] = {x-2,y-2,x+width+2,y+height+2}
            text.draw(font.small, x + 1, y + 1, 0, 0, 0, c[4], value)
            local width = text.width(font.small, value)
            if gradient and width > 0 then
                -- Clip the whole shaped string instead of splitting UTF-8 characters.
                local slices = math.max(2, math.min(24, math.ceil(width / 6)))
                for i = 1, slices do
                    local col = blend(first, last, (i-1)/(slices-1), factor)
                    draw.push_clip(x + width*(i-1)/slices, y-2, x + width*i/slices, y+text.height(font.small)+2)
                    text.draw(font.small, x, y, col[1], col[2], col[3], col[4], value)
                    draw.pop_clip()
                end
            else
            text.draw(font.small, x, y, c[1], c[2], c[3], c[4], value)
            end

            end
        end
    end

    for i = 1, #entities do
        local e = entities[i]
        cfg = e.cfg
        animate_colours()
        smooth_entity(e)
        local full_detail = not cfg.distance_detail or e.distance <= cfg.full_distance
        local compact = cfg.distance_detail and e.distance > math.max(cfg.full_distance,cfg.compact_distance)
        local factor = alpha_factor(e.distance)
        local c = target_colour(e, factor)
        if not e.on_screen then
            if cfg.arrows then draw_arrow(e, c) end
        else
            local left, top, right, bottom = bounds(e.category == 3 and e.box or e.bones, e.category == 3)
            if left and compact then
                local cx, cy = (left+right)*0.5, (top+bottom)*0.5
                draw.circle_outline(cx,cy,3,c[1],c[2],c[3],c[4],1.25)
                labels(e,cx-3,cy-3,cx+3,cy+3,c,factor,false)
            elseif left then
                draw_box(left, top, right, bottom, cfg.box_rgb and faded(cfg.box_colour, factor) or c, factor, e.box)
                if full_detail and cfg.skeleton and e.category ~= 3 then skeleton(e.bones, c, e.distance, top, bottom, factor) end
                if full_detail and cfg.head_marker and e.category ~= 3 then head_marker(e.bones[1], c) end
                if cfg.tracers then
                    local ox, oy = tracer_origin()
                    local endpoint
                    if e.category == 3 then
                        local y = cfg.tracer_endpoint == 0 and top or cfg.tracer_endpoint == 1 and (top + bottom) * 0.5 or bottom
                        endpoint = { (left + right) * 0.5, y, 1 }
                    elseif cfg.tracer_endpoint == 0 then endpoint = e.bones[1]
                    elseif cfg.tracer_endpoint == 1 then endpoint = { (left + right) * 0.5, (top + bottom) * 0.5, 1 }
                    elseif e.bones[22][3] == 1 and e.bones[25][3] == 1 then
                        endpoint = { (e.bones[22][1] + e.bones[25][1]) * 0.5, math.max(e.bones[22][2], e.bones[25][2]), 1 }
                    elseif e.bones[22][3] == 1 then endpoint = e.bones[22]
                    elseif e.bones[25][3] == 1 then endpoint = e.bones[25]
                    else endpoint = { (left + right) * 0.5, bottom, 1 } end
                    if endpoint[3] == 1 then
                        if cfg.tracer_gradient then
                            gradient_line(ox, oy, endpoint[1], endpoint[2], cfg.tracer_start, cfg.tracer_end, 0, 1, factor, cfg.tracer_thickness)
                        else
                        draw.line(ox, oy, endpoint[1], endpoint[2], c[1], c[2], c[3], c[4], cfg.tracer_thickness)
                        end
                    end
                end
                draw_bars(e, left, top, right, bottom, factor)
                labels(e, left, top, right, bottom, c, factor, full_detail)
            end
        end
    end
    render_labels()
end)
