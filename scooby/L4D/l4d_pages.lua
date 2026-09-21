-- Product pages use the template's native groups, feature rows, binds and color pickers.
ui.feature_visible("demo.animate", false)
-- Built-in feature pages share a three-column layout; file browsers and user Lua keep their own layouts.
local function columns(draw)
    ui.columns(3,draw,true)
end
local function choice(label,id,field,items)
    imgui.text(label:gsub("##.*", ""))
    local changed,value=ui.combo("##"..label,l4d.setting(id,field)+1,items)
    if changed then l4d.setting(id,field,value-1) end
end
local function slider(label,id,field,low,high)
    local changed,value=ui.slider(label,l4d.setting(id,field),low,high)
    if changed then l4d.setting(id,field,value) end
end
ui.subtab("visuals", "entities", "Entities", function()
    columns(function()
        ui.group("Entity classes", function()
            ui.feature("l4d.survivors"); ui.feature("l4d.infected"); ui.feature("l4d.items")
        end)
        ui.next_column()
        ui.group("Actor boxes",function()
            ui.feature("actor.fit")
            if features.get("actor.fit") then
                slider("Padding (%)","actor.box_padding","distance",0,10)
                imgui.text("Fits the animated body, including head and feet. Works with Skeleton off.")
            else
                slider("Width (%)","actor.box_width","distance",25,100)
                slider("Height (%)","actor.box_height","distance",50,100)
                imgui.text("Legacy render bounds. Enable Fit to model for aligned body boxes.")
            end
            if ui.button("Reset box fit") then
                features.set("actor.fit",true)
                l4d.setting("actor.box_padding","distance",1.5)
            end
        end)
    end)
end)
local infectedTypes={"Common infected","Uncommon infected","Witch","Smoker","Boomer","Hunter","Spitter","Jockey","Charger","Tank","Unknown special"}
local infectedIds={"common","uncommon","witch","smoker","boomer","hunter","spitter","jockey","charger","tank","unknown"}
local function toggle(label,id)
    local changed,value=ui.toggle(label,features.get(id))
    if changed then features.set(id,value) end
end
ui.subtab("visuals","infected","Infected",function()
    columns(function()
        ui.group("Infected ESP",function()
            toggle("Enable infected", "l4d.infected")
            toggle("Special infected (including Tank)", "infected.specials")
            toggle("Use type colors", "infected.colors")
            imgui.text("Choose a type to edit")
            local changed,value=ui.combo("##infectedType",l4d.setting("infected.selector","style")+1,infectedTypes)
            if changed then l4d.setting("infected.selector","style",value-1) end
        end)
        local selected=l4d.setting("infected.selector","style")+1
        local id="infected."..infectedIds[selected]
        ui.next_column()
        ui.group(infectedTypes[selected],function()
            toggle("Show this type",id)
            slider("Maximum range (m)",id,"distance",1,300)
            imgui.text("The main ESP range also applies.")
        end)
        ui.next_column()
        ui.group("Type colors",function()
            ui.feature(id..".box");ui.feature(id..".skeleton");ui.feature(id..".name")
            ui.feature(id..".distance");ui.feature(id..".snaplines")
            imgui.text("Untick a color to use the global ESP color.")
        end)
    end)
end)
local materials={"Lit","Flat","Chrome","Ghost","Additive","Wireframe","Glass","Glow","Fullbright","Chrome wireframe","Ghost wireframe","Neon wireframe"}
local chamsCategories={"Players","Arms","Weapon","Dropped weapons","Items","Self","Common infected","Uncommon infected","Witch","Smoker","Boomer","Hunter","Spitter","Jockey","Charger","Tank","Unknown special"}
local chamsIds={"chams.survivors","chams.arms","chams.held","chams.weapons","chams.pickups","chams.self","chams.common","chams.uncommon","chams.witch","chams.smoker","chams.boomer","chams.hunter","chams.spitter","chams.jockey","chams.charger","chams.tank","chams.unknown"}
ui.subtab("visuals", "chams", "Chams", function()
    columns(function()
        ui.group("Chams",function()
            toggle("Chams","chams.enabled")
            choice("Target","chams.selector","style",chamsCategories)
            local selected=l4d.setting("chams.selector","style")+1
            toggle("Enable target",chamsIds[selected])
            if selected>=10 then toggle("Special infected","chams.special") end
            if selected~=2 and selected~=3 then slider("Range (m)","chams.enabled","distance",1,300) end
        end)
        local selected=l4d.setting("chams.selector","style")+1
        local id=chamsIds[selected]
        local visible=selected==1 and "chams.visible" or id..".custom"
        local invisible=selected==1 and "chams.hidden" or id..".hidden"
        ui.next_column()
        ui.group("Material",function()
            ui.feature(visible)
            choice("Visible material",visible,"style",materials)
            ui.feature(invisible)
            choice("Invisible material",invisible,"style",materials)
        end)
        ui.next_column()
        ui.group("Shared effects",function()
            ui.feature("chams.overlay");ui.feature("chams.wire")
            ui.feature("chams.pulse");ui.feature("chams.rainbow")
            slider("Pulse speed (Hz)","chams.pulse","thickness",0.5,5)
            ui.feature("chams.copy_pass");ui.feature("chams.swap_passes")
        end)
    end)
end)
ui.subtab("visuals","pickups","Pickups",function()
    columns(function()
        ui.group("Weapons and items",function()
            ui.feature("l4d.items")
            ui.feature("items.weapons");ui.feature("items.melee");ui.feature("items.throwables")
            ui.feature("items.medical");ui.feature("items.ammo");ui.feature("items.upgrades");ui.feature("items.carryables")
        end)
        ui.next_column()
        ui.group("Appearance",function()
            ui.feature("items.box")
            choice("Box style","items.box","style",{"Rectangle","Corners"})
            ui.feature("items.name");ui.feature("items.distance");ui.feature("items.snaplines")
            slider("Range (m)","l4d.items","distance",1,300)
            slider("Label size","l4d.items","textSize",10,24)
        end)
    end)
end)
local function activationKey(label,id)
    imgui.text(label)
    local key,mode,capturing,waiting=l4d.keybind(id)
    local caption=waiting and "Wait 0.5s..." or capturing and "Press a key..." or "Set key"
    if ui.button(ui.tr(caption).."###set_"..id) then l4d.keybind(id,"capture") end
    if key~="" then
        imgui.text(key)
        if ui.button(ui.tr("Clear bind").."###clear_"..id) then l4d.keybind(id,"clear") end
    end
    local changed,value=ui.combo("##"..id.."mode",mode+1,{"Always","Toggle","Hold","Hold to disable"})
    if changed then l4d.keybind(id,"mode",value-1) end
end
local targetLabels={"Common infected","Special infected","Witch","Survivors"}
local targetIds={"common","special","witch","survivors"}
local function targets(prefix)
    local selected={}
    for i,id in ipairs(targetIds) do selected[i]=features.get(prefix..id) end
    local changed,values=ui.multi_combo("##"..prefix.."targets",selected,targetLabels)
    if changed then
        for i,id in ipairs(targetIds) do
            if values[i]~=selected[i] then features.set(prefix..id,values[i]) end
        end
    end
end
local hitboxes={"Upper body","Chest","Head","Stomach","Arms","Legs","All"}
local function aimPage(title,rage)
    local aim=rage and "aim.rage." or "aim."
    local weapon=rage and "weapon.rage." or "weapon."
    columns(function()
        ui.group(title.." aiming",function()
            local selected=l4d.setting("aim.profile","style")==1
            imgui.text(string.format(ui.tr("Selected profile: %s"),ui.tr(selected and "Rage" or "Legit")))
            if selected~=rage and ui.button("Use "..title.." profile") then
                l4d.setting("aim.profile","style",rage and 1 or 0)
            end
            ui.feature(aim.."enabled")
            activationKey("Aim key",aim.."key")
            choice("Aim mode",aim.."mode","style",{"Camera","Silent","pSilent"})
            ui.feature(aim.."lock");ui.feature(aim.."attack");ui.feature(aim.."visible")
        end)
        ui.next_column()
        ui.group("Targets",function()
            targets(aim)
            slider("Maximum range (m)",aim.."range","distance",1,300)
            choice("Hitboxes",aim.."point","style",hitboxes)
        end)
        ui.group("Weapon controls",function()
            ui.feature(weapon.."no_recoil");ui.feature(weapon.."no_spread")
        end)
        ui.next_column()
        ui.group("Aim visuals",function()
            local prefix=rage and "aim.rage." or "aim.legit."
            ui.feature(prefix.."circle");ui.feature(prefix.."snapline");ui.feature(prefix.."dot")
        end)
        ui.group("Response",function()
            slider("Field of view (degrees)",rage and "aim.rage" or "aim.legit","distance",1,180)
            if not rage and l4d.setting(aim.."mode","style")==0 then slider("Smoothing",aim.."smoothing","distance",1,30) end
        end)
    end)
end
local rage=ui.tab("rage","Rage",{section="Combat",icon=0xe0d2})
ui.subtab(rage,"rage_aim","Ragebot",function() aimPage("Rage",true) end)
local legit=ui.tab("legit","Legit",{section="Combat",icon=0xe180})
ui.subtab(legit,"legit_aim","Legitbot",function() aimPage("Legit",false) end)
local function triggerPage(title,rage)
    local trigger=rage and "trigger.rage." or "trigger."
    local weapon=rage and "weapon.rage." or "weapon."
    columns(function()
        ui.group("Triggerbot",function()
            local selected=l4d.setting("aim.profile","style")==1
            imgui.text(string.format(ui.tr("Selected profile: %s"),ui.tr(selected and "Rage" or "Legit")))
            if selected~=rage and ui.button("Use "..title.." profile") then
                l4d.setting("aim.profile","style",rage and 1 or 0)
            end
            ui.feature(trigger.."enabled")
            activationKey("Trigger key",trigger.."key")
            slider("Reaction delay (ms)",trigger.."delay","distance",0,500)
            slider("Maximum range (m)",trigger.."range","distance",1,300)
        end)
        ui.next_column()
        ui.group("Targets",function()
            targets(trigger)
            choice("Hitboxes",trigger.."hitbox","style",hitboxes)
        end)
        ui.next_column()
        ui.group("Weapon controls",function()
            ui.feature(weapon.."no_recoil");ui.feature(weapon.."no_spread")
        end)
    end)
end
ui.subtab(rage,"rage_triggerbot","Triggerbot",function() triggerPage("Rage",true) end)
ui.subtab(legit,"triggerbot","Triggerbot",function() triggerPage("Legit",false) end)
local movement=ui.tab("movement","Movement",{section="Misc",icon=0xe3b9})
ui.subtab(movement,"assistance","Assistance",function()
    columns(function()
        ui.group("Movement",function() ui.feature("movement.bhop");ui.feature("movement.strafe") end)
        ui.next_column()
        ui.group("Telemetry",function()
            ui.feature("debug.telemetry")
            local speed= l4d.metrics()
            imgui.text(string.format(ui.tr("Speed: %.0f units/s"),speed))
            imgui.text("Hold jump for assistance. Ladders and deep water are excluded.")
        end)
    end)
end)
local world=ui.tab("world","World",{section="Visuals",icon=0xe231})
ui.subtab(world,"effects","Materials",function()
    columns(function()
        ui.group("World materials",function()
            ui.feature("world.tint");ui.feature("world.props");ui.feature("world.sky")
        end)
        ui.next_column()
        ui.group("Material colors",function()
            imgui.text("Map surfaces, static props and sky have independent colors.")
            imgui.text("Original material colors return when disabled or when the tool stops.")
            ui.feature("world.night");ui.feature("world.warm");ui.feature("world.cool");ui.feature("world.reset")
        end)
    end)
end)
ui.subtab(world,"view","View",function()
    columns(function()
        ui.group("Camera",function()
            ui.feature("view.camera_fov")
            slider("FOV (degrees)","view.camera_fov","distance",60,140)
            ui.feature("view.keep_zoom")
        end)
        ui.group("Viewmodel",function()
            ui.feature("view.model_fov")
            slider("Model FOV (degrees)","view.model_fov","distance",40,140)
        end)
        if ui.button("Reset view") then
            features.set("view.camera_fov",false);features.set("view.model_fov",false);features.set("view.offsets",false)
            features.set("view.keep_zoom",true);features.set("view.thirdperson",false)
            l4d.setting("view.thirdperson_distance","distance",120)
            l4d.setting("view.thirdperson_side","distance",20);l4d.setting("view.thirdperson_height","distance",5)
            l4d.setting("view.camera_fov","distance",90);l4d.setting("view.model_fov","distance",68)
            for _,id in ipairs({"view.offset_x","view.offset_y","view.offset_z"}) do l4d.setting(id,"distance",0) end
        end
        ui.next_column()
        ui.group("Third person",function()
            ui.feature("view.thirdperson")
            slider("Camera distance","view.thirdperson_distance","distance",40,200)
            slider("Shoulder - left / right","view.thirdperson_side","distance",-40,40)
            slider("Camera - down / up","view.thirdperson_height","distance",-30,30)
            ui.feature("view.swap_shoulder");ui.feature("view.center_camera")
        end)
        ui.next_column()
        ui.group("Model position",function()
            ui.feature("view.offsets")
            slider("X - left / right","view.offset_x","distance",-20,20)
            slider("Y - back / forward","view.offset_y","distance",-20,20)
            slider("Z - down / up","view.offset_z","distance",-20,20)
            imgui.text("Offsets follow the camera. Positive values move right, forward and up.")
        end)
    end)
end)
local debug=ui.tab("debug","Debug",{section="Misc",icon=0xe20c,hidden=true})
ui.subtab(debug,"session","Session",function()
    columns(function()
        ui.group("Engine",function()
            imgui.text(l4d.status())
            local speed,entities,properties=l4d.metrics()
            imgui.text(string.format(ui.tr("Entities: %d | Receive properties: %d"),entities,properties))
            ui.feature("debug.telemetry")
        end)
        ui.next_column()
        ui.group("Tool lifecycle",function()
            ui.feature("debug.block_input")
            ui.feature("debug.stop")
            imgui.text("Stop restores the game effects. Assign an optional shortcut in Hotkeys.")
        end)
    end)
end)
