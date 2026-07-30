
-- input.* — additive over the engine input table (key_pressed/key_just_pressed/mouse_*). Adds a hotkey
-- helper that polls a key on the foundation scheduler.
input = input or {}
-- input.hotkey(vk, fn): run fn() once each time virtual-key `vk` transitions to pressed.
function input.hotkey(vk, fn)
    return thread.create(function()
        while true do
            if input.key_just_pressed(vk) then fn() end
            thread.yield()
        end
    end)
end
