local traces, trace_until = {}, 0

features.on_draw("Magic Bullets", function(f)
    if not f.enabled then traces = {}; return end
    local sw, sh = ctx.screen_w(), ctx.screen_h()
    local cx, cy = sw * 0.5, sh * 0.5
    local r, g, b, a = f.r or 255, f.g or 190, f.b or 65, f.a or 230
    local fov = f.fov or 160
    if f.screen_width and f.screen_width > 0 then fov = fov * sw / f.screen_width end
    if f.show_fov then draw.circle_outline(cx, cy, fov, r, g, b, math.floor(a * 0.75), 1.3) end

    local current = {}
    for i = 0, 4 do
        if f["target_" .. i .. "_valid"] then
            current[#current + 1] = { f["target_" .. i .. "_x"] or 0.5, f["target_" .. i .. "_y"] or 0.5 }
        end
    end
    if #current > 0 then
        traces = current
        trace_until = ctx.time() + (f.trace_time or 250) / 1000
    end
    local visible = #current > 0 and current or (ctx.time() < trace_until and traces or {})
    for _, p in ipairs(visible) do
        local x, y = p[1] * sw, p[2] * sh
        if f.show_trace or f.show_line then draw.line(cx, cy, x, y, r, g, b, math.floor(a * 0.55), 1.2) end
        if f.show_marker then draw.circle_outline(x, y, 10, r, g, b, a, 1.8) end
        if f.locked_dot then draw.circle(x, y, f.dot_size or 4, r, g, b, a) end
    end
    if f.show_counter then
        local label = "Magic Bullets  " .. tostring(math.floor(f.hit_count or 0))
        text.draw(font.small, sw - text.width(font.small, label) - 24, sh * 0.72, r, g, b, a, label)
    end
end)
