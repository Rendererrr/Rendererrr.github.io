
local nv = native_invoker
-- cam.* — camera helpers + world<->screen. Script-thread only (uses natives).
cam = cam or {}
local sx_buf, sy_buf
-- cam.world_to_screen(pos) -> onscreen(bool), x, y (normalised 0..1 screen coords).
function cam.world_to_screen(pos)
    if not sx_buf then sx_buf = memory.alloc(8); sy_buf = memory.alloc(8) end
    nv.begin_call()
    nv.push_arg_float(pos.x); nv.push_arg_float(pos.y); nv.push_arg_float(pos.z)
    nv.push_arg_pointer(sx_buf); nv.push_arg_pointer(sy_buf)
    nv.end_call("34E82F05DF2974F5")   -- GET_SCREEN_COORD_FROM_WORLD_COORD (_WORLD3D_TO_SCREEN2D)
    return nv.get_return_value_bool(), memory.read_float(sx_buf), memory.read_float(sy_buf)
end
-- cam.gameplay_coords() -> v3 of the gameplay camera position.
function cam.gameplay_coords()
    nv.begin_call(); nv.end_call("14D6F5678D8F1B37")   -- GET_GAMEPLAY_CAM_COORD
    return v3.new(nv.get_return_value_vector3())
end
