
-- native.* — typed native invocation. The engine binds native.call(hash, ...) (raw int64 return); this
-- adds the typed builder facade over the C++ native_invoker for float/vector/string returns.
native = native or {}
native.invoker = native_invoker
-- native.hash(name): JOAAT of a model/native name (alias of util.joaat).
function native.hash(name) return util.joaat(name) end
-- native.from_hex("ABCD..."): parse a 64-bit native-hash hex string into an integer.
function native.from_hex(s) return tonumber(s, 16) or 0 end
