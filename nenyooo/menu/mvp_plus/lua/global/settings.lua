
-- settings.* — per-script persisted config (JSON under Documents\Nenyoo\scripts). Built on fs + json.
settings = settings or {}
-- settings.load(name) -> table (empty if absent/corrupt).
function settings.load(name)
    local raw = file.read(name .. ".json")
    if not raw or raw == "" then return {} end
    local t = json.decode(raw)
    return (type(t) == "table") and t or {}
end
-- settings.save(name, tbl) -> bool.
function settings.save(name, tbl) return file.write(name .. ".json", json.encode(tbl or {})) end
