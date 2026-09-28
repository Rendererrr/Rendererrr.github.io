
-- native.* — typed native invocation. The engine binds native.call(hash, ...) (raw int64 return); this
-- adds the typed builder facade over the C++ native_invoker for float/vector/string returns.
native = native or {}
native.invoker = native_invoker
-- native.hash(name): JOAAT of a model/native name (alias of util.joaat).
function native.hash(name) return util.joaat(name) end
-- native.from_hex("ABCD..."): parse a 64-bit native-hash hex string into an integer.
function native.from_hex(s) return tonumber(s, 16) or 0 end

-- Typed named-native back end.  Lua treats integer 0 as truthy and raw float/string/vector return
-- bits are not useful values, so generated namespace wrappers select one of these by the native's
-- declared C++ return type instead of exposing native.call's raw int64 result.
local function call_typed(return_type, hash, ...)
    native_invoker.begin_call()
    local args = table.pack(...)
    for i = 1, args.n do
        local value = args[i]
        local kind = type(value)
        if kind == "boolean" then
            native_invoker.push_arg_bool(value)
        elseif kind == "string" then
            native_invoker.push_arg_string(value)
        elseif kind == "table" and type(value.get_address) == "function" then
            native_invoker.push_arg_pointer(value:get_address())
        elseif kind == "table" then
            native_invoker.push_arg_vector3(value)
        elseif kind == "number" and math.type(value) == "float" then
            native_invoker.push_arg_float(value)
        else
            native_invoker.push_arg_int(value or 0)
        end
    end
    native_invoker.end_call_2(hash)
    if return_type == "bool" then return native_invoker.get_return_value_bool() end
    if return_type == "float" then return native_invoker.get_return_value_float() end
    if return_type == "string" then return native_invoker.get_return_value_string() end
    if return_type == "vector3" then return native_invoker.get_return_value_vector3() end
    return native_invoker.get_return_value_int()
end
function native.call_bool(hash, ...) return call_typed("bool", hash, ...) end
function native.call_float(hash, ...) return call_typed("float", hash, ...) end
function native.call_string(hash, ...) return call_typed("string", hash, ...) end
function native.call_vector3(hash, ...) return call_typed("vector3", hash, ...) end
-- script.is_running(name_or_hash) -> bool: whether a game script (e.g. "fm_mission_controller") currently
-- has a running thread. Script-thread only.
function script.is_running(name)
    local hash = type(name) == "string" and util.joaat(name) or name
    native_invoker.begin_call(); native_invoker.push_arg_int(hash)
    native_invoker.end_call("2C83A9DA6BFFC4F9")   -- GET_NUMBER_OF_THREADS_RUNNING_THE_SCRIPT_WITH_THIS_HASH
    return native_invoker.get_return_value_int() > 0
end

-- script.execute_as(name_or_hash, fn), script.request_host(name_or_hash), and
-- script.call_offset(name_or_hash, bytecode_offset, integer_args) are native bindings.
