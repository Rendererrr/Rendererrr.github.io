
-- Smooth cursor. A precise inner dot stays exactly on the pointer (clicks feel
-- accurate) while a soft accent ring eases toward it for a fluid glide. Adds a
-- layered glow, gentle breathing, and smooth press / click feedback. Registered
-- as a global overlay so it draws once on top of every theme, tinted with accent.
local sx, sy    = -1.0, -1.0
local press     = 0.0
local pulse_t   = -1.0
local PULSE_LEN = 0.40
local function ease(speed, dt)
    if dt <= 0 then return 1.0 end
    return 1.0 - math.exp(-speed * dt)
end
-- Shape hint for the ImGui overlay (ImGui.SetMouseCursor / text fields / resize handles): a small glyph
-- beside the pointer, so the ring itself never changes.
local function glyph_line(x1, y1, x2, y2)
    draw.line(x1, y1, x2, y2, 0, 0, 0, 170, 3.4)
    draw.line(x1, y1, x2, y2, 255, 255, 255, 255, 1.6)
end
local function glyph_arrow(cx, cy, dx, dy, len)
    local x1, y1, x2, y2 = cx - dx * len, cy - dy * len, cx + dx * len, cy + dy * len
    glyph_line(x1, y1, x2, y2)
    local px, py = -dy * 3.5, dx * 3.5
    for _, e in ipairs({ { x1, y1, 1 }, { x2, y2, -1 } }) do
        local ex, ey, s = e[1], e[2], e[3]
        glyph_line(ex, ey, ex + (dx * 4 + px) * s, ey + (dy * 4 + py) * s)
        glyph_line(ex, ey, ex + (dx * 4 - px) * s, ey + (dy * 4 - py) * s)
    end
end
local function draw_shape(kind, mx, my)
    local x, y = mx + 15, my + 15
    if kind == 1 then
        glyph_line(x, y - 7, x, y + 7)
        glyph_line(x - 3, y - 7, x + 3, y - 7)
        glyph_line(x - 3, y + 7, x + 3, y + 7)
    elseif kind == 2 then
        glyph_arrow(x, y, 1, 0, 7)
        glyph_arrow(x, y, 0, 1, 7)
    elseif kind == 3 then
        glyph_arrow(x, y, 0, 1, 7)
    elseif kind == 4 then
        glyph_arrow(x, y, 1, 0, 7)
    elseif kind == 5 then
        glyph_arrow(x, y, 0.7071, -0.7071, 7)
    elseif kind == 6 then
        glyph_arrow(x, y, 0.7071, 0.7071, 7)
    elseif kind == 7 then
        draw.circle(x, y, 4, 255, 255, 255, 255)
        draw.circle_outline(x, y, 6.5, 255, 255, 255, 200, 1.4)
    elseif kind == 8 then
        draw.circle_outline(x, y, 6, 0, 0, 0, 170, 3.4)
        draw.circle_outline(x, y, 6, 235, 70, 70, 255, 1.8)
        draw.line(x - 4.2, y + 4.2, x + 4.2, y - 4.2, 235, 70, 70, 255, 1.8)
    end
end

overlay.on_draw("cursor", function()
    if not menu.is_visible() and not teleport.map_is_open()
       and not (welcome and welcome.active())
       and not (ui.cursor_forced and ui.cursor_forced()) then return end
    local mx, my = input.mouse_x(), input.mouse_y()
    local dt = ctx.delta()
    local t  = ctx.time()
    local ar, ag, ab = theme.accent()
    if sx < 0 then sx, sy = mx, my end
    local k = ease(26.0, dt)
    sx = sx + (mx - sx) * k
    sy = sy + (my - sy) * k
    local target = input.mouse_down(0) and 1.0 or 0.0
    press = press + (target - press) * ease(30.0, dt)
    if input.mouse_clicked(0) then pulse_t = t end
    local breathe = 0.5 + 0.5 * math.sin(t * 2.2)
    local R = 10.0 - press * 3.0 + breathe * 0.8
    -- soft layered glow behind for depth + contrast on bright backgrounds
    draw.circle(sx, sy, R + 7.0, ar, ag, ab, 18)
    draw.circle(sx, sy, R + 3.5, ar, ag, ab, 30)
    draw.circle_outline(sx, sy, R, 0, 0, 0, 90, 3.0)
    -- accent ring (alpha breathes subtly)
    draw.circle_outline(sx, sy, R, ar, ag, ab, math.floor(210 + 30 * breathe), 1.7)
    -- precise inner dot at the true pointer; grows slightly while pressed
    local dot = 2.0 + press * 1.6
    draw.circle(mx, my, dot + 1.2, 0, 0, 0, 120)
    draw.circle(mx, my, dot, 255, 255, 255, 255)
    if ImGui and ImGui.GetMouseCursor then
        local kind = ImGui.GetMouseCursor()
        if kind and kind > 0 then draw_shape(kind, mx, my) end
    end
    -- expanding click ripple
    if pulse_t >= 0 then
        local e = (t - pulse_t) / PULSE_LEN
        if e < 1.0 then
            draw.circle_outline(sx, sy, R + e * 18.0, ar, ag, ab, math.floor(190 * (1.0 - e)), 1.6)
        else
            pulse_t = -1.0
        end
    end
end)
