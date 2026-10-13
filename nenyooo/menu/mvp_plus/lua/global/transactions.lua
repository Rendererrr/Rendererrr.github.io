-- transactions.* — GTA Online basket transaction helpers. Script-thread only.
transactions = transactions or {}
local active_basket

function transactions.basket_start(category, action, flags)
    local out = memory.alloc_int()
    if not out or out == 0 then return false, 0 end
    local ok = native.call_bool(0x279F08B1A4B29B7E, out, category, action, flags or 4)
    local id = ok and memory.read_int(out) or 0
    memory.free(out)
    active_basket = id
    return ok, id
end

function transactions.begin_service(category, item, action, value, flags)
    local out = memory.alloc_int()
    if not out or out == 0 then return false, 0 end
    local ok = native.call_bool(0x3C5FD37B5499582E, out, category, item, action, value, flags or 2)
    local id = ok and memory.read_int(out) or 0
    memory.free(out)
    return ok, id
end

function transactions.basket_add_item(item)
    if type(item) ~= "table" then return false end
    local data = memory.alloc(20)
    if not data or data == 0 then return false end
    for i = 1, 5 do memory.write_int(data + (i - 1) * 4, tonumber(item[i]) or 0) end
    local ok = native.call_bool(0xF30980718C8ED876, data, tonumber(item[5]) or 1)
    memory.free(data)
    return ok
end

function transactions.checkout(transaction_id)
    return native.call_bool(0x39BE7CEA8D9CC8E6, transaction_id or active_basket or 0)
end
