
-- v3 — the foundation 3D vector type (table-based; chainable). Canonical home for EVERY dialect: compat
-- layers alias this rather than defining their own metatable, so all v3 objects share one method table.
v3 = v3 or {}
local v3mt = {}
__nyx_v3mt = v3mt   -- exposed so a compat layer can confirm/extend the shared metatable
v3mt.__index = v3mt
-- v3.new(x,y,z) OR v3.new({x=,y=,z=}) OR v3.new(other_v3) — coord tables / vectors accepted as the 1st arg.
function v3.new(x, y, z)
    if type(x) == "table" then return setmetatable({ x = x.x or 0.0, y = x.y or 0.0, z = x.z or 0.0 }, v3mt) end
    return setmetatable({ x = x or 0.0, y = y or 0.0, z = z or 0.0 }, v3mt)
end
setmetatable(v3, { __call = function(_, x, y, z) return v3.new(x, y, z) end })
-- Coerce an arg list to x,y,z: a v3/table -> components; one scalar -> (n,n,n); three -> as given.
local function g(a, b, c)
    if type(a) == "table" then return a.x or 0.0, a.y or 0.0, a.z or 0.0 end
    if b == nil then return a or 0.0, a or 0.0, a or 0.0 end
    return a or 0.0, b or 0.0, c or 0.0
end
function v3mt:get() return self.x, self.y, self.z end
function v3mt:getX() return self.x end
function v3mt:getY() return self.y end
function v3mt:getZ() return self.z end
function v3mt:set(a, b, c) self.x, self.y, self.z = g(a, b, c); return self end
function v3mt:setX(n) self.x = n; return self end
function v3mt:setY(n) self.y = n; return self end
function v3mt:setZ(n) self.z = n; return self end
function v3mt:reset() self.x, self.y, self.z = 0.0, 0.0, 0.0; return self end
function v3mt:add(a, b, c) local x, y, z = g(a, b, c); self.x = self.x + x; self.y = self.y + y; self.z = self.z + z; return self end
function v3mt:sub(a, b, c) local x, y, z = g(a, b, c); self.x = self.x - x; self.y = self.y - y; self.z = self.z - z; return self end
function v3mt:mul(a, b, c) local x, y, z = g(a, b, c); self.x = self.x * x; self.y = self.y * y; self.z = self.z * z; return self end
function v3mt:div(a, b, c) local x, y, z = g(a, b, c); self.x = self.x / x; self.y = self.y / y; self.z = self.z / z; return self end
function v3mt:addNew(a, b, c) return v3.new(self):add(a, b, c) end
function v3mt:subNew(a, b, c) return v3.new(self):sub(a, b, c) end
function v3mt:mulNew(a, b, c) return v3.new(self):mul(a, b, c) end
function v3mt:divNew(a, b, c) return v3.new(self):div(a, b, c) end
function v3mt:eq(o) return self.x == o.x and self.y == o.y and self.z == o.z end
function v3mt:magnitude() return math.sqrt(self.x*self.x + self.y*self.y + self.z*self.z) end
function v3mt:distance(o) local dx, dy, dz = self.x-o.x, self.y-o.y, self.z-o.z; return math.sqrt(dx*dx+dy*dy+dz*dz) end
function v3mt:abs() self.x, self.y, self.z = math.abs(self.x), math.abs(self.y), math.abs(self.z); return self end
function v3mt:min(o) return v3.new(math.min(self.x, o.x), math.min(self.y, o.y), math.min(self.z, o.z)) end
function v3mt:max(o) return v3.new(math.max(self.x, o.x), math.max(self.y, o.y), math.max(self.z, o.z)) end
function v3mt:dot(o) return self.x*o.x + self.y*o.y + self.z*o.z end
function v3mt:normalise() local m = self:magnitude(); if m > 0 then self.x, self.y, self.z = self.x/m, self.y/m, self.z/m end; return self end
v3mt.normalize = v3mt.normalise
function v3mt:crossProduct(o) return v3.new(self.y*o.z - self.z*o.y, self.z*o.x - self.x*o.z, self.x*o.y - self.y*o.x) end
v3mt.cross = v3mt.crossProduct
function v3mt:getHeading() return math.deg(math.atan(-self.x, self.y)) end
v3mt.heading = v3mt.getHeading
function v3mt:toString() return string.format("(%.3f, %.3f, %.3f)", self.x, self.y, self.z) end
v3mt.tostring = v3mt.toString
function v3mt:toDir()   -- rotation (deg) -> unit direction
    local rx, rz = math.rad(self.x), math.rad(self.z)
    local cosx = math.cos(rx)
    return v3.new(-math.sin(rz) * cosx, math.cos(rz) * cosx, math.sin(rx))
end
function v3mt:toRot()   -- direction -> rotation (pitch, 0, heading)
    return v3.new(math.deg(math.atan(self.z, math.sqrt(self.x*self.x + self.y*self.y))), 0.0, math.deg(math.atan(-self.x, self.y)))
end
function v3mt:lookAt(o) return v3.new(o):sub(self):toRot() end
function v3mt:free() end   -- no-op (table-based)
-- Static forms: v3.distance(a,b), v3.dot(a,b), v3.get(v), ... (each takes the vector as the first arg).
for _, m in ipairs({ "get","getX","getY","getZ","set","setX","setY","setZ","reset","add","sub","mul","div",
    "addNew","subNew","mulNew","divNew","eq","magnitude","distance","abs","min","max","dot","normalise",
    "crossProduct","cross","getHeading","heading","toString","tostring","toDir","toRot","lookAt","free" }) do
    v3[m] = function(self, ...) return v3mt[m](self, ...) end
end
