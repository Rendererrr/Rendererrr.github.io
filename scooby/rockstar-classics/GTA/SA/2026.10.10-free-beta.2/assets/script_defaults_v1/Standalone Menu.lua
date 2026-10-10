-- Floating session tools; F9 toggles the window independently of the main menu.
local visible = features.add {
    id="menu", label="Session tools", category="Tools / Session", default=true,
    key="F9", active_list=false
}
local hud = features.add {
    id="hud", label="Session timer HUD", category="Tools / Session", default=false
}
local elapsed, running = 0, false
local function clock()
    local seconds = math.floor(elapsed)
    return string.format("%02d:%02d:%02d", math.floor(seconds/3600), math.floor(seconds/60)%60, seconds%60)
end
local window = ui.window("menu", "Session Tools", {
    width=360, height=255, menu_only=false, attach="none"
}, function()
    imgui.text("Session time: " .. clock())
    imgui.text(string.format("FPS: %.0f", engine.fps()))
    if imgui.button(running and "Pause timer" or "Start timer") then running = not running end
    imgui.same_line()
    if imgui.button("Reset timer") then elapsed = 0 end
    ui.feature(hud)
    ui.keybind(visible, "Window key")
    if imgui.button("Toggle main menu") then ui.menu_visible(not ui.menu_visible()) end
end)
events.on("update", function()
    if running then elapsed = elapsed + math.max(0, engine.delta_time()) end
    ui.window_visible(window, features.active(visible))
end)
ui.overlay("session_timer", function()
    if not features.active(hud) then return end
    local width, height = engine.viewport()
    local text = clock() .. string.format("  |  %.0f FPS", engine.fps())
    render.rect(20, height-55, 240, 32, {0.05,0.07,0.09,0.85}, true, 4)
    render.text(30, height-48, text, {0.3,0.8,1,1}, 14)
end)
