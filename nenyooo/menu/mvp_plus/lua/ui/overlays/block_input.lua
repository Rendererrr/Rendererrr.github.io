
local disable = {
    24, 257, 25, 68, 69,
    140, 141, 142,
    27, 19, 20, 48,
    12, 13, 14, 15,
    37, 99,
    44, 38, 21,
    58, 56, 57,
    199, 244, 348,
    74, 86, 73, 357,
    80, 96, 97,
    85, 81, 82, 83, 84,
    180, 181, 241, 242,
    152, 153,
    288, 289, 172, 173, 174, 175, 176
}

script.on_tick(function()
    if not PAD then return end
    -- The first-run wizard owns the screen and every key on it (arrows/Enter/Tab/ESC drive the
    -- steps), so nothing may reach the game underneath -- full lockout, not the partial list below.
    if welcome and welcome.active() then
        PAD.DISABLE_ALL_CONTROL_ACTIONS(0)
        PAD.DISABLE_ALL_CONTROL_ACTIONS(1)
        PAD.DISABLE_ALL_CONTROL_ACTIONS(2)
        return
    end
    if not menu.is_visible() then return end
    -- While typing in a menu text field, lock out ALL game input so keystrokes don't drive the
    -- player/vehicle/weapons (movement controls aren't in the list below). Pause stays enabled.
    if menu.is_text_editing and menu.is_text_editing() then
        PAD.DISABLE_ALL_CONTROL_ACTIONS(0)
        PAD.DISABLE_ALL_CONTROL_ACTIONS(2)
        PAD.ENABLE_CONTROL_ACTION(2, 199, true)
        PAD.ENABLE_CONTROL_ACTION(2, 200, true)
        return
    end
    for _, c in ipairs(disable) do
        PAD.DISABLE_CONTROL_ACTION(0, c, true)
    end
end)
