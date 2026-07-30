
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
overlay.on_draw("cursor", function()
    if not menu.is_visible() and not teleport.map_is_open()
       and not (welcome and welcome.active()) then return end
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
