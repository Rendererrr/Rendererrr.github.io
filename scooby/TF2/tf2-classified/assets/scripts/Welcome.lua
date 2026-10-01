-- Quick controls for real features supplied by the current project.
local groups = {
    {"ESP", {"esp.enabled", "esp.box", "esp.name", "esp.health", "esp.health_text", "esp.skeleton", "esp.distance"}},
    {"Overlays", {"overlay.watermark", "overlay.active_features", "overlay.binds"}}
}
local function supported(id) return features.get(id) ~= nil end
local function apply(values)
    for id, value in pairs(values) do
        if supported(id) then features.set(id, value) end
    end
end
ui.tab("quick_controls", "Quick Controls", function()
    ui.columns(2, function()
        for column, group in ipairs(groups) do
            if column > 1 then ui.next_column() end
            ui.group(group[1], function()
                for _, id in ipairs(group[2]) do
                    if supported(id) then ui.feature(id) end
                end
            end)
        end
    end)
    ui.group("Presets", function()
        if imgui.button("Health and names") then
            apply({["esp.enabled"]=true, ["esp.name"]=true, ["esp.health"]=true,
                   ["esp.health_text"]=true, ["esp.box"]=false, ["esp.skeleton"]=false})
        end
        imgui.same_line()
        if imgui.button("Disable ESP") then
            apply({["esp.enabled"]=false, ["esp.teammate.enabled"]=false})
        end
        if imgui.button("Toggle main menu") then ui.menu_visible(not ui.menu_visible()) end
    end)
end, {section="Tools"})
