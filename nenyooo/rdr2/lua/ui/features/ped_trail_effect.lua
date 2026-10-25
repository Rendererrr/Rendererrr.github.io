features.on_draw("Trail Effect", function(f)
    if type(f.segments) ~= "string" then return end
    local sw, sh = ctx.screen_w(), ctx.screen_h()
    if not sw or not sh or sw < 1 or sh < 1 then return end
    for row in string.gmatch(f.segments, "[^\n]+") do
        local x1, y1, x2, y2, alpha = string.match(row,
            "([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)")
        x1, y1, x2, y2, alpha = tonumber(x1), tonumber(y1), tonumber(x2), tonumber(y2), tonumber(alpha)
        if x1 and y1 and x2 and y2 and alpha and alpha > 0 then
            alpha = math.min(1, alpha)
            draw.line(x1 * sw, y1 * sh, x2 * sw, y2 * sh, 170, 65, 255, alpha * 70, 7)
            draw.line(x1 * sw, y1 * sh, x2 * sw, y2 * sh, 225, 180, 255, alpha * 240, 2)
        end
    end
end)
