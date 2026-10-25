-- event.* — named events for scripts.
--
--   event.on(name, fn) -> fn        subscribe (returns fn so it can be passed to event.off later)
--   event.off(name, fn)             unsubscribe
--   event.emit(name, ...)           fire an event (scripts may use their own names too)
--
-- Built-in events:
--   "menu_open", "menu_close"            the menu was shown / hidden               (render thread)
--   "key_down"(vk), "key_up"(vk)         a key was pressed / released (Win32 VK)   (render thread)
--   "scripts_reloading"                  user scripts are about to be reloaded
--   "unload"                             the Lua state is about to be torn down (menu unload / rebuild)
--
-- Each handler runs in pcall, so one failing handler does not stop the others. Handlers registered by a
-- user script are removed when user scripts reload.

event = event or {}
script = script or {}

local handlers = {}   -- name -> { { fn = f, owner = "user\\..." | nil }, ... }
local unload_handlers = {}

local function current_owner()
    if thread and thread.current_owner then
        local owner = thread.current_owner()
        if owner and owner ~= "" then return owner end
    end
    if script and script.current_owner then
        local owner = script.current_owner()
        if owner and owner ~= "" then return owner end
    end
    return nil
end

local function report(name, err)
    local msg = "Event '" .. tostring(name) .. "' handler failed: " .. tostring(err)
    if log and log.warn then log.warn(msg) else print(msg) end
end

local function has_handlers(name)
    local list = handlers[name]
    return list ~= nil and #list > 0
end

function event.on(name, fn)
    if type(name) ~= "string" or type(fn) ~= "function" then error("event.on(name, fn): name string and function expected", 2) end
    local list = handlers[name]
    if not list then list = {}; handlers[name] = list end
    list[#list + 1] = { fn = fn, owner = current_owner() }
    return fn
end

function event.off(name, fn)
    local list = handlers[name]
    if not list then return end
    for i = #list, 1, -1 do
        if list[i].fn == fn then table.remove(list, i) end
    end
end

function event.emit(name, ...)
    local list = handlers[name]
    if not list or #list == 0 then return end
    local snapshot = { table.unpack(list) }   -- handlers may subscribe / unsubscribe while dispatching
    for i = 1, #snapshot do
        local entry = snapshot[i]
        local ok, err
        if entry.owner and thread and thread.with_owner then
            ok, err = pcall(thread.with_owner, entry.owner, entry.fn, ...)
        else
            ok, err = pcall(entry.fn, ...)
        end
        if not ok then report(name, err) end
    end
end

function event.emit_owner(name, owner, ...)
    local list = handlers[name]
    if not list or #list == 0 or not owner or owner == "" then return end
    local snapshot = { table.unpack(list) }
    for i = 1, #snapshot do
        local entry = snapshot[i]
        if entry.owner == owner then
            local runner = function(...) return entry.fn(...) end
            local ok, err
            if thread and thread.with_owner then ok, err = pcall(thread.with_owner, owner, runner, ...)
            else ok, err = pcall(runner, ...) end
            if not ok then report(name, err) end
        end
    end
end

function script.on_unload(fn)
    if type(fn) ~= "function" then error("script.on_unload(fn): function expected", 2) end
    local owner = current_owner()
    if not owner then error("script.on_unload(fn): only user scripts can register cleanup", 2) end
    unload_handlers[#unload_handlers + 1] = { fn = fn, owner = owner }
    return fn
end

-- Engine entry point (lua_engine.cpp emits "scripts_reloading" and "unload").
function __event_emit(name, ...) event.emit(name, ...) end

-- A user-script reload drops that generation's handlers; foundation and UI handlers stay.
__on_user_scripts_reload = __on_user_scripts_reload or {}
__on_user_scripts_reload[#__on_user_scripts_reload + 1] = function()
    for _, list in pairs(handlers) do
        for i = #list, 1, -1 do
            if list[i].owner then table.remove(list, i) end
        end
    end
end


__on_user_script_unload = __on_user_script_unload or {}
__on_user_script_unload[#__on_user_script_unload + 1] = function(owner)
    event.emit_owner("scripts_reloading", owner)
    for i = #unload_handlers, 1, -1 do
        local entry = unload_handlers[i]
        if entry.owner == owner then
            local ok, err
            if thread and thread.with_owner then ok, err = pcall(thread.with_owner, owner, entry.fn)
            else ok, err = pcall(entry.fn) end
            if not ok then report("script.on_unload", err) end
            table.remove(unload_handlers, i)
        end
    end
    for _, list in pairs(handlers) do
        for i = #list, 1, -1 do
            if list[i].owner == owner then table.remove(list, i) end
        end
    end
end

-- ── render-thread sources: menu visibility and keys ──
local menu_was_visible = nil

overlay.on_draw("__events", function()
    local vis = menu.is_visible() and true or false
    if menu_was_visible ~= nil and vis ~= menu_was_visible then
        event.emit(vis and "menu_open" or "menu_close")
    end
    menu_was_visible = vis

    local downs, ups = has_handlers("key_down"), has_handlers("key_up")
    if downs or ups then
        for vk = 1, 254 do
            if downs and input.key_just_pressed(vk) then event.emit("key_down", vk) end
            if ups and input.key_released(vk) then event.emit("key_up", vk) end
        end
    end
end)
