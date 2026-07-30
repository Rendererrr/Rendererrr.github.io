
-- Easy Melee Attack marker. Published fields: active (bool), x, y (normalized 0..1 screen pos of the
-- targeted ped). Draws a small reticle + a "Hold [E]" prompt over the target.
features.on_draw("Easy Melee Attack", function(f)
    if not f.active then return end

    local sw, sh = ctx.screen_w(), ctx.screen_h()
    local x, y = (f.x or 0.5) * sw, (f.y or 0.5) * sh
    local ar, ag, ab = theme.accent()

    -- reticle brackets around the target
    local s = 14
    draw.rect(x - s, y - s, x - s + 6, y - s + 2, ar, ag, ab, 235, 0)
    draw.rect(x - s, y - s, x - s + 2, y - s + 6, ar, ag, ab, 235, 0)
    draw.rect(x + s - 6, y - s, x + s, y - s + 2, ar, ag, ab, 235, 0)
    draw.rect(x + s - 2, y - s, x + s, y - s + 6, ar, ag, ab, 235, 0)
    draw.rect(x - s, y + s - 2, x - s + 6, y + s, ar, ag, ab, 235, 0)
    draw.rect(x - s, y + s - 6, x - s + 2, y + s, ar, ag, ab, 235, 0)
    draw.rect(x + s - 6, y + s - 2, x + s, y + s, ar, ag, ab, 235, 0)
    draw.rect(x + s - 2, y + s - 6, x + s, y + s, ar, ag, ab, 235, 0)

    -- "Hold [E]" prompt above the reticle
    text.draw(font.item, x - 22, y - s - 22, 255, 255, 255, 255, "Hold [E]")
end)
