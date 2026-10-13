-- Current-session modder list. Entries are published only for strong detection signals.
local GREEN = { 92, 214, 145 }
local RED = { 245, 83, 91 }

overlay.on_draw("modders_panel", function()
    if not __panelkit or not __panelkit.gate("modders_panel", "Show Modders", modders) then return end

    local rows = __panelkit.cached("modders_panel")
    if not rows then
        local L = str.panel_modders()
        local entries = modders.list()
        local count = #entries
        rows = {
            { L.current_session, "", section = true },
            { L.detected, string.format("%d", count), color = count > 0 and RED or GREEN },
        }
        if count == 0 then
            rows[#rows + 1] = { L.status, L.clear, color = GREEN }
        else
            for _, entry in ipairs(entries) do
                local reason = entry.reason
                if entry.detections and entry.detections > 1 then
                    reason = string.format("%s (%d)", reason, entry.detections)
                end
                rows[#rows + 1] = { entry.name, reason, color = RED }
            end
        end
        rows.title  = L.title
        rows.digest = { L.detected, string.format("%d", count) }
        __panelkit.cache("modders_panel", rows)
    end
    __panelkit.panel("modders_panel", 360, 330, rows.title, rows, { digest = rows.digest })
end)
