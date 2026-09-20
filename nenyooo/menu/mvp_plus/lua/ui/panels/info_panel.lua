
-- Info strip: Nenyoo | FPS | AVG | LOW | optional MS/RES | clock | rolling FPS graph.
-- FPS is the TRUE present rate from ctx.fps() (frame-gen aware). Draggable while the menu is open,
-- and dockable into the rail like any other panel now that the rail is not this panel.
local fps_history = {}
local fps_window_elapsed = 0
local fps_window_frames = 0
local FPS_HISTORY_SIZE = 64
local FPS_SAMPLE_SECONDS = 0.15


local function setting_enabled(name)
    local setting = menu.get_setting(name)
    return setting and setting.on or false
end
local function update_fps_history(dt, fallback_fps)
    if dt <= 0 or dt > 0.25 then dt = 1.0 / fallback_fps end
    fps_window_elapsed = fps_window_elapsed + dt
    fps_window_frames = fps_window_frames + 1
    if fps_window_elapsed >= FPS_SAMPLE_SECONDS then
        local sample = fps_window_frames / fps_window_elapsed
        if sample <= 0 or sample > 2000 then sample = fallback_fps end
        if #fps_history >= FPS_HISTORY_SIZE then table.remove(fps_history, 1) end
        fps_history[#fps_history + 1] = sample
        fps_window_elapsed = 0
        fps_window_frames = 0
    end

    if #fps_history == 0 then return fallback_fps, fallback_fps end
    local sum, low = 0, fps_history[1]
    for i = 1, #fps_history do
        sum = sum + fps_history[i]
        low = math.min(low, fps_history[i])
    end
    return sum / #fps_history, low
end

overlay.on_draw("info_panel", function()
    -- Deliberately NOT row-cached like the other panels: a throttled frame counter is a broken
    -- frame counter. This is the one panel whose whole point is a live number.
    if not __panelkit or not __panelkit.gate("info_panel", "Show Watermark", true) then return end
    local dt = ctx.delta()
    local fps = (ctx.fps and ctx.fps()) or 0
    if fps <= 0 then
        if dt <= 0 then dt = 1.0 / 60.0 end
        fps = 1.0 / dt
    end
    local avg_fps, low_fps = update_fps_history(dt, fps)
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
    local W, S = s.value_c, s.label_c
    local toks = {}
    local function push(tx, c) toks[#toks + 1] = { tx, c } end
    local function sep()        push("    ", S) end
    local first_group = true
    local function group(label, value)
        if not first_group then sep() end
        if label then push(label, S) end
        push(value, W)
        first_group = false
    end
    group(nil, "Nenyoo")
    group("FPS ", string.format("%d", math.floor(fps + 0.5)))
    group("AVG ", string.format("%d", math.floor(avg_fps + 0.5)))
    group("LOW ", string.format("%d", math.floor(low_fps + 0.5)))
    if setting_enabled("Watermark Frame Time") then group("MS ", string.format("%.1f", ms)) end
    if setting_enabled("Watermark Resolution") then group("RES ", string.format("%dx%d", rw, rh)) end
    group(nil, clock)
    local fh = text.height(F)
    __panelkit.info_strip("info_panel", ctx.screen_w() - 320, 20, toks, fh, {
        graph = fps_history,
        graph_w = 112,
        graph_h = 20,
    })
end)
