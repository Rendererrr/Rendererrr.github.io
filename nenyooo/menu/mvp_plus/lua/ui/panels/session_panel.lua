
-- Rich Session panel. Network/native values come from hud_feed's script-thread snapshot;
-- this render-thread callback only formats data that was already published safely.
-- Settings > Theme > HUD Panels > Show Session. Docks into the rail; draggable while menu open.
local function present(value)
    return value and value ~= "" and value or "-"
end

overlay.on_draw("session_panel", function()
    if not __panelkit or not __panelkit.gate("session_panel", "Show Session", session) then return end

    local rows = __panelkit.cached("session_panel")
    if not rows then
        local L, C = str.panel_session(), str.common()
        local type_labels = {
            [0] = C.offline,
            [1] = L.public,
            [2] = L.invite_only,
            [3] = L.closed_friends,
            [4] = L.closed_crew,
            [5] = L.solo,
            [6] = L.transition,
            [7] = C.na,
        }
        local nat_labels = {
            [1] = L.open,
            [2] = L.moderate,
            [3] = L.strict,
        }
        local connection_labels = {
            [1] = L.direct,
            [2] = L.relay,
            [3] = L.peer_relay,
            [4] = L.forced_relay,
        }

        local players, max_players = session.players(), session.max_players()
        local player_value = max_players > 0
            and string.format("%d / %d", players, max_players)
            or string.format("%d", players)
        local queue_position, queue_total = session.host_queue()
        local queue_value = queue_position > 0 and queue_total > 0
            and string.format("%d / %d", queue_position, queue_total)
            or C.na
        local in_session = session.in_session()
        local modder_count = modders and modders.count() or 0
        rows = {
            { L.status, session.online() and C.online or C.offline },
        }
        if in_session then
            rows[#rows + 1] = { L.session_type,  type_labels[session.session_type()] or C.na }
            rows[#rows + 1] = { L.matchmaking,   session.matchmaking_open() and L.open or L.closed }
            rows[#rows + 1] = { L.players,       player_value }
            rows[#rows + 1] = { L.modders,       string.format("%d", modder_count) }
            rows[#rows + 1] = { L.private_slots, string.format("%d", session.private_slots()) }
            rows[#rows + 1] = { L.host,          present(session.host()) }
            rows[#rows + 1] = { L.next_host,     present(session.next_host()) }
            rows[#rows + 1] = { L.script_host,   present(session.script_host()) }
            rows[#rows + 1] = { L.host_queue,    queue_value }
            rows[#rows + 1] = { L.host_token,    present(session.host_token()) }
            rows[#rows + 1] = { L.nat,           nat_labels[session.nat_type()] or C.na }
            rows[#rows + 1] = { L.connection,    connection_labels[session.connection_type()] or C.na }
            rows[#rows + 1] = { L.user,          present(session.user()) }
        end
        rows.title  = L.title
        rows.digest = in_session and { L.players, player_value }
                   or { L.status, session.online() and C.online or C.offline }
        __panelkit.cache("session_panel", rows)
    end
    __panelkit.panel("session_panel", 20, 330, rows.title, rows, { digest = rows.digest })
end)
