features.on_draw("Law Status HUD", function(f)
    if type(f.wanted_level) ~= "number" or not __panelkit then return end

    local active = f.incident or f.witnesses or f.witnesses_pending or f.wanted_level > 0
    if f.hide_inactive and not active then return end
    local warning = active and __panelkit.rgb(f, "warning_", 235, 65, 55) or nil

    local level = math.max(0, math.floor(f.wanted_level or 0))
    local status = active and "Active" or "Clear"
    local rows = {
        { "Status", status, color = warning },
        { "Wanted", level > 0 and string.rep("*", level) or "Clear", color = level > 0 and warning or nil },
    }
    if f.show_bounty then
        rows[#rows + 1] = { "Bounty", string.format("$%.2f", math.max(0, f.bounty or 0) / 100) }
    end
    if f.show_score then
        rows[#rows + 1] = { "Wanted Score", tostring(math.max(0, math.floor(f.wanted_score or 0))) }
    end
    if f.show_witnesses then
        local witness = f.witnesses and "Active" or (f.witnesses_pending and "Pending" or "Clear")
        rows[#rows + 1] = { "Witnesses", witness, color = (f.witnesses or f.witnesses_pending) and warning or nil }
    end
    if f.show_last_seen and type(f.seconds_since_seen) == "number" and f.seconds_since_seen >= 0 then
        rows[#rows + 1] = { "Last Seen", string.format("%.1f s", f.seconds_since_seen) }
    end
    __panelkit.feature("law_status_hud", "Law Status", rows, 82, 12, { digest = { "", status } })
end)
