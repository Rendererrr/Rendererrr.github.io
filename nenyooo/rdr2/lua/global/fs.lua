
-- fs.* — file IO under Documents\Nenyoo. Additive over the engine `fs` (list/list_ext/list_dirs/exists);
-- adds read/write/remove delegating to the engine `file` table (paths are relative to the Nenyoo dir).
fs = fs or {}
function fs.read(rel) return file.read(rel) end
function fs.write(rel, data) return file.write(rel, data) end
function fs.remove(rel) return file.remove(rel) end
-- fs.copy(src, dst) -> bool: copy a file (both paths relative to the Nenyoo dir). Overwrites dst.
function fs.copy(src, dst)
    local data = fs.read(src)
    if data == nil then return false end
    return fs.write(dst, data) ~= false
end
