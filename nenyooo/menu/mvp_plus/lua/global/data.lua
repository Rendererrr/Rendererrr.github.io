
-- data.* - game catalogs. Vehicles, peds, and objects use shared gtaDiscoveryApi data;
-- weapons retain Stand-compatible label keys. Returns plain arrays of tables.
data = data or {}
-- data.vehicles() -> { { name=, hash= }, ... }
-- Backed by gtaDiscoveryApi; returns an empty array until the shared vehicle catalog is ready.
function data.vehicles()
    local names = __stand_get_vehicles and __stand_get_vehicles() or {}
    local out = {}
    for i, name in ipairs(names) do out[i] = { name = name, hash = util.joaat(name) } end
    return out
end
-- data.weapons() -> { { name=, hash=, label= }, ... }
function data.weapons()
    local w = __stand_get_weapons and __stand_get_weapons() or {}
    local out = {}
    for i, e in ipairs(w) do out[i] = { name = e.d, hash = util.joaat(e.n), label = e.l } end
    return out
end
-- data.peds() -> { { name=, hash= }, ... }. Empty until the gtaDiscoveryApi ped catalog is fetched
-- (loads lazily when the Spooner Spawn-Ped page is first opened).
function data.peds() return __stand_get_peds and __stand_get_peds() or {} end
-- data.objects() -> { { name=, label=, hash= }, ... }. Empty until the object catalog is fetched.
function data.objects() return __stand_get_objects and __stand_get_objects() or {} end
