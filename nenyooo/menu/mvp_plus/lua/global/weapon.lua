
local nv = native_invoker
-- weapon.* — give / remove / ammo over natives. Script-thread only. `weap` may be a hash or name.
weapon = weapon or {}
local function h(w) if type(w) == "string" then return util.joaat(w) end return w end
-- weapon.give(ped, weap, ammo, equip)
function weapon.give(ped, weap, ammo, equip)
    nv.begin_call(); nv.push_arg_int(ped); nv.push_arg_int(h(weap)); nv.push_arg_int(ammo or 1000)
    nv.push_arg_bool(false); nv.push_arg_bool(equip ~= false); nv.end_call("BF0FD6E56C964FCB")   -- GIVE_WEAPON_TO_PED
end
-- weapon.remove(ped, weap)
function weapon.remove(ped, weap) nv.begin_call(); nv.push_arg_int(ped); nv.push_arg_int(h(weap)); nv.end_call("4899CB088EDF59B8") end  -- REMOVE_WEAPON_FROM_PED
-- weapon.remove_all(ped)
function weapon.remove_all(ped) nv.begin_call(); nv.push_arg_int(ped); nv.push_arg_bool(true); nv.end_call("F25DF915FA38C5F3") end       -- REMOVE_ALL_PED_WEAPONS
-- weapon.set_ammo(ped, weap, ammo)
function weapon.set_ammo(ped, weap, ammo) nv.begin_call(); nv.push_arg_int(ped); nv.push_arg_int(h(weap)); nv.push_arg_int(ammo); nv.end_call("14E56BC5B5DB6A19") end  -- SET_PED_AMMO
