
-- Info strip: Nenyoo | FPS | MS | RES | clock. FPS is the TRUE present rate from ctx.fps()
-- (frame-gen aware). Settings > Theme > Info Panel > Show Panel. Draggable while menu open.
overlay.on_draw("info_panel", function()
    local st = menu.get_setting("Show Panel")
    if not (st and st.on) or (st.value_index == 1 and not menu.is_visible()) then
        if __panelkit then __panelkit.hide("info_panel") end
        return
    end
    if not __panelkit then return end
    local fps = (ctx.fps and ctx.fps()) or 0
    if fps <= 0 then
        local dt = ctx.delta()
        if dt <= 0 then dt = 1.0 / 60.0 end
        fps = 1.0 / dt
    end
    local ms = 1000.0 / fps
    local ok, wt = pcall(function() return os.date("%H:%M:%S") end)
    local clock
    if ok and wt then
        clock = wt
    else
        local t = math.floor(ctx.time())
        clock = string.format("%02d:%02d", math.floor(t / 60) % 60, t % 60)
    end
    local scale = (ctx.scale and ctx.scale()) or 1.0
    local rw = math.floor(ctx.screen_w() * scale + 0.5)
    local rh = math.floor(ctx.screen_h() * scale + 0.5)
    local s = __panelkit.style
    local F = s.vfont
    local A = { theme.accent() }
    local W, S = s.value_c, s.label_c
    local toks = {}
    local function push(tx, c) toks[#toks + 1] = { tx, c } end
    local function sep()        push("  |  ", S) end
    push("Nenyoo", A); sep()
    push("FPS ", A); push(string.format("%d", math.floor(fps + 0.5)), W); sep()
    push("MS ",  A); push(string.format("%.1f", ms), W);                 sep()
    push("RES ", A); push(string.format("%dx%d", rw, rh), W);            sep()
    push(clock, W)
    local fh = text.height(F)
    __panelkit.info_strip("info_panel", ctx.screen_w() - 320, 20, toks, fh)
end)
