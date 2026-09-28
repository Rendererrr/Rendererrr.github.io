-- stats.* — canonical typed GTA stat access. Script-thread only.
stats = stats or {}

local function stat_name(value)
    value = tostring(value or "")
    if value:sub(1, 3) ~= "MPX" then return value end
    return "MP" .. tostring(stats.get_character_index()) .. value:sub(4)
end

local function stat_hash(value)
    return type(value) == "string" and util.joaat(stat_name(value)) or value
end

function stats.name(value) return stat_name(value) end
function stats.hash(value) return stat_hash(value) end

function stats.try_get_int(value)
    local out = memory.alloc_int()
    if not out or out == 0 then return false, nil end
    local ok = native.call_bool(0x767FBC2AC802EF3D, stat_hash(value), out, -1)
    local result = ok and memory.read_int(out) or nil
    memory.free(out)
    return ok, result
end

function stats.try_get_bool(value)
    local out = memory.alloc_int()
    if not out or out == 0 then return false, nil end
    local ok = native.call_bool(0x11B5E6D2AE73F48E, stat_hash(value), out, -1)
    local result = ok and memory.read_int(out) ~= 0 or nil
    memory.free(out)
    return ok, result
end

function stats.try_get_float(value)
    local out = memory.alloc(8)
    if not out or out == 0 then return false, nil end
    local ok = native.call_bool(0xD7AE6C9C9C6AC54C, stat_hash(value), out, -1)
    local result = ok and memory.read_float(out) or nil
    memory.free(out)
    return ok, result
end

function stats.get_int(value, fallback)
    local ok, result = stats.try_get_int(value)
    return ok and result or (fallback or 0)
end

function stats.get_bool(value, fallback)
    local ok, result = stats.try_get_bool(value)
    if ok then return result end
    return fallback and true or false
end

function stats.get_float(value, fallback)
    local ok, result = stats.try_get_float(value)
    return ok and result or (fallback or 0.0)
end

function stats.get_string(value)
    return native.call_string(0xE50384ACC2C3DB74, stat_hash(value), -1)
end

function stats.set_int(value, amount)
    return native.call_bool(0xB3271D7AB655B441, stat_hash(value), math.floor(tonumber(amount) or 0), true)
end

function stats.set_bool(value, amount)
    return native.call_bool(0x4B33C4243DE0C432, stat_hash(value), amount and true or false, true)
end

function stats.set_float(value, amount)
    return native.call_bool(0x4851997F37FE9B3C, stat_hash(value), tonumber(amount) or 0, true)
end

function stats.set_string(value, amount)
    return native.call_bool(0xA87B2335D12531D7, stat_hash(value), tostring(amount or ""), true)
end

function stats.get_character_index()
    return math.max(0, math.min(1, math.floor(tonumber(stats.get_int("MPPLY_LAST_MP_CHAR", 0)) or 0)))
end

function stats.get_packed_int(index, character)
    return native.call(0x0BC900A6FE73770C, index, character or stats.get_character_index())
end

function stats.get_packed_bool(index, character)
    return native.call_bool(0xDA7EBFC49AE3F1B0, index, character or stats.get_character_index())
end

function stats.set_packed_int(index, value, character)
    native.call(0x1581503AE529CD2E, index, value, character or stats.get_character_index())
end

function stats.set_packed_bool(index, value, character)
    native.call(0xDB8A58AEAA67CD07, index, value and true or false,
        character or stats.get_character_index())
end
