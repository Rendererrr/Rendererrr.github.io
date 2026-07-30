
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
