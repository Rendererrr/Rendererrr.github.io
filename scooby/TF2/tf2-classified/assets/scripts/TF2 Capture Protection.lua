-- Optional example for both TF2 Lua 1.2 hosts. No native effect/audio is generated.
assert(tf2 and tf2.capabilities().capture_features, "Update the TF2 Lua host to 1.2")
local hud=tf2.capture.feature({id="hud",label="Example HUD",default=true},"supported")
local effect=tf2.capture.feature({id="effect",label="Scene feature example"},"disable")
local strength=0.5
local pending={}
local function cancel_effects()
    pending={} -- Replace with cleanup of resources your feature actually owns.
end
events.on("capture_protection_changed",function()
    if capture_protection.enabled() then cancel_effects() end
end)
events.on("shutdown",cancel_effects)
events.on("update",function()
    if not features.active(effect) then cancel_effects(); return end
    -- Run your custom feature here, after the activation/policy check.
end)
local tab=ui.tab("capture_example","Capture example")
ui.subtab(tab,"features","Features",function()
    ui.feature(hud)
    ui.feature(effect)
    tf2.capture_scope(effect,function()
        local changed,value=imgui.slider_float("Effect strength",strength,0,1)
        if changed then strength=value end
    end)
    imgui.text(tf2.capture.status().renderer_status)
end)
ui.overlay("capture_example_hud",function()
    if features.active(hud) then render.text(20,140,"Capture-aware Lua HUD",{1,1,1,1},15) end
end)
