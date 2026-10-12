
-- Damage Numbers. Published fields: active (bool), popups (string blob of
-- "x,y,progress,amount,type;" entries; x/y are 0..1 screen coords, type 0 hit / 1 headshot / 2 kill).
local COLORS = {
    [0] = { 255, 255, 255 },
    [1] = { 255, 200, 60 },
    [2] = { 255, 70, 70 },
}

features.on_draw("Damage Numbers", function(f)
    if not f.active or not f.popups then return end

    local sw, sh = ctx.screen_w(), ctx.screen_h()
    for xs, ys, ps, amt, ty in string.gmatch(f.popups, "([^,]+),([^,]+),([^,]+),([^,]+),([^;]+);") do
        local x, y, p = tonumber(xs) * sw, tonumber(ys) * sh, tonumber(ps)
        local c = COLORS[tonumber(ty)] or COLORS[0]
        local a = math.floor(255 * (1 - p * p))
        local label = amt
        if ty == "1" then label = amt .. "!" elseif ty == "2" then label = "x " .. amt end
        local fnt = ty == "0" and font.small or font.item
        local w = text.width(fnt, label)
        text.draw(fnt, x - w * 0.5 + 1, y + 1, 0, 0, 0, math.floor(a * 0.7), label)
        text.draw(fnt, x - w * 0.5, y, c[1], c[2], c[3], a, label)
    end
end)
