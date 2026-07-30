
-- No Clip controls HUD. Published fields: active (bool).
features.on_draw("No Clip", function(f)
    if not f.active then return end

    local lines = {
        "NO CLIP",
        "W / A / S / D  -  Move",
        "Space  -  Up",
        "Ctrl  -  Down",
        "Shift  -  Boost",
    }

    local sw, sh = ctx.screen_w(), ctx.screen_h()
    local pad = 10
    local lh  = text.height(font.item) + 4
    local w   = 230
    local h   = pad * 2 + lh * #lines
    local x   = 20
    local y   = sh * 0.5 - h * 0.5

    draw.rect(x, y, x + w, y + h, 12, 12, 18, 200, 6)
    draw.rect(x, y, x + 3, y + h, 168, 85, 247, 255, 6)  -- accent edge

    local ar, ag, ab = theme.accent()
    for i, line in ipairs(lines) do
        local ty = y + pad + (i - 1) * lh
        if i == 1 then
            text.draw(font.item, x + pad + 6, ty, ar, ag, ab, 255, line)
        else
            text.draw(font.item, x + pad + 6, ty, 230, 230, 235, 255, line)
        end
    end
end)
