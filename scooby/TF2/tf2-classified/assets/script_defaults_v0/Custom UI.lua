-- Run from Lua > Scripts or the editor. A "My Tools" tab appears in the sidebar.
local enabled = features.add {
    id = "enabled", label = "My feature", category = "My Tools / General",
    description = "An example feature owned by this script.", default = true, key = "F8"
}
local reset = features.add {
    id = "reset", label = "Reset counter", kind = "action",
    on_trigger = function() print("Reset action triggered") end
}
local tab = ui.tab("tools", "My Tools")
local amount, caption, theme_enabled = 50, "My Lua overlay", false
ui.subtab(tab, "general", "General", function()
    ui.columns(2, function()
        ui.group("Features", function()
            ui.feature(enabled)
            ui.feature(reset)
        end)
        ui.next_column()
        ui.group("Appearance", function()
            local changed
            changed, amount = imgui.slider_float("Amount", amount, 0, 100)
            changed, caption = imgui.input_text("Caption", caption)
            changed, theme_enabled = imgui.checkbox("Custom theme", theme_enabled)
            if changed then
                if theme_enabled then
                    ui.theme { colors = {
                        CheckMark = {0.75, 0.4, 1, 1}, SliderGrab = {0.75, 0.4, 1, 1},
                        Button = {0.25, 0.16, 0.35, 1}, ButtonHovered = {0.35, 0.22, 0.5, 1}
                    }, rounding = 5 }
                else ui.reset_theme() end
            end
        end)
    end)
end)
ui.subtab("settings", "settings", "My Script", function()
    imgui.text("This sub-tab was added to the built-in Settings tab.")
    ui.feature(enabled)
end)
ui.overlay("hud", function()
    if not features.active(enabled) then return end
    local width, height = engine.viewport()
    render.rect(24, height - 76, 240, 42, {0.05, 0.07, 0.09, 0.9}, true, 4)
    render.text(36, height - 65, caption .. "  " .. string.format("%.0f", amount), {0.35, 0.8, 1, 1}, 15)
end)
events.on("update", function()
    -- Call your game's host API here after porting, gated by features.active(enabled).
end)
events.on("shutdown", function() print("My Tools stopped") end)
