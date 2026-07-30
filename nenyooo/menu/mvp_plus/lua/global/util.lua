
-- util.* — misc foundation helpers (time, log, toast, hashing, yield convenience). Additive (the engine
-- already binds util.hsv_to_rgb/util.rgb_to_hsv).
util = util or {}
-- util.joaat(s): the game string hash (JOAAT), matching GET_HASH_KEY.
function util.joaat(s)
    s = string.lower(tostring(s))
    local h = 0
    for i = 1, #s do
        h = (h + string.byte(s, i)) & 0xFFFFFFFF
        h = (h + (h << 10)) & 0xFFFFFFFF
        h = (h ~ (h >> 6)) & 0xFFFFFFFF
    end
    h = (h + (h << 3)) & 0xFFFFFFFF
    h = (h ~ (h >> 11)) & 0xFFFFFFFF
    h = (h + (h << 15)) & 0xFFFFFFFF
    return h
end
-- util.yield/wait(ms): cooperative yield via the foundation scheduler.
function util.yield(ms) return thread.yield(ms) end
util.wait = util.yield
-- util.create_thread(fn, ...): spawn a foundation scheduler coroutine.
function util.create_thread(fn, ...) return thread.create(fn, ...) end
-- util.time_ms(): milliseconds since game start.
function util.time_ms() return thread.now() end
util.log = util.log or print
-- util.toast(msg): a transient on-screen notification.
function util.toast(msg) if notify then notify.push("", tostring(msg), 4, 4.0) end end
