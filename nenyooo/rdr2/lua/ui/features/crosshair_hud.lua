features.on_draw("Crosshair HUD", function(f)
    local sw, sh = ctx.screen_w(), ctx.screen_h()
    if not sw or not sh or sw < 1 or sh < 1 then return end
    local x, y = sw * 0.5, sh * 0.5
    local shape = math.max(0, math.min(2, math.floor(f.shape or 0)))
    local gap = math.max(0, math.min(30, f.gap or 5))
    local length = math.max(2, math.min(40, f.length or 9))
    local thickness = math.max(0.5, math.min(6, f.thickness or 1.5))
    local r, g, b, a = f.color_r or 255, f.color_g or 255,
        f.color_b or 255, f.color_a or 255
    local or_, og, ob, oa = f.outline_r or 0, f.outline_g or 0,
        f.outline_b or 0, f.outline_a or 210

    local function line(x1, y1, x2, y2)
        if f.outline then
            draw.line(x1, y1, x2, y2, or_, og, ob, oa, thickness + 2)
        end
        draw.line(x1, y1, x2, y2, r, g, b, a, thickness)
    end

    if shape == 2 then
        if f.outline then
            draw.circle_outline(x, y, gap + length, or_, og, ob, oa, thickness + 2)
        end
        draw.circle_outline(x, y, gap + length, r, g, b, a, thickness)
    elseif shape == 1 then
        local diagonal = 0.70710678
        line(x - gap * diagonal, y - gap * diagonal,
            x - (gap + length) * diagonal, y - (gap + length) * diagonal)
        line(x + gap * diagonal, y - gap * diagonal,
            x + (gap + length) * diagonal, y - (gap + length) * diagonal)
        line(x - gap * diagonal, y + gap * diagonal,
            x - (gap + length) * diagonal, y + (gap + length) * diagonal)
        line(x + gap * diagonal, y + gap * diagonal,
            x + (gap + length) * diagonal, y + (gap + length) * diagonal)
    else
        line(x - gap - length, y, x - gap, y)
        line(x + gap, y, x + gap + length, y)
        line(x, y - gap - length, x, y - gap)
        line(x, y + gap, x, y + gap + length)
    end

    if f.center_dot then
        local radius = math.max(1.2, thickness)
        if f.outline then draw.circle(x, y, radius + 1.5, or_, og, ob, oa) end
        draw.circle(x, y, radius, r, g, b, a)
    end
end)
