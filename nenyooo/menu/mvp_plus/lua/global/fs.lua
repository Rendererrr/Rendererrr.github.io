
-- fs.* — file IO under Documents\Nenyoo. Additive over the engine `fs` (list/list_ext/list_dirs/exists);
-- adds read/write/remove delegating to the engine `file` table (paths are relative to the Nenyoo dir).
fs = fs or {}
function fs.read(rel) return file.read(rel) end
function fs.write(rel, data) return file.write(rel, data) end
function fs.remove(rel) return file.remove(rel) end
