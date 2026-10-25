-- Current feature hotkeys. Toggle-style bindings turn green while their option is enabled.
local GREEN = { 92, 214, 145 }
local INACTIVE = { 178, 181, 192 }
local MAX_VISIBLE = 14

overlay.on_draw("hotkeys_panel", function()
    if not __panelkit or not __panelkit.gate("hotkeys_panel", "Show Hotkeys", items and items.hotkeys) then return end

    local rows = __panelkit.cached("hotkeys_panel")
    if not rows then
        local L = str.panel_hotkeys()
        local bindings = items.hotkeys()
        rows = {}
        local visible = math.min(#bindings, MAX_VISIBLE)
        for i = 1, visible do
            local binding = bindings[i]
            rows[#rows + 1] = {
                binding.key,
                binding.name,
                color = binding.enabled and GREEN or INACTIVE,
                keycap = true,
            }
        end
        if #bindings == 0 then
            rows[1] = { "", L.none, color = INACTIVE, allow_empty = true }
        elseif #bindings > MAX_VISIBLE then
            rows[#rows + 1] = {
                "+" .. tostring(#bindings - MAX_VISIBLE),
                L.more,
                color = INACTIVE,
                keycap = true,
            }
        end
        rows.title  = L.title
        rows.digest = { "", string.format("%d", #bindings) }
        __panelkit.cache("hotkeys_panel", rows)
    end
    __panelkit.panel("hotkeys_panel", 700, 20, rows.title, rows, { digest = rows.digest })
end)
