
local nv = native_invoker
-- player.* — the local player + remote players (handles, info). Script-thread only.
player = player or {}
function player.id() nv.begin_call(); nv.end_call("4F8644AF03D0E0D6"); return nv.get_return_value_int() end          -- PLAYER_ID
function player.ped() nv.begin_call(); nv.end_call("D80958FC74E988A6"); return nv.get_return_value_int() end          -- PLAYER_PED_ID
function player.get_ped(pid) nv.begin_call(); nv.push_arg_int(pid); nv.end_call("43A66C31C68491C0"); return nv.get_return_value_int() end  -- GET_PLAYER_PED
local function active(pid) nv.begin_call(); nv.push_arg_int(pid); nv.end_call("B8DFD30D6973E135"); return nv.get_return_value_bool() end   -- NETWORK_IS_PLAYER_ACTIVE
-- player.list(): active player indices (0..31), or just self if solo.
function player.list()
    local out = {}
    for pid = 0, 31 do if active(pid) then out[#out + 1] = pid end end
    if #out == 0 then out[1] = player.id() end
    return out
end
function player.exists(pid) return active(pid) end
function player.name(pid) nv.begin_call(); nv.push_arg_int(pid); nv.end_call("6D0DE6A7B5DA71F8"); return nv.get_return_value_string() end   -- GET_PLAYER_NAME
function player.coords(pid) return entity.coords(player.get_ped(pid)) end
function player.in_vehicle(pid)
    nv.begin_call(); nv.push_arg_int(player.get_ped(pid)); nv.push_arg_bool(false); nv.end_call("997ABD671D25CA0B")   -- IS_PED_IN_ANY_VEHICLE
    return nv.get_return_value_bool()
end
function player.vehicle(pid)
    nv.begin_call(); nv.push_arg_int(player.get_ped(pid)); nv.push_arg_bool(false); nv.end_call("9A9112A0FE9A4713")   -- GET_VEHICLE_PED_IS_IN
    return nv.get_return_value_int()
end
-- player.set_wanted_level(level): self only.
function player.set_wanted_level(level)
    local pid = player.id()
    nv.begin_call(); nv.push_arg_int(pid); nv.push_arg_int(level); nv.push_arg_bool(false); nv.end_call("39FF19C64EF7DA5B")   -- SET_PLAYER_WANTED_LEVEL
    nv.begin_call(); nv.push_arg_int(pid); nv.push_arg_bool(false); nv.end_call("E0A7D1E497FFCD6F")                           -- SET_PLAYER_WANTED_LEVEL_NOW
end
-- player.teleport(x, y, z): self only.
function player.teleport(x, y, z) entity.set_coords(player.ped(), x, y, z) end
