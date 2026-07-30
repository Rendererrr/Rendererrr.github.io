
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
