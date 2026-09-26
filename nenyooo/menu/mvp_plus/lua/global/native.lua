
-- native.* — typed native invocation. The engine binds native.call(hash, ...) (raw int64 return); this
-- adds the typed builder facade over the C++ native_invoker for float/vector/string returns.
native = native or {}
native.invoker = native_invoker
-- native.hash(name): JOAAT of a model/native name (alias of util.joaat).
function native.hash(name) return util.joaat(name) end
-- native.from_hex("ABCD..."): parse a 64-bit native-hash hex string into an integer.
function native.from_hex(s) return tonumber(s, 16) or 0 end
-- script.is_running(name_or_hash) -> bool: whether a game script (e.g. "fm_mission_controller") currently
-- has a running thread. Script-thread only.
function script.is_running(name)
    local hash = type(name) == "string" and util.joaat(name) or name
    native_invoker.begin_call(); native_invoker.push_arg_int(hash)
    native_invoker.end_call("2C83A9DA6BFFC4F9")   -- GET_NUMBER_OF_THREADS_RUNNING_THE_SCRIPT_WITH_THIS_HASH
    return native_invoker.get_return_value_int() > 0
end
