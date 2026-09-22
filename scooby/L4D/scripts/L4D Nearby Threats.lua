-- A custom gameplay-aware warning for specials and witches in both games.
assert(L4D_API_VERSION == "1.0", "This example needs the updated Scooby L4D host")
local enabled = features.add {id="threats", label="Nearby threat warning", category="Lua / L4D", default=true}
local range, previous = 35, ""
ui.subtab("visuals", "lua_threats", "Lua threats", function()
    ui.group("Threat warnings", function()
        ui.feature(enabled)
        local changed
        changed, range = ui.slider("Warning distance (metres)", range, 5, 100)
    end)
end)
events.on("update", function()
    local active = features.active(enabled)
    local key = tostring(active)..":"..range
    if previous == key then return end
    previous = key
    if active then l4d.watch {survivors=false, infected=true, pickups=false, range=range}
    else l4d.watch(false) end
end)
ui.overlay("threats", function()
    if not features.active(enabled) then return end
    local nearest
    for _, entity in ipairs(l4d.entities {category="infected", range=range}) do
        if (entity.special or entity.type=="witch") and (not nearest or entity.distance_m<nearest.distance_m) then
            nearest=entity
        end
    end
    if not nearest then return end
    local width = engine.viewport()
    render.text(math.max(20,width/2-110), 70,
        string.format("%s nearby: %.0f m", nearest.name, nearest.distance_m), {1,.45,.3,1}, 18)
end)
