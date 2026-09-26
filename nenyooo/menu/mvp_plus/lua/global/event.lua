-- event.* — named events for scripts.
--
--   event.on(name, fn) -> fn        subscribe (returns fn so it can be passed to event.off later)
--   event.off(name, fn)             unsubscribe
--   event.emit(name, ...)           fire an event (scripts may use their own names too)
--
-- Built-in events:
--   "menu_open", "menu_close"            the menu was shown / hidden               (render thread)
--   "key_down"(vk), "key_up"(vk)         a key was pressed / released (Win32 VK)   (render thread)
--   "player_join"(id), "player_leave"(id) a player slot became active / inactive   (script thread)
--   "session_change"(generation, snapshot) session identity changed                 (script thread)
--   "network_event"(sender, event_id, bits) bounded read-only network payload       (script thread)
--   "scripted_game_event"(sender, args) decoded incoming script-event arguments     (script thread)
--   "scripts_reloading"                  user scripts are about to be reloaded
--   "unload"                             the Lua state is about to be torn down (menu unload / rebuild)
--
-- Each handler runs in pcall, so one failing handler does not stop the others. Handlers registered by a
-- user script are removed when user scripts reload. Players already in the session when the first
-- "player_*" handler is added do not fire "player_join" -- use player.list() for the current roster.
-- Game natives are only safe in the script-thread events; queue work with fiber.run from the others.

event = event or {}

local handlers = {}   -- name -> { { fn = f, user = bool }, ... }

local function user_loading()
    return script and script.loading_user_scripts and script.loading_user_scripts() or false
end

local function report(name, err)
    local msg = "Event '" .. tostring(name) .. "' handler failed: " .. tostring(err)
    if log and log.warn then log.warn(msg) else print(msg) end
end

local function has_handlers(name)
    local list = handlers[name]
    return list ~= nil and #list > 0
end

local function update_network_bridge()
    if __event_bridge and __event_bridge.set_mode then
        local mode = (has_handlers("network_event") and 1 or 0)
            | (has_handlers("scripted_game_event") and 2 or 0)
        __event_bridge.set_mode(mode)
    elseif __event_bridge and __event_bridge.set_enabled then
        __event_bridge.set_enabled(has_handlers("network_event") or has_handlers("scripted_game_event"))
    end
end

function event.on(name, fn)
    if type(name) ~= "string" or type(fn) ~= "function" then error("event.on(name, fn): name string and function expected", 2) end
    local list = handlers[name]
    if not list then list = {}; handlers[name] = list end
    list[#list + 1] = { fn = fn, user = user_loading() }
    if name == "network_event" or name == "scripted_game_event" then update_network_bridge() end
    return fn
end

function event.off(name, fn)
    local list = handlers[name]
    if not list then return end
    for i = #list, 1, -1 do
        if list[i].fn == fn then table.remove(list, i) end
    end
    if name == "network_event" or name == "scripted_game_event" then update_network_bridge() end
end

function event.emit(name, ...)
    local list = handlers[name]
    if not list or #list == 0 then return end
    local snapshot = { table.unpack(list) }   -- handlers may subscribe / unsubscribe while dispatching
    for i = 1, #snapshot do
        local ok, err = pcall(snapshot[i].fn, ...)
        if not ok then report(name, err) end
    end
end

-- Engine entry point (lua_engine.cpp emits "scripts_reloading" and "unload").
function __event_emit(name, ...) event.emit(name, ...) end

-- A user-script reload drops that generation's handlers; foundation and UI handlers stay.
__on_user_scripts_reload = __on_user_scripts_reload or {}
__on_user_scripts_reload[#__on_user_scripts_reload + 1] = function()
    for _, list in pairs(handlers) do
        for i = #list, 1, -1 do
            if list[i].user then table.remove(list, i) end
        end
    end
    update_network_bridge()
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

-- ── script-thread source: player slots ──
local nv = native_invoker
local active_players = nil
local session_signature = nil
local session_generation = 0

function event.session_generation() return session_generation end
function event.network_events_dropped()
    return __event_bridge and __event_bridge.dropped and __event_bridge.dropped() or 0
end

local bit_buffer = {}
bit_buffer.__index = bit_buffer

local function new_bit_buffer(data, bit_count)
    return setmetatable({ data = data or "", bits = bit_count or 0, cursor = 0 }, bit_buffer)
end

function bit_buffer:read_uns(count)
    count = math.tointeger(count) or -1
    if count < 0 or count > 64 or self.cursor + count > self.bits then return 0, false end
    local value = 0
    for _ = 1, count do
        local at = self.cursor
        local byte = string.byte(self.data, (at >> 3) + 1) or 0
        value = (value << 1) | ((byte >> (7 - (at & 7))) & 1)
        self.cursor = at + 1
    end
    return value, true
end

function bit_buffer:read_bool()
    local value, ok = self:read_uns(1)
    return value ~= 0, ok
end

function bit_buffer:remaining() return self.bits - self.cursor end
function bit_buffer:clone() return new_bit_buffer(self.data, self.bits) end
bit_buffer.ReadUns = bit_buffer.read_uns
bit_buffer.ReadBool = bit_buffer.read_bool

local function decode_script_event(raw)
    local bits = new_bit_buffer(raw.data, raw.bit_count)
    local byte_count, ok = bits:read_uns(32)
    if not ok or byte_count == 0 or byte_count > 54 * 8 or byte_count % 8 ~= 0 then return nil end
    local args = {}
    for i = 1, byte_count // 8 do
        -- The engine parser reads eight serialized bytes directly into an int64 on little-endian x64.
        -- Rebuild the value in that same byte order instead of treating the 64-bit field as one
        -- network-order integer.
        local value = 0
        for byte_index = 0, 7 do
            local byte, byte_ok = bits:read_uns(8)
            if not byte_ok then return nil end
            value = value | (byte << (byte_index * 8))
        end
        args[i] = value
    end
    return args
end

local function sender_snapshot(id)
    local valid = type(id) == "number" and id >= 0 and id < 32
    return {
        PlayerId = id,
        id = id,
        name = valid and players and players.get_name and players.get_name(id) or "",
        rid = valid and players and players.get_rockstar_id and players.get_rockstar_id(id) or 0,
    }
end

local function slot_active(id)
    nv.begin_call(); nv.push_arg_int(id); nv.end_call("B8DFD30D6973E135")   -- NETWORK_IS_PLAYER_ACTIVE
    return nv.get_return_value_bool()
end

script.on_tick(function()
    if __event_bridge and (has_handlers("network_event") or has_handlers("scripted_game_event")) then
        for _ = 1, 32 do
            local raw = __event_bridge.poll()
            if not raw then break end
            local sender = sender_snapshot(raw.sender)
            if has_handlers("network_event") then
                event.emit("network_event", sender, raw.event_id,
                    new_bit_buffer(raw.data, raw.bit_count))
            end
            if raw.event_id == 28 and has_handlers("scripted_game_event") then
                local args = decode_script_event(raw)
                if args then event.emit("scripted_game_event", sender, args) end
            end
        end
    end

    local watch_session = has_handlers("session_change")
    if watch_session then
        local online = session.in_session() and true or false
        local kind = session.session_type()
        local token = session.host_token()
        local signature = tostring(online) .. ":" .. tostring(kind) .. ":" .. tostring(token)
        if session_signature ~= nil and signature ~= session_signature then
            session_generation = session_generation + 1
            event.emit("session_change", session_generation, {
                online = online,
                session_type = kind,
                host_token = token,
            })
        end
        session_signature = signature
    else
        session_signature = nil
    end

    if not (has_handlers("player_join") or has_handlers("player_leave")) then
        active_players = nil
        return
    end
    local first = active_players == nil
    if first then active_players = {} end
    for id = 0, 31 do
        local now = slot_active(id)
        local was = active_players[id] or false
        if now ~= was then
            active_players[id] = now
            if not first then event.emit(now and "player_join" or "player_leave", id) end
        end
    end
end)

function event.on_network_event(fn) return event.on("network_event", fn) end
function event.on_scripted_game_event(fn) return event.on("scripted_game_event", fn) end
