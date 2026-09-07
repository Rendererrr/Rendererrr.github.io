-- Session security overlay backed by script-thread protection and network snapshots.
local GREEN = { 92, 214, 145 }
local YELLOW = { 235, 182, 70 }
local RED = { 245, 83, 91 }
local MUTED = { 145, 148, 160 }

local function present(value)
    return value and value ~= "" and value or "-"
end

local function activity_text(L)
    if not security.has_activity() then return L.no_activity end
    local seconds = math.floor(security.last_activity_age_ms() / 1000)
    if seconds < 1 then return L.just_now end
    if seconds < 60 then return string.format("%d %s", seconds, L.seconds_ago) end
    local minutes = math.floor(seconds / 60)
    if minutes < 60 then return string.format("%d %s", minutes, L.minutes_ago) end
    return string.format("%d %s", math.floor(minutes / 60), L.hours_ago)
end

-- Link quality, from the mean round-trip and packet loss hud_feed samples across the remote
-- players. Solo or offline there is nobody to measure against, so the row says N/A rather than
-- reporting a suspiciously perfect 0 ms.
local function quality_row(L, C)
    if not (security.link_valid and security.link_valid()) then
        return { L.quality, C.na, color = MUTED }
    end
    local ping = security.ping()
    local loss = security.packet_loss()
    local bars, tone
    if ping < 60 and loss < 2.0 then      bars, tone = 4, GREEN
    elseif ping < 95 and loss < 5.0 then  bars, tone = 3, GREEN
    elseif ping < 150 and loss < 10.0 then bars, tone = 2, YELLOW
    else                                   bars, tone = 1, RED end
    return { L.quality, string.format("%d ms", ping), color = tone,
             signal = { bars = bars, tone = tone } }
end

overlay.on_draw("protection_panel", function()
    if not __panelkit or not __panelkit.gate("protection_panel", "Show Protections", security) then return end

    local rows = __panelkit.cached("protection_panel")
    if not rows then
        local L, C = str.panel_protection(), str.common()
        local online = security.online()
        local in_session = security.in_session()
        local transition = security.in_transition()
        local stable = online and in_session and not transition
        local players, max_players = security.players(), security.max_players()
        local player_value = max_players > 0
            and string.format("%d / %d", players, max_players)
            or string.format("%d", players)
        local enabled, total = security.enabled_guards(), security.total_guards()
        local detected, blocked = security.detected(), security.blocked()

        local session_value = stable and L.stable or (transition and L.transition or C.offline)
        local session_color = stable and GREEN or (transition and YELLOW or RED)
        local sync_value = stable and L.healthy or (transition and L.recovering or L.unavailable)
        local sync_color = stable and GREEN or (transition and YELLOW or RED)
        local protection_heading = L.protection_health
        if not protection_heading or protection_heading:find("%S") == nil then protection_heading = L.protections end
        rows = {
            { L.current_session, "", section = true, no_line = true },
            { L.session, session_value, color = session_color },
            { L.players, player_value },
            { L.script_host, present(security.script_host()) },
            { L.host_migration, transition and L.active or L.idle, color = transition and YELLOW or GREEN },
            { L.sync, sync_value, color = sync_color },
            quality_row(L, C),
            { protection_heading, "", section = true, no_line = true },
            { L.guard_coverage, string.format("%d / %d", enabled, total), color = enabled == total and GREEN or YELLOW },
            { L.protections, string.format("%d %s | %d %s", blocked, L.blocked, detected, L.detected),
                color = detected > 0 and YELLOW or GREEN },
            { L.last_activity, activity_text(L), color = security.has_activity() and YELLOW or MUTED },
        }

        if not stable then
            rows[#rows + 1] = { L.recovery, "", section = true, no_line = true }
            rows[#rows + 1] = {
                L.state,
                transition and L.recovering or L.no_active_session,
                color = YELLOW,
            }
        end
        rows.title  = L.title
        rows.digest = { L.session, session_value }
        __panelkit.cache("protection_panel", rows)
    end
    __panelkit.panel("protection_panel", 360, 20, rows.title, rows, { digest = rows.digest })
end)
