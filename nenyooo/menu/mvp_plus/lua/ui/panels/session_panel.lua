
-- Session panel: player count + online/session status (session.* binding).
-- Settings > Theme > Session Panel > Show Session. Snaps to other panels; draggable while menu open.
overlay.on_draw("session_panel", function()
    local st = menu.get_setting("Show Session")
    if not (st and st.on) or (st.value_index == 1 and not menu.is_visible()) then
        if __panelkit then __panelkit.hide("session_panel") end
        return
    end
    if not session or not __panelkit then return end
    local L, C = str.panel_session(), str.common()
    local rows = {
        { L.players, string.format("%d", session.players()) },
        { L.status,  session.online() and C.online or C.offline },
        { L.session, session.in_session() and C.active or "-" },
    }
    __panelkit.panel("session_panel", 20, 330, L.title, rows)
end)
