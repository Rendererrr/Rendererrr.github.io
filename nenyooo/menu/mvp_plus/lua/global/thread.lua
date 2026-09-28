
-- thread.* — the ONE foundation coroutine scheduler (resumed on the script thread). Dialects share it.
thread = thread or {}
__nyx_threads = __nyx_threads or {}
local sched = __nyx_threads
local running_owner = nil
local function owner_now()
    if running_owner and running_owner ~= "" then return running_owner end
    if script and script.current_owner then
        local owner = script.current_owner()
        if type(owner) == "string" and owner ~= "" then return owner end
    end
    return nil
end
function thread.current_owner() return owner_now() end
function thread.with_owner(owner, fn, ...)
    local previous = running_owner
    running_owner = owner
    local values = table.pack(pcall(fn, ...))
    running_owner = previous
    if not values[1] then error(values[2], 0) end
    return table.unpack(values, 2, values.n)
end
-- thread.now(): milliseconds since game start (drives yield wake times).
function thread.now() return math.floor((ctx.time() or 0) * 1000) end
-- thread.create(fn, ...): spawn a cooperative coroutine; errors are reported with a traceback.
function thread.create(fn, ...)
    local args = table.pack(...)
    local co = coroutine.create(function()
        local ok, err = xpcall(function() return fn(table.unpack(args, 1, args.n)) end, debug.traceback)
        if not ok then
            print("[nenyoo] thread error: " .. tostring(err))
            if notify then notify.push("Script", tostring(err), 2, 6.0) end
        end
    end)
    sched[#sched + 1] = { co = co, wake = 0, owner = owner_now() }
    return co
end
-- thread.yield(ms)/sleep(ms): cooperatively yield (optionally for at least `ms` milliseconds).
function thread.yield(ms) return coroutine.yield(ms or 0) end
thread.sleep = thread.yield
function thread.count() return #sched end
-- thread.stop(co): remove a coroutine from the scheduler.
function thread.stop(co) for i = #sched, 1, -1 do if sched[i].co == co then table.remove(sched, i) end end end
function thread.stop_self() thread.stop(coroutine.running()); coroutine.yield() end
-- thread.adopt(co): schedule an already-created (and optionally already-resumed) coroutine.
function thread.adopt(co) sched[#sched + 1] = { co = co, wake = 0, owner = owner_now() } end
-- thread.scheduled(co): is this coroutine currently in the scheduler?
function thread.scheduled(co) for _, t in ipairs(sched) do if t.co == co then return true end end return false end
-- thread.clear(): drop every scheduled coroutine.
function thread.clear() for i = #sched, 1, -1 do sched[i] = nil end end
function thread.clear_owner(owner)
    if not owner or owner == "" then return end
    for i = #sched, 1, -1 do if sched[i].owner == owner then table.remove(sched, i) end end
end

__on_user_script_unload = __on_user_script_unload or {}
__on_user_script_unload[#__on_user_script_unload + 1] = function(owner)
    thread.clear_owner(owner)
end

script.on_tick(function()
    local now = thread.now()
    local i = 1
    while i <= #sched do
        local t = sched[i]
        if now >= t.wake then
            local previous_owner = running_owner
            running_owner = t.owner
            local ok, ret = coroutine.resume(t.co)
            running_owner = previous_owner
            if not ok then
                print("[nenyoo] thread error: " .. tostring(ret))
                if notify then notify.push("Script", tostring(ret), 2, 6.0) end
            end
            if coroutine.status(t.co) == "dead" then table.remove(sched, i); i = i - 1
            else t.wake = now + (tonumber(ret) or 0) end
        end
        i = i + 1
    end
end)
