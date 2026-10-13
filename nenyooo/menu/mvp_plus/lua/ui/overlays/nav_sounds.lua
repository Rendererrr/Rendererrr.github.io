
-- Menu navigation sounds. Runs entirely on the SCRIPT thread (script.on_tick), where the AUDIO
-- native is safe to call directly -- no fiber needed. input.key_repeat(vk) returns true once per
-- accelerating auto-repeat step (and clears it), so a sound plays on EVERY nav step while held --
-- faster the longer you hold, matching the menu's accelerating navigation. The latch is render-thread
-- safe (never misses/double-counts a repeat). Edit the sound names / keys freely.
local SET = "HUD_FRONTEND_DEFAULT_SOUNDSET"
local NAV = { VK.UP, VK.DOWN, VK.LEFT, VK.RIGHT, VK.RETURN, VK.BACK, VK.ESCAPE }
script.on_tick(function()
    if not menu.is_visible() then
        for _, vk in ipairs(NAV) do input.key_repeat(vk) end  -- drain latches so none fire stale on open
        return
    end
    if not AUDIO then return end                          -- natives.lua not loaded
    -- Consume every repeat latch first (so all drain this tick), then pick one sound.
    local up, dn   = input.key_repeat(VK.UP),   input.key_repeat(VK.DOWN)
    local lf, rt   = input.key_repeat(VK.LEFT), input.key_repeat(VK.RIGHT)
    local ret      = input.key_repeat(VK.RETURN)
    local bk, esc  = input.key_repeat(VK.BACK), input.key_repeat(VK.ESCAPE)
    local name
    if up or dn then name = "NAV_UP_DOWN"
    elseif lf or rt then name = "NAV_LEFT_RIGHT"
    elseif ret then name = "SELECT"
    elseif bk or esc then name = "BACK" end
    if name then AUDIO.PLAY_SOUND_FRONTEND(-1, name, SET, false) end
end)
