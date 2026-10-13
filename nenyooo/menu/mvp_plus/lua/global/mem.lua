
-- mem.* — guarded memory access. Thin clean facade over the C++ `memory` table (alloc/read/write/scan/
-- pointer-chains). Names mirror memory.* (read_int/write_float/scan/rip/script_global/...).
mem = mem or {}
for k, v in pairs(memory) do if mem[k] == nil then mem[k] = v end end
-- mem.read_ptr_chain(base, offsets): follow a base pointer through a list of byte offsets (8-byte derefs).
function mem.read_ptr_chain(base, offsets)
    local p = base
    for _, off in ipairs(offsets or {}) do
        if not p or p == 0 then return 0 end
        p = memory.read_long(p + off)
    end
    return p or 0
end

-- Chainable IDA-style address object. The original memory.* functions continue returning integers for
-- compatibility; opt into fluent addressing with mem.address(), mem.pattern()/scan_address(), or
-- mem.script(name):scan(). Operations are immutable, so a reusable signature result is never modified.
local address_methods = {}
local address_mt = { __index = address_methods }

local function address_value(value)
    if type(value) == "table" and getmetatable(value) == address_mt then return value.value or 0 end
    return tonumber(value) or 0
end

local function make_address(value)
    return setmetatable({ value = address_value(value) }, address_mt)
end

function mem.address(value) return make_address(value) end
function mem.scan_address(pattern, required) return make_address(memory.scan(pattern, required or false)) end
mem.pattern = mem.scan_address
function mem.scan_module_address(pattern, module) return make_address(memory.scan_module(pattern, module)) end
function mem.scan_range_address(pattern, base, size)
    return make_address(memory.scan_range(pattern, address_value(base), size))
end

function address_methods:get() return self.value end
function address_methods:as_integer() return self.value end
function address_methods:valid() return self.value ~= 0 end
function address_methods:is_null() return self.value == 0 end
function address_methods:add(offset) return make_address(memory.add(self.value, offset or 0)) end
function address_methods:sub(offset) return make_address(memory.sub(self.value, offset or 0)) end
function address_methods:rip(offset) return make_address(memory.rip(self.value + (offset or 0))) end
function address_methods:mov(offset) return make_address(memory.mov(self.value + (offset or 0))) end
function address_methods:call(offset) return make_address(memory.call(self.value + (offset or 0))) end
function address_methods:deref(offset) return make_address(memory.deref(self.value + (offset or 0))) end
function address_methods:ptr(offset) return self:deref(offset) end
function address_methods:chain(offsets) return make_address(mem.read_ptr_chain(self.value, offsets)) end

function address_methods:read_byte(offset) return memory.read_byte(self.value + (offset or 0)) end
function address_methods:read_ubyte(offset) return memory.read_ubyte(self.value + (offset or 0)) end
function address_methods:read_bool(offset) return memory.read_bool(self.value + (offset or 0)) end
function address_methods:read_short(offset) return memory.read_short(self.value + (offset or 0)) end
function address_methods:read_ushort(offset) return memory.read_ushort(self.value + (offset or 0)) end
function address_methods:read_int(offset) return memory.read_int(self.value + (offset or 0)) end
function address_methods:read_uint(offset) return memory.read_uint(self.value + (offset or 0)) end
function address_methods:read_long(offset) return memory.read_long(self.value + (offset or 0)) end
function address_methods:read_float(offset) return memory.read_float(self.value + (offset or 0)) end
function address_methods:read_string(offset) return memory.read_string(self.value + (offset or 0)) end
function address_methods:read_vector3(offset) return memory.read_vector3(self.value + (offset or 0)) end
function address_methods:read_bytes(count, offset)
    return memory.read_binary_string(self.value + (offset or 0), count)
end

function address_methods:write_byte(value, offset) memory.write_byte(self.value + (offset or 0), value); return self end
function address_methods:write_ubyte(value, offset) memory.write_ubyte(self.value + (offset or 0), value); return self end
function address_methods:write_bool(value, offset) memory.write_bool(self.value + (offset or 0), value); return self end
function address_methods:write_short(value, offset) memory.write_short(self.value + (offset or 0), value); return self end
function address_methods:write_ushort(value, offset) memory.write_ushort(self.value + (offset or 0), value); return self end
function address_methods:write_int(value, offset) memory.write_int(self.value + (offset or 0), value); return self end
function address_methods:write_uint(value, offset) memory.write_uint(self.value + (offset or 0), value); return self end
function address_methods:write_long(value, offset) memory.write_long(self.value + (offset or 0), value); return self end
function address_methods:write_float(value, offset) memory.write_float(self.value + (offset or 0), value); return self end
function address_methods:write_string(value, offset) memory.write_string(self.value + (offset or 0), value); return self end
function address_methods:write_bytes(value, offset) memory.write_binary_string(self.value + (offset or 0), value); return self end
-- set(value): repoint this address object in place (another address object or an integer)
function address_methods:set(value) self.value = address_value(value); return self end
-- read_vector4 / write_vector4: four consecutive floats as { x, y, z, w }
function address_methods:read_vector4(offset)
    local b = self.value + (offset or 0)
    return { x = memory.read_float(b), y = memory.read_float(b + 4), z = memory.read_float(b + 8), w = memory.read_float(b + 12) }
end
function address_methods:write_vector4(v, offset)
    local b = self.value + (offset or 0)
    memory.write_float(b, v.x or v[1] or 0); memory.write_float(b + 4, v.y or v[2] or 0)
    memory.write_float(b + 8, v.z or v[3] or 0); memory.write_float(b + 12, v.w or v[4] or 0)
    return self
end
-- read_matrix44 / write_matrix44: 16 consecutive floats as a flat array m[1..16] (row-major, as stored)
function address_methods:read_matrix44(offset)
    local b, m = self.value + (offset or 0), {}
    for i = 0, 15 do m[i + 1] = memory.read_float(b + i * 4) end
    return m
end
function address_methods:write_matrix44(m, offset)
    local b = self.value + (offset or 0)
    for i = 0, 15 do memory.write_float(b + i * 4, m[i + 1] or 0) end
    return self
end
-- write_fixed_string(str, size): write into a fixed char[size] buffer -- truncated to size - 1 bytes and
-- zero-filled to the end, so a shorter string never leaves stale characters behind
function address_methods:write_fixed_string(str, size, offset)
    size = size or (#str + 1)
    if size <= 0 then return self end
    local s = tostring(str):sub(1, size - 1)
    memory.write_binary_string(self.value + (offset or 0), s .. string.rep("\0", size - #s))
    return self
end

function address_methods:patch(bytes, offset) return memory.patch(self.value + (offset or 0), bytes) end
function address_methods:nop(count, offset) return memory.patch_nop(self.value + (offset or 0), count) end

address_mt.__add = function(a, b) return make_address(address_value(a) + address_value(b)) end
address_mt.__sub = function(a, b) return make_address(address_value(a) - address_value(b)) end
address_mt.__eq = function(a, b) return address_value(a) == address_value(b) end
address_mt.__tostring = function(a) return string.format("0x%X", address_value(a)) end

-- Loaded Rockstar-script object. Patterns scan the YSC bytecode pages, not the GTA executable image.
local script_methods = {}
local script_mt = { __index = script_methods }
function mem.script(name_or_hash) return setmetatable({ script = name_or_hash }, script_mt) end
function script_methods:loaded() return memory.script_program(self.script) ~= 0 end
function script_methods:program() return make_address(memory.script_program(self.script)) end
function script_methods:scan(pattern, after)
    return make_address(memory.script_scan(self.script, pattern, after and address_value(after) or nil))
end
function script_methods:scan_all(pattern, limit)
    local raw, result = memory.script_scan_all(self.script, pattern, limit), {}
    for i, value in ipairs(raw) do result[i] = make_address(value) end
    return result
end
function script_methods:contains(value) return memory.script_contains(self.script, address_value(value)) end
function script_methods:patch_at(value, bytes)
    return memory.script_patch_at(self.script, address_value(value), bytes)
end
function script_methods:patch(pattern, offset, bytes, occurrence)
    return memory.script_patch(self.script, pattern, offset or 0, bytes, occurrence or 1)
end
local function nop_bytes(count)
    local bytes = {}
    for i = 1, math.max(0, count or 0) do bytes[i] = 0x90 end
    return bytes
end
function script_methods:nop_at(value, count) return self:patch_at(value, nop_bytes(count)) end
function script_methods:patch_nop(pattern, offset, count, occurrence)
    return self:patch(pattern, offset, nop_bytes(count), occurrence)
end
function script_methods:unpatch(token) return memory.script_unpatch(token) end
function script_methods:patch_active(token) return memory.script_patch_active(token) end

memory.scan_address = mem.scan_address
memory.pattern = mem.pattern
memory.scan_module_address = mem.scan_module_address
memory.scan_range_address = mem.scan_range_address
memory.address = mem.address
memory.script = mem.script
