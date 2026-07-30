
local nv = native_invoker
-- world.* — environment queries + world drawing. Script-thread only.
world = world or {}
local gz_buf
-- world.ground_z(x, y, z) -> found(bool), z(number)
function world.ground_z(x, y, z)
    if not gz_buf then gz_buf = memory.alloc(8) end
    nv.begin_call()
    nv.push_arg_float(x); nv.push_arg_float(y); nv.push_arg_float(z or 1000.0)
    nv.push_arg_pointer(gz_buf); nv.push_arg_bool(false); nv.push_arg_bool(false)
    nv.end_call("C906A7DAB05C8D2B")   -- GET_GROUND_Z_FOR_3D_COORD
    return nv.get_return_value_bool(), memory.read_float(gz_buf)
end
-- world.set_waypoint(x, y)
function world.set_waypoint(x, y) nv.begin_call(); nv.push_arg_float(x); nv.push_arg_float(y); nv.end_call("FE43368D2AA4F2FC") end  -- SET_NEW_WAYPOINT
-- world.draw_line(x1,y1,z1, x2,y2,z2, r,g,b,a): a one-frame 3D line (call each tick in viewport).
function world.draw_line(x1, y1, z1, x2, y2, z2, r, g, b, a)
    nv.begin_call()
    nv.push_arg_float(x1); nv.push_arg_float(y1); nv.push_arg_float(z1)
    nv.push_arg_float(x2); nv.push_arg_float(y2); nv.push_arg_float(z2)
    nv.push_arg_int(r or 255); nv.push_arg_int(g or 255); nv.push_arg_int(b or 255); nv.push_arg_int(a or 255)
    nv.end_call("6B7256074AE34680")   -- DRAW_LINE
end
