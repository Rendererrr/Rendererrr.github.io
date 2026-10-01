local function slider(label,id,low,high)
    local changed,value=ui.slider(label,tf2.setting(id,"distance"),low,high)
    if changed then tf2.setting(id,"distance",value) end
end
local function choice(label,id,items)
    imgui.text(label:gsub("##.*", ""))
    local changed,value=ui.combo("##"..id,tf2.setting(id,"style")+1,items)
    if changed then tf2.setting(id,"style",value-1) end
end
local function activation(label,id)
    tf2.keybind_control(id,label)
end
local function combat(prefix)
    ui.columns(2,function()
        ui.group("Aim",function()
            choice("Active profile","combat.profile",{"Legit","Rage"})
            ui.feature(prefix.."enabled"); activation("Aim key",prefix.."key")
            choice("Aim mode",prefix.."mode",{"Camera","Silent"})
            slider("FOV",prefix.."fov",.1,180);slider("Range (m)",prefix.."range",1,500)
            slider("Smoothing",prefix.."smoothing",1,40)
            ui.feature(prefix.."autofire");ui.feature(prefix.."circle");ui.feature(prefix.."snapline")
        end)
        ui.next_column()
        ui.group("Targets",function()
            choice("Hitbox",prefix.."point",{"Head","Chest","Stomach","Left arm","Right arm","Left leg","Right leg","Upper body","Nearest"})
            ui.feature(prefix.."visible");ui.feature(prefix.."buildings")
            ui.feature(prefix.."cloaked");ui.feature(prefix.."disguised");ui.feature(prefix.."invulnerable")
        end)
    end,true)
end
local rage=ui.tab("tf2.rage","Rage",{section="Combat"})
ui.subtab(rage,"aim","Aimbot",function() combat("aim.rage.") end)
local function antiAim()
    ui.columns(2,function()
        ui.group("Anti-aim",function() ui.feature("antiaim.enabled");activation("Anti-aim key","antiaim.key") end)
        ui.next_column()
        ui.group("Angles",function()
            choice("Pitch","antiaim.pitch",{"Keep","Down","Up","Level","Jitter"})
            choice("Yaw","antiaim.yaw",{"Backwards","Left","Right","Jitter","Spin","View"})
            slider("Yaw offset","antiaim.offset",-180,180);slider("Jitter range","antiaim.jitter",0,180);slider("Spin speed","antiaim.spin",0,1440)
        end)
    end,true)
end
ui.subtab(rage,"antiaim","Anti-aim",antiAim)
local legit=ui.tab("tf2.legit","Legit",{section="Combat"})
ui.subtab(legit,"legit.aim","Aimbot",function() combat("aim.") end)

local function trigger(prefix)
    ui.columns(2,function()
        ui.group("Triggerbot",function()ui.feature(prefix.."enabled");activation("Trigger key",prefix.."key") end)
        ui.next_column()
        ui.group("Target",function()
            choice("Hitgroup",prefix.."group",{"Head","Chest","Stomach","Left arm","Right arm","Left leg","Right leg","Upper body","All"})
            slider("Delay (seconds)",prefix.."delay",0,1);slider("Range (m)",prefix.."range",1,500)
        end)
    end,true)
end
ui.subtab(rage,"rage.trigger","Triggerbot",function()trigger("trigger.rage.")end)
ui.subtab(legit,"legit.trigger","Triggerbot",function()trigger("trigger.")end)
local aimbot=ui.tab("tf2.aimbot","Aimbot",{section="Combat"})
ui.subtab(aimbot,"aimbot.aim","Aim",function() tf2.combat_page(0) end)
ui.subtab(aimbot,"aimbot.trigger","Triggerbot",function() tf2.combat_page(1) end)
ui.subtab(aimbot,"aimbot.antiaim","Anti-aim",antiAim)
local classes={"Scout","Sniper","Soldier","Demoman","Medic","Heavy","Pyro","Spy","Engineer"}
local chams=ui.tab("tf2.chams","Chams",{section="Visuals"})
local chamsTargets={"players","self","arms","weapon","world_weapon","buildings","teammates","items","dropped_weapons"}
local function chamsTarget(selected,labels)
    for index,label in ipairs(labels) do
        if index>1 then imgui.same_line() end
        local width=imgui.text_size(label)
        if ui.selectable(label.."##chams_target",selected==index,width+12) then selected=index end
    end
    return selected
end
local function chamsPage(targets,labels,preview)
    local selected,layer=1,1
    return function()
        ui.columns(preview and 2 or 1,function()
            if targets[1]==1 then
                selected=chamsTarget(selected,labels)
            elseif #targets>1 then
                local changed,value=ui.combo("Target",selected,labels)
                if changed then selected=value end
            end
            local target=targets[selected]
            if preview then ui.next_column() end
            layer=tf2.chams_preview_controls(layer,preview and (target==1 or target==2 or target==7))
            if preview then ui.next_column() end
            tf2.setting("chams.target","style",target-1)
            tf2.capture_scope(function() ui.group("Materials",function()
                for _,layer in ipairs({layer==1 and "visible" or "hidden","overlay"}) do
                    local id="chams."..chamsTargets[target].."."..layer
                    ui.feature(id)
                    if features.get(id) then
                        choice("Material##"..layer,id,{"Flat","Lit","Wireframe","Fresnel","Chrome","Crystal","Scanline"})
                        local textured=tf2.setting(id,"style")>=5
                        if not textured and tf2.setting(id..".animation","style")>3 then tf2.setting(id..".animation","style",0) end
                        choice("Animation##"..layer,id..".animation",textured and {"Static","Pulse","Rainbow","Breathe","Scroll","Rotate"} or {"Static","Pulse","Rainbow","Breathe"})
                        if tf2.setting(id..".animation","style")>0 then
                            slider("Speed##"..layer,id..".speed",0,10)
                            slider("Strength##"..layer,id..".strength",0,1)
                        end
                    end
                end
            end)
            end)
            if preview and target~=3 then
                ui.next_column()
                if target==4 or target==5 or target==9 then
                    tf2.object_preview("weapons",true,layer)
                elseif target==8 then
                    tf2.object_preview("items",true,layer)
                else
                    tf2.model_preview(true,layer)
                end
            end
        end,true)
    end
end
ui.subtab(chams,"chams.materials","Players",chamsPage({1,7},{"Enemy","Friendly"},true))
ui.subtab(chams,"chams.weapons","Weapons",chamsPage({4,5,9},{"Viewmodel weapon","Held weapon","Dropped weapons"},true))
ui.subtab(chams,"chams.items","Items",chamsPage({8},{"Items"},true))
ui.subtab(chams,"chams.self","Self",chamsPage({2,3},{"Player model","Arms"},true))
ui.subtab(chams,"chams.buildings","Buildings",chamsPage({6},{"Buildings"},false))

local vfx=ui.tab("tf2.vfx","VFX",{section="Visuals"})
ui.subtab(vfx,"vfx.world","World",function()
    tf2.capture_scope(function()
    ui.columns(2,function()
        ui.group("World",function()
            tf2.tint_control("vfx.world")
            tf2.toggle_control("vfx.night")
            if features.get("vfx.night") then slider("Brightness (%)","vfx.brightness",5,100) end
        end)
        ui.next_column()
        ui.group("Props",function()
            tf2.tint_control("vfx.props")
            if features.get("vfx.props") then slider("Opacity (%)","vfx.prop_opacity",5,100) end
        end)
    end,true)
    end)
end)
ui.subtab(vfx,"vfx.sky","Sky",function()
    tf2.capture_scope(function()
    ui.columns(2,function()
        ui.group("Skybox",function()choice("Preset","vfx.skybox",{"Map default","2Fort","Dustbowl","Badlands","Hydro","Gravelpit","Harvest","Harvest night","Night","Stormfront","Alpine storm"}) end)
        ui.next_column()
        ui.group("Sky color",function()tf2.tint_control("vfx.sky") end)
    end,true)
    end)
end)
ui.subtab(vfx,"vfx.effects","Effects",function()
    tf2.capture_scope(function()
    ui.columns(2,function()
        ui.group("World pulse",function()
            tf2.toggle_control("vfx.world_pulse")
            if features.get("vfx.world_pulse") then slider("Speed","vfx.pulse_speed",0,5);slider("Strength","vfx.pulse_strength",0,1) end
        end)
        ui.next_column()
        ui.group("Sky cycle",function()
            tf2.toggle_control("vfx.sky_cycle")
            if features.get("vfx.sky_cycle") then slider("Speed","vfx.sky_speed",0,5);slider("Strength","vfx.sky_strength",0,1) end
        end)
    end,true)
    end)
end)

ui.subtab(vfx,"vfx.filters","Filters",function()
    tf2.capture_scope(function()
    ui.columns(2,function()
        ui.group("Fog",function()
            tf2.toggle_control("vfx.no_fog")
            tf2.toggle_control("vfx.no_sky_fog")
        end)
        ui.group("Custom materials",function()
            tf2.toggle_control("vfx.pure_bypass")
            imgui.text("Enable before joining a server.")
            imgui.text("Restart if a whitelist was already loaded.")
        end)
        ui.next_column()
        ui.group("Remove screen effects",function()
            for _,id in ipairs({"water","invulnerability","milk","jarate","bleeding","stealth","bonk","gas","burning"}) do
                tf2.toggle_control("vfx.remove."..id)
            end
        end)
    end,true)
    end)
end)

local function viewPage()
    tf2.capture_scope(function()
    ui.columns(2,function()
    ui.group("Third person",function()
        tf2.toggle_control("view.thirdperson")
        slider("Distance","view.thirdperson_distance",30,400)
        slider("Shoulder","view.thirdperson_shoulder",-64,64)
        slider("Height","view.thirdperson_height",-64,64)
        tf2.toggle_control("view.thirdperson_swap")
        tf2.toggle_control("view.thirdperson_collision")
        tf2.toggle_control("view.thirdperson_scoped")
    end)
    ui.group("Free camera",function()
        tf2.toggle_control("view.freecam")
        slider("Flight speed","view.freecam_speed",50,2000)
        slider("Speed multiplier","view.freecam_boost",1,5)
        imgui.text("Move / Jump / Duck to fly. Speed key boosts.")
    end)
    ui.next_column()
    ui.group("Camera & model",function()
        tf2.toggle_control("view.camera_fov");slider("FOV","view.camera_fov",60,130)
        tf2.toggle_control("view.model_fov");slider("Model FOV","view.model_fov",40,140)
        tf2.toggle_control("view.model_offset")
        if features.get("view.model_offset") then
            slider("X (right)","view.offset_x",-60,60);slider("Y (forward)","view.offset_y",-60,60);slider("Z (up)","view.offset_z",-60,60)
            slider("Pitch","view.angle_pitch",-180,180);slider("Yaw","view.angle_yaw",-180,180);slider("Roll","view.angle_roll",-180,180)
        end
    end)
    end,true)
    end)
end
local function movementPage()
    ui.group("Movement",function()
        tf2.toggle_control("movement.bhop")
        tf2.toggle_control("movement.air_jump")
        tf2.toggle_control("movement.rev_jump")
        tf2.toggle_control("movement.strafe")
        if features.get("movement.strafe") then
            choice("Strafe direction","movement.strafe_direction",{"View / mouse","Movement keys"})
            tf2.toggle_control("movement.prespeed")
        end
    end)
end
-- Keep old script routes and feature IDs available to existing configs/scripts.
local self=ui.tab("tf2.self","View",{section="Misc"})
ui.subtab(self,"view","Camera & model",viewPage)
local movement=ui.tab("tf2.movement","Movement",{section="Misc"})
ui.subtab(movement,"movement.main","Movement",movementPage)
local misc=ui.tab("tf2.misc","Misc",{section="Misc"})
ui.subtab(misc,"misc.skins","Skins",function() tf2.capture_scope(function() tf2.skins_page(3) end) end)
ui.subtab(misc,"misc.inventory","Inventory",function() tf2.capture_scope(function() tf2.skins_page(4) end) end)
ui.subtab(misc,"misc.view","View",viewPage)
ui.subtab(misc,"misc.movement","Movement",movementPage)
ui.subtab(misc,"misc.main","Misc",function()
    ui.group("Session",function() ui.feature("tf2.stop") end)
end)

local worldIds={"buildings","projectiles","health","ammo","weapons","objectives","payload","robots","giants","tanks","currency","bomb","revive","bosses","halloween","powerups","robot_destruction","passtime","control_points"}
local worldLabels={"Buildings","Projectiles","Health packs","Ammo packs","Dropped weapons","Flags / objectives","Payload / trains","Robots","Giant robots","Tanks","Currency","MvM bomb","Revive markers","Bosses","Halloween pickups / bombs","Mannpower powerups","Robot Destruction robots","PASS Time ball","Control points"}
ui.subtab("visuals","tf2.world","World & modes",function()
    choice("Target","world.target",worldLabels)
    local id="esp.world."..worldIds[tf2.setting("world.target","style")+1].."."
    ui.columns(2,function()
        ui.group("ESP",function()
            for _,part in ipairs({"enabled","box","name","distance","snaplines"}) do ui.feature(id..part) end
            local target=worldIds[tf2.setting("world.target","style")+1]
            if target=="buildings" or target=="robots" or target=="giants" or target=="tanks" or target=="revive" or target=="bosses" or target=="robot_destruction" then
                ui.feature(id.."health")
            end
            if target=="robots" or target=="giants" then ui.feature(id.."skeleton") end
        end)
        ui.next_column()
        ui.group("Range",function()slider("Max distance (m)",id.."enabled",1,1000)end)
    end,true)
end)
ui.subtab(misc,"misc.mvm","Mann vs. Machine",function()
    ui.group("Mann vs. Machine",function()
        ui.feature("mvm.auto_ready");ui.feature("mvm.wave_panel")
    end)
end)

local itemTypes={"health","ammo"}
local itemLabels={"Health packs","Ammo packs"}
local function objectEsp(category,label)
    local id="esp.world."..category.."."
    ui.columns(2,function()
        ui.group(label.." visuals",function()
            for _,part in ipairs({"enabled","box","name","distance","snaplines"}) do ui.feature(id..part) end
            slider("Max distance (m)",id.."enabled",1,1000)
        end)
        ui.next_column()
        tf2.object_preview(category,false)
    end,true)
end
ui.subtab("visuals","tf2.weapons","Weapons",function() objectEsp("weapons","Weapon") end)
ui.subtab("visuals","tf2.items","Items",function()
    choice("Item type","preview.object.type",itemLabels)
    objectEsp(itemTypes[tf2.setting("preview.object.type","style")+1],"Item")
end)

local skins=ui.tab("tf2.skins","Skins",{section="Visuals"})
ui.subtab(skins,"skins.weapons","Weapons",function() tf2.capture_scope(function() tf2.skins_page(false) end) end)
ui.subtab(skins,"skins.players","Players",function() tf2.capture_scope(function() tf2.skins_page(true) end) end)
ui.subtab(skins,"skins.cosmetics","Hats & cosmetics",function() tf2.capture_scope(function() tf2.skins_page(2) end) end)

ui.subtab("settings","capture.protection","Capture Protection",function() tf2.capture_page() end)
