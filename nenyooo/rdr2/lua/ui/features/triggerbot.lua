features.on_draw("TriggerBot", function(f)
    if type(f.markers) ~= "string" or f.markers == "" then return end
    local sw, sh = ctx.screen_w(), ctx.screen_h()
    if not sw or not sh or sw < 1 or sh < 1 then return end
    for row in string.gmatch(f.markers, "([^\n]+)") do
        local nx, ny = string.match(row, "([^\t]+)\t([^\t]+)")
        nx, ny = tonumber(nx), tonumber(ny)
        if nx and ny then
            local x, y = nx * sw, ny * sh
            draw.circle_outline(x, y, 3, 255, 255, 255, 255, 4)
        end
    end
end)
