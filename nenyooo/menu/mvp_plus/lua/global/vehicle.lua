
local nv = native_invoker
-- vehicle.* — vehicle-specific helpers over entity + natives. Script-thread only.
vehicle = vehicle or {}
-- vehicle.spawn(model, pos, heading, networked): alias of entity.spawn_vehicle.
function vehicle.spawn(model, pos, heading, networked) return entity.spawn_vehicle(model, pos, heading, networked) end
-- vehicle.current(): the local player's current vehicle handle (0 if on foot).
function vehicle.current()
    nv.begin_call(); nv.push_arg_int(player.ped()); nv.push_arg_bool(false); nv.end_call("9A9112A0FE9A4713")   -- GET_VEHICLE_PED_IS_IN
    return nv.get_return_value_int()
end
-- vehicle.repair(veh)
function vehicle.repair(veh) nv.begin_call(); nv.push_arg_int(veh); nv.end_call("115722B1B9C14C1C") end   -- SET_VEHICLE_FIXED
-- vehicle.set_engine(veh, on)
function vehicle.set_engine(veh, on) nv.begin_call(); nv.push_arg_int(veh); nv.push_arg_bool(on); nv.push_arg_bool(true); nv.push_arg_bool(true); nv.end_call("2497C4717C8B881E") end  -- SET_VEHICLE_ENGINE_ON
-- vehicle.display_name(model) -> string: the in-game name of a vehicle model (hash or model name), e.g.
-- "Adder". Falls back to the model's label, then to the input, when the game has no text for it.
function vehicle.display_name(model)
    local hash = type(model) == "string" and util.joaat(model) or model
    nv.begin_call(); nv.push_arg_int(hash); nv.end_call("B215AAC32D25D019")   -- GET_DISPLAY_NAME_FROM_VEHICLE_MODEL
    local label = nv.get_return_value_string()
    if not label or label == "" or label == "CARNOTFOUND" then return tostring(model) end
    nv.begin_call(); nv.push_arg_string(label); nv.end_call("7B5280EBA9840C72")   -- GET_FILENAME_FOR_AUDIO_CONVERSATION
    local text = nv.get_return_value_string()
    if not text or text == "" or text == "NULL" then return label end
    return text
end
