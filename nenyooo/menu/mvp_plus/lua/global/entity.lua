
local nv = native_invoker
-- entity.* — spawn / control / query over game natives + the entity pool. Script-thread only.
entity = entity or {}
local function done(h) nv.begin_call(); nv.push_arg_int(h); nv.end_call("E532F5D78798DAAB") end   -- SET_MODEL_AS_NO_LONGER_NEEDED
-- entity.request_model(model): request + yield until the model streams in (call inside a thread).
function entity.request_model(model)
    if type(model) == "string" then model = util.joaat(model) end
    local tries = 0
    repeat
        nv.begin_call(); nv.push_arg_int(model); nv.end_call("963D27A58DF860AC")   -- REQUEST_MODEL
        nv.begin_call(); nv.push_arg_int(model); nv.end_call("98A4EB5D89A0C952")   -- HAS_MODEL_LOADED
        if nv.get_return_value_bool() then return model end
        util.yield(); tries = tries + 1
    until tries >= 100
    return model
end
-- entity.coords(ent) -> v3
function entity.coords(ent)
    nv.begin_call(); nv.push_arg_int(ent); nv.push_arg_bool(true); nv.end_call("3FEF770D40960D5A")   -- GET_ENTITY_COORDS
    return v3.new(nv.get_return_value_vector3())
end
-- entity.rotation(ent) -> v3 (order 2)
function entity.rotation(ent)
    nv.begin_call(); nv.push_arg_int(ent); nv.push_arg_int(2); nv.end_call("AFBD61CC738D9EB9")   -- GET_ENTITY_ROTATION
    return v3.new(nv.get_return_value_vector3())
end
-- entity.set_coords(ent, x, y, z)
function entity.set_coords(ent, x, y, z)
    nv.begin_call(); nv.push_arg_int(ent)
    nv.push_arg_float(x); nv.push_arg_float(y); nv.push_arg_float(z)
    nv.push_arg_bool(false); nv.push_arg_bool(false); nv.push_arg_bool(false); nv.push_arg_bool(true)
    nv.end_call("06843DA7060A026B")   -- SET_ENTITY_COORDS
end
function entity.model(ent) nv.begin_call(); nv.push_arg_int(ent); nv.end_call("9F47B058362C84B5"); return nv.get_return_value_int() end       -- GET_ENTITY_MODEL
function entity.health(ent) nv.begin_call(); nv.push_arg_int(ent); nv.end_call("EEF059FAD016D209"); return nv.get_return_value_int() end       -- GET_ENTITY_HEALTH
-- Existence + type checks.
function entity.exists(ent) nv.begin_call(); nv.push_arg_int(ent); nv.end_call("7239B21A38F536BA"); return nv.get_return_value_bool() end     -- DOES_ENTITY_EXIST
function entity.is_ped(ent) nv.begin_call(); nv.push_arg_int(ent); nv.end_call("524AC5ECEA15343E"); return nv.get_return_value_bool() end     -- IS_ENTITY_A_PED
function entity.is_vehicle(ent) nv.begin_call(); nv.push_arg_int(ent); nv.end_call("6AC7003FA6E5575E"); return nv.get_return_value_bool() end -- IS_ENTITY_A_VEHICLE
function entity.is_object(ent) nv.begin_call(); nv.push_arg_int(ent); nv.end_call("8A8694B48715B000"); return nv.get_return_value_bool() end  -- IS_ENTITY_AN_OBJECT
-- Model checks (model may be a hash or name).
function entity.model_valid(model) if type(model) == "string" then model = util.joaat(model) end
    nv.begin_call(); nv.push_arg_int(model); nv.end_call("C0296A2EDF545E92"); return nv.get_return_value_bool() end                            -- IS_MODEL_VALID
function entity.model_is_vehicle(model) if type(model) == "string" then model = util.joaat(model) end
    nv.begin_call(); nv.push_arg_int(model); nv.end_call("19AAC8F07BFEC53E"); return nv.get_return_value_bool() end                            -- IS_MODEL_A_VEHICLE
-- entity.pointer(handle): real CEntity* address (int64) for a script handle, or 0. Read offsets via memory.*.
function entity.pointer(handle) return memory.handle_to_pointer(handle) end
-- entity.request_control(ent, timeout_ms): loop until network control is granted or timeout.
function entity.request_control(ent, timeout)
    local deadline = util.time_ms() + (timeout or 2000)
    repeat
        nv.begin_call(); nv.push_arg_int(ent); nv.end_call("01BF60A500E28887")   -- NETWORK_HAS_CONTROL_OF_ENTITY
        if nv.get_return_value_bool() then return true end
        nv.begin_call(); nv.push_arg_int(ent); nv.end_call("B69317BF5E782347")   -- NETWORK_REQUEST_CONTROL_OF_ENTITY
        util.yield()
    until util.time_ms() >= deadline
    return false
end
-- entity.spawn_ped(model, pos, heading, networked) -> handle
function entity.spawn_ped(model, pos, heading, networked)
    if type(model) == "string" then model = util.joaat(model) end
    entity.request_model(model)
    nv.begin_call(); nv.push_arg_int(4); nv.push_arg_int(model)
    nv.push_arg_float(pos.x); nv.push_arg_float(pos.y); nv.push_arg_float(pos.z); nv.push_arg_float(heading or 0.0)
    nv.push_arg_bool(networked ~= false); nv.push_arg_bool(true)
    nv.end_call("D49F9B0955C367DE")   -- CREATE_PED
    local h = nv.get_return_value_int(); done(model); return h
end
-- entity.spawn_vehicle(model, pos, heading, networked) -> handle
function entity.spawn_vehicle(model, pos, heading, networked)
    if type(model) == "string" then model = util.joaat(model) end
    entity.request_model(model)
    nv.begin_call(); nv.push_arg_int(model)
    nv.push_arg_float(pos.x); nv.push_arg_float(pos.y); nv.push_arg_float(pos.z); nv.push_arg_float(heading or 0.0)
    nv.push_arg_bool(networked ~= false); nv.push_arg_bool(true); nv.push_arg_bool(false)
    nv.end_call("AF35D0D2583051B0")   -- CREATE_VEHICLE
    local h = nv.get_return_value_int(); done(model); return h
end
-- entity.spawn_object(model, pos, networked) -> handle
function entity.spawn_object(model, pos, networked)
    if type(model) == "string" then model = util.joaat(model) end
    entity.request_model(model)
    nv.begin_call(); nv.push_arg_int(model)
    nv.push_arg_float(pos.x); nv.push_arg_float(pos.y); nv.push_arg_float(pos.z)
    nv.push_arg_bool(networked ~= false); nv.push_arg_bool(true); nv.push_arg_bool(false)
    nv.end_call("9A294B2138ABB884")   -- CREATE_OBJECT_NO_OFFSET
    local h = nv.get_return_value_int(); done(model); return h
end
local del_buf
-- entity.delete(ent): take control, mark as mission, delete.
function entity.delete(ent)
    if not ent or ent == 0 then return false end
    entity.request_control(ent)
    nv.begin_call(); nv.push_arg_int(ent); nv.push_arg_bool(false); nv.push_arg_bool(true); nv.end_call("AD738C3085FE7E11")  -- SET_ENTITY_AS_MISSION_ENTITY
    if not del_buf then del_buf = memory.alloc(8) end
    memory.write_int(del_buf, ent)
    nv.begin_call(); nv.push_arg_pointer(del_buf); nv.end_call("AE3CBE5BF394C9C9")   -- DELETE_ENTITY(&handle)
    return true
end
-- entity.all_peds()/all_vehicles()/all_objects(): pool enumeration (handles). Script-thread only.
function entity.all_peds() return __stand_get_all(false, true, false) end
function entity.all_vehicles() return __stand_get_all(true, false, false) end
function entity.all_objects() return __stand_get_all(false, false, true) end
