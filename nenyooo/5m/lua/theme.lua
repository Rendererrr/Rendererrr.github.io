
-- nenyoo_builtin_theme_version=5
theme_full = true
menu.set_navigation_style("tabs")

local palette = {
    bg={13,11,20,255}, panel={18,15,27,255}, card={26,22,38,255},
    input={20,17,30,255}, side={30,24,46,255}, border={255,255,255,20},
    text={238,234,246,255}, dim={154,148,168,255}, faint={110,104,126,255},
    accent={168,85,247,255}, accentHi={192,132,252,255},
    accentLo={124,58,237,255}, green={52,211,130,255}
}

local function read_config()
    local out, raw = {}, file.read("theme_settings.ini")
    if type(raw) ~= "string" then return out end
    for key,value in raw:gmatch("([%w_]+)=([^\r\n]+)") do out[key]=value end
    return out
end
local saved=read_config()
local function num(key,fallback) return tonumber(saved[key]) or fallback end
local function saved_color(key,fallback)
    local value=saved[key]
    if not value then return table.unpack(fallback) end
    local r,g,b,a=value:match("(%d+),(%d+),(%d+),(%d+)")
    if not r then return table.unpack(fallback) end
    return tonumber(r),tonumber(g),tonumber(b),tonumber(a)
end

menu.clear_settings()
menu.add_setting_submenu("Nenyoo Appearance","Layout and complete Lua palette")
menu.add_sub_color("Accent",saved_color("accent",palette.accent))
menu.add_sub_color("Background",saved_color("background",palette.bg))
menu.add_sub_color("Panel",saved_color("panel",palette.panel))
menu.add_sub_slider("Sidebar Width",num("sidebar",250),190,330,1,"Left navigation width")
menu.add_sub_slider("Corner Radius",num("radius",8),0,18,1,"Cards and controls")
menu.add_setting_submenu("Typography","Font sizes are controlled by Lua")
menu.add_sub_slider("Title Size",num("title_size",36),24,48,1)
menu.add_sub_slider("Item Size",num("item_size",12),10,20,1)
menu.add_sub_slider("Small Size",num("small_size",8),8,16,1)
menu.add_sub_slider("Value Size",num("value_size",math.max(10,num("item_size",12)-1)),9,18,1)
menu.add_sub_slider("Description Size",num("desc_size",9),8,16,1)
menu.add_sub_slider("Section Label Size",num("label_size",8),8,14,1)
menu.add_sub_slider("Tagline Size",num("tagline_size",9),8,16,1)
menu.add_sub_slider("Overlay Text Size",num("tiny_size",8),7,14,1)
menu.add_setting_submenu("Motion","Restrained interface animation")
menu.add_sub_toggle("Animations Enabled",num("motion_enabled",1)~=0,"Enable interface transitions and ambient movement")
menu.add_sub_slider("Motion Speed",num("motion_speed",1),.5,2,.05,"Animation speed multiplier")

local motion_enabled=true
local motion_speed=1
local combat_tab=1
local visuals_tab="ESP"
local visuals_header_scroll=0
local visuals_header_last_tab=nil
local visuals_header_drag=false
local search_target=nil
local search_popup_bounds=nil
local search_popup_click=false

local function setting(name)
    local value=menu.get_setting(name)
    return type(value)=="table" and value or nil
end
local last_config=""
local function sync_settings()
    local accent,background,panel=setting("Accent"),setting("Background"),setting("Panel")
    if accent then palette.accent={accent.r,accent.g,accent.b,accent.a} end
    if background then palette.bg={background.r,background.g,background.b,background.a} end
    if panel then palette.panel={panel.r,panel.g,panel.b,panel.a} end
    local sidebar,radius=setting("Sidebar Width"),setting("Corner Radius")
    local title,item,small=setting("Title Size"),setting("Item Size"),setting("Small Size")
    local value,desc,label,tagline,tiny=setting("Value Size"),setting("Description Size"),setting("Section Label Size"),setting("Tagline Size"),setting("Overlay Text Size")
    local enabled_setting,speed_setting=setting("Animations Enabled"),setting("Motion Speed")
    local sv=sidebar and sidebar.f_val or 250
    local rv=radius and radius.f_val or 8
    local tv=title and title.f_val or 36
    local iv=item and item.f_val or 12
    local sm=small and small.f_val or 8
    local vv=value and value.f_val or 11
    local dv=desc and desc.f_val or 9
    local lv=label and label.f_val or 8
    local gv=tagline and tagline.f_val or 9
    local nv=tiny and tiny.f_val or 8
    motion_enabled=not enabled_setting or enabled_setting.on
    motion_speed=speed_setting and speed_setting.f_val or 1
    if ui.set_motion then ui.set_motion(motion_enabled,motion_speed) end
    local ar,ag,ab=palette.accent[1],palette.accent[2],palette.accent[3]
    palette.accentHi={math.min(255,ar+24),math.min(255,ag+47),math.min(255,ab+5),255}
    palette.accentLo={math.floor(ar*.74),math.floor(ag*.68),math.floor(ab*.96),255}
    theme.set_accent_palette(ar,ag,ab,palette.accent[4])
    theme.set_body_bg(table.unpack(palette.bg)); theme.set_menu_bg(table.unpack(palette.panel))
    text.set_size(font.title,tv); text.set_size(font.item,iv)
    text.set_size(font.value,vv); text.set_size(font.small,sm)
    text.set_size(font.breadcrumb,10); text.set_size(font.desc,dv)
    text.set_size(font.label,lv); text.set_size(font.tagline,gv); text.set_size(font.tiny,nv)
    text.set_weight(font.title,800); text.set_weight(font.item,500)
    text.set_weight(font.breadcrumb,600); text.set_weight(font.desc,400)
    text.set_weight(font.label,700); text.set_weight(font.tagline,500)
    text.set_weight(font.value,600); text.set_weight(font.small,400); text.set_weight(font.tiny,600)
    local xr,xg,xb,xa=table.unpack(palette.accent)
    local br,bg,bb,ba=table.unpack(palette.bg)
    local pr,pg,pb,pa=table.unpack(palette.panel)
    local encoded=string.format(
        "accent=%d,%d,%d,%d\r\nbackground=%d,%d,%d,%d\r\npanel=%d,%d,%d,%d\r\nsidebar=%.0f\r\nradius=%.0f\r\ntitle_size=%.0f\r\nitem_size=%.0f\r\nsmall_size=%.0f\r\nvalue_size=%.0f\r\ndesc_size=%.0f\r\nlabel_size=%.0f\r\ntagline_size=%.0f\r\ntiny_size=%.0f\r\nmotion_enabled=%d\r\nmotion_speed=%.2f\r\n",
        xr,xg,xb,xa,br,bg,bb,ba,pr,pg,pb,pa,
        sv,rv,tv,iv,sm,vv,dv,lv,gv,nv,motion_enabled and 1 or 0,motion_speed)
    if encoded~=last_config then last_config=encoded; file.write("theme_settings.ini",encoded) end
    return sv,rv
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
    if request.kind=="tab" then menu.switch_tab(request.target)
    elseif request.kind=="combat" then combat_tab=request.target
    elseif request.kind=="visuals" then
        visuals_tab=request.target
        if menu.page_id()~=items.joaat("Visuals") then menu.replace_page(items.joaat("Visuals")) end
    elseif request.kind=="search" then
        local target=request.target
        search_target=target.handle and {
            handle=target.handle,page_id=target.page_id,
            pending=true,expires=ctx.time()+3
        } or nil
        menu.navigate(target.page_id)
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
local function outline(x,y,w,h,color,radius,thickness)
    draw.rect_outline(x,y,x+w,y+h,color[1],color[2],color[3],color[4],radius or 0,thickness or 1)
end
local function line(x1,y1,x2,y2,color,thickness)
    draw.line(x1,y1,x2,y2,color[1],color[2],color[3],color[4],thickness or 1)
end
local function button(x,y,w,h,label,primary,radius)
    return ui.button(x,y,w,h,label,primary,false,false)
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
    local function band(rx,ry,rw,rh,c) fill(rx,ry,rw,rh,c,0) end
    local white={245,245,245,255}; local red={210,35,50,255}; local blue={35,70,150,255}
    if code=="fr" or code=="it" then
        local left=code=="fr" and {20,70,155,255} or {0,140,69,255}
        band(x,y,w/3,h,left); band(x+w/3,y,w/3,h,white); band(x+2*w/3,y,w/3,h,red)
    elseif code=="de" then
        band(x,y,w,h/3,{25,25,25,255}); band(x,y+h/3,w,h/3,{210,20,35,255}); band(x,y+2*h/3,w,h/3,{245,195,25,255})
    elseif code=="es" then
        band(x,y,w,h/4,red); band(x,y+h/4,w,h/2,{250,195,35,255}); band(x,y+3*h/4,w,h/4,red)
    elseif code=="ru" then
        band(x,y,w,h/3,white); band(x,y+h/3,w,h/3,{35,75,170,255}); band(x,y+2*h/3,w,h/3,red)
    elseif code=="pl" then
        band(x,y,w,h/2,white); band(x,y+h/2,w,h/2,{220,20,60,255})
    elseif code=="hi" then
        band(x,y,w,h/3,{255,153,51,255}); band(x,y+h/3,w,h/3,white); band(x,y+2*h/3,w,h/3,{19,136,8,255})
        draw.circle(x+w*.5,y+h*.5,h*.1,0,0,128,255)
    elseif code=="jp" or code=="kr" then
        band(x,y,w,h,white); draw.circle(x+w*.5,y+h*.5,h*.27,code=="jp" and 188 or 0,code=="jp" and 0 or 71,code=="jp" and 45 or 160,255)
    elseif code=="cn" then
        band(x,y,w,h,{222,41,16,255}); draw.circle(x+w*.24,y+h*.35,h*.15,255,222,0,255)
    elseif code=="pt" then
        band(x,y,w*.4,h,{0,102,51,255}); band(x+w*.4,y,w*.6,h,{206,17,38,255}); draw.circle(x+w*.4,y+h*.5,h*.15,245,205,45,255)
    elseif code=="br" then
        band(x,y,w,h,{0,135,60,255}); draw.circle(x+w*.5,y+h*.5,h*.3,255,220,0,255)
    elseif code=="tw" then
        band(x,y,w,h,{195,25,45,255}); band(x,y,w*.45,h*.55,{0,55,135,255}); draw.circle(x+w*.22,y+h*.27,h*.13,255,255,255,255)
    elseif code=="nl" then
        band(x,y,w,h/3,{174,28,40,255}); band(x,y+h/3,w,h/3,white); band(x,y+2*h/3,w,h/3,{33,70,139,255})
    elseif code=="id" then
        band(x,y,w,h/2,{206,17,38,255}); band(x,y+h/2,w,h/2,white)
    elseif code=="vi" then
        band(x,y,w,h,{210,32,40,255}); draw.circle(x+w*.5,y+h*.5,h*.23,255,220,0,255)
    elseif code=="uk" then
        band(x,y,w,h/2,{0,91,187,255}); band(x,y+h/2,w,h/2,{255,213,0,255})
    elseif code=="ro" then
        band(x,y,w/3,h,{0,43,127,255}); band(x+w/3,y,w/3,h,{252,209,22,255}); band(x+2*w/3,y,w/3,h,{206,17,38,255})
    elseif code=="cs" then
        band(x,y,w,h/2,white); band(x,y+h/2,w,h/2,{215,20,40,255}); band(x,y,w*.4,h,{17,69,126,255})
    elseif code=="sv" then
        band(x,y,w,h,{0,106,167,255}); band(x+w*.32,y,w*.15,h,{254,204,0,255}); band(x,y+h*.42,w,h*.16,{254,204,0,255})
    elseif code=="ar" then
        band(x,y,w,h,{80,55,120,255}); txt(font.small,x+3,y+1,white,"AR")
    elseif code=="th" then
        band(x,y,w,h/6,red); band(x,y+h/6,w,h/6,white); band(x,y+2*h/6,w,2*h/6,{45,42,74,255}); band(x,y+4*h/6,w,h/6,white); band(x,y+5*h/6,w,h/6,red)
    elseif code=="tr" then
        band(x,y,w,h,{227,10,23,255}); draw.circle(x+w*.4,y+h*.5,h*.24,255,255,255,255); draw.circle(x+w*.47,y+h*.5,h*.19,227,10,23,255)
    else
        band(x,y,w,h,{25,55,120,255}); band(x,y+h*.4,w,h*.2,white); band(x+w*.42,y,w*.18,h,white); band(x,y+h*.44,w,h*.12,red); band(x+w*.45,y,w*.12,h,red)
    end
    outline(x,y,w,h,{255,255,255,45},2)
end

local language_open=false
local language_scroll=0
local function language_picker(x,y,radius)
    local fw,fh,bw=22,14,36
    local picker_hover=inside(x-4,y-3,bw+8,fh+6)
    local hover_a=motion_to("language_hover",picker_hover and 1 or 0,24,0)
    if hover_a>.01 then fill(x-5,y-3,bw+8,fh+7,{255,255,255,22},6,math.floor(22*hover_a)) end
    flag(i18n.active(),x,y,fw,fh)
    line(x+27,y+5,x+30,y+8,palette.dim,1.4); line(x+30,y+8,x+33,y+5,palette.dim,1.4)
    if clicked(x-4,y-3,bw+8,fh+6) then
        language_open=not language_open
        if language_open then
            for i=1,i18n.count() do
                if i18n.code(i)==i18n.active() then language_scroll=math.max(0,i-5); break end
            end
        end
    end
    local popup=motion_to("language_popup",language_open and 1 or 0,22,0)
    if popup<.01 then return end
    local row_h,dw=28,190; local dx,dy=x+bw-dw,y+fh+8
    local visible_count=math.min(i18n.count(),10)
    local dh=visible_count*row_h+8
    local max_scroll=math.max(0,i18n.count()-visible_count)
    if inside(dx,dy,dw,dh) then
        language_scroll=math.max(0,math.min(max_scroll,
            language_scroll-input.mouse_wheel()*2))
    end
    language_scroll=math.floor(math.max(0,math.min(max_scroll,language_scroll)))
    draw.push_motion(0,-5*(1-popup),popup)
    fill(dx+2,dy+6,dw,dh,{0,0,0,120},radius); fill(dx,dy,dw,dh,palette.panel,radius); outline(dx,dy,dw,dh,palette.border,radius)
    draw.push_clip(dx+4,dy+4,dx+dw-4,dy+dh-4)
    for i=1,i18n.count() do
        local ry=dy+4+(i-1-language_scroll)*row_h
        if ry>=dy+4 and ry+row_h<=dy+dh-4 then
        local code=i18n.code(i); local active=code==i18n.active()
        local hov=inside(dx+4,ry,dw-8,row_h)
        local row_a=motion_to("language_row_"..i,hov and 1 or 0,26,0)
        if row_a>.01 then fill(dx+4,ry,dw-8,row_h,palette.side,6,math.floor(190*row_a)) end
        if active then fill(dx+4,ry+5,3,row_h-10,palette.accent,1) end
        flag(code,dx+14,ry+(row_h-fh)*.5,fw,fh)
        txt_ellipsis(font.item,dx+48,ry+(row_h-text.height(font.item))*.5,
            active and palette.accentHi or palette.text,i18n.label(i),dw-60)
        if language_open and clicked(dx+4,ry,dw-8,row_h) then i18n.set_active(code); language_open=false end
        end
    end
    draw.pop_clip()
    if max_scroll>0 then
        fill(dx+dw-4,dy+8,2,dh-16,palette.border,1)
        fill(dx+dw-4,dy+8+(dh-16)*(language_scroll/i18n.count()),2,
            math.max(22,(dh-16)*visible_count/i18n.count()),palette.accent,1)
    end
    draw.pop_motion()
end

local scroll,search,search_focus={},"",false
local search_popup_query=""
local slider_visual,slider_drag={},nil
local function focus_scroll(page_id,center,viewport,max_scroll)
    if search_target and search_target.pending and search_target.page_id==page_id then
        scroll[page_id]=math.max(0,math.min(max_scroll,center-viewport*.5))
        search_target.pending=false
    end
end
local option_visual={}
local option_open,option_anchor,option_seen=nil,nil,false
local color_presets={{168,85,247,255},{59,130,246,255},{34,197,94,255},
    {239,68,68,255},{249,115,22,255},{236,72,153,255},{20,184,166,255}}
local color_open,color_anchor,color_seen=nil,nil,false
local function color_popup_rect(anchor)
    local width,height=270,180
    local screen_w,screen_h=ctx.screen_w()/ctx.ui_scale(),ctx.screen_h()/ctx.ui_scale()
    local x=math.max(8,math.min(screen_w-width-8,anchor.x+anchor.w-width))
    local y=anchor.y+anchor.h+4
    if y+height>screen_h-8 then y=anchor.y-height-4 end
    return x,math.max(8,y),width,height
end
local function color_popup_input()
    if not color_open or not color_anchor or not input.mouse_clicked(0) then return end
    local x,y,w,h=color_popup_rect(color_anchor)
    if not inside(x,y,w,h) and not inside(color_anchor.x,color_anchor.y,color_anchor.w,color_anchor.h) then
        color_open,color_anchor=nil,nil
    end
end
local function draw_color_popup(radius)
    if not color_open or not color_anchor then return end
    local item=items.at(color_open)
    if not item then color_open,color_anchor=nil,nil; return end
    local x,y,w,h=color_popup_rect(color_anchor)
    fill(x+2,y+5,w,h,{0,0,0,125},radius)
    fill(x,y,w,h,palette.panel,radius)
    outline(x,y,w,h,palette.border,radius)
    txt(font.item,x+12,y+10,palette.text,item.name)
    local r,g,b,a,changed=ui.color_picker(0xC500+color_open,x+12,y+34,w-24,item.r,item.g,item.b,item.a)
    if changed then items.set_color(color_open,r,g,b,a) end
    local sw=25
    for i,value in ipairs(color_presets) do
        local sx=x+12+(i-1)*35
        local sy=y+h-38
        fill(sx,sy,sw,sw,value,5)
        outline(sx,sy,sw,sw,palette.border,5)
        if clicked(sx,sy,sw,sw) then items.set_color(color_open,table.unpack(value)) end
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
local function visuals_tabs_list()
    local tabs={}
    for _,handle in ipairs(items.page_items(items.joaat("Visuals"))) do
        local item=items.at(handle)
        if item and item.type==item_type.sub_menu then
            tabs[#tabs+1]={name=item.name,id=items.submenu_page_id(handle)}
        end
    end
    return tabs
end
local function row(handle,x,y,w,h,radius)
    local item=items.at(handle); if not item then return end
    local color_blocked=false
    if color_open and color_anchor then
        local px,py,pw,ph=color_popup_rect(color_anchor)
        color_blocked=inside(px,py,pw,ph)
    end
    local hover=inside(x,y,w,h) and not color_blocked
    local hover_a=motion_to("row_hover_"..handle,hover and 1 or 0,26,0)
    if item.type==item_type.toggle and item.name:sub(1,7)=="Enable " then
        fill(x+4,y+2,w-8,h-4,palette.accent,6,item.on and 27 or 12)
    end
    if hover_a>.01 then fill(x,y,w,h,palette.side,radius,math.floor(190*hover_a)) end
    if search_target and search_target.handle==handle and ctx.time()<search_target.expires then
        fill(x+2,y+2,w-4,h-4,palette.accent,radius,30)
        outline(x+2,y+2,w-4,h-4,{palette.accentHi[1],palette.accentHi[2],palette.accentHi[3],170},radius,1.5)
    end
    local base_name=item.disabled and palette.faint or palette.text
    local name_color=mix_color(base_name,{255,255,255,255},hover_a*.28)
    local control_space=0
    if item.type==item_type.toggle or item.type==item_type.float_toggle or
       item.type==item_type.int_toggle or item.type==item_type.array_toggle or
       item.type==item_type.color then control_space=48
    elseif item.type==item_type.loop_option or item.type==item_type.array_option then
        control_space=math.min(170,math.max(130,text.width(font.value,item.current_value or "")+36))
    elseif item.type==item_type.sub_menu then control_space=28 end
    if item.type==item_type.label then
        txt_wrap(font.item,x+12,y+9,name_color,item.name,w-24)
    else
        txt_ellipsis(font.item,x+12,y+9,name_color,item.name,w-24-control_space)
    end
    if h>=46 and item.desc and item.desc~="" then
        txt_ellipsis(font.small,x+12,y+28,palette.dim,item.desc,w-24)
    end
    if item.type==item_type.toggle or item.type==item_type.float_toggle or
       item.type==item_type.int_toggle or item.type==item_type.array_toggle then
        local sx,sy=x+w-42,y+(h-22)*.5
        local on_a=motion_to("toggle_on_"..handle,item.on and 1 or 0,20,item.on and 1 or 0)
        local glow=motion_to("toggle_hover_"..handle,hover and 1 or 0,25,0)
        local off=mix_color(palette.input,palette.side,glow)
        local on=mix_color(palette.accent,palette.accentHi,glow*.35)
        fill(sx,sy,22,22,mix_color(off,on,on_a),6)
        outline(sx,sy,22,22,mix_color(palette.border,palette.accentHi,on_a),6,1+glow*.5)
        if on_a>.01 then
            local check={255,255,255,math.floor(255*on_a)}
            local cx,cy=sx+11,sy+11
            local function reveal(px,py) return cx+(px-cx)*on_a,cy+(py-cy)*on_a end
            local x1,y1=reveal(sx+5,sy+11); local x2,y2=reveal(sx+9,sy+15)
            local x3,y3=reveal(sx+17,sy+6)
            draw.line(x1,y1,x2,y2,check[1],check[2],check[3],check[4],2)
            draw.line(x2,y2,x3,y3,check[1],check[2],check[3],check[4],2)
        end
        if hover and input.mouse_clicked(0) then items.toggle(handle) end
    elseif item.type==item_type.slider then
        local value=string.format("%.2f",item.f_val)
        local value_w=text.width(font.small,value)
        local sx,sw,sy=x+value_w+28,w-value_w-40,y+h-9
        local span=math.max(.0001,item.f_max-item.f_min)
        local target=math.max(0,math.min(1,(item.f_val-item.f_min)/span))
        local track_hover=inside(sx-6,sy-10,sw+12,20) and not color_blocked
        if track_hover and input.mouse_clicked(0) then slider_drag=handle end
        if slider_drag==handle and input.mouse_down(0) then
            target=math.max(0,math.min(1,(input.mouse_x()-sx)/sw))
            local nv=item.f_min+target*span
            items.set_f_val(handle,nv)
            value=string.format("%.2f",nv)
        end
        if slider_drag==handle and not input.mouse_down(0) then slider_drag=nil end
        local shown=slider_visual[handle]
        if shown==nil then shown=target end
        local ease=motion_enabled and (1-math.exp(-22*motion_speed*math.min(.1,ctx.delta()))) or 1
        shown=shown+(target-shown)*ease
        if math.abs(target-shown)<.0005 then shown=target end
        slider_visual[handle]=shown
        fill(sx,sy-2,sw,4,palette.input,2)
        fill(sx,sy-2,sw*shown,4,palette.accent,2)
        draw.circle(sx+sw*shown,sy,(slider_drag==handle or track_hover) and 6.5 or 5.5,rgba(palette.accentHi))
        txt(font.small,x+12,sy-text.height(font.small)*.5,palette.dim,value)
    elseif item.type==item_type.color then
        local sx,sy,size=x+w-44,y+(h-24)*.5,24
        draw.rect(sx,sy,sx+size,sy+size,item.r,item.g,item.b,item.a,6); outline(sx,sy,size,size,palette.border,6)
        if color_open==handle then
            color_seen=true
            color_anchor={x=sx,y=sy,w=size,h=size}
        end
        if hover and input.mouse_clicked(0) then
            if color_open==handle then color_open,color_anchor=nil,nil
            else
                option_open,option_anchor=nil,nil
                color_open=handle
                color_anchor={x=sx,y=sy,w=size,h=size}
                color_seen=true
            end
        end
    elseif item.type==item_type.loop_option or item.type==item_type.array_option then
        local value=item.current_value or ""
        local state=option_visual[handle]
        if not state then state={current=value,previous=value,phase=1}; option_visual[handle]=state end
        if state.current~=value then
            state.previous=state.current; state.current=value; state.phase=0
        end
        state.phase=motion_enabled and math.min(1,state.phase+ctx.delta()*12*motion_speed) or 1
        local eased=1-(1-state.phase)*(1-state.phase)
        -- Keep every value on the same right edge, with a fixed gap before
        -- the chevron. The old left-anchored text shifted as labels changed.
        local value_right=x+w-32
        local value_max=control_space-28
        if state.phase<1 then
            local old=state.previous
            local old_color={palette.accentHi[1],palette.accentHi[2],palette.accentHi[3],math.floor(255*(1-eased))}
            txt_ellipsis(font.value,value_right-math.min(text.width(font.value,old),value_max),
                y+7-2*eased,old_color,old,value_max)
        end
        local value_color={palette.accentHi[1],palette.accentHi[2],palette.accentHi[3],math.floor(255*eased)}
        txt_ellipsis(font.value,value_right-math.min(text.width(font.value,value),value_max),
            y+11-2*eased,value_color,value,value_max)
        local chevron_x=x+w-16
        line(chevron_x-4,y+15,chevron_x,y+19,palette.accentHi,1.5)
        line(chevron_x,y+19,chevron_x+4,y+15,palette.accentHi,1.5)
        if option_open==handle then
            option_seen=true
            option_anchor={x=x+w-control_space,y=y,w=control_space,h=h}
        end
        if hover and input.mouse_clicked(0) and item.value_count>0 then
            if option_open==handle then option_open,option_anchor=nil,nil
            else
                color_open,color_anchor=nil,nil
                option_open=handle
                option_anchor={x=x+w-control_space,y=y,w=control_space,h=h}
                option_seen=true
            end
        end
    elseif item.type==item_type.sub_menu then
        local shift=motion_to("chevron_"..handle,hover and 3 or 0,24,0)
        txt(font.item,x+w-26+shift,y+9,palette.accentHi,">")
        if hover and input.mouse_clicked(0) then
            local target=items.submenu_page_id(handle)
            if target and target~=0 then request_navigation("page",target) else items.activate(handle) end
        end
    elseif item.type==item_type.action and hover and input.mouse_clicked(0) then items.activate(handle) end
end



local function named_row(page,name,x,y,w,h,radius)
    local handle=items.get(page,name)
    if handle then row(handle,x,y,w,h,radius) end
end

local function compact_toggle(page,name,id,body,y,label)
    local handle=items.get(page,name); if not handle then return end
    local item=items.at(handle); if not item then return end
    local value,changed=ui.row_toggle(id,body,y,label or item.name,item.on)
    if changed and value~=item.on then items.toggle(handle) end
end

local pending_ui_scale=nil
local function compact_slider(page,name,id,body,y,label,format)
    local handle=items.get(page,name); if not handle then return end
    local item=items.at(handle); if not item then return end
    local defer_scale=page=="Settings" and name=="UI Scale"
    local displayed=defer_scale and (pending_ui_scale or item.f_val) or item.f_val
    local value,changed=ui.row_slider(id,body,y,label or item.name,displayed,item.f_min,item.f_max,format or "%.2f")
    if defer_scale then
        if changed then pending_ui_scale=value end
        if pending_ui_scale and input.mouse_released(0) then
            items.set_f_val(handle,pending_ui_scale)
            pending_ui_scale=nil
        end
    elseif changed then items.set_f_val(handle,value) end
end

local function theme_row(handle,x,y,w,active,radius)
    local item=items.at(handle); if not item then return end
    local hover=inside(x,y,w,30)
    if active then fill(x,y,w,30,palette.accent,radius,44)
    elseif hover then fill(x,y,w,30,{255,255,255,16},radius) end
    txt(font.value,x+12,y+(30-text.height(font.value))*.5,active and palette.text or palette.dim,item.name)
    if active then
        local cx,cy=x+w-24,y+15
        line(cx,cy+1,cx+4,cy+5,palette.accentHi,1.8)
        line(cx+4,cy+5,cx+11,cy-5,palette.accentHi,1.8)
    end
    if hover and input.mouse_clicked(0) and not active then items.activate(handle) end
end

local settings_color_open=nil
local settings_scroll=0
local config_name,config_status,config_delete_confirm="","",false
local config_seen_active=""
local function settings_columns(x,y,w,h,radius)
    local pad,gap=30,20
    local content_w=w-pad*2
    local col_w=(content_w-gap)*.5
    local lx,rx=x+pad,x+pad+col_w+gap

    local choose=items.get("Settings","Choose Theme")
    local theme_handles=choose and items.page_items(items.submenu_page_id(choose)) or {}
    local list_h=math.max(1,#theme_handles)*30
    local theme_h=44+list_h+12+34+16
    local typography_h=44+8*34+16
    local appearance_h=44+4*34+16
    local colors_h=44+3*34+16+(settings_color_open and 132 or 0)
    local streamer_handle=items.get("Streamer Mode","Enabled")
    local streamer_h=streamer_handle and 90 or 0
    local colors_top=streamer_handle and 110 or 0
    local profiles=ui.config_profiles()
    local active_profile=ui.config_active()
    if active_profile~=config_seen_active then
        config_delete_confirm=false
        config_seen_active=active_profile
    end
    local appearance_top=colors_top+colors_h+20
    local config_top=appearance_top+appearance_h+20
    local config_h=242+34*math.max(1,#profiles)
    local left_bottom=154+20+typography_h+20+theme_h
    local right_bottom=config_top+config_h
    local content_h=math.max(left_bottom,right_bottom)+40
    local scroll_max=math.max(0,content_h-h)
    if search_target and search_target.pending and search_target.page_id==items.joaat("Settings") then
        local item=items.at(search_target.handle)
        local name=item and item.name or ""
        local center=54
        if name=="Reload Lua Theme" or name=="Reset Theme" or name=="Open Themes Folder" then
            center=174+typography_h+20+theme_h-36
        end
        settings_scroll=math.max(0,math.min(scroll_max,center-h*.5))
        search_target.pending=false
    end
    local over=inside(x,y,w-14,h)
    settings_scroll=smooth_scroll(0xA200,settings_scroll,scroll_max,over,100,11)

    draw.push_clip(x,y,x+w,y+h)
    local top=y+20-settings_scroll

    local bx,by,bw,bh=panel(lx,top,col_w,154,"UI Scale","Release the slider to resize the menu",radius)
    local body=ui.rect(bx,by,bw,bh)
    compact_toggle("Settings","Auto UI Scale",0xC001,body,by,"Auto UI Scale")
    compact_slider("Settings","UI Scale",0xC002,body,by+34,"UI Scale","%.2f x")
    compact_slider("Settings","Overlays/Panels Scale",0xC003,body,by+68,"Overlays","%.2f x")
    if search_target and search_target.page_id==items.joaat("Settings") and ctx.time()<search_target.expires then
        local names={"Auto UI Scale","UI Scale","Overlays/Panels Scale"}
        for index,name in ipairs(names) do
            if items.get("Settings",name)==search_target.handle then
                outline(bx,by+(index-1)*34,bw,28,{palette.accentHi[1],palette.accentHi[2],palette.accentHi[3],170},radius,1.5)
            end
        end
    end

    local typography_y=top+174
    local fx,fy,fw,fh=panel(lx,typography_y,col_w,typography_h,"Typography","Adjust text across the menu and overlays",radius)
    local font_body=ui.rect(fx,fy,fw,fh)
    local font_rows={
        {"Title Size","Title"},{"Item Size","Menu Items"},{"Small Size","Small Text"},
        {"Value Size","Values"},{"Description Size","Descriptions"},
        {"Section Label Size","Section Labels"},{"Tagline Size","Tagline"},
        {"Overlay Text Size","Overlay Text"}
    }
    for index,entry in ipairs(font_rows) do
        compact_slider("Typography",entry[1],0xC010+index,font_body,fy+(index-1)*34,entry[2],"%.0f px")
    end

    local theme_y=typography_y+typography_h+20
    local tx,ty,tw,th=panel(lx,theme_y,col_w,theme_h,"Theme","Pick a theme; changes apply live",radius)
    local active_path=theme.active_path()
    local ry=ty
    for _,handle in ipairs(theme_handles) do
        local item=items.at(handle)
        theme_row(handle,tx,ry,tw,item and (item.type==item_type.selected_tick or item.desc==active_path),radius)
        ry=ry+30
    end
    if #theme_handles==0 then txt(font.small,tx+12,ry+6,palette.faint,"No .lua themes found.") end
    local action_y=ty+th-34
    local action_w=(tw-20)/3
    local reload=items.get("Settings","Reload Lua Theme")
    local reset=items.get("Settings","Reset Theme")
    local open=items.get("Settings","Open Themes Folder")
    if button(tx,action_y,action_w,34,"Reload",true,radius) and reload then items.activate(reload) end
    if button(tx+action_w+10,action_y,action_w,34,"Reset",false,radius) and reset then items.activate(reset) end
    if button(tx+(action_w+10)*2,action_y,action_w,34,"Open",false,radius) and open then items.activate(open) end
    if search_target and search_target.page_id==items.joaat("Settings") and ctx.time()<search_target.expires then
        local action_index=search_target.handle==reload and 0 or
            (search_target.handle==reset and 1 or (search_target.handle==open and 2 or nil))
        if action_index then
            outline(tx+(action_w+10)*action_index,action_y,action_w,34,
                {palette.accentHi[1],palette.accentHi[2],palette.accentHi[3],170},radius,1.5)
        end
    end

    if streamer_handle then
        local sx,sy,sw,sh=panel(rx,top,col_w,streamer_h,"Streamer Mode","Hide the window from screen capture",radius)
        compact_toggle("Streamer Mode","Enabled",0xC100,ui.rect(sx,sy,sw,sh),sy,"Enabled")
    end

    local ax,ay,aw,ah=panel(rx,top+colors_top,col_w,colors_h,"Colours","Recolour the interface live",radius)
    local color_rows={{"Accent",palette.accent},{"Background",palette.bg},{"Panel",palette.panel}}
    for index,entry in ipairs(color_rows) do
        local name,color=entry[1],entry[2]
        local cy=ay+(index-1)*34
        ui.row_label(ax,cy,30,name)
        local cr,cg,cb,ca=color[1],color[2],color[3],color[4]
        local swatch_w,swatch_h=54,26
        local swatch_x,swatch_y=ax+aw-swatch_w,cy+2
        fill(swatch_x,swatch_y,swatch_w,swatch_h,{cr,cg,cb,ca},7)
        local hovered=inside(swatch_x,swatch_y,swatch_w,swatch_h)
        outline(swatch_x,swatch_y,swatch_w,swatch_h,hovered and {255,255,255,235} or palette.border,7,hovered and 1.6 or 1)
        local hex=string.format("#%02X%02X%02X",cr,cg,cb)
        txt(font.value,swatch_x-text.width(font.value,hex)-12,cy+(30-text.height(font.value))*.5,palette.dim,hex)
        if clicked(swatch_x,swatch_y,swatch_w,swatch_h) then
            settings_color_open=settings_color_open==name and nil or name
        end
    end
    if settings_color_open then
        local color=setting(settings_color_open)
        if color then
            local nr,ng,nb,na,changed=ui.color_picker(0xC400,ax,ay+114,aw,color.r,color.g,color.b,color.a)
            local color_handle=items.get("Nenyoo Appearance",settings_color_open)
            if changed and color_handle then items.set_color(color_handle,nr,ng,nb,na) end
        end
    end

    local mx,my,mw,mh=panel(rx,top+appearance_top,col_w,appearance_h,"Layout & Motion","Tune the menu shape and transitions",radius)
    local appearance_body=ui.rect(mx,my,mw,mh)
    compact_slider("Nenyoo Appearance","Sidebar Width",0xC110,appearance_body,my,"Sidebar Width","%.0f px")
    compact_slider("Nenyoo Appearance","Corner Radius",0xC111,appearance_body,my+34,"Corner Radius","%.0f px")
    compact_toggle("Motion","Animations Enabled",0xC112,appearance_body,my+68,"Animations")
    compact_slider("Motion","Motion Speed",0xC113,appearance_body,my+102,"Motion Speed","%.2f x")

    local px,py,pw=panel(rx,top+config_top,col_w,config_h,"Configs","Save and switch FiveM setups",radius)
    txt_ellipsis(font.item,px+12,py+3,palette.text,
        i18n.tr("Active: ")..(active_profile=="Default" and i18n.tr("Default") or active_profile),pw-24)
    txt(font.small,px+12,py+27,palette.dim,"Config name")
    local submitted
    config_name,submitted=ui.field(0xC510,px+12,py+40,pw-24,30,config_name,"Enter a name",false)
    local action_w=(pw-40)/3
    local function create_config()
        if ui.config_create(config_name) then
            config_status="Config created"
            config_name=""
        else config_status="Choose a unique valid name" end
    end
    if submitted then create_config() end
    if button(px+12,py+80,action_w,30,"Create",true,radius) then create_config() end
    if button(px+20+action_w,py+80,action_w,30,"Save Now",false,radius) then
        config_status=ui.config_save() and "Config saved" or "Could not save config"
    end
    if button(px+28+action_w*2,py+80,action_w,30,"Rename",false,radius) then
        if ui.config_rename(config_name) then
            config_status="Config renamed"
            config_name=""
        else config_status="Cannot rename; check the name" end
    end
    if active_profile~="Default" then
        if config_delete_confirm then
            if button(px+12,py+118,(pw-32)*.5,30,"Confirm Delete",false,radius) then
                config_status=ui.config_delete() and "Config deleted" or "Could not delete config"
                config_delete_confirm=false
            end
            if button(px+20+(pw-32)*.5,py+118,(pw-32)*.5,30,"Cancel",false,radius) then
                config_delete_confirm=false
            end
        elseif button(px+12,py+118,pw-24,30,"Delete Current Config",false,radius) then
            config_delete_confirm=true
        end
    else
        txt(font.small,px+12,py+127,palette.faint,"Default cannot be renamed or deleted.")
    end
    txt_ellipsis(font.small,px+12,py+157,palette.dim,
        config_status~="" and config_status or "Changes save to the active config automatically.",pw-24)
    for index,name in ipairs(profiles) do
        local ry=py+180+(index-1)*34
        local selected=name==active_profile
        local hovered=inside(px+8,ry,pw-16,32)
        if selected then fill(px+8,ry,pw-16,32,palette.accent,5,30)
        elseif hovered then fill(px+8,ry,pw-16,32,palette.side,5) end
        txt_ellipsis(font.value,px+18,ry+9,selected and palette.accentHi or palette.text,name,pw-78)
        if selected then txt(font.small,px+pw-56,ry+10,palette.accentHi,"ACTIVE")
        else txt(font.small,px+pw-48,ry+10,palette.dim,"LOAD") end
        if hovered and input.mouse_clicked(0) and not selected then
            config_status=ui.config_load(name) and (i18n.tr("Loaded ")..name) or "Could not load config"
            config_delete_confirm=false
        end
    end

    scroll_fades(x,y,w,h,settings_scroll,scroll_max,nil,radius)
    draw.pop_clip()
    if scroll_max>0 then
        settings_scroll=ui.scrollbar(0xA201,x+w-10,y+10,y+h-10,settings_scroll,scroll_max,content_h)
    end
end

local function combat_tabs(x,y,w,h,radius,selected)
    if selected then combat_tab=selected end
    if #combat_tabs_list()==0 then return end
    local active=combat_definitions[combat_tab]
    active.id=items.joaat(active.name)
    local handles=items.page_items(active.id)
    local pad,gap,card_gap=30,20,16
    local col_w=(w-pad*2-gap)*.5
    local left_x=x+pad
    local right_x=left_x+col_w+gap

    local function row_height(handle)
        local item=items.at(handle)
        return item and item.type==item_type.slider and 64 or 54
    end
    local function group_height(group)
        local total=0
        local last=math.min(group.last,#handles)
        for index=group.first,last do total=total+row_height(handles[index]) end
        return total+60
    end

    local function column_height(groups)
        local total=0
        for index,group in ipairs(groups) do
            total=total+group_height(group)
            if index<#groups then total=total+card_gap end
        end
        return total
    end

    local left_h=column_height(active.left)
    local right_h=column_height(active.right)
    local page_h=math.max(left_h,right_h)+40
    local max_scroll=math.max(0,page_h-h)
    if search_target and search_target.pending and search_target.page_id==active.id then
        local function target_center(groups)
            local offset=20
            for _,group in ipairs(groups) do
                local row_offset=offset+50
                for index=group.first,math.min(group.last,#handles) do
                    local handle=handles[index]
                    local item_h=row_height(handle)
                    if handle==search_target.handle then return row_offset+item_h*.5 end
                    row_offset=row_offset+item_h
                end
                offset=offset+group_height(group)+card_gap
            end
        end
        local center=target_center(active.left) or target_center(active.right)
        if center then focus_scroll(active.id,center,h,max_scroll) end
    end
    local current=scroll[active.id] or 0
    current=smooth_scroll(0xA300+combat_tab,current,max_scroll,inside(x,y,w-14,h),82,13)
    scroll[active.id]=current

    draw.push_clip(x,y,x+w,y+h)
    local top=y+20-current

    local function draw_groups(groups,cx)
        local card_y=top
        for group_index,group in ipairs(groups) do
            local card_h=group_height(group)
            local animated_y=card_y+card_entry_offset(group_index)
            local body_x,body_y,body_w=panel(cx,animated_y,col_w,card_h,group.title,"",radius)
            local item_y=body_y
            local last=math.min(group.last,#handles)
            for index=group.first,last do
                local item_h=row_height(handles[index])
                if item_y+item_h>=y and item_y<=y+h then
                    row(handles[index],body_x,item_y,body_w,item_h-4,radius)
                end
                item_y=item_y+item_h
            end
            card_y=card_y+card_h+card_gap
        end
    end

    draw_groups(active.left,left_x)
    draw_groups(active.right,right_x)
    scroll_fades(x,y,w,h,scroll[active.id] or 0,max_scroll,nil,radius)
    draw.pop_clip()
    if max_scroll>0 then
        scroll[active.id]=ui.scrollbar(0xA310+combat_tab,x+w-10,y+10,y+h-10,
            scroll[active.id],max_scroll,page_h)
    end
end

local function visuals_cards(x,y,w,h,radius,page_id,definition,all_handles)
    local handles=all_handles or items.page_items(page_id)
    local by_name={}
    for _,handle in ipairs(handles) do
        local item=items.at(handle)
        if item then by_name[item.name]=handle end
    end
    local function resolve_handle(entry)
        return type(entry)=="number" and entry or by_name[entry]
    end
    local pad,gap,card_gap=30,20,16
    local col_w=(w-pad*2-gap)*.5
    local left_x=x+pad
    local right_x=left_x+col_w+gap

    local function row_height(handle)
        local item=items.at(handle)
        return item and item.type==item_type.slider and 64 or 54
    end
    local function group_height(group)
        local total=0
        for _,entry in ipairs(group.items) do
            local handle=resolve_handle(entry)
            if handle then total=total+row_height(handle) end
        end
        return total+60
    end
    local function column_height(groups)
        local total=0
        for index,group in ipairs(groups) do
            total=total+group_height(group)
            if index<#groups then total=total+card_gap end
        end
        return total
    end

    local left_groups,right_groups=definition.left,definition.right
    local shown={}
    for _,groups in ipairs({left_groups,right_groups}) do
        for _,group in ipairs(groups) do
            for _,entry in ipairs(group.items) do
                local handle=resolve_handle(entry)
                if handle then shown[handle]=true end
            end
        end
    end
    local other={}
    for _,handle in ipairs(handles) do
        local item=items.at(handle)
        if item and item.type~=item_type.sub_menu and item.type~=item_type.label and
            not shown[handle] then other[#other+1]=handle end
    end
    if #other>0 then
        left_groups={table.unpack(definition.left)}
        right_groups={table.unpack(definition.right)}
        local column=column_height(left_groups)<=column_height(right_groups) and left_groups or right_groups
        column[#column+1]={title="Other Controls",items=other}
    end
    local left_h=column_height(left_groups)
    local right_h=column_height(right_groups)
    local page_h=math.max(left_h,right_h)+40
    local max_scroll=math.max(0,page_h-h)
    if search_target and search_target.pending then
        local function target_center(groups)
            local offset=20
            for _,group in ipairs(groups) do
                local row_offset=offset+50
                for _,entry in ipairs(group.items) do
                    local handle=resolve_handle(entry)
                    if handle then
                        local item_h=row_height(handle)
                        if handle==search_target.handle then return row_offset+item_h*.5 end
                        row_offset=row_offset+item_h
                    end
                end
                offset=offset+group_height(group)+card_gap
            end
        end
        local center=target_center(left_groups) or target_center(right_groups)
        if center then
            scroll[page_id]=math.max(0,math.min(max_scroll,center-h*.5))
            search_target.pending=false
        end
    end
    local current=scroll[page_id] or 0
    current=smooth_scroll(0xA320+(page_id%128),current,max_scroll,inside(x,y,w-14,h),82,13)
    scroll[page_id]=current

    draw.push_clip(x,y,x+w,y+h)
    local top=y+20-current
    local function draw_groups(groups,cx)
        local card_y=top
        for group_index,group in ipairs(groups) do
            local card_h=group_height(group)
            local animated_y=card_y+card_entry_offset(group_index)
            local body_x,body_y,body_w=panel(cx,animated_y,col_w,card_h,group.title,"",radius)
            local item_y=body_y
            for _,entry in ipairs(group.items) do
                local handle=resolve_handle(entry)
                if handle then
                    local item_h=row_height(handle)
                    if item_y+item_h>=y and item_y<=y+h then
                        row(handle,body_x,item_y,body_w,item_h-4,radius)
                    end
                    item_y=item_y+item_h
                end
            end
            card_y=card_y+card_h+card_gap
        end
    end

    draw_groups(left_groups,left_x)
    draw_groups(right_groups,right_x)
    scroll_fades(x,y,w,h,scroll[page_id] or 0,max_scroll,nil,radius)
    draw.pop_clip()
    if max_scroll>0 then
        scroll[page_id]=ui.scrollbar(0xA3A0+(page_id%128),x+w-10,y+10,y+h-10,
            scroll[page_id],max_scroll,page_h)
    end
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

local function draw_vfx_group(x,y,w,h,radius,parent,parent_id)
    local definition,handles=flattened_vfx_definition(parent,parent_id)
    visuals_cards(x,y,w,h,radius,parent_id,definition,handles)
end

local function draw_visuals_tab(x,y,w,h,radius)
    local tabs=visuals_tabs_list()
    local selected=nil
    for _,tab in ipairs(tabs) do
        if tab.name==visuals_tab then selected=tab; break end
    end
    if not selected then selected=tabs[1] end
    if not selected or not selected.id or selected.id==0 then return end
    visuals_tab=selected.name
    draw_vfx_group(x,y,w,h,radius,selected.name,selected.id)
end

local function draw_vfx_child_page(x,y,w,h,radius,parent)
    local link=items.get("Visuals",parent)
    local parent_id=link and items.submenu_page_id(link)
    if parent_id and parent_id~=0 then
        visuals_tab=parent
        draw_vfx_group(x,y,w,h,radius,parent,parent_id)
    end
end

local function draw_page(x,y,w,h,radius)
    local page_id,page_name=menu.page_id(),menu.page_name()
    local home_id,settings_id=items.joaat("Home"),items.joaat("Settings")
    local misc_id=items.joaat("Misc")
    local combat_id=items.joaat("Combat")
    local visuals_id,esp_id=items.joaat("Visuals"),items.joaat("ESP")
    local lock_id=items.joaat("Lock-on Aimbot")
    local silent_id=items.joaat("Silent Aim")
    local magic_id=items.joaat("Magic Bullet")
    if page_id==menu.root_page() or page_name=="" then
        menu.replace_page(home_id); page_id,page_name=home_id,"Home"
    end
    if page_id==home_id then
        local pad,gap=30,20
        local col_w=(w-pad*2-gap)*.5
        local bx,by=x+pad,y+20
        local cx,cy,cw=panel(bx,by,col_w,164,"Welcome","Your FiveM menu",radius)
        local username=ui.username()
        local greeting=username=="Guest" and "Welcome to Nenyoo." or (i18n.tr("Welcome back, ")..username..".")
        txt_ellipsis(font.item,cx,cy+5,palette.text,greeting,cw-12)
        txt(font.small,cx,cy+33,palette.dim,"Ready when you are.")
        ui.pill(cx,cy+66,"READY",palette.green[1],palette.green[2],palette.green[3],palette.green[4],false)
        ui.pill(cx+74,cy+66,"v0.1",palette.accentHi[1],palette.accentHi[2],palette.accentHi[3],palette.accentHi[4],false)

        local kx,ky,kw=panel(bx+col_w+gap,by,col_w,164,"Open Menu Key","Choose your menu hotkey",radius)
        txt(font.small,kx+12,ky+5,palette.dim,"Click the key, then press a new one.")
        ui.row_menu_keybind(0xD001,ui.rect(kx+12,ky+35,kw-24,28),ky+35,"Open menu")
        txt(font.small,kx+12,ky+80,palette.faint,"Esc cancels key capture.")
        return
    end
    -- Keep the same polished two-column Settings surface on both targets.
    -- Target-specific pages are still available through their own registry routes.
    if page_id==settings_id then settings_columns(x,y,w,h,radius); return end
    if page_id==misc_id then visuals_cards(x,y,w,h,radius,misc_id,misc_definition); return end
    if page_id==visuals_id then draw_visuals_tab(x,y,w,h,radius); return end
    if page_id==esp_id then
        visuals_tab="ESP"; menu.replace_page(visuals_id)
        draw_visuals_tab(x,y,w,h,radius); return
    end
    for _,tab in ipairs(visuals_tabs_list()) do
        if page_id==tab.id then
            visuals_tab=tab.name; menu.replace_page(visuals_id)
            draw_visuals_tab(x,y,w,h,radius); return
        end
    end
    if weather_effect_names[page_name] then
        draw_vfx_child_page(x,y,w,h,radius,"Weather",page_name)
        return
    end
    if sky_child_names[page_name] then
        draw_vfx_child_page(x,y,w,h,radius,"Sky",page_name)
        return
    end
    if lighting_child_names[page_name] then
        draw_vfx_child_page(x,y,w,h,radius,"Lighting",page_name)
        return
    end
    if decal_child_names[page_name] then
        draw_vfx_child_page(x,y,w,h,radius,"Decals",page_name)
        return
    end
    if vehicle_lighting_child_names[page_name] then
        draw_vfx_child_page(x,y,w,h,radius,"Vehicle Lighting",page_name)
        return
    end
    if water_child_names[page_name] then
        draw_vfx_child_page(x,y,w,h,radius,"Water",page_name)
        return
    end
    if page_id==combat_id then combat_tabs(x,y,w,h,radius); return end
    if page_id==lock_id or page_id==silent_id or page_id==magic_id then
        local selected=page_id==lock_id and 1 or (page_id==silent_id and 2 or 3)
        menu.replace_page(combat_id)
        combat_tabs(x,y,w,h,radius,selected)
        return
    end
    local bx,by,bw,bh=panel(x+20,y+20,w-40,h-40,page_name,"Registry-backed settings",radius)
    local handles=items.page_items(page_id); local row_h=54
    local max_scroll=math.max(0,#handles*row_h-bh)
    if search_target and search_target.pending and search_target.page_id==page_id then
        for index,handle in ipairs(handles) do
            if handle==search_target.handle then
                focus_scroll(page_id,(index-.5)*row_h,bh,max_scroll)
                break
            end
        end
    end
    local current=scroll[page_id] or 0
    current=smooth_scroll(0xA330+(page_id%128),current,max_scroll,inside(bx,by,bw,bh),72,13)
    scroll[page_id]=current; draw.push_clip(bx,by,bx+bw,by+bh)
    for index,handle in ipairs(handles) do
        local ry=by+(index-1)*row_h-current
        if ry+row_h>=by and ry<=by+bh then row(handle,bx,ry,bw,row_h-4,radius) end
    end
    scroll_fades(bx,by,bw,bh,current,max_scroll)
    draw.pop_clip()
end

local function search_box(x,y,w,h,radius)
    if clicked(x,y,w,h) then search_focus=true end
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
    outline(x,y,w,h,mix_color(palette.border,palette.accent,focus_a),radius,1+focus_a*.35)
    draw.circle_outline(x+18,y+h*.5,5,palette.dim[1],palette.dim[2],palette.dim[3],palette.dim[4],1.5)
    line(x+22,y+h*.5+4,x+26,y+h*.5+8,palette.dim,1.5)
    txt_ellipsis(font.small,x+34,y+8,search=="" and palette.faint or palette.text,
        search=="" and "Search features..." or search,w-42)
    local show=search_focus and search~=""
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
        local hov=item and inside(x+4,ry,w-8,36)
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

-- Loader-style ambient background: 3 soft pulsing orbs (concentric fades to
-- fake a radial gradient) + a vector flow-field of purple dashes with two
-- drifting vortex centres and a cursor influence halo.
local function ambient_orbs(x1,y1,x2,y2)
    local t=ctx.time(); local w=x2-x1; local h=y2-y1
    local orbs={
        {0.24,0.18,0.05,0.13,0.0,220,168,85,247,60},
        {0.76,0.74,0.06,0.10,2.1,250,124,58,237,52},
        {0.50,0.46,0.04,0.16,4.2,180,192,132,252,34},
    }
    for i=1,#orbs do
        local o=orbs[i]
        local cx=x1+(o[1]+math.sin(t*o[4]+o[5])*o[3])*w
        local cy=y1+(o[2]+math.cos(t*o[4]*0.9+o[5])*o[3])*h
        local pulse=0.92+0.08*math.sin(t*0.6+o[5])
        local rad=o[6]*pulse
        for s=1,12 do
            local ratio=1.0-(s-1)/12.0
            local a=math.floor(o[10]*ratio*ratio*0.42)
            if a>0 then draw.circle(cx,cy,rad*ratio,o[7],o[8],o[9],a) end
        end
    end
end
local function ambient_particles(x1,y1,x2,y2)
    if not motion_enabled then return end
    local W=x2-x1; local H=y2-y1
    if W<=1 or H<=1 then return end
    local t=ctx.time(); local ts=t*0.18
    local vcx1=W*(0.50+0.30*math.sin(t*0.13))
    local vcy1=H*(0.46+0.30*math.cos(t*0.11))
    local vcx2=W*(0.50+0.32*math.cos(t*0.10))
    local vcy2=H*(0.54+0.26*math.sin(t*0.09))
    local mx=input.mouse_x()-x1; local my=input.mouse_y()-y1
    local R=70; local R2=R*R
    local SP=44; local len=SP*0.46
    local gx=SP*0.5
    while gx<W do
        local gy=SP*0.5
        while gy<H do
            local vdx1=gx-vcx1; local vdy1=gy-vcy1
            local vr1=math.sqrt(vdx1*vdx1+vdy1*vdy1)+1
            local vdx2=gx-vcx2; local vdy2=gy-vcy2
            local vr2=math.sqrt(vdx2*vdx2+vdy2*vdy2)+1
            local w1=1/(1+vr1/280); local w2=1/(1+vr2/280)
            local vx=(-vdy1/vr1)*w1+(vdy2/vr2)*w2+math.cos((gx+gy)*0.003+ts)*0.10
            local vy=(vdx1/vr1)*w1+(-vdx2/vr2)*w2+math.sin((gx-gy)*0.003-ts)*0.10
            local sh=0.5+0.5*math.sin(math.atan(vdy1,vdx1)*3+vr1*0.03-t*4)
            local bright=0.05+sh*0.15; local width=1
            local dx=gx-mx; local dy=gy-my; local d2=dx*dx+dy*dy
            if d2<R2 then
                local infl=1-math.sqrt(d2)/R
                local sAng=math.atan(dy,dx)+1.5708
                local sxv=math.cos(sAng); local syv=math.sin(sAng)
                vx=vx+(sxv-vx)*infl; vy=vy+(syv-vy)*infl
                bright=0.10+infl*0.85; width=1+infl*1.4
            end
            local ml=math.sqrt(vx*vx+vy*vy); if ml<0.0001 then ml=1 end
            local hx=(vx/ml)*len*0.5; local hy=(vy/ml)*len*0.5
            local a=math.floor(bright*255); if a<0 then a=0 elseif a>255 then a=255 end
            draw.line(x1+gx-hx,y1+gy-hy,x1+gx+hx,y1+gy+hy,173,143,250,a,width)
            if bright>0.55 then
                local da=math.floor((bright-0.55)*0.9*255)
                if da>255 then da=255 end
                draw.circle(x1+gx,y1+gy,1.4,210,190,255,da)
            end
            gy=gy+SP
        end
        gx=gx+SP
    end
end

-- Sidebar uses the same flow-field particles as the content area.
local function sidebar_effect(x1,y1,x2,y2)
    ambient_particles(x1,y1,x2,y2)
end

-- Story-mode feature rendering stays in Lua so colors, line weights and the
-- complete visual treatment remain theme-editable. C++ only publishes a
-- validated memory snapshot through story.targets().
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
function draw_menu()
    search_popup_click=false
    if search_focus and search_popup_bounds and input.mouse_clicked(0) and
        inside(search_popup_bounds.x,search_popup_bounds.y,
            search_popup_bounds.w,search_popup_bounds.h) then
        search_popup_click=true
        input.consume_mouse_click()
    end
    if search_target and ctx.time()>=search_target.expires then search_target=nil end
    option_popup_input()
    color_popup_input()
    option_seen=false
    color_seen=false
    local sidebar,radius=sync_settings()
    content_alpha,content_offset,content_progress=update_transition()
    local width,height=ui.win_w,ui.win_h
    local base_x,base_y=0,0
    if not ui.windowed then
        base_x=math.max(20,(ctx.screen_w()/ctx.ui_scale()-width)*.5)
        base_y=math.max(20,(ctx.screen_h()/ctx.ui_scale()-height)*.5)
    end
    -- The Builder theme fills its entire native window, so moving its canvas
    -- only clips the right/bottom edges. Header dragging is useful for the
    -- in-game overlay, where the menu floats over a larger game surface.
    local off_x,off_y=menu.drag_header(base_x,base_y,sidebar,100,not ui.windowed)
    local ox,oy=base_x+off_x,base_y+off_y
    fill(ox,oy,width,height,palette.bg,radius); fill(ox,oy,sidebar,height,palette.bg,radius)
    draw.push_clip(ox+sidebar,oy,ox+width,oy+height)
    ambient_particles(ox+sidebar,oy,ox+width,oy+height)
    draw.pop_clip()
    -- SIDEBAR_EFFECT_MARKER
    draw.push_clip(ox,oy,ox+sidebar,oy+height)
    sidebar_effect(ox,oy,ox+sidebar,oy+height)
    draw.pop_clip()
    local logo="NENYOO"
    txt(font.title,ox+(sidebar-text.width(font.title,logo))*.5,oy+36,palette.text,logo)
    -- "FiveM" tagline: "Five" in dim white, "M" in green.
    do
        local a,b="Five","M"
        local wa=text.width(font.item,a); local wb=text.width(font.item,b)
        local tx=ox+(sidebar-(wa+wb))*.5
        local ty=oy+36+text.height(font.title)+2
        txt(font.item,tx,   ty,palette.dim,a)
        txt(font.item,tx+wa,ty,palette.green,b)
    end
    txt(font.label,ox+10,oy+117,palette.faint,"MENU")
    if menu.build_tabs then menu.build_tabs() end
    local tab_count=menu.tab_count and menu.tab_count() or 0
    local active_tab=menu.tab_active and menu.tab_active() or 0
    local nav_top=oy+139
    local nav_bottom=oy+height-12
    local nav_h=math.max(1,nav_bottom-nav_top)
    local max_nav_scroll=math.max(0,tab_count*60+128-nav_h)
    if active_tab~=sidebar_last_active then
        local active_top,active_bottom=active_tab*60,active_tab*60+50
        if active_top<sidebar_nav_scroll then sidebar_nav_scroll=active_top end
        if active_bottom>sidebar_nav_scroll+nav_h then
            sidebar_nav_scroll=active_bottom-nav_h
        end
        sidebar_last_active=active_tab
    end
    if inside(ox,nav_top,sidebar,nav_h) then
        sidebar_nav_scroll=sidebar_nav_scroll-input.mouse_wheel()*54
    end
    sidebar_nav_scroll=math.max(0,math.min(max_nav_scroll,sidebar_nav_scroll))
    draw.push_clip(ox+8,nav_top,ox+sidebar-8,nav_bottom)
    if tab_count>0 then
        local target_y=139+active_tab*60-sidebar_nav_scroll
        local active_y=oy+motion_to("sidebar_active_y",target_y,18,target_y)
        fill(ox+10,active_y,sidebar-20,50,palette.side,4)
    end
    for index=0,tab_count-1 do
        local name=menu.tab_name(index)
        local x,y,w,h=ox+10,nav_top+index*60-sidebar_nav_scroll,sidebar-20,50
        local active=active_tab==index
        local hov=inside(x,y,w,h) and inside(ox,nav_top,sidebar,nav_h)
        local hover_a=motion_to("sidebar_hover_"..index,hov and 1 or 0,24,0)
        if not active and hover_a>.01 then fill(x,y,w,h,palette.input,4,math.floor(220*hover_a)) end
        local icon_color=mix_color(palette.dim,active and palette.accentHi or palette.text,active and 1 or hover_a*.45)
        local label_color=mix_color(palette.dim,palette.text,active and 1 or hover_a*.7)
        nav_icon(name,x+25,y+25,icon_color)
        txt(font.item,x+48,y+17,label_color,name)
        if hov and clicked(x,y,w,h) and not active then request_navigation("tab",index) end
    end
    local upcoming_top=nav_top+tab_count*60+14-sidebar_nav_scroll
    line(ox+24,upcoming_top-10,ox+sidebar-24,upcoming_top-10,palette.border,1)
    for index,name in ipairs({"Lua Executor","Events"}) do
        local x,y,w,h=ox+10,upcoming_top+4+(index-1)*60,sidebar-20,50
        fill(x,y,w,h,palette.input,4,110)
        outline(x,y,w,h,palette.border,4)
        nav_icon(name,x+25,y+25,palette.faint)
        txt_ellipsis(font.item,x+48,y+9,palette.dim,name,w-60)
        txt(font.small,x+48,y+29,palette.faint,"Upcoming")
    end
    draw.pop_clip()
    if max_nav_scroll>0 then
        local track_h=nav_h-16
        local thumb_h=math.max(24,track_h*nav_h/(nav_h+max_nav_scroll))
        local thumb_y=nav_top+8+(track_h-thumb_h)*sidebar_nav_scroll/max_nav_scroll
        fill(ox+sidebar-4,nav_top+8,2,track_h,palette.border,1)
        fill(ox+sidebar-4,thumb_y,2,thumb_h,palette.accent,1)
    end
    local top_x=ox+sidebar+10
    if ui.windowed and button(ox+width-44,oy+6,32,28,"_",false,4) then menu.minimize_window() end
    local header_name=menu.page_name()
    local combat_header=header_name=="Combat" or header_name=="Lock-on Aimbot" or
        header_name=="Silent Aim" or header_name=="Magic Bullet"
    local visuals_header=header_name=="Visuals" or weather_effect_names[header_name] or
        sky_child_names[header_name] or lighting_child_names[header_name] or
        decal_child_names[header_name] or vehicle_lighting_child_names[header_name] or
        water_child_names[header_name]
    if weather_effect_names[header_name] then visuals_tab="Weather" end
    if sky_child_names[header_name] then visuals_tab="Sky" end
    if lighting_child_names[header_name] then visuals_tab="Lighting" end
    if decal_child_names[header_name] then visuals_tab="Decals" end
    if vehicle_lighting_child_names[header_name] then visuals_tab="Vehicle Lighting" end
    if water_child_names[header_name] then visuals_tab="Water" end
    local vfx_tabs=visuals_tabs_list()
    for _,tab in ipairs(vfx_tabs) do
        if header_name==tab.name then visuals_header=true; visuals_tab=tab.name end
    end
    if combat_header then
        if header_name=="Lock-on Aimbot" then combat_tab=1
        elseif header_name=="Silent Aim" then combat_tab=2
        elseif header_name=="Magic Bullet" then combat_tab=3 end
        local combat_tabs_available=combat_tabs_list()
        local pill_y,pill_h,pill_pad,pill_x=oy+42,48,25,0
        local positions={}
        for _,tab in ipairs(combat_tabs_available) do
            local index=tab.index
            local tw=text.width(font.item,tab.name)+pill_pad*2
            positions[index]={x=pill_x,w=tw}
            pill_x=pill_x+tw+6
        end
        local selected=positions[combat_tab]
        if not selected then return end
        local active_x=top_x+motion_to("combat_tab_x",selected.x,18,selected.x)
        local active_w=motion_to("combat_tab_w",selected.w,18,selected.w)
        fill(active_x,pill_y,active_w,pill_h,palette.side,4)
        local underline_w=active_w*.42
        fill(active_x+(active_w-underline_w)*.5,pill_y+pill_h-3,underline_w,3,palette.accent,1)
        for _,tab in ipairs(combat_tabs_available) do
            local index=tab.index
            local px,tw=top_x+positions[index].x,positions[index].w
            local hov=inside(px,pill_y,tw,pill_h)
            local active=combat_tab==index
            local hover_a=motion_to("combat_hover_"..index,hov and 1 or 0,24,0)
            if not active and hover_a>.01 then fill(px,pill_y,tw,pill_h,palette.input,4,math.floor(210*hover_a)) end
            txt(font.item,px+pill_pad,pill_y+(pill_h-text.height(font.item))*.5,
                mix_color(palette.dim,palette.text,active and 1 or hover_a*.7),tab.name)
            if clicked(px,pill_y,tw,pill_h) and not active then request_navigation("combat",index) end
        end
        txt(font.small,ox+width-140,oy+64,palette.faint,"Combat")
    elseif visuals_header then
        local pill_y,pill_h,pill_pad,pill_x=oy+42,48,12,0
        local positions={}
        for index,tab in ipairs(vfx_tabs) do
            local tw=text.width(font.item,tab.name)+pill_pad*2
            positions[index]={x=pill_x,w=tw}
            pill_x=pill_x+tw+6
        end
        local visible_w=math.max(100,width-sidebar-145)
        local arrow_w=22
        local clip_x=top_x+arrow_w+5
        local clip_w=math.max(60,visible_w-arrow_w*2-10)
        local max_scroll=math.max(0,pill_x-6-clip_w)
        visuals_header_scroll=math.max(0,math.min(max_scroll,visuals_header_scroll))
        if inside(clip_x,pill_y,clip_w,pill_h) then
            visuals_header_scroll=math.max(0,math.min(max_scroll,
                visuals_header_scroll-input.mouse_wheel()*75))
        end
        if max_scroll>0 then
            local right_x=clip_x+clip_w+5
            local can_left=visuals_header_scroll>0
            local can_right=visuals_header_scroll<max_scroll
            if can_left and clicked(top_x,pill_y+9,arrow_w,30) then
                visuals_header_scroll=math.max(0,visuals_header_scroll-clip_w*.55)
            end
            if can_right and clicked(right_x,pill_y+9,arrow_w,30) then
                visuals_header_scroll=math.min(max_scroll,visuals_header_scroll+clip_w*.55)
            end
            fill(top_x,pill_y+9,arrow_w,30,palette.side,4)
            fill(right_x,pill_y+9,arrow_w,30,palette.side,4)
            txt(font.value,top_x+7,pill_y+17,can_left and palette.text or palette.faint,"<")
            txt(font.value,right_x+7,pill_y+17,can_right and palette.text or palette.faint,">")
            local rail_y=pill_y+50
            local thumb_w=math.max(36,clip_w*(clip_w/(pill_x-6)))
            if clicked(clip_x,rail_y-3,clip_w,8) then visuals_header_drag=true end
            if not input.mouse_down(0) then visuals_header_drag=false end
            if visuals_header_drag then
                local frac=(input.mouse_x()-clip_x-thumb_w*.5)/(clip_w-thumb_w)
                visuals_header_scroll=math.max(0,math.min(max_scroll,frac*max_scroll))
            end
        else visuals_header_drag=false end
        local selected_index=1
        for index,tab in ipairs(vfx_tabs) do
            if tab.name==visuals_tab then selected_index=index; break end
        end
        local selected=positions[selected_index]
        if selected and visuals_header_last_tab~=visuals_tab then
            if selected.x<visuals_header_scroll then visuals_header_scroll=selected.x end
            if selected.x+selected.w>visuals_header_scroll+clip_w then
                visuals_header_scroll=selected.x+selected.w-clip_w
            end
            visuals_header_last_tab=visuals_tab
        end
        if selected then
            local shown=motion_to("visuals_header_view",visuals_header_scroll,20,visuals_header_scroll)
            draw.push_clip(clip_x,pill_y,clip_x+clip_w,pill_y+pill_h)
            local active_x=clip_x+motion_to("visuals_tab_x",selected.x-shown,18,
                selected.x-shown)
            local active_w=motion_to("visuals_tab_w",selected.w,18,selected.w)
            if active_x>=clip_x and active_x+active_w<=clip_x+clip_w then
                fill(active_x,pill_y,active_w,pill_h,palette.side,4)
                local underline_w=active_w*.42
                fill(active_x+(active_w-underline_w)*.5,pill_y+pill_h-3,underline_w,3,palette.accent,1)
            end
            for index,tab in ipairs(vfx_tabs) do
                local px,tw=clip_x+positions[index].x-shown,positions[index].w
                local visible=px>=clip_x and px+tw<=clip_x+clip_w
                local hov=visible and inside(px,pill_y,tw,pill_h) and
                    inside(clip_x,pill_y,clip_w,pill_h)
                local active=visuals_tab==tab.name
                local hover_a=motion_to("visuals_hover_"..index,hov and 1 or 0,24,0)
                if visible then
                    if not active and hover_a>.01 then fill(px,pill_y,tw,pill_h,palette.input,4,
                        math.floor(210*hover_a)) end
                    txt(font.item,px+pill_pad,pill_y+(pill_h-text.height(font.item))*.5,
                        mix_color(palette.dim,palette.text,active and 1 or hover_a*.7),tab.name)
                end
                if visible and hov and clicked(px,pill_y,tw,pill_h) and
                    (not active or header_name~="Visuals") then
                    request_navigation("visuals",tab.name)
                end
            end
            draw.pop_clip()
            if max_scroll>0 then
                local thumb_w=math.max(36,clip_w*(clip_w/(pill_x-6)))
                local thumb_x=clip_x+(clip_w-thumb_w)*(shown/max_scroll)
                fill(clip_x,pill_y+50,clip_w,2,palette.border,1)
                fill(thumb_x,pill_y+50,thumb_w,2,palette.accent,1)
            end
        end
        txt_ellipsis(font.small,ox+width-130,oy+64,palette.faint,
            header_name=="Visuals" and "Visuals" or header_name,110)
    else
        txt(font.item,top_x,oy+60,palette.text,header_name)
    end
    line(top_x,oy+96,ox+width-10,oy+96,palette.border,1)
    draw.push_motion(content_offset,0,content_alpha)
    draw_page(ox+sidebar,oy+108,width-sidebar,height-108,radius)
    draw.pop_motion()
    search_box(top_x,oy+6,math.min(240,width-sidebar-130),28,4)
    language_picker(ox+width-(ui.windowed and 94 or 54),oy+13,radius)
    menu.set_content_rect(ox+sidebar,oy+108,width-sidebar,height-108)
    if option_open and not option_seen then option_open,option_anchor=nil,nil end
    if color_open and not color_seen then color_open,color_anchor=nil,nil end
    draw_option_popup(radius)
    draw_color_popup(radius)
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
