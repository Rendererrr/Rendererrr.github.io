features.on_draw("Weapon Condition HUD", function(f)
    if type(f.condition) ~= "number" or not __panelkit then return end

    local low = f.condition <= (f.low_threshold or 25)
    local condition_color = low and __panelkit.rgb(f, "warning_", 240, 75, 60) or __panelkit.rgb(f, "condition_", 95, 210, 105)
    local function meter(label, value, color, text_color)
        value = math.max(0, math.min(100, value or 0))
        return { label, string.format("%d%%", math.floor(value + 0.5)), bar = value / 100, bar_h = 4,
            bar_color = color, color = text_color }
    end

    local rows = { meter("Condition", f.condition, condition_color, low and condition_color or nil) }
    if f.show_dirt_soot then
        rows[#rows + 1] = meter("Dirt", f.dirt, { 176, 132, 76 })
        rows[#rows + 1] = meter("Soot", f.soot, { 105, 105, 112 })
    end
    if f.show_permanent then
        rows[#rows + 1] = meter("Permanent Wear", f.permanent_wear, { 200, 120, 75 })
    end
    __panelkit.feature("weapon_condition_hud", "Weapon Condition", rows, 82, 66,
        { digest = { "", string.format("%d%%", math.floor(math.max(0, f.condition) + 0.5)) } })
end)
