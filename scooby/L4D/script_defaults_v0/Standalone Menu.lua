-- Independent menu in the host viewport. F9 toggles it, even when the main GUI is hidden.
local visible = features.add {
    id = "menu", label = "My menu", category = "My UI", default = true,
    key = "F9", active_list = false
}
local feature = features.add {
    id = "example", label = "Example feature", category = "My UI", default = false
}
local strength, mode = 25, 1
local window = ui.window("menu", "My Independent Menu", {
    width = 390, height = 290, menu_only = false, attach = "none"
}, function()
    imgui.with_style({Button = {0.2, 0.3, 0.5, 1}, CheckMark = {0.4, 0.7, 1, 1}}, function()
        imgui.text("This UI is built by Lua and has its own controls.")
        local changed, enabled = imgui.checkbox("Example feature", features.get(feature))
        if changed then features.set(feature, enabled) end
        changed, strength = imgui.slider_float("Strength", strength, 0, 100)
        changed, mode = imgui.combo("Mode", mode, {"Default", "Alternate", "Custom"})
        if imgui.button("Toggle main GUI") then ui.menu_visible(not ui.menu_visible()) end
        imgui.same_line()
        if imgui.button("Log values") then print(strength, mode, features.active(feature)) end
        imgui.text("F9 hides or reopens this window.")
    end)
end)
events.on("update", function()
    ui.window_visible(window, features.active(visible))
end)
