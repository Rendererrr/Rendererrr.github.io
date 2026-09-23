-- Product pages use the template's native groups, feature rows, binds and color pickers.
ui.feature_visible("demo.animate", false)
-- Built-in feature pages share a three-column layout; file browsers and user Lua keep their own layouts.
local function columns(draw)
    ui.columns(3,draw,true)
end
local function choice(label,id,field,items,materialChoice)
    imgui.text(label:gsub("##.*", ""))
    local changed,value=ui.combo("##"..label,l4d.setting(id,field)+1,items)
    if changed then l4d.setting(id,field,value-1);if materialChoice then l4d.user_material(id,0) end end
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
local materials={"Lit","Flat","Chrome","Ghost","Additive","Wireframe","Glass","Glow","Fullbright","Chrome wireframe","Ghost wireframe","Neon wireframe","Galaxy","Galaxy flow","Lightning","Lightning overlay","Plasma flow","Aurora","Molten","Dark Matter","Acid","Vortex","Hologram","Frost","Inferno","Circuit","Pearl"}
local function supportsAnimation(style) return style>=12 and style<#materials end
local chamsTypes={"Players","Self","Common infected","Uncommon infected","Special infected","Witch","Arms","Weapon","Held weapon (world)","Dropped weapons","Items"}
-- Map the grouped menu to the existing saved selector; existing configs and Lua indices remain stable.
local chamsTypeTargets={1,6,7,8,10,9,2,3,18,4,5}
local specialChamsTypes={"Smoker","Boomer","Hunter","Spitter","Jockey","Charger","Tank","Unknown special"}
local lastSpecialChams=10
local function chamsTargetDropdown()
    local selected=l4d.setting("chams.selector","style")+1
    local category=1
    if selected>=10 and selected<=17 then
        category=5
        lastSpecialChams=selected
    else
        for i,target in ipairs(chamsTypeTargets) do
            if selected==target then category=i;break end
        end
    end
    imgui.text("Target")
    local changed,value=ui.combo("##chamsType",category,chamsTypes)
    if changed then
        category=value
        selected=category==5 and lastSpecialChams or chamsTypeTargets[category]
        l4d.setting("chams.selector","style",selected-1)
    end
    if category==5 then
        imgui.text("Infected type")
        changed,value=ui.combo("##chamsInfectedType",selected-9,specialChamsTypes)
        if changed then
            selected=value+9
            lastSpecialChams=selected
            l4d.setting("chams.selector","style",selected-1)
        end
    end
    return selected
end
local chamsIds={"chams.survivors","chams.arms","chams.held","chams.weapons","chams.pickups","chams.self","chams.common","chams.uncommon","chams.witch","chams.smoker","chams.boomer","chams.hunter","chams.spitter","chams.jockey","chams.charger","chams.tank","chams.unknown","chams.world_weapon"}
local animationLayer=1
ui.subtab("visuals", "chams", "Chams", function()
    columns(function()
        ui.group("Chams",function()
            toggle("Chams","chams.enabled")
            local selected=chamsTargetDropdown()
            toggle("Enable target",chamsIds[selected])
            if selected>=10 and selected<=17 then toggle("Special infected","chams.special") end
            if selected~=2 and selected~=3 then slider("Range (m)","chams.enabled","distance",1,300) end
        end)
        local selected=l4d.setting("chams.selector","style")+1
        local id=chamsIds[selected]
        local visible=selected==1 and "chams.visible" or id..".custom"
        local invisible=selected==1 and "chams.hidden" or id..".hidden"
        local overlay=id..".overlay"
        local animationSupported=supportsAnimation(l4d.setting(visible,"style")) or supportsAnimation(l4d.setting(invisible,"style")) or
            (features.get(overlay) and supportsAnimation(l4d.setting(overlay,"style")))
        ui.next_column()
        ui.group("Material",function()
            ui.feature(visible)
            choice("Visible material",visible,"style",materials,true)
            ui.feature(invisible)
            choice("Invisible material",invisible,"style",materials,true)
        end)
        ui.group("Layer animation",function()
            local changed,value=ui.combo("Layer",animationLayer,{"Visible","Invisible","Overlay"})
            if changed then animationLayer=value end
            local pass=({visible,invisible,overlay})[animationLayer]
            local animation=pass..".animation"
            local mode=l4d.setting(animation,"style")
            if mode==1 or mode==6 or mode==7 then ui.feature(animation) else toggle("Custom animation",animation) end
            if features.get(animation) then
                choice("Mode",animation,"style",{"Static","Color wave","Pulse opacity","Rainbow colors","Shimmer","Ember flicker","Color surge","Color steps"})
                if mode~=0 then
                    slider("Speed (Hz)",animation.."_speed","distance",0.05,3)
                    slider("Strength",animation.."_amount","distance",0,1)
                end
                ui.keybind(animation)
            end
        end)
        ui.next_column()
        ui.group("Overlay",function()
            ui.feature(overlay)
            if features.get(overlay) then choice("Overlay material",overlay,"style",materials,true) end
        end)
        ui.group("Shared effects",function()
            ui.feature("chams.overlay");ui.feature("chams.wire")
            ui.feature("chams.pulse");ui.feature("chams.rainbow")
            if animationSupported then
                ui.feature("chams.animation")
                if features.get("chams.animation") then
                    choice("Mode","chams.animation","style",{"Color wave","Breathing","Shimmer"})
                    slider("Speed (Hz)","chams.animation_speed","distance",0.05,3)
                    slider("Strength","chams.animation_amount","distance",0,1)
                end
            end
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
-- Persisted value 6 already scans every hitbox and ranks by crosshair angle.
local aimHitboxes={"Upper body","Chest","Head","Stomach","Arms","Legs","Nearest"}
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
            choice("Target priority",aim.."priority","style",{"Crosshair","Special infected","Survivors","Common infected"})
            choice("Hitboxes",aim.."point","style",aimHitboxes)
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
ui.subtab(rage,"anti_aim","Anti-Aim",function()
    columns(function()
        ui.group("Anti-Aim",function()
            ui.feature("antiaim.enabled")
            activationKey("AntiAim Hotkey","antiaim.key")
            ui.feature("antiaim.invert")
        end)
        ui.next_column()
        ui.group("Yaw",function()
            choice("Yaw","antiaim.yaw","style",{"Backwards","Left","Right","Jitter","Spin","Random","Distortion","Switch","View"})
            slider("Yaw Offset","antiaim.yaw_offset","distance",-180,180)
            local yaw=l4d.setting("antiaim.yaw","style")
            if yaw==4 then slider("Spin Speed","antiaim.spin","distance",30,1440) end
            if yaw==3 or yaw==6 then slider("Jitter Range","antiaim.jitter","distance",0,180) end
        end)
        ui.next_column()
        ui.group("Pitch",function()
            choice("Pitch","antiaim.pitch","style",{"View","Down","Up","Zero","Jitter","Custom"})
            if l4d.setting("antiaim.pitch","style")==5 then
                slider("Custom Pitch","antiaim.custom_pitch","distance",-89,89)
            end
        end)
    end)
end)
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
-- VFX keeps the existing world/chams IDs so profiles, scripts and shortcuts survive.
local skyNames={"Galaxy","Blue nebula","Crimson nebula","Dawn","Storm","Aurora","Bloodmoon","Synthwave","Frost","Toxic","Sunset","Noir"}
local vfx=ui.tab("vfx","VFX",{section="Visuals",icon=0xe231})
local previewMotion=true
local function motionToggle()
    local changed,value=ui.toggle("Animate preview",previewMotion)
    if changed then previewMotion=value end
end
-- Keep a single library beside an independently scrollable inspector.
local function vfxSplit(library,inspector)
    local width,height=imgui.available()
    local gap=14
    if width<430 then
        library()
        imgui.spacing(12)
        inspector()
        return
    end
    local side=math.max(188,math.min(246,width*.37))
    local panelHeight=math.max(80,height-4)
    imgui.child("vfx-library",width-side-gap,panelHeight,library)
    imgui.same_line(gap)
    imgui.child("vfx-inspector",side,panelHeight,function()
        inspector()
        imgui.spacing(12)
    end)
end
local function gallery(kind,names,first,current,onSelect,last)
    local width,height=imgui.available()
    local gap=8
    local count=width>=270 and 3 or width>=156 and 2 or 1
    local w=math.max(32,(width-gap*(count-1))/count)
    local rows=math.ceil(((last or #names)-first+1)/count)
    local h=math.max(kind=="material" and 50 or 58,math.min(w*.58+23,(height-10-gap*(rows-1))/rows))
    for i=first,last or #names do
        local column=(i-first)%count
        if column~=0 then imgui.same_line(gap)
        elseif i~=first then imgui.spacing(4) end
        if l4d.vfx_card(kind,i-1,current==i-1,w,h,false,"",ui.tr(names[i])) then onSelect(i-1) end
        imgui.tooltip(names[i])
    end
end
local function skyPreview()
    -- available() returns width AND height; capture width before passing it on.
    local width=imgui.available()
    width=math.max(32,width)
    l4d.vfx_card("sky",l4d.setting("world.skybox","style"),false,width,math.min(92,width*.52),false)
end
local atmospheres={
    {{.34,.32,.48},{.54,.50,.68},{1,1,1}},
    {{.25,.39,.54},{.43,.6,.73},{1,1,1}},
    {{.43,.24,.33},{.65,.4,.5},{1,1,1}},
    {{.83,.67,.54},{.96,.81,.65},{1,1,1}},
    {{.34,.4,.45},{.49,.56,.61},{.9,.95,1}},
    {{.28,.42,.44},{.45,.63,.62},{1,1,1}},
    {{.43,.2,.23},{.62,.33,.35},{1,1,1}},
    {{.45,.28,.53},{.64,.43,.69},{1,1,1}},
    {{.53,.67,.78},{.7,.84,.94},{1,1,1}},
    {{.38,.43,.21},{.57,.65,.36},{1,1,1}},
    {{.75,.49,.34},{.9,.65,.46},{1,1,1}},
    {{.32,.32,.35},{.48,.48,.51},{1,1,1}}
}
local function skyLibrary(title)
    -- The ordinary settings group intentionally caps its width; galleries use the full panel.
    imgui.text(title)
    imgui.spacing(8)
    gallery("sky",skyNames,1,l4d.setting("world.skybox","style"),function(style)
        l4d.setting("world.skybox","style",style)
    end)
end
ui.subtab(vfx,"vfx_presets","Presets",function()
    vfxSplit(function() skyLibrary("Atmosphere library") end,function()
        ui.group(skyNames[l4d.setting("world.skybox","style")+1],function()
            skyPreview()
            imgui.spacing(4)
            if imgui.button(ui.tr("Apply preset"),imgui.available(),24) then
                local colors=atmospheres[l4d.setting("world.skybox","style")+1]
                for i,id in ipairs({"world.tint","world.props","world.sky"}) do
                    features.color(id,colors[i][1],colors[i][2],colors[i][3],1)
                    features.set(id,true)
                end
                features.set("world.skybox",true)
                features.set("world.sky_animation",false);features.set("world.pulse",false)
                l4d.setting("world.sky_brightness","distance",1)
            end
        end)
        ui.group("Fine tuning",function()
            ui.feature("world.tint");ui.feature("world.props");ui.feature("world.sky")
            slider("Sky brightness","world.sky_brightness","distance",.1,2)
            ui.feature("world.reset")
        end)
    end)
end)
ui.subtab(vfx,"vfx_sky","Sky",function()
    vfxSplit(function() skyLibrary("Sky library") end,function()
        ui.group(skyNames[l4d.setting("world.skybox","style")+1],function()
            skyPreview()
            toggle("Enable skybox","world.skybox")
            slider("Brightness","world.sky_brightness","distance",.1,2)
        end)
        ui.group("Color and motion",function()
            ui.feature("world.sky")
            ui.feature("world.sky_animation")
            slider("Color speed (Hz)","world.sky_speed","distance",.05,1)
        end)
        ui.group("Skybox shortcut",function() ui.keybind("world.skybox") end)
    end)
end)
ui.subtab(vfx,"vfx_lighting","Lighting",function()
    ui.columns(3,function()
        ui.group("World materials",function()
            ui.feature("world.tint");ui.feature("world.props");ui.feature("world.sky")
        end)
        ui.group("Lighting presets",function()
            ui.feature("world.night");ui.feature("world.warm");ui.feature("world.cool");ui.feature("world.reset")
        end)
        ui.next_column()
        ui.group("World animation",function()
            ui.feature("world.pulse")
            slider("Pulse speed (Hz)","world.pulse_speed","distance",.05,1)
            slider("Pulse strength","world.pulse_amount","distance",0,.8)
        end)
        ui.next_column()
        ui.group("Sky color",function()
            ui.feature("world.sky_animation")
            slider("Color speed (Hz)","world.sky_speed","distance",.05,1)
        end)
    end,true)
end)
local vfxLayer=1
local materialLibrary=1
local libraryNotice={}
local initialMaterials=l4d.user_materials()
if #initialMaterials>0 then materialLibrary=2 end
for i,id in ipairs(chamsIds) do
    for _,pass in ipairs({i==1 and "chams.visible" or id..".custom",i==1 and "chams.hidden" or id..".hidden",id..".overlay"}) do
        ui.feature_visible(pass..".user_material",false)
    end
end
local function selectedPass()
    local selected=l4d.setting("chams.selector","style")+1
    local id=chamsIds[selected]
    return ({selected==1 and "chams.visible" or id..".custom",selected==1 and "chams.hidden" or id..".hidden",id..".overlay"})[vfxLayer]
end
ui.subtab(vfx,"vfx_materials","Materials",function()
    vfxSplit(function()
        local pass=selectedPass()
        local changed,value=ui.combo("Library",materialLibrary,{"Built-in materials","My materials"})
        if changed then materialLibrary=value end
        imgui.spacing(8)
        if materialLibrary==1 then
            gallery("material",materials,13,l4d.user_material(pass)==0 and l4d.setting(pass,"style") or -1,function(style)
                l4d.setting(pass,"style",style);l4d.user_material(pass,0)
            end)
        else
            local entries,folder,errors=l4d.user_materials()
            for _,action in ipairs({{"Open folder","open"},{"Refresh","refresh"},{"Add example","example"}}) do
                if ui.button(action[1]) then entries,folder,libraryNotice=l4d.user_materials(action[2]) end
                if action[2]~="example" then imgui.same_line() end
            end
            imgui.spacing(6)
            imgui.text("name.vmt + name.vtf")
            imgui.text("Preview: matching name.png or name.gif")
            if #entries==0 then imgui.text("Add your files, then press Refresh.") end
            local available=imgui.available()
            local columns=available>=250 and 3 or 2
            local width=math.max(32,(available-(columns-1)*10)/columns)
            local selected=l4d.user_material(pass)
            for i,item in ipairs(entries) do
                if l4d.vfx_card("user",item.id,selected==item.id,width,width*.64+28,previewMotion,"",item.name) then
                    l4d.user_material(pass,item.id)
                end
                if i%columns~=0 then imgui.same_line(10) end
            end
            imgui.spacing(8)
            for _,message in ipairs(errors) do imgui.text(message) end
            for _,message in ipairs(libraryNotice) do imgui.text(message) end
        end
    end,function()
        ui.group("Target and layer",function()
            toggle("Chams","chams.enabled")
            local selected=chamsTargetDropdown()
            toggle("Enable target",chamsIds[selected])
            if selected>=10 and selected<=17 then toggle("Special infected","chams.special") end
            local changed,value=ui.combo("Layer",vfxLayer,{"Visible","Invisible","Overlay"})
            if changed then vfxLayer=value end
        end)
        local pass=selectedPass()
        ui.group("Selected material",function()
            local style=l4d.setting(pass,"style")
            local userId=l4d.user_material(pass)
            local selectedUser=nil
            for _,item in ipairs(l4d.user_materials()) do if item.id==userId then selectedUser=item end end
            if selectedUser or (userId==0 and style>=12) then
                local width=imgui.available()
                width=math.max(32,width)
                l4d.vfx_card(selectedUser and "user" or "material",selectedUser and userId or style,false,width,math.min(122,width*.57),previewMotion,pass)
                if selectedUser then imgui.text(selectedUser.name) end
                motionToggle()
            elseif userId~=0 then
                imgui.text("Custom material missing. Using built-in fallback.")
            end
            if userId~=0 and ui.button("Use built-in material") then l4d.user_material(pass,0) end
            ui.feature(pass)
            choice(userId~=0 and "Built-in fallback##vfx" or "Material##vfx",pass,"style",materials,true)
        end)
        ui.group("Layer animation",function()
            local animation=pass..".animation"
            ui.feature(animation)
            choice("Animation##vfx",animation,"style",{"Static","Color wave","Pulse opacity","Rainbow colors","Shimmer","Ember flicker","Color surge","Color steps"})
            slider("Speed (Hz)",animation.."_speed","distance",.05,3)
            slider("Strength",animation.."_amount","distance",0,1)
            ui.keybind(animation)
        end)
        ui.group("Shared effects",function()
            ui.feature("chams.pulse");ui.feature("chams.rainbow");ui.feature("chams.animation")
            slider("Shared speed (Hz)","chams.animation_speed","distance",.05,3)
            slider("Shared strength","chams.animation_amount","distance",0,1)
            ui.feature("chams.copy_pass");ui.feature("chams.swap_passes")
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
