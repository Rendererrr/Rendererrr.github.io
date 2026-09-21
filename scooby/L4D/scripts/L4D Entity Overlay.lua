-- Independent entity ESP for either game. Requires the Scooby L4D API 1.0 host.
assert(L4D_API_VERSION == "1.0", "This example needs the updated Scooby L4D host")
local enabled = features.add {id="overlay", label="Lua entity overlay", category="Lua / L4D",
    description="Independent survivor, infected and pickup labels", default=true}
local skeleton = features.add {id="skeleton", label="Lua skeleton", category="Lua / L4D", default=false}
local range, kind, previous = 80, 1, ""
local categories = {"all", "survivor", "infected", "pickup"}
local colors = {survivor={.3,.8,1,1}, infected={1,.45,.35,1}, pickup={.5,1,.55,1}}
ui.subtab("visuals", "lua_entities", "Lua entities", function()
    ui.group("Custom entity overlay", function()
        ui.feature(enabled)
        ui.feature(skeleton)
        local changed
        changed, range = ui.slider("Range (metres)", range, 1, 150)
        changed, kind = ui.combo("Category", kind, {"All", "Survivors", "Infected", "Pickups"})
        imgui.text("Uses game snapshots independently of built-in ESP switches.")
    end)
end)
events.on("update", function()
    local active, bones = features.active(enabled), features.active(skeleton)
    local key = tostring(active)..":"..tostring(bones)..":"..range
    if previous == key then return end
    previous = key
    if active then l4d.watch {range=range, bones=bones} else l4d.watch(false) end
end)
ui.overlay("entities", function()
    if not features.active(enabled) or not l4d.session().data_available then return end
    local drawn = 0
    for _, entity in ipairs(l4d.entities {category=categories[kind], range=range}) do
        local box = l4d.screen_box(entity.index)
        if box then
            local color = colors[entity.category]
            render.rect(box.left, box.top, box.width, box.height, color)
            render.text(box.left, math.max(0, box.top-16), entity.name..string.format("  %.0f m", entity.distance_m), color)
            if features.active(skeleton) and entity.bones_available then
                -- Cap segments and actors to stay within the UI's draw-call budget.
                for i, segment in ipairs(l4d.bones(entity.index)) do
                    if i > 24 then break end
                    local a, b = l4d.world_to_screen(segment.from), l4d.world_to_screen(segment.to)
                    if a and b then render.line(a.x, a.y, b.x, b.y, color) end
                end
            end
            drawn = drawn + 1
            if drawn >= 16 then break end
        end
    end
end)
