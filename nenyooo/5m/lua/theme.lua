
-- nenyoo_builtin_theme_version=8
theme_full = true
menu.set_navigation_style("tabs")
local logo_font=font.logo or font.title

local palette = {
    bg={21,24,27,230}, panel={15,18,20,255}, card={17,20,23,255},
    input={28,32,36,255}, side={34,40,45,255}, border={255,255,255,12},
    text={211,216,219,255}, dim={153,162,168,255}, faint={102,113,120,255},
    accent={186,134,255,255}, accentHi={198,155,255,255},
    accentLo={137,91,244,255}, green={186,134,255,255},
    logoNen={186,134,255,255}, logoYoo={255,255,255,255},
    sidebar={21,24,27,230}, header={21,24,27,230}, groupHeader={13,16,18,255}
}

-- One definition drives registration, persistence, reset, and the settings cards.
local color_settings={
    {"Accent","accent","accent"},{"Background","background","bg"},{"Panel","panel","panel"},
    {"Nen Color","logo_nen","logoNen"},{"yoo Color","logo_yoo","logoYoo"},
    {"Sidebar","sidebar_color","sidebar"},{"Header","header_color","header"},
    {"Group Header","group_header","groupHeader","group_header"},
    {"Input","input_color","input","input"},{"Selection","selection_color","side","selection"},
    {"Text","text_color","text","text"},{"Muted Text","muted_text","dim","muted_text"},
    {"Section Text","section_text","faint","section_text"},{"Border","border_color","border","border"}
}
for _,entry in ipairs(color_settings) do entry.default={table.unpack(palette[entry[3]])} end
local layout_sliders={
    {"Group Columns","columns",3,1,3,"Maximum columns; adapts to available width"},
    {"Group Spacing","group_spacing",16,8,28,"Space between groups"},
    {"Row Spacing","row_spacing",0,0,12,"Extra space between feature controls"},
    {"Scroll Speed","scroll_speed",70,20,140,"Scroll distance per wheel step"}
}
local navigation_toggles={
    {"Sidebar Labels","sidebar_labels",true},{"Sidebar Icons","sidebar_icons",true},
    {"Tab Underline","tab_underline",true}
}
local ui_options={columns=3,group_spacing=16,row_spacing=0,scroll_speed=70,
    sidebar_labels=true,sidebar_icons=true,tab_underline=true}
local function read_config()
    local out, raw = {}, file.read("theme_settings.ini")
    if type(raw) ~= "string" then return out end
    for key,value in raw:gmatch("([%w_]+)=([^\r\n]+)") do out[key]=value end
    return out
end
local saved=read_config()
-- Put both games on the same FiveM reference appearance once. This only
-- resets visual settings; language, menu keys, and gameplay state live in
-- their own stores and remain untouched.
local appearance_revision="unified_fivem_1"
if saved.appearance_revision~=appearance_revision then
    for _,entry in ipairs(color_settings) do saved[entry[2]]=nil end
    for _,entry in ipairs(layout_sliders) do saved[entry[2]]=nil end
    for _,entry in ipairs(navigation_toggles) do saved[entry[2]]=nil end
    for _,key in ipairs({"sidebar","sidebar_layout","radius","title_size","item_size","small_size",
        "value_size","desc_size","label_size","tagline_size","tiny_size","motion_enabled","motion_speed"}) do
        saved[key]=nil
    end
end
local function num(key,fallback) return tonumber(saved[key]) or fallback end
local function saved_color(key,fallback)
    local value=saved[key]
    if not value then return table.unpack(fallback) end
    local r,g,b,a=value:match("(%d+),(%d+),(%d+),(%d+)")
    if not r then return table.unpack(fallback) end
    local function channel(v) return math.max(0,math.min(255,tonumber(v))) end
    return channel(r),channel(g),channel(b),channel(a)
end

menu.clear_settings()
menu.add_setting_submenu("Nenyoo Appearance","Layout and complete Lua palette")
for _,entry in ipairs(color_settings) do
    menu.add_sub_color(entry[1],saved_color(entry[2],entry.default))
end
local sidebar_default=num("sidebar",170)
if not saved.sidebar_layout and sidebar_default==250 then sidebar_default=170 end
menu.add_sub_slider("Sidebar Width",sidebar_default,150,230,1,"Left navigation width")
menu.add_sub_slider("Corner Radius",num("radius",3),0,18,1,"Cards and controls")
menu.add_setting_submenu("UI Layout","Spacing, scrolling, and navigation")
for _,entry in ipairs(layout_sliders) do
    menu.add_sub_slider(entry[1],math.max(entry[4],math.min(entry[5],num(entry[2],entry[3]))),entry[4],entry[5],1,entry[6])
end
for _,entry in ipairs(navigation_toggles) do
    menu.add_sub_toggle(entry[1],num(entry[2],entry[3] and 1 or 0)~=0)
end
menu.add_setting_submenu("Typography","Font sizes are controlled by Lua")
menu.add_sub_slider("Title Size",num("title_size",20),16,32,1)
menu.add_sub_slider("Item Size",num("item_size",11),10,20,1)
menu.add_sub_slider("Small Size",num("small_size",9),8,16,1)
menu.add_sub_slider("Value Size",num("value_size",math.max(10,num("item_size",11)-1)),9,18,1)
menu.add_sub_slider("Description Size",num("desc_size",9),8,16,1)
menu.add_sub_slider("Section Label Size",num("label_size",10),8,14,1)
menu.add_sub_slider("Tagline Size",num("tagline_size",9),8,16,1)
menu.add_sub_slider("Overlay Text Size",num("tiny_size",8),7,14,1)
menu.add_setting_submenu("Motion","Restrained interface animation")
menu.add_sub_toggle("Animations Enabled",num("motion_enabled",1)~=0,"Enable interface transitions")
menu.add_sub_slider("Motion Speed",num("motion_speed",1),.5,2,.05,"Animation speed multiplier")

local motion_enabled=true
local motion_speed=1
local combat_tab=1
local aim_keybind_id,aim_keybind_seen=0xD005,false
local visual_tabs={Visuals="ESP",["VFX's"]="Sky"}
local visuals_header_scroll=0
local visuals_header_last_tab=nil
local visuals_header_drag=false
local search_target=nil
local settings_tab="General"
local settings_tab_names={"General","Layout","Colors","Config"}
local function settings_section_for(page_id,handle)
    local item=handle and items.at(handle)
    if page_id==items.joaat("Settings") then
        if not item then return settings_tab end
        if item.name=="Theme" or item.name=="Choose Theme" or item.name=="Reload Lua Theme" or
           item.name=="Reset Theme" or item.name=="Open Themes Folder" then return "Config" end
        if item.name=="Auto UI Scale" or item.name=="UI Scale" or
           item.name=="Overlays/Panels Scale" or item.name=="Streamer Mode" then return "General" end
        return "Layout"
    end
    if page_id==items.joaat("Load Theme") then return "Config" end
    if page_id==items.joaat("Streamer Mode") then return "General" end
    if page_id==items.joaat("Nenyoo Appearance") then
        return (not item or item.type==item_type.color) and "Colors" or "Layout"
    end
    for _,name in ipairs({"UI Layout","Typography","Motion","Theme Settings"}) do
        if page_id==items.joaat(name) then return "Layout" end
    end
end
local preview_recenter=false
local search_popup_bounds=nil
local search_popup_click=false

local function setting(name)
    local value=menu.get_setting(name)
    return type(value)=="table" and value or nil
end
local last_config=""
local function sync_settings()
    for _,entry in ipairs(color_settings) do
        local color=setting(entry[1])
        if color then palette[entry[3]]={color.r,color.g,color.b,color.a} end
        if entry[4] and theme.set_palette_color then theme.set_palette_color(entry[4],table.unpack(palette[entry[3]])) end
    end
    for _,entry in ipairs(layout_sliders) do
        local item=setting(entry[1])
        ui_options[entry[2]]=math.max(entry[4],math.min(entry[5],math.floor((item and item.f_val or entry[3])+.5)))
    end
    for _,entry in ipairs(navigation_toggles) do
        local item=setting(entry[1]); ui_options[entry[2]]=not item or item.on
    end
    local sidebar,radius=setting("Sidebar Width"),setting("Corner Radius")
    local title,item,small=setting("Title Size"),setting("Item Size"),setting("Small Size")
    local value,desc,label,tagline,tiny=setting("Value Size"),setting("Description Size"),setting("Section Label Size"),setting("Tagline Size"),setting("Overlay Text Size")
    local enabled_setting,speed_setting=setting("Animations Enabled"),setting("Motion Speed")
    local sv=sidebar and sidebar.f_val or 170
    local rv=radius and radius.f_val or 3
    if theme.set_panel_radius then theme.set_panel_radius(rv) end
    local tv=title and title.f_val or 20
    local iv=item and item.f_val or 11
    local sm=small and small.f_val or 9
    local vv=value and value.f_val or 11
    local dv=desc and desc.f_val or 9
    local lv=label and label.f_val or 10
    local gv=tagline and tagline.f_val or 9
    local nv=tiny and tiny.f_val or 8
    motion_enabled=not enabled_setting or enabled_setting.on
    motion_speed=speed_setting and speed_setting.f_val or 1
    if ui.set_motion then ui.set_motion(motion_enabled,motion_speed) end
    local ar,ag,ab=palette.accent[1],palette.accent[2],palette.accent[3]
    palette.accentHi={math.floor(ar+(255-ar)*.18),math.floor(ag+(255-ag)*.18),math.floor(ab+(255-ab)*.18),palette.accent[4]}
    palette.accentLo={math.floor(ar*.74),math.floor(ag*.68),math.floor(ab*.96),palette.accent[4]}
    theme.set_accent_palette(ar,ag,ab,palette.accent[4])
    theme.set_body_bg(table.unpack(palette.bg)); theme.set_menu_bg(table.unpack(palette.panel))
    text.set_size(font.title,tv); text.set_size(font.item,iv)
    text.set_size(font.value,vv); text.set_size(font.small,sm)
    text.set_size(font.breadcrumb,10); text.set_size(font.desc,dv)
    text.set_size(font.label,lv); text.set_size(font.tagline,gv); text.set_size(font.tiny,nv)
    text.set_weight(font.title,600); text.set_weight(font.item,400)
    text.set_size(logo_font,tv); text.set_weight(logo_font,300)
    text.set_weight(font.breadcrumb,600); text.set_weight(font.desc,400)
    text.set_weight(font.label,500); text.set_weight(font.tagline,500)
    text.set_weight(font.value,400); text.set_weight(font.small,400); text.set_weight(font.tiny,600)
    local encoded=string.format(
        "appearance_revision=%s\r\ndesign_revision=midnight_1\r\npalette_revision=lavender_1\r\nsidebar_layout=3\r\nsidebar=%.0f\r\nradius=%.0f\r\ntitle_size=%.0f\r\nitem_size=%.0f\r\nsmall_size=%.0f\r\nvalue_size=%.0f\r\ndesc_size=%.0f\r\nlabel_size=%.0f\r\ntagline_size=%.0f\r\ntiny_size=%.0f\r\nmotion_enabled=%d\r\nmotion_speed=%.2f\r\n",
        appearance_revision,
        sv,rv,tv,iv,sm,vv,dv,lv,gv,nv,motion_enabled and 1 or 0,motion_speed)
    local parts={encoded}
    for _,entry in ipairs(color_settings) do
        parts[#parts+1]=entry[2].."="..table.concat(palette[entry[3]],",").."\r\n"
    end
    for _,entry in ipairs(layout_sliders) do parts[#parts+1]=entry[2].."="..ui_options[entry[2]].."\r\n" end
    for _,entry in ipairs(navigation_toggles) do parts[#parts+1]=entry[2].."="..(ui_options[entry[2]] and "1" or "0").."\r\n" end
    encoded=table.concat(parts)
    if encoded~=last_config then last_config=encoded; file.write("theme_settings.ini",encoded) end
    return sv,rv
end

local function reset_appearance()
    for _,entry in ipairs(color_settings) do
        local handle=items.get("Nenyoo Appearance",entry[1])
        if handle then items.set_color(handle,table.unpack(entry.default)) end
    end
    local sliders={{"Nenyoo Appearance","Sidebar Width",170},{"Nenyoo Appearance","Corner Radius",3},
        {"Motion","Motion Speed",1},{"Typography","Title Size",20},{"Typography","Item Size",11},
        {"Typography","Small Size",9},{"Typography","Value Size",10},{"Typography","Description Size",9},
        {"Typography","Section Label Size",10},{"Typography","Tagline Size",9},{"Typography","Overlay Text Size",8}}
    for _,entry in ipairs(layout_sliders) do sliders[#sliders+1]={"UI Layout",entry[1],entry[3]} end
    for _,entry in ipairs(sliders) do
        local handle=items.get(entry[1],entry[2]); if handle then items.set_f_val(handle,entry[3]) end
    end
    local toggles={{"Motion","Animations Enabled",true}}
    for _,entry in ipairs(navigation_toggles) do toggles[#toggles+1]={"UI Layout",entry[1],entry[3]} end
    for _,entry in ipairs(toggles) do
        local handle=items.get(entry[1],entry[2]); local item=handle and items.at(handle)
        if item and item.on~=entry[3] then items.toggle(handle) end
    end
    sync_settings()
end

local function rgba(c,a) return c[1],c[2],c[3],a or c[4] end
local function txt(face,x,y,color,value)
    text.draw(face,x,y,color[1],color[2],color[3],color[4],tostring(value or ""))
end
local function txt_wrap(face,x,y,color,value,max_w)
    text.draw(face,x,y,color[1],color[2],color[3],color[4],tostring(value or ""),max_w)
end
local function txt_ellipsis(face,x,y,color,value,max_w)
    text.draw_ellipsis(face,x,y,color[1],color[2],color[3],color[4],tostring(value or ""),max_w)
end
local function inside(x,y,w,h)
    local mx,my=input.mouse_x(),input.mouse_y()
    return mx>=x and mx<=x+w and my>=y and my<=y+h
end
local function clicked(x,y,w,h) return inside(x,y,w,h) and input.mouse_clicked(0) end
local motion_values={}
local function motion_to(key,target,speed,initial)
    if not motion_enabled then motion_values[key]=target; return target end
    local value=motion_values[key]
    if value==nil then value=initial~=nil and initial or target end
    local ease=1-math.exp(-(speed or 16)*motion_speed*math.min(.1,ctx.delta()))
    value=value+(target-value)*ease
    if math.abs(target-value)<.0005 then value=target end
    motion_values[key]=value
    return value
end
local function motion_reset(key,value) motion_values[key]=value end
local function smooth_scroll(id,current,maximum,hovered,step,speed)
    step=step*ui_options.scroll_speed/70
    if motion_enabled then
        return ui.scroll_smooth(id,current,maximum,hovered,step,speed*motion_speed)
    end
    if hovered then current=current-input.mouse_wheel()*step end
    return math.max(0,math.min(maximum,current))
end
local function mix_color(a,b,t)
    t=math.max(0,math.min(1,t))
    return {
        math.floor(a[1]+(b[1]-a[1])*t+.5),math.floor(a[2]+(b[2]-a[2])*t+.5),
        math.floor(a[3]+(b[3]-a[3])*t+.5),math.floor(a[4]+(b[4]-a[4])*t+.5)
    }
end
local transition={stage="idle",phase=1,pending=nil,serial=0}
local function perform_navigation(request)
    if not request then return end
    if ui.cancel_menu_keybind then
        ui.cancel_menu_keybind(0xD001); ui.cancel_menu_keybind(0xD003)
        ui.cancel_menu_keybind(aim_keybind_id)
    end
    if request.kind=="settings" then
        settings_tab=request.target
        menu.replace_page(items.joaat("Settings"))
    elseif request.kind=="tab" then menu.switch_tab(request.target)
    elseif request.kind=="combat" then combat_tab=request.target
    elseif request.kind=="visuals" or request.kind=="vfx" then
        local root=request.kind=="vfx" and "VFX's" or "Visuals"
        visual_tabs[root]=request.target
        if menu.page_id()~=items.joaat(root) then menu.replace_page(items.joaat(root)) end
    elseif request.kind=="search" then
        local target=request.target
        search_target=target.handle and {
            handle=target.handle,page_id=target.page_id,
            pending=true,expires=ctx.time()+3
        } or nil
        local section=settings_section_for(target.page_id,target.handle)
        if section then settings_tab=section; menu.navigate(items.joaat("Settings"))
        else menu.navigate(target.page_id) end
    elseif request.kind=="page" then menu.navigate(request.target) end
end
local function request_navigation(kind,target)
    if not motion_enabled then perform_navigation({kind=kind,target=target}); return end
    transition.pending={kind=kind,target=target}
    transition.stage="out"
    transition.phase=0
    transition.serial=transition.serial+1
end
local function ease_out_expo(t) if t>=1 then return 1 end; return 1-2^(-10*t) end

local function update_transition()
    if not motion_enabled then
        perform_navigation(transition.pending)
        transition.pending=nil; transition.stage="idle"; transition.phase=1
        return 1,0,1
    end
    local dt=math.min(.1,ctx.delta())*motion_speed
    if transition.stage=="out" then
        -- Skip the out fade — navigate immediately, let the new content fade
        -- in over the old. Feels like a smooth crossfade rather than a
        -- flash-to-nothing-then-fade-back.
        perform_navigation(transition.pending)
        transition.pending=nil
        transition.stage="in"
        transition.phase=0
        return 1,0,0
    elseif transition.stage=="in" then
        -- Single long ease-out-expo fade — decelerates deep into the tail so
        -- there's no visible snap at the end.
        transition.phase=math.min(1,transition.phase+dt/.55)
        local eased=ease_out_expo(transition.phase)
        if transition.phase>=1 then transition.stage="idle" end
        return eased,0,eased
    end
    return 1,0,1
end
local content_alpha,content_offset,content_progress=1,0,1
local function card_entry_offset(index)
    -- No cascade offset — cards fade in together as one calm crossfade.
    return 0
end
local function fill(x,y,w,h,color,radius,alpha)
    draw.rect(x,y,x+w,y+h,color[1],color[2],color[3],alpha or color[4],radius or 0)
end
local function draw_window_surfaces(x,y,w,h,sidebar,radius)
    local function same(a,b)
        for i=1,4 do if a[i]~=b[i] then return false end end
        return true
    end
    if same(palette.bg,palette.sidebar) and same(palette.bg,palette.header) then
        fill(x,y,w,h,palette.bg,radius)
        return
    end
    -- Each region gets a single translucent fill, with one shared outer shape.
    -- This also keeps independent sidebar/header alpha edits from stacking on bg.
    local regions={
        {x,y,x+sidebar,y+h,palette.sidebar},
        {x+sidebar,y,x+w,y+62,palette.header},
        {x+sidebar,y+62,x+w,y+h,palette.bg}
    }
    for _,region in ipairs(regions) do
        draw.push_clip(region[1],region[2],region[3],region[4])
        fill(x,y,w,h,region[5],radius)
        draw.pop_clip()
    end
end
local function outline(x,y,w,h,color,radius,thickness)
    draw.rect_outline(x,y,x+w,y+h,color[1],color[2],color[3],color[4],radius or 0,thickness or 1)
end
local function line(x1,y1,x2,y2,color,thickness)
    draw.line(x1,y1,x2,y2,color[1],color[2],color[3],color[4],thickness or 1)
end
local function button(x,y,w,h,label,primary,radius)
    local hover=inside(x,y,w,h)
    fill(x,y,w,h,hover and palette.side or palette.input,2)
    local tw=text.width(font.value,label)
    txt_ellipsis(font.value,x+math.max(6,(w-tw)*.5),y+(h-text.height(font.value))*.5,
        primary and palette.accentHi or palette.text,label,w-12)
    return clicked(x,y,w,h)
end

local function panel(x,y,w,h,title,subtitle,radius)
    return ui.panel_values(x,y,w,h,title,subtitle or "")
end
-- Loader-style edge fades: subtle gradient at the top/bottom of a scrollable
-- viewport, showing when there is more content in that direction.
local function scroll_fades(x,y,w,h,current,max_scroll,depth,corner_radius)
    depth=depth or 34
    local br,bgc,bb=palette.bg[1],palette.bg[2],palette.bg[3]
    local ta=math.min(1,current/30)
    local ba=math.min(1,math.max(0,(max_scroll-current)/30))
    if ta>0.01 then
        local op=math.floor(ta*255)
        draw.rect_gradient(x,y,x+w,y+depth,
            br,bgc,bb,op, br,bgc,bb,op,
            br,bgc,bb,0,  br,bgc,bb,0)
    end
    if ba>0.01 then
        local op=math.floor(ba*255)
        -- A square gradient would paint over the window's rounded bottom
        -- corners whenever there is more content below the viewport.
        local corner=math.min(math.max(0,math.ceil(corner_radius or 0)),depth-1)
        if corner==0 then
            draw.rect_gradient(x,y+h-depth,x+w,y+h,
                br,bgc,bb,0, br,bgc,bb,0,
                br,bgc,bb,op, br,bgc,bb,op)
        else
            local upper_alpha=math.floor(op*(depth-corner)/depth)
            draw.rect_gradient(x,y+h-depth,x+w,y+h-corner,
                br,bgc,bb,0, br,bgc,bb,0,
                br,bgc,bb,upper_alpha, br,bgc,bb,upper_alpha)
            for row=0,corner-1 do
                local inset=corner-math.sqrt(corner*corner-(row+.5)*(row+.5))
                local alpha=math.floor(op*(depth-corner+row+1)/depth)
                draw.rect(x+inset,y+h-corner+row,x+w-inset,y+h-corner+row+1,
                    br,bgc,bb,alpha)
            end
        end
    end
end

local function nav_icon(name,x,y,color)
    local function stroke(x1,y1,x2,y2) line(x1,y1,x2,y2,color,1.6) end
    if name=="Home" then
        stroke(x-8,y-1,x,y-7); stroke(x,y-7,x+8,y-1)
        stroke(x-6,y-2,x-6,y+7); stroke(x+6,y-2,x+6,y+7)
        stroke(x-6,y+7,x+6,y+7); stroke(x-2,y+7,x-2,y+2)
        stroke(x-2,y+2,x+2,y+2); stroke(x+2,y+2,x+2,y+7)
    elseif name=="Combat" then
        draw.circle_outline(x,y,6,color[1],color[2],color[3],color[4],1.6)
        draw.circle(x,y,2,rgba(color))
        stroke(x-9,y,x-6,y); stroke(x+6,y,x+9,y)
        stroke(x,y-9,x,y-6); stroke(x,y+6,x,y+9)
    elseif name=="Visuals" then
        stroke(x-9,y,x-4,y-5); stroke(x-4,y-5,x+4,y-5)
        stroke(x+4,y-5,x+9,y); stroke(x+9,y,x+4,y+5)
        stroke(x+4,y+5,x-4,y+5); stroke(x-4,y+5,x-9,y)
        draw.circle_outline(x,y,2.6,color[1],color[2],color[3],color[4],1.5)
    elseif name=="VFX's" then
        stroke(x-3,y-8,x-1,y-2); stroke(x-1,y-2,x+5,y)
        stroke(x+5,y,x-1,y+2); stroke(x-1,y+2,x-3,y+8)
        stroke(x-3,y+8,x-5,y+2); stroke(x-5,y+2,x-11,y)
        stroke(x-11,y,x-5,y-2); stroke(x-5,y-2,x-3,y-8)
        stroke(x+5,y-7,x+9,y-7); stroke(x+7,y-9,x+7,y-5)
    elseif name=="Misc" then
        stroke(x-8,y-6,x+8,y-6); stroke(x-8,y,x+8,y)
        stroke(x-8,y+6,x+8,y+6)
        draw.circle(x-3,y-6,2,rgba(color))
        draw.circle(x+4,y,2,rgba(color))
        draw.circle(x-1,y+6,2,rgba(color))
    elseif name=="Settings" then
        draw.circle_outline(x,y,5.5,color[1],color[2],color[3],color[4],1.6)
        draw.circle_outline(x,y,2,color[1],color[2],color[3],color[4],1.4)
        for i=0,7 do
            local a=i*math.pi/4; local c,s=math.cos(a),math.sin(a)
            stroke(x+c*6.5,y+s*6.5,x+c*9,y+s*9)
        end
    elseif name=="Lua Executor" then
        stroke(x-4,y-6,x-9,y); stroke(x-9,y,x-4,y+6)
        stroke(x+4,y-6,x+9,y); stroke(x+9,y,x+4,y+6)
        stroke(x+2,y-8,x-2,y+8)
    elseif name=="Events" then
        stroke(x-5,y-4,x+5,y-4)
        stroke(x-5,y-4,x,y+6); stroke(x+5,y-4,x,y+6)
        draw.circle(x-6,y-5,2,rgba(color))
        draw.circle(x+6,y-5,2,rgba(color))
        draw.circle(x,y+7,2,rgba(color))
    else
        draw.circle_outline(x,y,6,color[1],color[2],color[3],color[4],1.6)
    end
end



local function flag(code,x,y,w,h)
    ui.language_flag(code,x,y,w,h)
end

local language_open=false

local scroll,search,search_focus={},"",false
local search_expanded=false
local search_popup_query=""
local quick_open,quick_section,quick_anchor,quick_color=false,nil,nil,false
local quick_scroll=0
local slider_visual,slider_drag={},nil
local function focus_scroll(page_id,center,viewport,max_scroll)
    if search_target and search_target.pending and search_target.page_id==page_id then
        scroll[page_id]=math.max(0,math.min(max_scroll,center-viewport*.5))
        search_target.pending=false
    end
end
local option_visual={}
local option_open,option_anchor,option_seen=nil,nil,false
local color_open,color_anchor,color_seen=nil,nil,false
local function color_popup_rect(anchor)
    local screen_w,screen_h=ctx.screen_w()/ctx.ui_scale(),ctx.screen_h()/ctx.ui_scale()
    local width,height=math.min(280,screen_w-16),math.min(330,screen_h-16)
    local x=math.max(8,math.min(screen_w-width-8,anchor.x+anchor.w-width))
    local y=anchor.y+anchor.h+4
    if y+height>screen_h-8 then y=anchor.y-height-4 end
    return x,math.max(8,math.min(screen_h-height-8,y)),width,height
end
local color_pointer_capture=false
local function close_color_popup()
    color_open,color_anchor=nil,nil
    color_pointer_capture=false
    ui.close_color_picker()
end
local function color_swatch(handle,x,y,w,h)
    if not handle then return end
    if color_open==handle then
        color_seen=true
        color_anchor={x=x,y=y,w=w,h=h}
    end
    if clicked(x,y,w,h) then
        if color_open==handle then close_color_popup()
        else
            option_open,option_anchor=nil,nil
            color_open=handle
            color_anchor={x=x,y=y,w=w,h=h}
            color_seen=true
        end
        input.consume_mouse_click()
    end
end
local function color_popup_input()
    if not input.mouse_down(0) then color_pointer_capture=false end
    if not color_open or not color_anchor then return false end
    if input.key_just_pressed(VK.ESCAPE) then
        close_color_popup()
        color_pointer_capture=false
        return false
    end
    local x,y,w,h=color_popup_rect(color_anchor)
    local over=inside(x,y,w,h)
    if input.mouse_clicked(0) then
        if over then color_pointer_capture=true
        elseif not inside(color_anchor.x,color_anchor.y,color_anchor.w,color_anchor.h) then
            close_color_popup()
            return false
        end
    end
    return over or color_pointer_capture
end
local function draw_color_popup(radius)
    if not color_open or not color_anchor then return end
    local item=items.at(color_open)
    if not item then close_color_popup(); return end
    local x,y,w,h=color_popup_rect(color_anchor)
    -- The editor must remain usable when the panel color itself is transparent.
    fill(x,y,w,h,{palette.panel[1],palette.panel[2],palette.panel[3],255},radius)
    outline(x,y,w,h,palette.border,radius)
    txt(font.item,x+12,y+10,palette.text,item.name)
    local r,g,b,a,changed=ui.color_picker(0xC500+color_open,x+12,y+34,w-24,item.r,item.g,item.b,item.a,h-46)
    if changed then
        items.set_color(color_open,r,g,b,a)
        local accent_handle=items.get("Nenyoo Appearance","Accent")
        if color_open==accent_handle then
            local nen_handle=items.get("Nenyoo Appearance","Nen Color")
            if nen_handle then items.set_color(nen_handle,r,g,b,a) end
            palette.logoNen={r,g,b,a}
        end
    end
end
local function option_popup_rect(anchor,count)
    local width=math.max(150,anchor.w)
    local height=count*30+8
    local screen_w,screen_h=ctx.screen_w()/ctx.ui_scale(),ctx.screen_h()/ctx.ui_scale()
    local x=math.max(8,math.min(screen_w-width-8,anchor.x+anchor.w-width))
    local y=anchor.y+anchor.h+4
    if y+height>screen_h-8 then y=anchor.y-height-4 end
    return x,math.max(8,y),width,height
end
local function option_popup_input()
    if not option_open or not option_anchor or not input.mouse_clicked(0) then return end
    local values=items.values(option_open)
    local x,y,w,h=option_popup_rect(option_anchor,#values)
    if inside(x,y,w,h) then
        local index=math.floor((input.mouse_y()-y-4)/30)+1
        if index>=1 and index<=#values then items.set_value_index(option_open,index-1) end
        option_open,option_anchor=nil,nil
        input.consume_mouse_click()
    elseif not inside(option_anchor.x,option_anchor.y,option_anchor.w,option_anchor.h) then
        option_open,option_anchor=nil,nil
    end
end
local function draw_option_popup(radius)
    if not option_open or not option_anchor then return end
    local values=items.values(option_open)
    if #values==0 then option_open,option_anchor=nil,nil; return end
    local x,y,w,h=option_popup_rect(option_anchor,#values)
    fill(x+2,y+5,w,h,{0,0,0,125},radius)
    fill(x,y,w,h,palette.panel,radius)
    outline(x,y,w,h,palette.border,radius)
    local item=items.at(option_open)
    for i,value in ipairs(values) do
        local ry=y+4+(i-1)*30
        local hovered=inside(x+4,ry,w-8,30)
        local active=item and item.value_index==i-1
        if hovered then fill(x+4,ry,w-8,30,palette.side,5) end
        if active then fill(x+5,ry+7,3,16,palette.accent,1) end
        txt_ellipsis(font.value,x+15,ry+8,active and palette.accentHi or palette.text,value,w-38)
        if active then txt(font.value,x+w-20,ry+8,palette.accentHi,"✓") end
    end
end
local combat_definitions={
    {name="Lock-on Aimbot",
     left={{title="Aim",first=1,last=5},{title="Target Selection",first=6,last=10},{title="Lock Behavior",first=11,last=13}},
     right={{title="Prediction",first=14,last=15},{title="Response",first=16,last=20},{title="Friends & Overlay",first=21,last=24}}},
    {name="Silent Aim",
     left={{title="Aim",first=1,last=5}},
     right={{title="Shot Behavior",first=6,last=9}}},
    {name="Magic Bullet",
     left={{title="Aim",first=1,last=3}},
     right={{title="Targeting",first=4,last=5}}}
}
local function combat_tabs_list()
    local tabs={}
    local selected_available=false
    for index,tab in ipairs(combat_definitions) do
        local link=items.get("Combat",tab.name)
        if link and items.submenu_page_id(link)~=0 then
            tab.index=index
            tabs[#tabs+1]=tab
            if combat_tab==index then selected_available=true end
        end
    end
    if not selected_available then combat_tab=tabs[1] and tabs[1].index or 1 end
    return tabs
end
local visuals_definition={
    left={
        {title="Ped Display",items={"Enable Ped ESP","ESP Distance","Color Mode","Show Friends","Friend Color","Off-screen Indicators"}},
        {title="Boxes",items={"Enable Boxes","Box Style","Box Color","Gradient End","Rainbow Speed","Box Thickness"}},
        {title="Labels",items={"Model Names","Weapon Names","Distance Text","Vitals Text"}}
    },
    right={
        {title="Markers & Bars",items={"Basic Skeleton","Head Dot","Marker Color","Health Bars","Armor Bars"}},
        {title="Snaplines",items={"Enable Snaplines","Snapline Origin","Snapline End","Snapline Color","Snapline Thickness"}},
        {title="Vehicles",items={"Enable Vehicle ESP","Vehicle Health","Vehicle Names","Vehicle Distance"}},
        {title="Objects",items={"Enable Object ESP","Object Names","Object Distance"}}
    }
}
local misc_definition={
    left={{title="FOV Editor",items={"Override FOV","Field of View"}}},
    right={}
}
local vfx_definitions={
    Sky={
        left={{title="Sky Override",items={"Sky Intensity","Intensity"}},
              {title="Field Colour Animation",items={"Color Rainbow Speed"}}},
        right={{title="Rainbow Sky",items={"Rainbow Sky","Rainbow Sky Speed","Rainbow Sky Alpha"}}}
    },
    ["Post Processing"]={
        left={{title="Lighting & Reflection",items={"Shadow Light","Shadow Light Strength","Reflection","Reflection Strength","Gamma","Gamma Strength"}}},
        right={{title="Image Effects",items={"Blur","Blur Strength","Blur 2","Blur 2 Strength","Saturation","Saturation Strength"}}}
    },
    Weather={
        left={{title="Rain & Snow",items={"Rainstorm","Thunder","Snow Light","Snow Heavy","Blizzard"}}},
        right={{title="Ambient Effects",items={"Underwater","Lake Fog","Woodland Pollen","Woodland Firefly","Wetland Flies"}}}
    },
    Lightning={
        left={{title="Strike Control",items={"Enabled","Force Lightning","Strike Frequency"}}},
        right={{title="Lightning Colours",items={"Main Color","Corona Color","Rainbow","Rainbow Speed"}}}
    },
    Lighting={
        left={{title="Weather Lighting",items={"Lightning","Fog","Traffic Signals"}}},
        right={{title="World Lighting",items={"Ped Light","Street Light","Scene Lights"}}}
    },
    Fog={
        left={{title="Fog Colour",items={"Enabled","Color"}}},
        right={{title="Animation",items={"Rainbow","Rainbow Speed"}}}
    },
    ["Ped Light"]={
        left={{title="Ped Light Colour",items={"Enabled","Color"}}},
        right={{title="Animation",items={"Rainbow","Rainbow Speed"}}}
    },
    Water={
        left={{title="Ocean",items={"Ocean Height","Height","Transparent Ocean"}}},
        right={{title="Wetness",items={"Puddles","Puddle Amount"}}}
    },
    ["Water Color"]={
        left={{title="Directional Water",items={"Enabled","Override Directional","Directional Color","Directional Intensity"}}},
        right={{title="Ambient Water",items={"Override Ambient","Ambient Color","Ambient Intensity"}}}
    },
    Liquid={
        left={{title="Petrol Duration",items={"Petrol VFX","Foot Duration","Wheel Duration"}}},
        right={{title="Petrol Appearance",items={"Foot Lifetime","Wheel Lifetime","Petrol Color","Rainbow","Rainbow Speed"}}}
    },
    Particles={
        left={{title="Particle Tint",items={"Enabled","Color"}}},
        right={{title="Animation",items={"Rainbow","Rainbow Speed"}}}
    },
    Fire={
        left={{title="Fire Tint",items={"Enabled","Color","Rainbow","Rainbow Speed"}}},
        right={{title="Fire Types",items={"Petrol Tank Fires","Vehicle Wreck Fires","Peds On Fire","Environmental Fires"}}}
    },
    Decals={left={},right={}},
    Footprints={
        left={{title="Footprint Colour",items={"Enabled","Color"}}},
        right={{title="Animation",items={"Rainbow","Rainbow Speed"}}}
    },
    ["Bullet Impact"]={
        left={{title="Impact Colour",items={"Enabled","Color"}}},
        right={{title="Animation",items={"Rainbow","Rainbow Speed"}}}
    },
    ["Vehicle Lighting"]={
        left={{title="Neon Lighting",items={"Neon"}}},
        right={{title="Vehicle Lights",items={"Vehicle Lights"}}}
    },
    Neon={
        left={{title="Neon Glow",items={"Enabled","Intensity","Radius","Falloff Exponent"}}},
        right={{title="Neon Shape",items={"Capsule Sides","Capsule Front/Back","Clip Plane Height","Bike Clip Height"}}}
    },
    ["Vehicle Lights"]={
        left={{title="Cabin & Plate",items={"Enabled","Interior Light","Plate Light"}}},
        right={{title="Dash & Door",items={"Dash Light","Door Light","Rainbow","Rainbow Speed"}}}
    },
    ["Traffic Signals"]={
        left={{title="Signal Colours",items={"Enabled","Red","Amber","Green","Walk","Don't Walk","Rainbow","Rainbow Speed"}}},
        right={{title="Fade Distances",items={"Far Fade Start","Far Fade End","Near Fade Start","Near Fade End"}}}
    },
    ["Street Light"]={
        left={{title="Light Colour",items={"Enabled","Mode","Hue","Saturation","Intensity","Custom Color"}}},
        right={{title="Rainbow Motion",items={"Frequency","Update Delay","Update Value","Min Value","Max Value"}}}
    },
    ["Scene Lights"]={
        left={{title="Light Colour",items={"Enabled","Mode","Hue","Saturation","Intensity","Custom Color"}}},
        right={{title="Rainbow Motion",items={"Frequency","Update Delay","Update Value","Min Value","Max Value"}}}
    },
    weather_effect={
        left={{title="Particle Motion",items={"Enabled","Velocity","Gravity","Box Size X","Box Size Y","Box Size Z","Life Min","Life Max"}}},
        right={{title="Particle Appearance",items={"Size Min","Size Max","Edge Softness","Local Lights","Particle Color %","Color","Luminance","Rainbow","Rainbow Speed"}}}
    }
}
local weather_effect_names={
    Rainstorm=true,Thunder=true,["Snow Light"]=true,["Snow Heavy"]=true,Blizzard=true,
    Underwater=true,["Lake Fog"]=true,["Woodland Pollen"]=true,
    ["Woodland Firefly"]=true,["Wetland Flies"]=true
}
local sky_child_names={
    ["Sky Colors"]=true,Sun=true,Moon=true,Clouds=true,Atmosphere=true
}
local lighting_child_names={Lightning=true,Fog=true,["Ped Light"]=true,
    ["Traffic Signals"]=true,["Street Light"]=true,["Scene Lights"]=true}
local decal_child_names={Footprints=true,["Bullet Impact"]=true}
local vehicle_lighting_child_names={Neon=true,["Vehicle Lights"]=true}
local water_child_names={["Water Color"]=true}
local function sky_child_definition(page_id,page_name)
    local blocks={}
    for _,handle in ipairs(items.page_items(page_id)) do
        local item=items.at(handle)
        if item then
            if item.name:sub(1,9)=="Override " then blocks[#blocks+1]={} end
            if #blocks>0 then blocks[#blocks][#blocks[#blocks]+1]=item.name end
        end
    end
    local left,right={},{}
    local split=math.ceil(#blocks*.5)
    for index,block in ipairs(blocks) do
        local target=index<=split and left or right
        for _,name in ipairs(block) do target[#target+1]=name end
    end
    return {left={{title=page_name.." Colours",items=left}},
            right={{title=page_name.." Properties",items=right}}}
end
local function visuals_tabs_list(root)
    local tabs={}
    for _,handle in ipairs(items.page_items(items.joaat(root or "Visuals"))) do
        local item=items.at(handle)
        if item and item.type==item_type.sub_menu then
            tabs[#tabs+1]={name=item.name,id=items.submenu_page_id(handle)}
        end
    end
    return tabs
end
-- Keep root selection and search results in the same category, including
-- effects exposed as flattened cards from a nested native page.
local function visual_section_for(page_id,page_name)
    for _,root in ipairs({"Visuals","VFX's"}) do
        if page_id==items.joaat(root) then return root end
        for _,tab in ipairs(visuals_tabs_list(root)) do
            if page_id==tab.id then return root,tab.name end
        end
    end
    local parent
    if weather_effect_names[page_name] then parent="Weather"
    elseif sky_child_names[page_name] then parent="Sky"
    elseif lighting_child_names[page_name] then parent="Lighting"
    elseif decal_child_names[page_name] then parent="Decals"
    elseif vehicle_lighting_child_names[page_name] then parent="Vehicle Lighting"
    elseif water_child_names[page_name] then parent="Water" end
    if parent then return "VFX's",parent end
end
local function control_height(handle)
    local item=items.at(handle)
    if not item then return 0 end
    if item.type==item_type.keybind then return 34+ui_options.row_spacing end
    if item.type==item_type.slider then return 42+ui_options.row_spacing end
    if item.type==item_type.loop_option or item.type==item_type.array_option then return 54+ui_options.row_spacing end
    if item.type==item_type.action or item.type==item_type.sub_menu or item.type==item_type.selected_tick then return 32+ui_options.row_spacing end
    return 24+ui_options.row_spacing
end
local function slider_control(id,x,y,w,value,vmin,vmax,format,label,disabled)
    local span=math.max(.0001,vmax-vmin)
    local target=math.max(0,math.min(1,(value-vmin)/span))
    local sx,sy,sw=x+4,y+28,w-8
    local hot=not disabled and inside(sx-4,sy-8,sw+8,16)
    if hot and input.mouse_clicked(0) then slider_drag=id end
    local changed=false
    if slider_drag==id and input.mouse_down(0) and not disabled then
        target=math.max(0,math.min(1,(input.mouse_x()-sx)/sw))
        local next_value=vmin+target*span
        changed=next_value~=value; value=next_value
    end
    if slider_drag==id and not input.mouse_down(0) then slider_drag=nil end
    local shown=motion_to("slider_value_"..id,target,24,target)
    local value_text=string.format(format or "%.2f",value)
    local value_w=text.width(font.value,value_text)
    txt_ellipsis(font.item,x,y+2,disabled and palette.faint or palette.text,label,w-value_w-12)
    txt(font.value,x+w-value_w,y+2,palette.dim,value_text)
    fill(sx,sy-1.5,sw,3,palette.input,1)
    fill(sx,sy-1.5,sw*shown,3,palette.accent,1)
    draw.circle(sx+sw*shown,sy,4.2,rgba(palette.panel))
    local knob=disabled and palette.faint or palette.accentHi
    draw.circle_outline(sx+sw*shown,sy,4.2,knob[1],knob[2],knob[3],knob[4],1.4)
    return value,changed
end
local function row(handle,x,y,w,h,radius,label)
    local item=items.at(handle); if not item then return end
    local color_blocked=false
    if color_open and color_anchor then
        local px,py,pw,ph=color_popup_rect(color_anchor)
        color_blocked=inside(px,py,pw,ph)
    end
    local hover=inside(x,y,w,h) and not color_blocked and not item.disabled
    local name=label or item.name
    local name_color=item.disabled and palette.faint or palette.text
    if search_target and search_target.handle==handle and ctx.time()<search_target.expires then
        fill(x-5,y+2,2,math.max(10,h-4),palette.accent,1)
    end
    if item.type==item_type.toggle or item.type==item_type.float_toggle or
       item.type==item_type.int_toggle or item.type==item_type.array_toggle then
        local sy=y+(h-14)*.5
        local on=motion_to("toggle_on_"..handle,item.on and 1 or 0,22,item.on and 1 or 0)
        fill(x,sy,14,14,mix_color(palette.input,palette.accent,on),2)
        if on>.01 then
            local ink={12,28,34,math.floor(255*on)}
            line(x+3,sy+7,x+6,sy+10,ink,1.2)
            line(x+6,sy+10,x+11,sy+4,ink,1.2)
        end
        txt_ellipsis(font.item,x+19,y+(h-text.height(font.item))*.5,name_color,name,w-19)
        if hover and input.mouse_clicked(0) then items.toggle(handle) end
    elseif item.type==item_type.slider then
        local value,changed=slider_control(handle,x,y,w,item.f_val,item.f_min,item.f_max,"%.2f",name,item.disabled or color_blocked)
        if changed then items.set_f_val(handle,value) end
    elseif item.type==item_type.keybind then
        aim_keybind_seen=true
        ui.row_aim_keybind_values(aim_keybind_id,x,y,w,name)
    elseif item.type==item_type.loop_option or item.type==item_type.array_option then
        txt_ellipsis(font.item,x,y+2,name_color,name,w)
        local sy=y+20
        fill(x,sy,w,27,palette.input,2)
        txt_ellipsis(font.value,x+10,sy+(27-text.height(font.value))*.5,palette.dim,item.current_value or "",w-32)
        line(x+w-16,sy+11,x+w-12,sy+15,palette.faint,1.2)
        line(x+w-12,sy+15,x+w-8,sy+11,palette.faint,1.2)
        if option_open==handle then option_seen=true; option_anchor={x=x,y=sy,w=w,h=27} end
        if hover and clicked(x,sy,w,27) and item.value_count>0 then
            if option_open==handle then option_open,option_anchor=nil,nil
            else close_color_popup(); option_open=handle; option_anchor={x=x,y=sy,w=w,h=27}; option_seen=true end
        end
    elseif item.type==item_type.color then
        txt_ellipsis(font.item,x,y+(h-text.height(font.item))*.5,name_color,name,w-26)
        local sx,sy=x+w-14,y+(h-14)*.5
        fill(sx,sy,14,14,{item.r,item.g,item.b,item.a},2)
        color_swatch(handle,sx,sy,14,14)
    elseif item.type==item_type.action or item.type==item_type.sub_menu or item.type==item_type.selected_tick then
        fill(x,y,w,h-4,hover and palette.side or palette.input,2)
        local tw=text.width(font.item,name)
        txt_ellipsis(font.item,x+math.max(8,(w-tw)*.5),y+(h-4-text.height(font.item))*.5,name_color,name,w-16)
        if item.type==item_type.sub_menu then txt(font.small,x+w-14,y+8,palette.dim,">") end
        if hover and input.mouse_clicked(0) then
            if item.type==item_type.sub_menu then
                local target=items.submenu_page_id(handle)
                if target and target~=0 then request_navigation("page",target) else items.activate(handle) end
            else
                items.activate(handle)
                if ui.preview_canvas and item.page=="Settings" and item.name=="Reset Menu Position" then
                    preview_recenter=true
                end
            end
        end
    else
        txt_ellipsis(font.item,x,y+(h-text.height(font.item))*.5,name_color,name,w)
    end
end

local collapsed_groups={}
local function grouped_page(x,y,w,h,radius,page_id,groups,column_count)
    local pad,gap,vgap=18,ui_options.group_spacing,ui_options.group_spacing
    local min_width=column_count and 160 or 220
    local columns=math.max(1,math.min(column_count or ui_options.columns,math.floor((w-pad*2+gap)/(min_width+gap))))
    local col_w=(w-pad*2-gap*(columns-1))/columns
    local heights,expanded_heights,layouts={},{},{}
    for i=1,columns do heights[i],expanded_heights[i]=0,0 end
    for index,group in ipairs(groups) do
        if #group.items>0 then
            local key=tostring(page_id)..":"..index..":"..group.title
            if search_target and search_target.pending then
                for _,handle in ipairs(group.items) do
                    if handle==search_target.handle then collapsed_groups[key]=nil end
                end
            end
            local expanded_h=38
            for _,handle in ipairs(group.items) do expanded_h=expanded_h+control_height(handle) end
            local collapsed=not not collapsed_groups[key]
            local ch=collapsed and 30 or expanded_h
            -- Balance using expanded sizes so collapsing a card never changes columns.
            local column=1
            for i=2,columns do if expanded_heights[i]<expanded_heights[column] then column=i end end
            layouts[#layouts+1]={group=group,key=key,column=column,y=heights[column],h=ch,collapsed=collapsed}
            heights[column]=heights[column]+ch+vgap
            expanded_heights[column]=expanded_heights[column]+expanded_h+vgap
        end
    end
    local total=0
    for _,height in ipairs(heights) do total=math.max(total,height) end
    local page_h=total+pad*2-vgap
    local maximum=math.max(0,page_h-h)
    if search_target and search_target.pending then
        for _,layout in ipairs(layouts) do
            local ry=pad+layout.y+28
            for _,handle in ipairs(layout.group.items) do
                if handle==search_target.handle then
                    scroll[page_id]=math.max(0,math.min(maximum,ry+control_height(handle)*.5-h*.5))
                    search_target.pending=false
                end
                ry=ry+control_height(handle)
            end
        end
    end
    local current=smooth_scroll(0xA300+page_id%512,scroll[page_id] or 0,maximum,inside(x,y,w-12,h),70,14)
    current=math.max(0,math.min(maximum,current)); scroll[page_id]=current
    draw.push_clip(x,y,x+w,y+h)
    for _,layout in ipairs(layouts) do
        local gx=x+pad+(layout.column-1)*(col_w+gap)
        local gy=y+pad+layout.y-current
        if gy+layout.h>=y and gy<=y+h then
            local bx,by,bw=panel(gx,gy,col_w,layout.h,layout.group.title,"",radius)
            local cx,cy=gx+col_w-15,gy+14
            if layout.collapsed then
                line(cx-2,cy-3,cx+2,cy,palette.faint,1.2); line(cx+2,cy,cx-2,cy+3,palette.faint,1.2)
            else
                line(cx-3,cy-2,cx,cy+2,palette.faint,1.2); line(cx,cy+2,cx+3,cy-2,palette.faint,1.2)
            end
            if inside(x,y,w,h) and clicked(gx,gy,col_w,27) then
                collapsed_groups[layout.key]=not collapsed_groups[layout.key]
                input.consume_mouse_click()
            end
            -- Apply header changes on the next layout pass: body and bounds stay in sync.
            if not layout.collapsed then
                for _,handle in ipairs(layout.group.items) do
                    local rh=control_height(handle)
                    if by+rh>=y and by<=y+h then row(handle,bx,by,bw,rh-2,radius) end
                    by=by+rh
                end
            end
        end
    end
    draw.pop_clip()
    if maximum>0 then scroll[page_id]=ui.scrollbar(0xA600+page_id%512,x+w-7,y+8,y+h-8,current,maximum,page_h) end
end
local function registry_groups(page_id,page_name)
    local groups,current={},nil
    for _,handle in ipairs(items.page_items(page_id)) do
        local item=items.at(handle)
        if item and item.type==item_type.label then
            current={title=item.name,items={}}; groups[#groups+1]=current
        elseif item then
            if not current or #current.items>=9 then
                current={title=#groups==0 and page_name or (page_name.." / "..(#groups+1)),items={}}
                groups[#groups+1]=current
            end
            current.items[#current.items+1]=handle
        end
    end
    return groups
end

local function named_row(page,name,x,y,w,h,radius)
    local handle=items.get(page,name)
    if handle then row(handle,x,y,w,h,radius) end
end

local function compact_toggle(page,name,id,x,w,y,label)
    local handle=items.get(page,name)
    if handle then row(handle,x,y,w,22,2,label) end
end
local pending_ui_scale=nil
local function compact_slider(page,name,id,x,w,y,label,format)
    local handle=items.get(page,name); if not handle then return end
    local item=items.at(handle); if not item then return end
    local defer_scale=page=="Settings" and name=="UI Scale"
    local displayed=defer_scale and (pending_ui_scale or item.f_val) or item.f_val
    local value,changed=slider_control(id,x,y,w,displayed,item.f_min,item.f_max,format,label or name,item.disabled)
    if defer_scale then
        if changed then pending_ui_scale=value end
        if pending_ui_scale and not input.mouse_down(0) then
            local auto=items.get("Settings","Auto UI Scale")
            local auto_item=auto and items.at(auto)
            if auto_item and auto_item.on then items.toggle(auto) end
            items.set_f_val(handle,pending_ui_scale)
            pending_ui_scale=nil
        end
    elseif changed then items.set_f_val(handle,value) end
end

local function theme_row(handle,x,y,w,active,radius)
    local item=items.at(handle); if not item then return end
    fill(x,y,w,26,active and palette.side or palette.input,2)
    txt_ellipsis(font.value,x+8,y+(26-text.height(font.value))*.5,active and palette.accentHi or palette.dim,item.name,w-30)
    if active then
        line(x+w-20,y+12,x+w-17,y+15,palette.accentHi,1.2)
        line(x+w-17,y+15,x+w-11,y+8,palette.accentHi,1.2)
    end
    if clicked(x,y,w,26) and not active then items.activate(handle) end
end

-- Native settings not explicitly laid out below stay visible as the project grows.
local settings_presented={
    ["Auto UI Scale"]=true,["UI Scale"]=true,["Overlays/Panels Scale"]=true,
    ["Theme"]=true,["Choose Theme"]=true,["Streamer Mode"]=true,
    ["Reload Lua Theme"]=true,["Reset Theme"]=true,["Open Themes Folder"]=true,
}
local function additional_settings()
    local result={}
    for _,handle in ipairs(items.page_items(items.joaat("Settings"))) do
        local item=items.at(handle)
        if item and item.type~=item_type.label and not settings_presented[item.name] then
            result[#result+1]=handle
        end
    end
    return result
end
local settings_scroll={}
local config_name,config_status,config_delete_confirm="","",false
local config_seen_active=""
local function settings_columns(x,y,w,h,radius)
    local cards={}
    local function add_card(title,height,render,targets)
        cards[#cards+1]={title=title,h=height,render=render,targets=targets or {}}
    end
    local function target(page,name,offset)
        return {handle=items.get(page,name),offset=offset or 0}
    end
    if settings_tab=="General" then
        add_card("UI Scale",140,function(bx,by,bw,bh)
        compact_toggle("Settings","Auto UI Scale",0xC001,bx,bw,by,"Auto UI Scale")
        compact_slider("Settings","UI Scale",0xC002,bx,bw,by+26,"UI Scale","%.2f x")
        compact_slider("Settings","Overlays/Panels Scale",0xC003,bx,bw,by+68,"Overlays","%.2f x")
        end,{target("Settings","Auto UI Scale"),target("Settings","UI Scale",26),target("Settings","Overlays/Panels Scale",68)})
        add_card("Open Menu Keys",164,function(kx,ky,kw)
        ui.row_menu_keybind_values(0xD001,kx,ky,kw,"Open menu")
        ui.row_menu_keybind_values(0xD003,kx,ky+36,kw,"Alternate key",true)
        txt_ellipsis(font.small,kx,ky+78,palette.dim,"Click the key, then press a new one.",kw)
        txt(font.small,kx,ky+98,palette.faint,"Esc cancels key capture.")
        end)
        if items.get("Streamer Mode","Enabled") then
            add_card("Streamer Mode",60,function(sx,sy,sw,sh)
                compact_toggle("Streamer Mode","Enabled",0xC100,sx,sw,sy,"Enabled")
            end,{target("Streamer Mode","Enabled"),target("Settings","Streamer Mode")})
        end
    elseif settings_tab=="Layout" then
        local layout_targets={target("Nenyoo Appearance","Sidebar Width"),target("Nenyoo Appearance","Corner Radius",42)}
        for index,entry in ipairs(layout_sliders) do layout_targets[#layout_targets+1]=target("UI Layout",entry[1],(index+1)*42) end
        add_card("UI Layout",290,function(mx,my,mw,mh)
        compact_slider("Nenyoo Appearance","Sidebar Width",0xC110,mx,mw,my,"Sidebar Width","%.0f px")
        compact_slider("Nenyoo Appearance","Corner Radius",0xC111,mx,mw,my+42,"Corner Radius","%.0f px")
        for index,entry in ipairs(layout_sliders) do
            compact_slider("UI Layout",entry[1],0xC120+index,mx,mw,my+(index+1)*42,entry[1],entry[2]=="columns" and "%.0f" or "%.0f px")
        end
        end,layout_targets)
        local font_targets={}
        for index,name in ipairs({"Title Size","Item Size","Small Size","Value Size","Description Size","Section Label Size","Tagline Size","Overlay Text Size"}) do
            font_targets[#font_targets+1]=target("Typography",name,(index-1)*42)
        end
        add_card("Typography",378,function(fx,fy,fw,fh)
        local fonts={{"Title Size","Brand"},{"Item Size","Menu Items"},{"Small Size","Small Text"},
            {"Value Size","Values"},{"Description Size","Descriptions"},{"Section Label Size","Group Titles"},
            {"Tagline Size","Tagline"},{"Overlay Text Size","Overlay Text"}}
        for index,entry in ipairs(fonts) do
            compact_slider("Typography",entry[1],0xC010+index,fx,fw,fy+(index-1)*42,entry[2],"%.0f px")
        end
        end,font_targets)
        local navigation_targets={}
        for index,entry in ipairs(navigation_toggles) do navigation_targets[#navigation_targets+1]=target("UI Layout",entry[1],(index-1)*24) end
        add_card("Navigation",110,function(nx,ny,nw,nh)
        for index,entry in ipairs(navigation_toggles) do
            compact_toggle("UI Layout",entry[1],0xC130+index,nx,nw,ny+(index-1)*24,entry[1])
        end
        end,navigation_targets)
        add_card("Motion",106,function(ax,ay,aw,ah)
        compact_toggle("Motion","Animations Enabled",0xC112,ax,aw,ay,"Animations")
        compact_slider("Motion","Motion Speed",0xC113,ax,aw,ay+26,"Motion Speed","%.2f x")
        end,{target("Motion","Animations Enabled"),target("Motion","Motion Speed",26)})
        local extra=additional_settings()
        if #extra>0 then
            local height,targets=38,{}
            for _,handle in ipairs(extra) do
                targets[#targets+1]={handle=handle,offset=height-38}
                height=height+control_height(handle)
            end
            add_card("More Settings",height,function(ex,ey,ew)
                for _,handle in ipairs(extra) do
                    local rh=control_height(handle)
                    row(handle,ex,ey,ew,rh,radius)
                    ey=ey+rh
                end
            end,targets)
        end
    elseif settings_tab=="Colors" then
        local function color_group(title,first,last)
            local targets={}
            for index=first,last do targets[#targets+1]=target("Nenyoo Appearance",color_settings[index][1],(index-first)*30) end
            add_card(title,42+(last-first+1)*30,function(ax,ay,aw)
                for index=first,last do
                    local entry=color_settings[index]; local name,color=entry[1],palette[entry[3]]
                    local cy=ay+(index-first)*30
                    local hex=string.format("#%02X%02X%02X%02X",table.unpack(color))
                    local hex_w=text.width(font.value,hex)
                    txt_ellipsis(font.item,ax,cy+6,palette.text,name,aw-hex_w-42)
                    txt(font.value,ax+aw-32-hex_w,cy+6,palette.dim,hex)
                    fill(ax+aw-22,cy+2,22,22,color,2)
                    outline(ax+aw-22,cy+2,22,22,palette.dim,2)
                    color_swatch(items.get("Nenyoo Appearance",name),ax+aw-22,cy+2,22,22)
                end
            end,targets)
        end
        color_group("Colors",1,5)
        color_group("Surface Colors",6,10)
        color_group("Text & Borders",11,14)
    elseif settings_tab=="Config" then
        local profiles=ui.config_profiles()
        local active_profile=ui.config_active()
        if config_seen_active~=active_profile then config_delete_confirm=false; config_seen_active=active_profile end
        local choose=items.get("Settings","Choose Theme")
        local themes=choose and items.page_items(items.submenu_page_id(choose)) or {}
        local theme_targets={target("Settings","Theme"),target("Settings","Choose Theme")}
        for index,handle in ipairs(themes) do theme_targets[#theme_targets+1]={handle=handle,offset=(index-1)*28} end
        for _,name in ipairs({"Reload Lua Theme","Reset Theme","Open Themes Folder"}) do
            theme_targets[#theme_targets+1]=target("Settings",name,28*math.max(1,#themes)+8)
        end
        add_card("Theme",76+28*math.max(1,#themes),function(tx,ty,tw,th)
        local active_path=theme.active_path()
        for index,handle in ipairs(themes) do
            local item=items.at(handle)
            theme_row(handle,tx,ty+(index-1)*28,tw,item and (item.type==item_type.selected_tick or item.desc==active_path),2)
        end
        if #themes==0 then txt(font.small,tx+4,ty+6,palette.dim,"Default theme") end
        local action_y=ty+28*math.max(1,#themes)+8
        local action_w=(tw-12)/3
        for index,entry in ipairs({{"Reload","Reload Lua Theme"},{"Reset","Reset Theme"},{"Open","Open Themes Folder"}}) do
            local handle=items.get("Settings",entry[2])
            if button(tx+(index-1)*(action_w+6),action_y,action_w,28,entry[1],false,2) and handle then items.activate(handle) end
        end
        end,theme_targets)
        add_card("Configs",264+30*math.max(1,#profiles),function(px,py,pw)
        txt_ellipsis(font.item,px,py+2,palette.text,i18n.tr("Active: ")..active_profile,pw)
        txt(font.small,px,py+24,palette.dim,"Config name")
        local submitted
        config_name,submitted=ui.field(0xC510,px,py+42,pw,28,config_name,"Enter a name",false)
        local action_w=(pw-12)/3
        local function create_config()
            if ui.config_create(config_name) then config_status="Config created"; config_name=""
            else config_status="Choose a unique valid name" end
        end
        if submitted then create_config() end
        if button(px,py+78,action_w,28,"Create",true,radius) then create_config() end
        if button(px+action_w+6,py+78,action_w,28,"Save",false,radius) then
            config_status=ui.config_save() and "Config saved" or "Could not save config"
        end
        if button(px+(action_w+6)*2,py+78,action_w,28,"Rename",false,radius) then
            if ui.config_rename(config_name) then config_status="Config renamed"; config_name=""
            else config_status="Cannot rename; check the name" end
        end
        if active_profile~="Default" then
            if config_delete_confirm then
                if button(px,py+112,(pw-6)*.5,28,"Confirm Delete",false,radius) then
                    config_status=ui.config_delete() and "Config deleted" or "Could not delete config"
                    config_delete_confirm=false
                end
                if button(px+(pw+6)*.5,py+112,(pw-6)*.5,28,"Cancel",false,radius) then config_delete_confirm=false end
            elseif button(px,py+112,pw,28,"Delete Current Config",false,radius) then config_delete_confirm=true end
        else txt_ellipsis(font.small,px,py+120,palette.faint,"Default cannot be renamed or deleted.",pw) end
        txt_ellipsis(font.small,px,py+156,palette.dim,config_status~="" and config_status or "Changes save automatically.",pw)
        for index,name in ipairs(profiles) do
            local cy=py+186+(index-1)*30
            local selected=name==active_profile
            fill(px,cy,pw,26,selected and palette.side or palette.input,2)
            txt_ellipsis(font.value,px+8,cy+7,selected and palette.accentHi or palette.text,name,pw-56)
            if selected then txt(font.small,px+pw-42,cy+8,palette.accentHi,"Active") end
            if clicked(px,cy,pw,26) and not selected then
                config_status=ui.config_load(name) and (i18n.tr("Loaded ")..name) or "Could not load config"
                config_delete_confirm=false
            end
        end
        end)
        add_card("Appearance Defaults",98,function(rx,ry,rw)
        txt_ellipsis(font.small,rx,ry+2,palette.dim,"Restore colours, layout, and fonts.",rw)
        -- Keep the recovery button legible even after making text fully transparent.
        fill(rx,ry+28,rw,28,{34,40,45,255},2)
        local reset_label=i18n.tr("Reset Appearance")
        txt_ellipsis(font.value,rx+8,ry+36,{211,216,219,255},reset_label,rw-16)
        if clicked(rx,ry+28,rw,28) then
            close_color_popup(); reset_appearance(); settings_scroll={}
            input.consume_mouse_click()
        end
        end)
    end

    local pad,gap=18,ui_options.group_spacing
    local columns=math.max(1,math.min(ui_options.columns,#cards,math.floor((w-pad*2+gap)/(220+gap))))
    local cw=(w-pad*2-gap*(columns-1))/columns
    local heights,total={},0
    for i=1,columns do heights[i]=0 end
    for _,card in ipairs(cards) do
        local column=1
        for i=2,columns do if heights[i]<heights[column] then column=i end end
        card.x=x+pad+(column-1)*(cw+gap)
        card.y=heights[column]
        heights[column]=heights[column]+card.h+gap
        total=math.max(total,heights[column]-gap)
    end
    local page_h=total+pad*2
    local maximum=math.max(0,page_h-h)
    local current=settings_scroll[settings_tab] or 0
    if search_target and search_target.pending then
        current=0
        for _,card in ipairs(cards) do
            for _,entry in ipairs(card.targets) do
                if entry.handle==search_target.handle then current=pad+card.y+28+entry.offset-h*.4 end
            end
        end
        search_target.pending=false
    end
    local tab_id=0
    for index,name in ipairs(settings_tab_names) do
        if name==settings_tab then tab_id=(index-1)*2; break end
    end
    current=smooth_scroll(0xA200+tab_id,current,maximum,inside(x,y,w-12,h),70,14)
    current=math.max(0,math.min(maximum,current)); settings_scroll[settings_tab]=current
    draw.push_clip(x,y,x+w,y+h)
    local function render_controls()
        for _,card in ipairs(cards) do
            local cy=y+pad+card.y-current
            if cy+card.h>=y and cy<=y+h then
                local bx,by,bw,bh=panel(card.x,cy,cw,card.h,card.title,"",radius)
                card.render(bx,by,bw,bh)
            end
        end
    end
    if inside(x,y,w,h) or slider_drag then render_controls()
    else input.with_pointer_blocked(render_controls) end
    draw.pop_clip()
    if maximum>0 then settings_scroll[settings_tab]=ui.scrollbar(0xA201+tab_id,x+w-7,y+8,y+h-8,current,maximum,page_h) end
end

local function combat_tabs(x,y,w,h,radius,selected)
    if selected then combat_tab=selected end
    if #combat_tabs_list()==0 then return end
    local active=combat_definitions[combat_tab]
    local page_id=items.joaat(active.name)
    local handles=items.page_items(page_id)
    local groups,shown={},{}
    for _,side in ipairs({active.left,active.right}) do
        for _,group in ipairs(side) do
            local entry={title=group.title,items={}}
            for index=group.first,math.min(group.last,#handles) do
                entry.items[#entry.items+1]=handles[index]; shown[handles[index]]=true
            end
            groups[#groups+1]=entry
        end
    end
    local extra={title="Other Controls",items={}}
    for _,handle in ipairs(handles) do if not shown[handle] then extra.items[#extra.items+1]=handle end end
    groups[#groups+1]=extra
    grouped_page(x,y,w,h,radius,page_id,groups)
end
local function visuals_cards(x,y,w,h,radius,page_id,definition,all_handles,column_count)
    local handles=all_handles or items.page_items(page_id)
    local by_name,shown,groups={},{},{}
    for _,handle in ipairs(handles) do local item=items.at(handle); if item then by_name[item.name]=handle end end
    for _,side in ipairs({definition.left,definition.right}) do
        for _,group in ipairs(side) do
            local entry={title=group.title,items={}}
            for _,name in ipairs(group.items) do
                local handle=type(name)=="number" and name or by_name[name]
                if handle then entry.items[#entry.items+1]=handle; shown[handle]=true end
            end
            groups[#groups+1]=entry
        end
    end
    local extra={title="Other Controls",items={}}
    for _,handle in ipairs(handles) do
        local item=items.at(handle)
        if item and item.type~=item_type.label and not shown[handle] then extra.items[#extra.items+1]=handle end
    end
    groups[#groups+1]=extra
    grouped_page(x,y,w,h,radius,page_id,groups,column_count)
end

local function flattened_vfx_definition(parent,parent_id)
    local definition={left={},right={}}
    local handles,seen={},{}
    local function add_page(page_id,source,page_name)
        local page_handles=items.page_items(page_id)
        local by_name={}
        for _,handle in ipairs(page_handles) do
            local item=items.at(handle)
            if item then
                by_name[item.name]=handle
                if item.type~=item_type.sub_menu and not seen[handle] then
                    handles[#handles+1]=handle
                    seen[handle]=true
                end
            end
        end
        if not source then return end
        for _,side in ipairs({"left","right"}) do
            for _,group in ipairs(source[side] or {}) do
                local controls={}
                for _,entry in ipairs(group.items or {}) do
                    local handle=type(entry)=="number" and entry or by_name[entry]
                    local item=handle and items.at(handle)
                    if item and item.type~=item_type.sub_menu and item.type~=item_type.label then
                        controls[#controls+1]=handle
                    end
                end
                if #controls>0 then
                    local title=page_name and (page_name.." / "..group.title) or group.title
                    definition[side][#definition[side]+1]={title=title,items=controls}
                end
            end
        end
    end
    add_page(parent_id,parent=="ESP" and visuals_definition or vfx_definitions[parent])
    for _,link in ipairs(items.page_items(parent_id)) do
        local item=items.at(link)
        if item and item.type==item_type.sub_menu then
            local child_id=items.submenu_page_id(link)
            if child_id and child_id~=0 then
                local child_definition
                if parent=="Sky" then child_definition=sky_child_definition(child_id,item.name)
                elseif parent=="Weather" then child_definition=vfx_definitions.weather_effect
                else child_definition=vfx_definitions[item.name] end
                add_page(child_id,child_definition,item.name)
            end
        end
    end
    return definition,handles
end

local function draw_vfx_group(x,y,w,h,radius,parent,parent_id,column_count)
    local definition,handles=flattened_vfx_definition(parent,parent_id)
    visuals_cards(x,y,w,h,radius,parent_id,definition,handles,column_count)
end

local function draw_visuals_tab(x,y,w,h,radius,root)
    local tabs=visuals_tabs_list(root)
    local selected=nil
    for _,tab in ipairs(tabs) do
        if tab.name==visual_tabs[root] then selected=tab; break end
    end
    if not selected then selected=tabs[1] end
    if not selected or not selected.id or selected.id==0 then return end
    visual_tabs[root]=selected.name
    draw_vfx_group(x,y,w,h,radius,selected.name,selected.id,root=="VFX's" and 4 or nil)
end

local welcome_open,welcome_anchor,welcome_scroll=nil,nil,0
local welcome_bounds,welcome_resize=nil,nil
local welcome_keybind_id,welcome_alt_keybind_id=0xD002,0xD004
local welcome_return_tab=nil
local function enter_main_ui()
    if menu.build_tabs then menu.build_tabs() end
    local destination=welcome_return_tab
    if not destination or menu.tab_name(destination)=="Home" or menu.tab_name(destination)=="" then
        destination=nil
        for tab=0,(menu.tab_count and menu.tab_count() or 0)-1 do
            if menu.tab_name(tab)~="Home" then destination=tab; break end
        end
    end
    if destination then request_navigation("tab",destination) end
end
local function close_welcome_dropdown()
    welcome_open,welcome_anchor=nil,nil
    if ui.cancel_menu_keybind then
        ui.cancel_menu_keybind(welcome_keybind_id)
        ui.cancel_menu_keybind(welcome_alt_keybind_id)
    end
end
local function welcome_choices()
    local entries={}
    if welcome_open=="language" then
        for i=1,i18n.count() do
            entries[#entries+1]={label=i18n.label(i),code=i18n.code(i),selected=i18n.code(i)==i18n.active()}
        end
    elseif welcome_open=="menu_scale" then
        local auto=items.get("Settings","Auto UI Scale")
        local automatic=auto and items.at(auto)
        local handle=items.get("Settings","UI Scale")
        local item=handle and items.at(handle)
        if automatic then entries[#entries+1]={label="Auto",auto=auto,selected=automatic.on} end
        if item then
            for _,value in ipairs({.5,.75,1,1.25,1.5,1.75,2}) do
                if value>=item.f_min and value<=item.f_max then
                    entries[#entries+1]={label=string.format("%.0f%%",value*100),value=value,handle=handle,
                        selected=not (automatic and automatic.on) and math.abs(item.f_val-value)<.001}
                end
            end
        end

    end
    return entries
end
local function welcome_popup_rect()
    if not welcome_anchor then return end
    local vw,vh=ctx.screen_w()/ctx.ui_scale(),ctx.screen_h()/ctx.ui_scale()
    local w=math.min(math.max(220,welcome_anchor.w),vw-16)
    local h=math.min(8,#welcome_choices())*30+12
    h=math.min(h,vh-16)
    local x=math.max(8,math.min(vw-w-8,welcome_anchor.x+welcome_anchor.w-w))
    local y=welcome_anchor.y+welcome_anchor.h+5
    if y+h>vh-8 then y=welcome_anchor.y-h-5 end
    return x,math.max(8,math.min(vh-h-8,y)),w,h
end
local function welcome_popup_input()
    if not welcome_open then return false end
    if menu.page_id()~=items.joaat("Home") then close_welcome_dropdown(); return false end
    if input.key_just_pressed(VK.ESCAPE) then close_welcome_dropdown(); return true end
    local x,y,w,h=welcome_popup_rect()
    if input.mouse_clicked(0) and not inside(x,y,w,h) then
        close_welcome_dropdown(); input.consume_mouse_click()
    end
    return true
end
local function welcome_field(id,label,value,x,y,w)
    txt(font.item,x,y+(30-text.height(font.item))*.5,palette.text,label)
    local fw=math.min(220,w*.58)
    local fx=x+w-fw
    local hot=inside(fx,y,fw,30)
    fill(fx,y,fw,30,hot and palette.side or palette.input,4)
    txt_ellipsis(font.value,fx+12,y+(30-text.height(font.value))*.5,palette.text,value,fw-40)
    line(fx+fw-18,y+12,fx+fw-14,y+16,palette.dim,1.2)
    line(fx+fw-14,y+16,fx+fw-10,y+12,palette.dim,1.2)
    if welcome_open==id then welcome_anchor={x=fx,y=y,w=fw,h=30} end
    if clicked(fx,y,fw,30) then
        close_welcome_dropdown()
        welcome_open=id; welcome_anchor={x=fx,y=y,w=fw,h=30}; welcome_scroll=0
        close_color_popup(); option_open,option_anchor=nil,nil
        for index,entry in ipairs(welcome_choices()) do
            if entry.selected then welcome_scroll=math.max(0,index-4); break end
        end
        input.consume_mouse_click()
    end
end
local function welcome_layout()
    local layout={greeting=22}
    layout.subtitle=layout.greeting+text.height(font.title)+6
    layout.setup=layout.subtitle+text.height(font.desc)+16
    layout.button=layout.setup+184
    layout.height=layout.button+34+22
    return layout
end
local function draw_welcome(x,y,w,h,radius)
    local layout=welcome_layout()
    local left,width=x+22,w-44
    local username=ui.username()
    local greeting=username=="Guest" and "Welcome to Nenyoo." or (i18n.tr("Welcome back, ")..username..".")
    txt_ellipsis(font.title,left,y+layout.greeting,palette.text,greeting,width)
    txt_ellipsis(font.desc,left,y+layout.subtitle,palette.dim,"Set up your menu, then get started.",width)
    -- Share the welcome surface without layering another translucent fill.
    txt_ellipsis(font.label,left+12,y+layout.setup+8,palette.faint,i18n.tr("Quick Setup"),width-36)
    local bx,by,bw=left+10,y+layout.setup+28,width-20
    local auto=items.get("Settings","Auto UI Scale")
    local automatic=auto and items.at(auto)
    local scale=items.get("Settings","UI Scale")
    local value=scale and items.at(scale)
    local scale_label=automatic and automatic.on and "Auto" or (value and string.format("%.0f%%",value.f_val*100) or "Auto")
    local language="English"
    for i=1,i18n.count() do if i18n.code(i)==i18n.active() then language=i18n.label(i); break end end
    welcome_field("menu_scale","Menu scale",scale_label,bx+4,by,bw-8)
    welcome_field("language","Language",language,bx+4,by+36,bw-8)
    ui.row_menu_keybind_values(welcome_keybind_id,bx+4,by+74,bw-8,"Open key")
    ui.row_menu_keybind_values(welcome_alt_keybind_id,bx+4,by+108,bw-8,"Alternate key",true)
    local button_y=y+h-56
    local hot=inside(left,button_y,width,34)
    fill(left,button_y,width,34,hot and palette.accentHi or palette.accent,5)
    local label=i18n.tr("Enter")
    local label_w=text.width(font.item,label)
    txt_ellipsis(font.item,left+math.max(12,(width-label_w)*.5),button_y+(34-text.height(font.item))*.5,
        {21,24,27,255},label,width-24)
    if clicked(left,button_y,width,34) then
        close_welcome_dropdown(); enter_main_ui(); input.consume_mouse_click()
    end
end
local function welcome_surface_rect()
    local vw,vh=ctx.screen_w()/ctx.ui_scale(),ctx.screen_h()/ctx.ui_scale()
    local max_w,max_h=math.max(1,vw-32),math.max(1,vh-32)
    local min_w,min_h=math.min(360,max_w),math.min(welcome_layout().height,max_h)
    if not welcome_bounds then
        local w,h=math.min(480,max_w),min_h
        welcome_bounds={x=(vw-w)*.5,y=(vh-h)*.5,w=w,h=h,vw=vw,vh=vh}
    end
    local bounds=welcome_bounds
    if bounds.vw~=vw or bounds.vh~=vh then
        bounds.x=(bounds.x+bounds.w*.5)*vw/bounds.vw-bounds.w*.5
        bounds.y=(bounds.y+bounds.h*.5)*vh/bounds.vh-bounds.h*.5
        bounds.vw,bounds.vh=vw,vh
        welcome_resize=nil
    end
    bounds.w=math.max(min_w,math.min(max_w,bounds.w))
    bounds.h=math.max(min_h,math.min(max_h,bounds.h))
    bounds.x=math.max(16,math.min(vw-16-bounds.w,bounds.x))
    bounds.y=math.max(16,math.min(vh-16-bounds.h,bounds.y))
    return bounds.x,bounds.y,bounds.w,bounds.h
end
local function resize_welcome_surface()
    local x,y,w,h=welcome_surface_rect()
    if not welcome_resize and not welcome_open and clicked(x+w-20,y+h-20,20,20) then
        welcome_resize={x=input.mouse_x(),y=input.mouse_y(),w=w,h=h}
        close_welcome_dropdown()
        input.consume_mouse_click()
    end
    if welcome_resize then
        if input.mouse_down(0) then
            local max_w=welcome_bounds.vw-16-x
            local max_h=welcome_bounds.vh-16-y
            welcome_bounds.w=math.max(math.min(360,max_w),math.min(max_w,welcome_resize.w+input.mouse_x()-welcome_resize.x))
            welcome_bounds.h=math.max(math.min(welcome_layout().height,max_h),math.min(max_h,welcome_resize.h+input.mouse_y()-welcome_resize.y))
        else welcome_resize=nil end
    end
    return welcome_resize~=nil
end
local function draw_welcome_surface(radius)
    local vw,vh=ctx.screen_w()/ctx.ui_scale(),ctx.screen_h()/ctx.ui_scale()
    if ui.preview_canvas then fill(0,0,vw,vh,{51,65,85,255},0) end
    local resizing=resize_welcome_surface()
    local x,y,w,h=welcome_surface_rect()
    fill(x,y,w,h,palette.bg,math.max(6,radius))
    menu.drag_header(x,y,w,62,false)
    menu.set_content_rect(x,y,w,h)
    -- The resize corner has no grip, hover fill, border, or highlight.
    if resizing then input.with_pointer_blocked(function() draw_welcome(x,y,w,h,radius) end)
    else draw_welcome(x,y,w,h,radius) end
end

local function draw_welcome_dropdown()
    if not welcome_open then return end
    local x,y,w,h=welcome_popup_rect()
    fill(x,y,w,h,{23,26,30,255},5)
    local choices=welcome_choices()
    local visible=math.max(1,math.floor((h-12)/30))
    local maximum=math.max(0,#choices-visible)
    if inside(x,y,w,h) then welcome_scroll=welcome_scroll-input.mouse_wheel()*2 end
    welcome_scroll=math.floor(math.max(0,math.min(maximum,welcome_scroll)))
    for i=welcome_scroll+1,math.min(#choices,welcome_scroll+visible) do
        local entry=choices[i]; local ry=y+6+(i-welcome_scroll-1)*30
        if inside(x+5,ry,w-10,28) or entry.selected then fill(x+5,ry,w-10,28,palette.side,3) end
        local label_x=x+12
        if entry.code then flag(entry.code,x+12,ry+7,21,14); label_x=x+42 end
        txt_ellipsis(font.item,label_x,ry+(28-text.height(font.item))*.5,
            entry.selected and palette.accentHi or palette.text,entry.label,w-(label_x-x)-28)
        if entry.selected then
            line(x+w-23,ry+14,x+w-20,ry+17,palette.accentHi,1.2)
            line(x+w-20,ry+17,x+w-14,ry+10,palette.accentHi,1.2)
        end
        if clicked(x+5,ry,w-10,28) then
            if entry.code then i18n.set_active(entry.code)
            elseif entry.auto then
                if not items.at(entry.auto).on then items.toggle(entry.auto) end
            else
                local auto=items.get("Settings","Auto UI Scale")
                if auto and items.at(auto).on then items.toggle(auto) end
                items.set_f_val(entry.handle,entry.value)
            end
            close_welcome_dropdown()
            input.consume_mouse_click(); break
        end
    end
    if maximum>0 then
        local track=h-12; local thumb=math.max(16,track*visible/#choices)
        fill(x+w-3,y+6+(track-thumb)*welcome_scroll/maximum,2,thumb,palette.dim,1,130)
    end
end

local function draw_page(x,y,w,h,radius)
    local page_id,page_name=menu.page_id(),menu.page_name()
    local home_id,settings_id=items.joaat("Home"),items.joaat("Settings")
    local misc_id=items.joaat("Misc")
    local combat_id=items.joaat("Combat")
    local lock_id=items.joaat("Lock-on Aimbot")
    local silent_id=items.joaat("Silent Aim")
    local magic_id=items.joaat("Magic Bullet")
    if page_id==menu.root_page() or page_name=="" then
        menu.replace_page(home_id); page_id,page_name=home_id,"Home"
    end
    if page_id==home_id then
        draw_welcome(x,y,w,h,radius)
        return
    end
    -- Keep the same compact Settings surface on both targets.
    -- Target-specific pages are still available through their own registry routes.
    local section=settings_section_for(page_id)
    if section then
        if search_target and search_target.pending then
            section=settings_section_for(search_target.page_id,search_target.handle) or section
        end
        settings_tab=section
        if page_id~=settings_id then menu.replace_page(settings_id) end
        settings_columns(x,y,w,h,radius); return
    end
    if page_id==misc_id then visuals_cards(x,y,w,h,radius,misc_id,misc_definition); return end
    local visual_root,selected=visual_section_for(page_id,page_name)
    if visual_root then
        if selected then visual_tabs[visual_root]=selected end
        if page_id~=items.joaat(visual_root) then menu.replace_page(items.joaat(visual_root)) end
        draw_visuals_tab(x,y,w,h,radius,visual_root); return
    end
    if page_id==combat_id then combat_tabs(x,y,w,h,radius); return end
    if page_id==lock_id or page_id==silent_id or page_id==magic_id then
        local selected=page_id==lock_id and 1 or (page_id==silent_id and 2 or 3)
        menu.replace_page(combat_id)
        combat_tabs(x,y,w,h,radius,selected)
        return
    end
    grouped_page(x,y,w,h,radius,page_id,registry_groups(page_id,page_name))
end

local function search_box(x,y,w,h,radius,interactive)
    if interactive and clicked(x,y,w,h) then search_focus=true end
    if search_focus and input.mouse_clicked(0) and not inside(x,y,w,h) and
        not (search_popup_bounds and inside(search_popup_bounds.x,search_popup_bounds.y,
            search_popup_bounds.w,search_popup_bounds.h)) then search_focus=false end
    if search_focus then
        local chars=input.get_chars(); if chars~="" then search=search..chars end
        if input.key_just_pressed(VK.BACK) then search=search:sub(1,math.max(0,#search-1)) end
        if input.key_just_pressed(VK.ESCAPE) then search_focus=false end
    end
    local focus_a=motion_to("search_focus",search_focus and 1 or 0,22,0)
    fill(x,y,w,h,mix_color(palette.input,palette.side,focus_a*.3),radius)
    draw.circle_outline(x+18,y+h*.5,5,palette.dim[1],palette.dim[2],palette.dim[3],palette.dim[4],1.5)
    line(x+22,y+h*.5+4,x+26,y+h*.5+8,palette.dim,1.5)
    txt_ellipsis(font.small,x+34,y+8,search=="" and palette.faint or palette.text,
        search=="" and "Search features..." or search,w-42)
    local show=interactive and search_focus and search~=""
    if show then search_popup_query=search end
    local popup=motion_to("search_popup",show and 1 or 0,22,0)
    if popup<.01 or search_popup_query=="" then search_popup_bounds=nil; return end
    local results=items.search(search_popup_query)
    local count=math.min(#results,6)
    local oh=math.max(1,count)*40+8
    search_popup_bounds=show and {x=x,y=y+h+6,w=w,h=oh} or nil
    local function open_result(handle,item)
        local destination=item.page_id
        local focus_handle=handle
        if item.type==item_type.sub_menu then
            local child=items.submenu_page_id(handle)
            if child and child~=0 then
                destination=child
                focus_handle=nil
            end
        end
        request_navigation("search",{
            page_id=destination,handle=focus_handle
        })
        search,search_focus="",false
        search_popup_bounds=nil
    end
    if show and count>0 and input.key_just_pressed(VK.RETURN) then
        local handle=results[1]
        local item=items.at(handle)
        if item then open_result(handle,item) end
    end
    draw.push_motion(0,-5*(1-popup),popup)
    fill(x,y+h+6,w,oh,palette.panel,radius); outline(x,y+h+6,w,oh,palette.border,radius)
    if count==0 then txt(font.small,x+14,y+h+22,palette.dim,"No matching features") end
    for i=1,count do
        local handle,item=results[i],items.at(results[i]); local ry=y+h+10+(i-1)*40
        local hov=show and item and inside(x+4,ry,w-8,36)
        local row_a=motion_to("search_row_"..handle,hov and 1 or 0,26,0)
        if row_a>.01 then fill(x+4,ry,w-8,36,palette.side,radius,math.floor(190*row_a)) end
        if item then
            txt_ellipsis(font.small,x+14,ry+5,palette.text,item.name,w-28)
            txt_ellipsis(font.small,x+14,ry+20,palette.dim,item.page,w-28)
            if show and search_popup_click and hov then open_result(handle,item) end
        end
    end
    draw.pop_motion()
end

local function compact_search(x,y,w,h,radius)
    local hover=inside(x,y,32,h)
    if clicked(x,y,32,h) then
        search_expanded=not search_expanded
        search_focus=search_expanded
        if search_expanded then
            language_open=false
            search,search_popup_query="",""
            motion_reset("search_popup",0)
        end
        input.consume_mouse_click()
    end
    if search_expanded and input.key_just_pressed(VK.ESCAPE) then
        search_expanded,search_focus=false,false
    end
    local active=motion_to("search_icon",(search_expanded or hover) and 1 or 0,22,0)
    local tint=mix_color(palette.dim,palette.accentHi,active)
    local rounding=math.max(radius,6)
    if active>.01 then fill(x,y,32,h,palette.side,rounding,math.floor(palette.side[4]*active)) end
    draw.circle_outline(x+14,y+h*.5-1,5,tint[1],tint[2],tint[3],tint[4],1.5)
    line(x+18,y+h*.5+3,x+22,y+h*.5+7,tint,1.5)
    local reveal=motion_to("search_reveal",search_expanded and 1 or 0,20,0)
    if reveal>.01 then
        local box_w=w*(.92+.08*reveal)
        draw.push_motion(0,0,reveal)
        search_box(x-box_w-8,y,box_w,h,rounding,search_expanded)
        draw.pop_motion()
        if not search_focus then search_expanded=false end
    end
    if not search_expanded then
        search_popup_bounds=nil
        if reveal<=.01 then
            search,search_popup_query="",""
            motion_reset("search_popup",0)
        end
    end
end
__overlay_draws = __overlay_draws or {}
__overlay_draws.story_features = function()
    if type(story) ~= "table" then return end
    local any_enabled=story.aim_enabled() or story.esp_enabled() or story.vehicle_esp() or story.object_esp() or story.diagnostics() or story.silent_enabled() or story.magic_enabled()
    if any_enabled and not story.ready() then
        -- World data can legitimately be absent on FiveM's home screen.
        -- Keep this persistent banner for the explicit Diagnostics mode.
        if not story.diagnostics() then return end
        draw.rect(18,18,390,52,palette.panel[1],palette.panel[2],palette.panel[3],235,6)
        draw.rect_outline(18,18,390,52,palette.accent[1],palette.accent[2],palette.accent[3],130,6,1,true)
        text.draw(font.small,30,28,palette.text[1],palette.text[2],palette.text[3],235,story.status())
        return
    end
    if (story.silent_enabled() or story.magic_enabled()) and not story.weapon_redirect_ready() then
        draw.rect(18,18,440,52,palette.panel[1],palette.panel[2],palette.panel[3],235,6)
        draw.rect_outline(18,18,440,52,palette.accent[1],palette.accent[2],palette.accent[3],130,6,1,true)
        text.draw(font.small,30,28,palette.text[1],palette.text[2],palette.text[3],235,
            "Weapon redirect unavailable: FireDelayedHit signature missing")
        return
    end
    if story.aim_enabled() and story.show_fov() then
        draw.circle_outline(ctx.screen_w()*.5,ctx.screen_h()*.5,story.aim_fov(),
            palette.accent[1],palette.accent[2],palette.accent[3],150,1.25)
    end
    if story.silent_enabled() and story.silent_show_fov() then
        draw.circle_outline(ctx.screen_w()*.5,ctx.screen_h()*.5,story.silent_fov(),
            palette.accentHi[1],palette.accentHi[2],palette.accentHi[3],130,1)
    end
    if story.magic_enabled() then
        draw.circle_outline(ctx.screen_w()*.5,ctx.screen_h()*.5,story.magic_fov(),
            palette.green[1],palette.green[2],palette.green[3],130,1)
    end
    local targets=story.targets()
    if story.silent_enabled() or story.magic_enabled() then
        local aim_indices={1,8,9}
        local chosen=story.magic_enabled() and story.magic_bone() or story.silent_bone()
        local redirect_index=aim_indices[(chosen or 0)+1] or 1
        for _,target in ipairs(targets) do
            if target.selected and target.bones and target.bones[redirect_index] then
                local point=target.bones[redirect_index]
                if point.visible then
                    local color=story.magic_enabled() and palette.green or palette.accentHi
                    draw.circle_outline(point.x,point.y,6,color[1],color[2],color[3],230,1.5)
                end
            end
        end
    end
    if story.aim_enabled() and (story.aim_target_line() or story.aim_target_marker()) then
        local aim_indices={1,8,9}
        local aim_index=aim_indices[(story.aim_bone() or 0)+1] or 1
        for _,target in ipairs(targets) do
            if target.selected and target.bones and target.bones[aim_index] then
                local point=target.bones[aim_index]
                if point.visible then
                    if story.aim_target_line() then
                        draw.line(ctx.screen_w()*.5,ctx.screen_h()*.5,point.x,point.y,
                            palette.accent[1],palette.accent[2],palette.accent[3],190,1.25)
                    end
                    if story.aim_target_marker() then
                        draw.circle(point.x,point.y,3.25,
                            palette.accentHi[1],palette.accentHi[2],palette.accentHi[3],240)
                    end
                end
            end
        end
    end
    if story.esp_enabled() then
    local pr,pg,pb,pa=story.esp_primary_color()
    local sr,sg,sb,sa=story.esp_secondary_color()
    local fr,fg,fb,fa=story.esp_friend_color()
    local mr,mg,mb,ma=story.esp_marker_color()
    local nr,ng,nb,na=story.esp_snapline_color()
    local primary,secondary,friend,marker,snap_color={pr,pg,pb,pa},{sr,sg,sb,sa},{fr,fg,fb,fa},{mr,mg,mb,ma},{nr,ng,nb,na}
    local mode=story.esp_color_mode()
    local rainbow_phase=ctx.time()*math.max(.05,story.esp_rainbow_speed())*.18
    local function esp_color(target,t)
        if target.friend then return friend end
        if mode==1 then
            local r,g,b=util.hsv_to_rgb((rainbow_phase+t*.22)%1,1,1)
            return {r,g,b,primary[4]}
        end
        if mode==2 then return mix_color(primary,secondary,t) end
        return primary
    end
    local function esp_line(x1,y1,x2,y2,target,t1,t2,alpha,thickness)
        if target.friend or mode==0 then
            local c=esp_color(target,0)
            draw.line(x1,y1,x2,y2,c[1],c[2],c[3],math.floor(c[4]*alpha),thickness)
            return
        end
        for segment=0,7 do
            local a,b=segment/8,(segment+1)/8
            local c=esp_color(target,t1+(t2-t1)*(a+b)*.5)
            draw.line(x1+(x2-x1)*a,y1+(y2-y1)*a,x1+(x2-x1)*b,y1+(y2-y1)*b,
                c[1],c[2],c[3],math.floor(c[4]*alpha),thickness)
        end
    end
    local function bone_line(bones,a,b,color)
        local p1,p2=bones[a],bones[b]
        if p1 and p2 and p1.visible and p2.visible then
            draw.line(p1.x,p1.y,p2.x,p2.y,color[1],color[2],color[3],color[4],1.25)
        end
    end
    for _,target in ipairs(targets) do
      if not target.friend or story.esp_show_friends() then
        local joint_height=math.abs(target.feet_y-target.head_y)
        local on_screen=target.head_x>=0 and target.head_x<=ctx.screen_w() and target.head_y>=0 and target.head_y<=ctx.screen_h()
        if not on_screen and story.esp_offscreen() then
            local edge_x=math.max(16,math.min(ctx.screen_w()-16,target.head_x))
            local edge_y=math.max(16,math.min(ctx.screen_h()-16,target.head_y))
            local edge_color=target.friend and friend or marker
            draw.circle_outline(edge_x,edge_y,6,edge_color[1],edge_color[2],edge_color[3],edge_color[4],1.5)
        elseif joint_height>4 and joint_height<ctx.screen_h()*1.5 then
            -- The stored head joint projects near the face/neck, not the top
            -- of the skull. Extend the box by a fraction of projected stature
            -- so its upper edge actually encloses the visible head.
            local top=math.min(target.head_y,target.feet_y)-joint_height*.095
            local bottom=math.max(target.head_y,target.feet_y)+joint_height*.015
            local height=bottom-top
            local width=math.max(height*.40,math.abs(target.feet_x-target.head_x)+height*.28)
            local center_x=(target.head_x+target.feet_x)*.5
            local left=center_x-width*.5
            local color=target.friend and friend or marker
            if story.esp_snaplines() then
                local origin=story.esp_snapline_origin()
                local start_y=origin==1 and ctx.screen_h()*.5 or (origin==2 and 2 or ctx.screen_h()-2)
                local endpoint=story.esp_snapline_end()
                local end_x=endpoint==2 and target.head_x or (endpoint==1 and center_x or target.feet_x)
                local end_y=endpoint==2 and target.head_y or (endpoint==1 and (top+bottom)*.5 or bottom)
                local start_x=ctx.screen_w()*.5
                local line_weight=story.esp_snapline_thickness()
                if mode==2 and not target.friend then
                    for segment=0,7 do
                        local a,b=segment/8,(segment+1)/8
                        local sc=mix_color(snap_color,secondary,(a+b)*.5)
                        draw.line(start_x+(end_x-start_x)*a,start_y+(end_y-start_y)*a,
                            start_x+(end_x-start_x)*b,start_y+(end_y-start_y)*b,
                            sc[1],sc[2],sc[3],math.floor(sc[4]*.75),line_weight)
                    end
                else
                    local sc=target.friend and friend or (mode==1 and esp_color(target,.5) or snap_color)
                    draw.line(start_x,start_y,end_x,end_y,
                        sc[1],sc[2],sc[3],math.floor(sc[4]*.75),line_weight)
                end
            end
            if story.esp_boxes() then
                local style=story.esp_box_style()
                local thick=story.esp_box_thickness()
                if style==1 then
                    local cw,ch=width*.25,(bottom-top)*.18
                    esp_line(left,top,left+cw,top,target,0,0,.85,thick)
                    esp_line(left,top,left,top+ch,target,0,.18,.85,thick)
                    esp_line(left+width,top,left+width-cw,top,target,0,0,.85,thick)
                    esp_line(left+width,top,left+width,top+ch,target,0,.18,.85,thick)
                    esp_line(left,bottom,left+cw,bottom,target,1,1,.85,thick)
                    esp_line(left,bottom,left,bottom-ch,target,1,.82,.85,thick)
                    esp_line(left+width,bottom,left+width-cw,bottom,target,1,1,.85,thick)
                    esp_line(left+width,bottom,left+width,bottom-ch,target,1,.82,.85,thick)
                elseif style==2 then
                    local upper,lower=esp_color(target,0),esp_color(target,1)
                    draw.rect_gradient(left,top,left+width,bottom,
                        upper[1],upper[2],upper[3],math.floor(upper[4]*.15),upper[1],upper[2],upper[3],math.floor(upper[4]*.15),
                        lower[1],lower[2],lower[3],math.floor(lower[4]*.15),lower[1],lower[2],lower[3],math.floor(lower[4]*.15))
                    esp_line(left,top,left+width,top,target,0,0,.85,thick)
                    esp_line(left,bottom,left+width,bottom,target,1,1,.85,thick)
                    esp_line(left,top,left,bottom,target,0,1,.85,thick)
                    esp_line(left+width,top,left+width,bottom,target,0,1,.85,thick)
                else
                    esp_line(left,top,left+width,top,target,0,0,.85,thick)
                    esp_line(left,bottom,left+width,bottom,target,1,1,.85,thick)
                    esp_line(left,top,left,bottom,target,0,1,.85,thick)
                    esp_line(left+width,top,left+width,bottom,target,0,1,.85,thick)
                end
            end
            if story.esp_head_dot() then draw.circle(target.head_x,target.head_y,2.75,color[1],color[2],color[3],230) end
            if story.esp_health() then
                local bar_x=left-5
                draw.rect(bar_x,top,bar_x+3,bottom,12,10,18,210,1)
                local filled=(bottom-top)*math.max(0,math.min(1,target.health))
                draw.rect(bar_x,bottom-filled,bar_x+3,bottom,
                    palette.green[1],palette.green[2],palette.green[3],240,1)
            end
            if story.esp_armor() and target.armor>0 then
                local bar_x=left+width+2
                draw.rect(bar_x,top,bar_x+3,bottom,12,10,18,210,1)
                local filled=(bottom-top)*math.max(0,math.min(1,target.armor))
                draw.rect(bar_x,bottom-filled,bar_x+3,bottom,80,160,255,235,1)
            end
            if story.esp_skeleton() and target.bones then
                local b=target.bones
                -- Direct CPed bone array: head, feet, ankles, hands, neck, abdomen.
                bone_line(b,1,8,color); bone_line(b,8,9,color)
                bone_line(b,9,6,color); bone_line(b,9,7,color)
                bone_line(b,9,4,color); bone_line(b,9,5,color)
                bone_line(b,4,2,color); bone_line(b,5,3,color)
            end
            if story.esp_distance_text() then
                local label=string.format("%.0fm",target.distance)
                text.draw_centered(font.tiny,left,bottom+3,left+width,
                    palette.dim[1],palette.dim[2],palette.dim[3],220,label)
            end
            if story.esp_names() and target.label then
                local prefix=target.friend and "[FRIEND] " or ""
                local name_color=target.friend and friend or palette.text
                text.draw_centered(font.tiny,left,top-13,left+width,
                    name_color[1],name_color[2],name_color[3],225,prefix..target.label)
            end
            if story.esp_weapon() and target.weapon_label and target.weapon_label~="" then
                text.draw_centered(font.tiny,left,bottom+14,left+width,
                    palette.faint[1],palette.faint[2],palette.faint[3],210,target.weapon_label)
            end
            if story.esp_vitals_text() then
                local vitals=string.format("HP %d  AR %d",math.floor(target.health*100),math.floor(target.armor*100))
                text.draw(font.tiny,left+width+7,top,
                    palette.dim[1],palette.dim[2],palette.dim[3],210,vitals)
            end
        end
      end
    end
    end
    if story.vehicle_esp() then
        for _,vehicle in ipairs(story.vehicles()) do
            local height=math.abs(vehicle.bottom_y-vehicle.top_y)
            if height>3 and height<ctx.screen_h()*1.5 then
                local width=height*1.35
                local left=vehicle.top_x-width*.5
                local top=math.min(vehicle.top_y,vehicle.bottom_y)
                local bottom=math.max(vehicle.top_y,vehicle.bottom_y)
                draw.rect_outline(left,top,left+width,bottom,
                    palette.accent[1],palette.accent[2],palette.accent[3],190,2,1.2,true)
                if story.vehicle_health() then
                    local filled=width*math.max(0,math.min(1,vehicle.health))
                    draw.rect(left,bottom+2,left+width,bottom+5,12,10,18,210,1)
                    draw.rect(left,bottom+2,left+filled,bottom+5,
                        palette.green[1],palette.green[2],palette.green[3],230,1)
                end
                if story.vehicle_names() then
                    text.draw_centered(font.tiny,left,top-13,left+width,
                        palette.accentHi[1],palette.accentHi[2],palette.accentHi[3],220,vehicle.label)
                end
            end
        end
    end
    if story.object_esp() then
        for _,object in ipairs(story.objects()) do
            draw.circle_outline(object.x,object.y,3,
                palette.accentHi[1],palette.accentHi[2],palette.accentHi[3],190,1)
            if story.object_names() then
                local label=object.label..string.format("  %.0fm",object.distance)
                text.draw(font.tiny,object.x+6,object.y-6,
                    palette.dim[1],palette.dim[2],palette.dim[3],205,label)
            end
        end
    end
    if story.diagnostics() then
        local vehicles=story.vehicle_esp() and story.vehicles() or {}
        local objects=story.object_esp() and story.objects() or {}
        local line=string.format("Peds %d  Vehicles %d  Objects %d  Friends %d  Redirects %d",
            #targets,#vehicles,#objects,story.friend_count(),story.redirect_count())
        draw.rect(18,ctx.screen_h()-48,560,ctx.screen_h()-16,
            palette.panel[1],palette.panel[2],palette.panel[3],225,6)
        text.draw(font.small,28,ctx.screen_h()-39,
            palette.text[1],palette.text[2],palette.text[3],225,line)
    end
end

local sidebar_nav_scroll=0
local sidebar_last_active=-1
local function sidebar_entries()
    if menu.build_tabs then menu.build_tabs() end
    local sections={{title="Combat",entries={}},{title="World",entries={}},{title="Visuals",entries={}},{title="Misc",entries={}}}
    local categories={Home=1,Self=1,Player=1,Online=1,Combat=1,Weapon=1,Vehicle=1,
        Teleport=2,Domain=2,Visuals=3,["VFX's"]=3,UI=3,Misc=4,Cloud=4,Settings=4}
    for index=0,(menu.tab_count and menu.tab_count() or 0)-1 do
        local name=menu.tab_name(index)
        if name~="Home" then
            local section=sections[categories[name] or 4]
            section.entries[#section.entries+1]={name=name,label=name=="Combat" and "Aimbot" or name,index=index}
        end
    end
    local entries,offset={},0
    for _,section in ipairs(sections) do
        if #section.entries>0 then
            if offset>0 then offset=offset+20 end
            if ui_options.sidebar_labels then entries[#entries+1]={title=section.title,y=offset}; offset=offset+21 end
            for _,entry in ipairs(section.entries) do entry.y=offset; entries[#entries+1]=entry; offset=offset+32 end
        end
    end
    return entries,offset
end
local function render_sidebar(ox,oy,sidebar,height,radius)
    local logo_x,logo_y=ox+22,oy+(62-text.height(logo_font))*.5
    txt(logo_font,logo_x,logo_y,palette.logoNen,"Nen")
    txt(logo_font,logo_x+text.width(logo_font,"Nen"),logo_y,palette.logoYoo,"yoo")
    local entries,total=sidebar_entries()
    local active=menu.tab_active and menu.tab_active() or 0
    local nav_top,nav_bottom=oy+70,oy+height-18
    local nav_h=nav_bottom-nav_top
    local maximum=math.max(0,total-nav_h)
    local selected=nil
    for _,entry in ipairs(entries) do if entry.index==active then selected=entry end end
    if active~=sidebar_last_active and selected then
        if selected.y<sidebar_nav_scroll then sidebar_nav_scroll=selected.y end
        if selected.y+32>sidebar_nav_scroll+nav_h then sidebar_nav_scroll=selected.y+32-nav_h end
        sidebar_last_active=active
    end
    if inside(ox,nav_top,sidebar,nav_h) then sidebar_nav_scroll=sidebar_nav_scroll-input.mouse_wheel()*32*ui_options.scroll_speed/70 end
    sidebar_nav_scroll=math.max(0,math.min(maximum,sidebar_nav_scroll))
    draw.push_clip(ox,nav_top,ox+sidebar,nav_bottom)
    if selected then
        local target=selected.y-sidebar_nav_scroll
        local sy=nav_top+motion_to("sidebar_active_y",target,20,target)
        fill(ox+4,sy,sidebar-8,32,palette.side,2)
    end
    for _,entry in ipairs(entries) do
        local x,y=ox+22,nav_top+entry.y-sidebar_nav_scroll
        if entry.title then txt(font.small,x,y+4,palette.faint,entry.title)
        else
            local active_row=entry.index==active
            local hovered=inside(ox+4,y,sidebar-8,32) and inside(ox,nav_top,sidebar,nav_h)
            local tint=active_row and palette.accentHi or (hovered and palette.text or palette.dim)
            if ui_options.sidebar_icons then nav_icon(entry.name,x+7,y+16,tint) end
            local label_offset=ui_options.sidebar_icons and 26 or 0
            txt_ellipsis(font.item,x+label_offset,y+(32-text.height(font.item))*.5,tint,entry.label,sidebar-30-label_offset)
            if hovered and input.mouse_clicked(0) and not active_row then request_navigation("tab",entry.index) end
        end
    end
    draw.pop_clip()
    if maximum>0 then
        local thumb=math.max(24,nav_h*nav_h/total)
        fill(ox+sidebar-3,nav_top+(nav_h-thumb)*sidebar_nav_scroll/maximum,2,thumb,palette.dim,1,100)
    end
end
local header_scroll,header_last={},{ }
local function header_tabs()
    local page_id,page_name=menu.page_id(),menu.page_name()
    -- Home is the opening welcome screen, without a navigation tab.
    if page_id==items.joaat("Home") then return {} end
    local tabs={}
    if settings_section_for(page_id) then
        for _,name in ipairs(settings_tab_names) do
            tabs[#tabs+1]={name=name,kind="settings",target=name,active=settings_tab==name}
        end
        return tabs
    end
    if page_name=="Combat" or page_name=="Lock-on Aimbot" or page_name=="Silent Aim" or page_name=="Magic Bullet" then
        if page_name=="Lock-on Aimbot" then combat_tab=1 elseif page_name=="Silent Aim" then combat_tab=2 elseif page_name=="Magic Bullet" then combat_tab=3 end
        for _,tab in ipairs(combat_tabs_list()) do
            tabs[#tabs+1]={name=tab.name,kind="combat",target=tab.index,active=combat_tab==tab.index}
        end
        return tabs
    end
    local visual_root,selected=visual_section_for(page_id,page_name)
    if visual_root then
        if selected then visual_tabs[visual_root]=selected end
        for _,tab in ipairs(visuals_tabs_list(visual_root)) do
            tabs[#tabs+1]={name=tab.name,kind=visual_root=="VFX's" and "vfx" or "visuals",
                target=tab.name,active=visual_tabs[visual_root]==tab.name}
        end
        return tabs
    end
    local active=menu.tab_active and menu.tab_active() or 0
    local root_name=menu.tab_name(active)
    local root_id=items.joaat(root_name)
    tabs[1]={name=page_name=="Home" and "Main" or root_name,kind="page",target=root_id,active=page_id==root_id}
    if root_name~="Settings" then
        for _,handle in ipairs(items.page_items(root_id)) do
            local item=items.at(handle)
            if item and item.type==item_type.sub_menu then
                local child=items.submenu_page_id(handle)
                if child and child~=0 then tabs[#tabs+1]={name=item.name,kind="page",target=child,active=page_id==child} end
            end
        end
    end
    return tabs
end
local function header_layout(ox,oy,width,sidebar)
    local tabs=header_tabs()
    local key=tostring(menu.tab_active and menu.tab_active() or 0)
    local x,y,w,h=ox+sidebar+18,oy+5,width-sidebar-106,53
    local offset,selected=0,nil
    for _,tab in ipairs(tabs) do
        tab.label=string.upper(tab.name)
        tab.x=offset; tab.w=text.width(font.breadcrumb,tab.label)+28
        if tab.active then selected=tab end
        offset=offset+tab.w
    end
    local overflowing=offset>w
    local arrow=overflowing and 18 or 0
    local vx,vw=x+arrow,w-arrow*2
    local maximum=math.max(0,offset-vw)
    local current=math.max(0,math.min(maximum,header_scroll[key] or 0))
    if selected and header_last[key]~=selected.name then
        if selected.x<current then current=selected.x end
        if selected.x+selected.w>current+vw then current=selected.x+selected.w-vw end
    end
    return tabs,key,x,y,w,h,vx,vw,current,maximum,overflowing,selected
end
local function header_tools_hit(ox,oy,width,sidebar)
    local search_x=ox+width-78
    if inside(search_x,oy+18,32,28) or inside(ox+width-38,oy+18,28,28) then return true end
    local reveal=motion_values.search_reveal or 0
    if search_expanded or reveal>.01 then
        local box_w=math.min(240,width-sidebar-120)*(.92+.08*reveal)
        if inside(search_x-box_w-8,oy+18,box_w,28) then return true end
    end
    return false
end
local function header_can_drag(ox,oy,width,sidebar)
    if not inside(ox,oy,width,62) or header_tools_hit(ox,oy,width,sidebar) then return false end
    local tabs,_,x,y,w,h,vx,vw,current,_,overflowing=header_layout(ox,oy,width,sidebar)
    if overflowing and (inside(x,y,18,h) or inside(x+w-18,y,18,h)) then return false end
    if inside(vx,y,vw,h) then
        for _,tab in ipairs(tabs) do
            if inside(vx+tab.x-current,y,tab.w,h) then return false end
        end
    end
    return true
end
local preview_position,preview_drag,preview_viewport=nil,nil,nil
local preview_offsets=nil
local function preview_menu_origin(sidebar,width,height)
    local scale=ctx.ui_scale()
    local viewport_w,viewport_h=ctx.screen_w()/scale,ctx.screen_h()/scale
    local left,top,bottom=16/scale,40/scale,16/scale
    local right=math.max(left,viewport_w-width-left)
    local lower=math.max(top,viewport_h-height-bottom)
    local function clamp(value,low,high) return math.max(low,math.min(high,value)) end
    local function offset(name)
        local handle=items.get("Settings",name)
        local item=handle and items.at(handle)
        return item and item.f_val or 0
    end
    local offsets={x=offset("Menu Offset X"),y=offset("Menu Offset Y")}
    if preview_recenter then
        preview_position,preview_drag,preview_offsets=nil,nil,nil
        preview_recenter=false
    end
    if not preview_position then
        preview_position={x=(viewport_w-width)*.5+offsets.x,y=(viewport_h-height)*.5+offsets.y}
    elseif preview_viewport and (viewport_w~=preview_viewport.w or viewport_h~=preview_viewport.h) then
        -- Preserve the menu's relative centre when its scale or workspace changes.
        preview_position.x=(preview_position.x+width*.5)*viewport_w/preview_viewport.w-width*.5
        preview_position.y=(preview_position.y+height*.5)*viewport_h/preview_viewport.h-height*.5
        preview_drag=nil
    end
    if preview_offsets then
        if offsets.x~=preview_offsets.x then preview_position.x=(viewport_w-width)*.5+offsets.x end
        if offsets.y~=preview_offsets.y then preview_position.y=(viewport_h-height)*.5+offsets.y end
    end
    preview_offsets=offsets
    preview_viewport={w=viewport_w,h=viewport_h}
    preview_position.x=clamp(preview_position.x,left,right)
    preview_position.y=clamp(preview_position.y,top,lower)
    if input.mouse_clicked(0) and header_can_drag(preview_position.x,preview_position.y,width,sidebar) then
        preview_drag={x=input.mouse_x()-preview_position.x,y=input.mouse_y()-preview_position.y}
        input.consume_mouse_click()
    end
    if preview_drag then
        if input.mouse_down(0) then
            preview_position.x=clamp(input.mouse_x()-preview_drag.x,left,right)
            preview_position.y=clamp(input.mouse_y()-preview_drag.y,top,lower)
        else preview_drag=nil end
    end
    -- Keep the existing menu bounds in sync without altering game offsets.
    menu.drag_header(preview_position.x,preview_position.y,width,62,false)
    return preview_position.x,preview_position.y
end
local function menu_display_scale()
    return ctx.ui_scale()/(ctx.ui_dpi_scale and ctx.ui_dpi_scale() or 1)
end
local function close_quick_settings()
    quick_open=false; quick_section=nil
    if quick_color then close_color_popup(); quick_color=false end
end
local function quick_rects()
    if not quick_anchor then return end
    local vw,vh=ctx.screen_w()/ctx.ui_scale(),ctx.screen_h()/ctx.ui_scale()
    local w,h=280,364
    local x=math.max(8,math.min(vw-w-8,quick_anchor.x+quick_anchor.w-w))
    local y=math.max(8,math.min(vh-h-8,quick_anchor.y+quick_anchor.h+9))
    local sub_w=232
    local sub_h=quick_section=="language" and math.min(10,i18n.count())*30+38 or 256
    sub_h=math.min(sub_h,vh-16)
    local sub_x=x+w+6
    if sub_x+sub_w>vw-8 then sub_x=x-sub_w-6 end
    sub_x=math.max(8,math.min(vw-sub_w-8,sub_x))
    local offset=quick_section=="language" and 78 or (quick_section=="menu_scale" and 114 or 150)
    local sub_y=math.max(8,math.min(vh-sub_h-8,y+offset))
    return x,y,w,h,sub_x,sub_y,sub_w,sub_h
end
local function quick_input()
    if not quick_open then return false end
    if color_open then return true end
    if input.key_just_pressed(VK.ESCAPE) then
        if quick_section then quick_section=nil else close_quick_settings() end
        return true
    end
    local x,y,w,h,sx,sy,sw,sh=quick_rects()
    if not x then close_quick_settings(); return true end
    if input.mouse_clicked(0) then
        if inside(quick_anchor.x,quick_anchor.y,quick_anchor.w,quick_anchor.h) then
            close_quick_settings(); input.consume_mouse_click()
        elseif not inside(x,y,w,h) and not (quick_section and inside(sx,sy,sw,sh)) then
            close_quick_settings(); input.consume_mouse_click()
        end
    end
    return true
end
local function quick_icon(x,y)
    quick_anchor={x=x-14,y=y-14,w=28,h=28}
    nav_icon("Settings",x,y,quick_open and palette.accentHi or (inside(x-14,y-14,28,28) and palette.text or palette.dim))
    if clicked(x-14,y-14,28,28) then
        quick_open=not quick_open; quick_section=nil
        if quick_open then
            search_expanded,search_focus=false,false; search,search_popup_query="",""
            search_popup_bounds=nil; option_open,option_anchor=nil,nil
            close_color_popup(); quick_color=false
        end
        input.consume_mouse_click()
    end
end
local function quick_glyph(kind,x,y,color)
    if kind=="language" then
        draw.circle_outline(x,y,6,color[1],color[2],color[3],color[4],1)
        line(x-6,y,x+6,y,color,1); line(x,y-6,x,y+6,color,1)
        line(x-4,y-4,x+4,y-4,color,1); line(x-4,y+4,x+4,y+4,color,1)
    elseif kind=="style" then
        fill(x-6,y-6,12,12,palette.accent,3)
    elseif kind=="animations" then
        line(x-4,y-6,x+4,y,color,1.3); line(x+4,y,x-4,y+6,color,1.3)
    elseif kind=="settings" then nav_icon("Settings",x,y,color)
    elseif kind=="welcome" then nav_icon("Home",x,y,color)
    else
        outline(x-6,y-5,12,10,color,1,1)
        line(x-3,y+8,x+3,y+8,color,1)
    end
end
local function draw_quick_settings(radius)
    if not quick_open then return end
    local x,y,w,h,sx,sy,sw,sh=quick_rects()
    if not x then return end
    local popup_bg={19,22,26,255}
    fill(x+2,y+5,w,h,{0,0,0,90},12)
    fill(x,y,w,h,popup_bg,12)
    outline(x,y,w,h,{255,255,255,14},12)
    local username=ui.username()
    fill(x+16,y+16,38,38,palette.side,19)
    txt(font.item,x+30,y+28,palette.accentHi,string.upper(username:sub(1,1)))
    txt_ellipsis(font.item,x+66,y+19,palette.text,username,w-82)
    txt(font.small,x+66,y+39,palette.dim,"Nenyoo")
    line(x+12,y+66,x+w-12,y+66,palette.border,1)
    local language="English"
    for index=1,i18n.count() do if i18n.code(index)==i18n.active() then language=i18n.label(index); break end end
    local auto=items.get("Settings","Auto UI Scale")
    local menu_scale=items.get("Settings","UI Scale")
    local overlay_scale=items.get("Settings","Overlays/Panels Scale")
    local function scale_text(handle)
        local item=handle and items.at(handle)
        if item and handle==menu_scale and ui.preview_canvas and menu_display_scale()+.005<item.f_val then
            return string.format("Fit: %.0f%%",menu_display_scale()*100)
        end
        return item and string.format("%.0f%%",item.f_val*100) or "Unavailable"
    end
    local auto_item=auto and items.at(auto)
    local rows={
        {id="language",label="Language",value=language},
        {id="menu_scale",label="Menu Scale",value=auto_item and auto_item.on and "Auto" or scale_text(menu_scale)},
        {id="overlay_scale",label="Overlay Scale",value=scale_text(overlay_scale)},
        {id="style",label="Style",value="Accent"},
        {id="animations",label="Animations",value=motion_enabled and "On" or "Off"},
        {id="settings",label="All Settings",value=""},
        {id="welcome",label="Welcome",value=""}
    }
    for index,entry in ipairs(rows) do
        local ry=y+78+(index-1)*38
        local hot=inside(x+8,ry,w-16,34)
        if hot or quick_section==entry.id then fill(x+8,ry,w-16,34,palette.side,6) end
        quick_glyph(entry.id,x+26,ry+17,palette.dim)
        txt_ellipsis(font.item,x+46,ry+(34-text.height(font.item))*.5,palette.text,entry.label,112)
        if entry.id=="style" then
            local handle=items.get("Nenyoo Appearance","Accent")
            fill(x+w-40,ry+8,18,18,palette.accent,4)
            color_swatch(handle,x+w-40,ry+8,18,18)
            if color_open==handle then quick_color=true; quick_section=nil end
        else
            local value_w=math.min(90,text.width(font.value,entry.value))
            txt_ellipsis(font.value,x+w-32-value_w,ry+(34-text.height(font.value))*.5,palette.dim,entry.value,90)
            line(x+w-21,ry+13,x+w-17,ry+17,palette.dim,1.2)
            line(x+w-17,ry+17,x+w-21,ry+21,palette.dim,1.2)
        end
        if hot and input.mouse_clicked(0) then
            if entry.id=="animations" then
                local handle=items.get("Motion","Animations Enabled"); if handle then items.toggle(handle) end
                quick_section=nil
            elseif entry.id=="settings" or entry.id=="welcome" then
                close_quick_settings()
                local destination=entry.id=="welcome" and "Home" or "Settings"
                for tab=0,(menu.tab_count and menu.tab_count() or 0)-1 do
                    if menu.tab_name(tab)==destination then request_navigation("tab",tab); break end
                end
            elseif entry.id=="style" then
                local handle=items.get("Nenyoo Appearance","Accent")
                if handle and not color_open then
                    color_open=handle; color_anchor={x=x+w-40,y=ry+8,w=18,h=18}; color_seen=true; quick_color=true
                end
                quick_section=nil
            else
                quick_section=quick_section==entry.id and nil or entry.id
                quick_scroll=0
                if quick_section=="language" then
                    for i=1,i18n.count() do if i18n.code(i)==i18n.active() then quick_scroll=math.max(0,i-5); break end end
                end
            end
            input.consume_mouse_click()
        end
    end
    if not quick_section then return end
    -- Recompute after opening a different flyout this frame.
    x,y,w,h,sx,sy,sw,sh=quick_rects()
    local entries={}
    if quick_section=="language" then
        for i=1,i18n.count() do entries[#entries+1]={label=i18n.label(i),code=i18n.code(i),selected=i18n.code(i)==i18n.active()} end
    else
        local handle=quick_section=="menu_scale" and menu_scale or overlay_scale
        local item=handle and items.at(handle)
        if quick_section=="menu_scale" and auto_item then entries[#entries+1]={label="Auto",auto=true,selected=auto_item.on} end
        if item then
            for _,value in ipairs({.5,.75,1,1.25,1.5,1.75,2}) do
                if value>=item.f_min and value<=item.f_max then
                    entries[#entries+1]={label=string.format("%.0f%%",value*100),value=value,handle=handle,
                        selected=math.abs(item.f_val-value)<.001 and not (quick_section=="menu_scale" and auto_item and auto_item.on)}
                end
            end
        end
    end
    local visible=math.max(1,math.floor((sh-38)/30))
    local maximum=math.max(0,#entries-visible)
    if inside(sx,sy,sw,sh) then quick_scroll=quick_scroll-input.mouse_wheel()*2 end
    quick_scroll=math.floor(math.max(0,math.min(maximum,quick_scroll)))
    fill(sx+2,sy+4,sw,sh,{0,0,0,85},10); fill(sx,sy,sw,sh,popup_bg,10)
    outline(sx,sy,sw,sh,{255,255,255,14},10)
    txt(font.small,sx+14,sy+12,palette.dim,quick_section=="language" and "Language" or (quick_section=="menu_scale" and "Menu Scale" or "Overlay Scale"))
    for i=quick_scroll+1,math.min(#entries,quick_scroll+visible) do
        local entry=entries[i]; local ry=sy+30+(i-quick_scroll-1)*30
        if inside(sx+6,ry,sw-12,28) or entry.selected then fill(sx+6,ry,sw-12,28,palette.side,5) end
        local label_x=sx+14
        if entry.code then flag(entry.code,sx+14,ry+7,21,14); label_x=sx+44 end
        txt_ellipsis(font.item,label_x,ry+(28-text.height(font.item))*.5,entry.selected and palette.accentHi or palette.text,entry.label,sw-(label_x-sx)-32)
        if entry.selected then
            line(sx+sw-23,ry+14,sx+sw-20,ry+17,palette.accentHi,1.2)
            line(sx+sw-20,ry+17,sx+sw-14,ry+10,palette.accentHi,1.2)
        end
        if clicked(sx+6,ry,sw-12,28) then
            if entry.code then i18n.set_active(entry.code)
            elseif entry.auto then if auto_item and not auto_item.on then items.toggle(auto) end
            else
                if quick_section=="menu_scale" and auto_item and auto_item.on then items.toggle(auto) end
                items.set_f_val(entry.handle,entry.value)
            end
            local resizing=quick_section=="menu_scale"
            quick_section=nil
            if resizing then close_quick_settings() end
            input.consume_mouse_click(); break
        end
    end
    if maximum>0 then
        local track=sh-42; local thumb=math.max(16,track*visible/#entries)
        fill(sx+sw-4,sy+34+(track-thumb)*quick_scroll/maximum,2,thumb,palette.dim,1,130)
    end
end

local function draw_topbar(ox,oy,width,sidebar,radius)
    local tabs,key,x,y,w,h,vx,vw,current,maximum,overflowing,selected=header_layout(ox,oy,width,sidebar)
    if selected then header_last[key]=selected.name end
    local tools_hovered=header_tools_hit(ox,oy,width,sidebar)
    if not tools_hovered and inside(vx,y,vw,h) then current=math.max(0,math.min(maximum,current-input.mouse_wheel()*75*ui_options.scroll_speed/70)) end
    if overflowing then
        txt(font.small,x+3,y+22,palette.dim,"<")
        txt(font.small,x+w-12,y+22,palette.dim,">")
        if not tools_hovered and clicked(x,y,18,h) then current=math.max(0,current-vw*.65) end
        if not tools_hovered and clicked(x+w-18,y,18,h) then current=math.min(maximum,current+vw*.65) end
    end
    header_scroll[key]=current
    draw.push_clip(vx,y,vx+vw,y+h)
    for _,tab in ipairs(tabs) do
        local tx=vx+tab.x-current
        local hovered=not tools_hovered and inside(tx,y,tab.w,h) and inside(vx,y,vw,h)
        txt(font.breadcrumb,tx+14,y+(h-text.height(font.breadcrumb))*.5,
            tab.active and palette.text or (hovered and palette.text or palette.dim),tab.label)
        if tab.active and ui_options.tab_underline then fill(tx+5,y+h-1,tab.w-10,1,palette.accent,0) end
        if hovered and input.mouse_clicked(0) and not tab.active then request_navigation(tab.kind,tab.target) end
    end
    draw.pop_clip()
    compact_search(ox+width-78,oy+18,math.min(240,width-sidebar-120),28,3)
    quick_icon(ox+width-24,oy+32)
end
local function draw_menu_body(sidebar,radius)
    content_alpha,content_offset,content_progress=update_transition()
    if menu.page_id()==items.joaat("Home") or menu.page_name()=="" then
        draw_welcome_surface(radius)
        return
    end
    welcome_resize=nil
    local active_tab=menu.tab_active and menu.tab_active()
    if active_tab and menu.tab_name(active_tab)~="Home" then welcome_return_tab=active_tab end
    local width,height=ui.win_w,ui.win_h
    local ox,oy
    if ui.preview_canvas then
        local scale=ctx.ui_scale()
        fill(0,0,ctx.screen_w()/scale,ctx.screen_h()/scale,{51,65,85,255},0)
        local hint="Drag empty space in the top bar to move the menu"
        local scale_handle=items.get("Settings","UI Scale")
        local scale_item=scale_handle and items.at(scale_handle)
        local auto_handle=items.get("Settings","Auto UI Scale")
        local auto_item=auto_handle and items.at(auto_handle)
        if auto_item and not auto_item.on and scale_item and menu_display_scale()+.005<scale_item.f_val then
            hint=string.format("Menu fitted to %.0f%% (%.0f%% selected). Enlarge the preview for more space.",menu_display_scale()*100,scale_item.f_val*100)
        end
        txt_ellipsis(font.small,16/scale,14/scale,palette.faint,hint,(ctx.screen_w()-32)/scale)
        ox,oy=preview_menu_origin(sidebar,width,height)
    else
        local base_x,base_y=0,0
        if not ui.windowed then
            base_x=math.max(20,(ctx.screen_w()/ctx.ui_scale()-width)*.5)
            base_y=math.max(20,(ctx.screen_h()/ctx.ui_scale()-height)*.5)
        end
        local current_x,current_y=base_x,base_y
        if menu.drag_origin then current_x,current_y=menu.drag_origin(base_x,base_y,not ui.windowed) end
        local allow_drag=header_can_drag(current_x,current_y,width,sidebar)
        local off_x,off_y=menu.drag_header(base_x,base_y,width,62,not ui.windowed,allow_drag)
        ox,oy=base_x+off_x,base_y+off_y
    end
    draw_window_surfaces(ox,oy,width,height,sidebar,radius)
    render_sidebar(ox,oy,sidebar,height,radius)
    draw.push_motion(content_offset,0,content_alpha)
    draw_page(ox+sidebar,oy+62,width-sidebar,height-62,radius)
    draw.pop_motion()
    draw_topbar(ox,oy,width,sidebar,radius)
    menu.set_content_rect(ox+sidebar,oy+62,width-sidebar,height-62)
end
function draw_menu()
    local color_blocks_pointer=color_popup_input()
    local quick_blocks_pointer=quick_input()
    local welcome_blocks_pointer=welcome_popup_input()
    search_popup_click=false
    if not color_blocks_pointer and not quick_blocks_pointer and not welcome_blocks_pointer then
        if search_focus and search_popup_bounds and input.mouse_clicked(0) and
            inside(search_popup_bounds.x,search_popup_bounds.y,
                search_popup_bounds.w,search_popup_bounds.h) then
            search_popup_click=true
            input.consume_mouse_click()
        end
        option_popup_input()
    end
    if search_target and ctx.time()>=search_target.expires then search_target=nil end
    option_seen=false
    color_seen=false
    aim_keybind_seen=false
    local sidebar,radius=sync_settings()
    if color_blocks_pointer or quick_blocks_pointer or welcome_blocks_pointer then
        input.with_pointer_blocked(function() draw_menu_body(sidebar,radius) end)
    else
        draw_menu_body(sidebar,radius)
    end
    if color_blocks_pointer then input.with_pointer_blocked(function() draw_quick_settings(radius) end)
    else draw_quick_settings(radius) end
    if not aim_keybind_seen then ui.cancel_menu_keybind(aim_keybind_id) end
    if option_open and not option_seen then option_open,option_anchor=nil,nil end
    if color_open and not color_seen then close_color_popup() end
    draw_option_popup(radius)
    draw_color_popup(radius)
    draw_welcome_dropdown()
end

-- Matches the GTAV Nenyoo cursor: a precise dot, eased accent ring, soft glow,
-- and a short click ripple. Coordinates are physical pixels; the renderer may
-- scale the UI canvas, so divide only at the draw boundary.
local cursor_x,cursor_y=-1,-1
local cursor_press=0
local cursor_pulse=-1
local function cursor_ease(speed,dt)
    return dt<=0 and 1 or 1-math.exp(-speed*dt)
end
__overlay_draws=__overlay_draws or {}
__overlay_draws.cursor=function()
    if ui.windowed or not ui.menu_open() then
        cursor_x,cursor_y=-1,-1
        return
    end
    local mx,my=input.mouse_x(),input.mouse_y()
    local dt,t=ctx.delta(),ctx.time()
    local scale=math.max(.01,ctx.ui_scale())
    local ar,ag,ab=theme.accent()
    if cursor_x<0 then cursor_x,cursor_y=mx,my end
    local k=cursor_ease(26,dt)
    cursor_x=cursor_x+(mx-cursor_x)*k
    cursor_y=cursor_y+(my-cursor_y)*k
    cursor_press=cursor_press+((input.mouse_down(0) and 1 or 0)-cursor_press)*cursor_ease(30,dt)
    if input.mouse_clicked(0) then cursor_pulse=t end
    local breathe=.5+.5*math.sin(t*2.2)
    local radius=10-cursor_press*3+breathe*.8
    local x,y=cursor_x*scale,cursor_y*scale
    local px,py=mx*scale,my*scale
    draw.circle(x,y,radius+7,ar,ag,ab,18)
    draw.circle(x,y,radius+3.5,ar,ag,ab,30)
    draw.circle_outline(x,y,radius,0,0,0,90,3)
    draw.circle_outline(x,y,radius,ar,ag,ab,math.floor(210+30*breathe),1.7)
    local dot=2+cursor_press*1.6
    draw.circle(px,py,dot+1.2,0,0,0,120)
    draw.circle(px,py,dot,255,255,255,255)
    if cursor_pulse>=0 then
        local e=(t-cursor_pulse)/.4
        if e<1 then
            draw.circle_outline(x,y,radius+e*18,ar,ag,ab,
                math.floor(190*(1-e)),1.6)
        else cursor_pulse=-1 end
    end
end
