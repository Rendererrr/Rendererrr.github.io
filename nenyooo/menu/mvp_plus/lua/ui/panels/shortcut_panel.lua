-- Minimal VCA-style shortcut guide: plain outlined text near the upper centre. No card, accent
-- rail, or keycap chrome; it should read like a small native status label over the game world.
overlay.on_draw("shortcut_panel", function()
    if not __panelkit or not __panelkit.gate("shortcut_panel", "Show Shortcuts", true) then return end
    if menu.is_visible() then
        __panelkit.hide("shortcut_panel")
        return
    end

    local scale = (ctx.panel_scale and ctx.panel_scale()) or 1.0
    local fnt = font.small
    local menu_key = menu.vk_name(input.menu_keyboard_vk())
    local menu_pad = input.menu_controller_binding and input.menu_controller_binding() or "LB + D-pad Right"
    local lines = {
        "MENU  " .. menu_key .. " / " .. menu_pad,
        "SPOONER  F9 / RB + D-pad Right",
    }
    local y = math.floor(ctx.screen_h() * 0.12)
    local line_h = text.height(fnt) + 3 * scale
    for i, label in ipairs(lines) do
        local x = math.floor((ctx.screen_w() - text.width(fnt, label)) * 0.5)
        text.draw_outlined(fnt, x, y + (i - 1) * line_h,
            238, 240, 244, 235, 0, 0, 0, 225, 1.25 * scale, label)
    end
end)
