-- Shared V1/V2 standalone UI example. Values are local demonstrations, not game features.
-- Main uses native imgui controls; Visuals draws custom widgets; Settings includes widgets.*.
local visible = features.add{capture_protection="safe",id="menu",label="ImGui demo",default=true,key="F10",active_list=false}
local page = "Main"
local aim, fovChanger, crosshair, visibleOnly, teamCheck = true, true, false, true, true
local fov, smooth, pitch, yaw, chance, delay, position, priority = 45, 22, 100, 100, 72, 35, 1, 1
local recoil, trigger = true, false
local boxes, names, health, opacity, palette = true, true, true, 0.75, 1
local themed, themedAmount, themedMode, showFooter = true, 0.4, 1, true
local palettes = {{0.48,0.62,0.86,1},{0.48,0.72,0.57,1},{0.66,0.55,0.85,1}}
local paletteNames = {"Slate", "Sage", "Violet"}
local c = {
    bg={0.045,0.050,0.060,1}, panel={0.056,0.063,0.075,1},
    header={0.066,0.074,0.088,1}, border={0.15,0.17,0.21,1},
    text={0.86,0.88,0.92,1}, muted={0.49,0.54,0.62,1},
    field={0.082,0.094,0.115,1}, hover={0.12,0.15,0.20,1}, clear={0,0,0,0}
}
local s, font, accent = 1, 14, palettes[1]
local function gap(amount) imgui.dummy(0,amount*s) end

-- Native inputs on a shared label/control grid. Hidden IDs remain stable.
local function row(label, kind, value, options)
    local x,y=imgui.cursor()
    local width=imgui.available()
    local height=24*s
    local control=math.min(132*s,width*0.48)
    if kind=="check" then control=font+6*s
    elseif kind=="slider" then control=math.min(168*s,width*0.55) end
    draw.text(x,y+(height-font)*0.5,label,c.text,font)
    imgui.set_cursor_screen(x+width-control,y+(height-font-6*s)*0.5)
    imgui.set_next_item_width(control)
    local changed
    if kind=="check" then changed,value=imgui.checkbox("##"..label,value)
    elseif kind=="combo" then
        imgui.with_style_vars({WindowPadding={7*s,6*s}},function()
            changed,value=imgui.combo("##"..label,value,options)
        end)
    elseif kind=="slider" then
        changed,value=imgui.slider_int("##"..label,value,options[1],options[2],{style="track"})
        if imgui.is_item_hovered() and not imgui.is_item_active() then
            imgui.with_style_vars({WindowPadding={7*s,5*s}},function()
                imgui.tooltip("Drag to adjust. Click value to type.")
            end)
        end
    else imgui.text_colored(tostring(value),c.muted) end
    imgui.set_cursor_screen(x,y)
    imgui.dummy(width,height)
    return value
end

-- Titled, bordered panels with independent clipping/scrolling.
local function panel(title,height,contents)
    local x,y=imgui.cursor()
    local width=imgui.available()
    draw.rect(x,y+font*0.5,width,height-font*0.5,c.panel,true,4*s)
    draw.rect(x,y+font*0.5,width,height-font*0.5,c.border,false,4*s)
    local tw=imgui.text_size(title)
    draw.rect(x+(width-tw)*0.5-8*s,y,tw+16*s,font,c.bg,true)
    draw.text(x+(width-tw)*0.5,y,title,c.text,font)
    imgui.with_style_vars({WindowPadding={14*s,24*s},ChildBorderSize=0},function()
        imgui.child(title,width,height,contents,{padding=true})
    end)
end
local function columns(left,right)
    local width=imgui.available()
    if width<520*s then
        left();gap(14);right()
    else
        local half=(width-14*s)*0.5
        imgui.child("left_column",half,0,left)
        imgui.same_line(14*s)
        imgui.child("right_column",half,0,right)
    end
end

-- Lua-owned toggle input and rendering; no host toggle is used here.
local function customToggle(label,value)
    local x,y=imgui.cursor()
    local width=imgui.available()
    if imgui.invisible_button(label,width,29*s) then value=not value end
    local hovered=imgui.is_item_hovered()
    draw.text(x,y+(29*s-font)*0.5,label,hovered and {1,1,1,1} or c.text,font)
    draw.rect(x+width-28*s,y+7*s,28*s,15*s,value and accent or c.border,true,8*s)
    draw.circle(x+width-(value and 7.5 or 20.5)*s,y+14.5*s,4.5*s,{0.94,0.96,1,1},true)
    return value
end
local function customSlider(label,value)
    local x,y=imgui.cursor()
    local width=imgui.available()
    draw.text(x,y+5*s,label,c.text,font)
    local formatted=string.format("%.0f%%",value*100)
    draw.text(x+width-imgui.text_size(formatted),y+5*s,formatted,c.muted,font)
    imgui.set_cursor_screen(x,y+26*s)
    imgui.invisible_button(label,width,20*s)
    if imgui.is_item_active() and imgui.is_mouse_down(0) then
        local mx=imgui.mouse_pos()
        value=math.max(0,math.min(1,(mx-x)/width))
    end
    draw.rect(x,y+34*s,width,3*s,c.field,true,2*s)
    draw.rect(x,y+34*s,width*value,3*s,accent,true,2*s)
    draw.circle(x+width*value,y+35.5*s,4*s,accent,true)
    return value
end
local function customPalette()
    imgui.text("Accent")
    imgui.set_next_item_width(-1)
    imgui.with_style_vars({WindowPadding={7*s,6*s}},function()
    imgui.combo_custom("##custom_palette",paletteNames[palette],function()
        for i,label in ipairs(paletteNames) do
            local x,y=imgui.cursor()
            local width=imgui.available()
            if imgui.invisible_button(label,width,27*s) then palette=i;imgui.close_popup() end
            if imgui.is_item_hovered() then draw.rect(x,y,width,27*s,c.hover,true,3*s) end
            draw.rect(x+8*s,y+9*s,8*s,8*s,palettes[i],true,2*s)
            draw.text(x+25*s,y+(27*s-font)*0.5,label,palette==i and accent or c.text,font)
        end
    end)
    end)
end

local function mainPage()
    columns(function()
        local _,remaining=imgui.available()
        panel("General",math.min(365*s,math.max(255*s,remaining-5*s)),function()
            aim=row("Enabled","check",aim)
            fovChanger=row("FOV changer","check",fovChanger)
            crosshair=row("Crosshair","check",crosshair)
            visibleOnly=row("Visible only","check",visibleOnly)
            teamCheck=row("Team check","check",teamCheck)
            position=row("Hit position","combo",position,{"Thigh","Chest","Head"})
            priority=row("Priority","combo",priority,{"Distance","Health","Field of view"})
        end)
    end,function()
        panel("Aimbot settings",193*s,function()
            fov=row("Field of view","slider",fov,{0,100})
            smooth=row("Smoothing","slider",smooth,{0,100})
            recoil=row("Recoil control","check",recoil)
            imgui.disabled(not recoil,function()
                pitch=row("Pitch","slider",pitch,{0,100})
                yaw=row("Yaw","slider",yaw,{0,100})
            end)
        end)
        gap(14)
        panel("Triggerbot settings",143*s,function()
            trigger=row("Enabled","check",trigger)
            chance=row("Hit chance","slider",chance,{0,100})
            delay=row("Delay","slider",delay,{0,250})
        end)
    end)
end
local function visualsPage()
    columns(function()
        panel("Overlay",147*s,function()
            boxes=customToggle("Bounding box",boxes)
            names=customToggle("Name",names)
            health=customToggle("Health bar",health)
        end)
        gap(14)
        panel("Appearance",189*s,function()
            opacity=customSlider("Opacity",opacity)
            gap(12)
            customPalette()
        end)
    end,function()
        local _,remaining=imgui.available()
        panel("Preview",math.min(365*s,math.max(220*s,remaining-5*s)),function()
            local x,y=imgui.cursor()
            local w,h=imgui.available()
            local center=x+w*0.5
            local top=y+35*s
            local bottom=y+h-25*s
            local mid=top+(bottom-top)*0.5
            local tint={accent[1],accent[2],accent[3],opacity}
            if names then draw.text(center-imgui.text_size("Preview entity")*0.5,top-24*s,"Preview entity",c.text,font) end
            if boxes then draw.rect(center-50*s,top,100*s,bottom-top,tint,false,2*s) end
            if health then
                draw.rect(center-58*s,top,3*s,bottom-top,c.field,true)
                draw.rect(center-58*s,top+(bottom-top)*0.2,3*s,(bottom-top)*0.8,{0.46,0.72,0.57,opacity},true)
            end
            draw.circle(center,top+25*s,10*s,tint,false,1.5*s)
            draw.line(center,top+37*s,center,mid+10*s,tint,1.5*s)
            draw.line(center,top+45*s,center-29*s,mid,tint,1.5*s)
            draw.line(center,top+45*s,center+29*s,mid,tint,1.5*s)
            draw.line(center,mid+10*s,center-24*s,bottom-10*s,tint,1.5*s)
            draw.line(center,mid+10*s,center+24*s,bottom-10*s,tint,1.5*s)
            imgui.dummy(w,h)
        end)
    end)
end
local function settingsPage()
    columns(function()
        panel("Interface",117*s,function()
            palette=row("Accent","combo",palette,paletteNames)
            showFooter=row("Show footer","check",showFooter)
        end)
        gap(14)
        panel("Window",148*s,function()
            row("Open key","text","F10")
            gap(8)
            if imgui.button("Close window",-1,29*s) then features.set(visible,false) end
        end)
    end,function()
        panel("Shared widgets",279*s,function()
            local changed
            changed,themed=widgets.toggle("Enabled",themed)
            gap(12)
            changed,themedAmount=widgets.slider("Amount",themedAmount,0,1)
            gap(12)
            changed,themedMode=widgets.combo("Mode",themedMode,{"Default","Subtle","Strong"})
        end)
    end)
end

ui.overlay("interface",function()
    if not features.active(visible) then return end
    local _,hostFont=imgui.text_size("M")
    font=math.min(80,math.max(14,hostFont));s=font/14;accent=palettes[palette]
    local vw,vh=engine.viewport()
    local colors={WindowBg=c.bg,ChildBg=c.clear,PopupBg=c.panel,Text=c.text,TextDisabled=c.muted,
        Border=c.border,FrameBg=c.field,FrameBgHovered=c.hover,FrameBgActive={0.16,0.20,0.27,1},
        CheckMark=accent,SliderGrab=accent,SliderGrabActive={0.70,0.79,0.94,1},
        Button=c.field,ButtonHovered=c.hover,ButtonActive={0.16,0.21,0.30,1},
        Header={0.14,0.19,0.28,1},HeaderHovered=c.hover,HeaderActive={0.18,0.24,0.34,1}}
    imgui.with_font_size(font,function()
        imgui.with_style(colors,function()
            imgui.with_style_vars({WindowPadding={0,0},WindowRounding=5*s,WindowBorderSize=1,
                ChildRounding=4*s,FramePadding={6*s,3*s},FrameRounding=3*s,FrameBorderSize=1,
                ItemSpacing={7*s,5*s},GrabMinSize=7*s,GrabRounding=2*s,PopupRounding=4*s},function()
                imgui.window("GH",{width=math.min(vw-48,650*s),height=math.min(vh-70,480*s),
                    x=24,y=32,no_title_bar=true},function()
                    local wx,wy=imgui.window_pos()
                    local width,height=imgui.window_size()
                    local tabWidth=0
                    for _,name in ipairs({"Main","Visuals","Settings"}) do tabWidth=tabWidth+imgui.text_size(name)+24*s end
                    local stacked=width<tabWidth+120*s
                    local header=(stacked and 84 or 48)*s
                    draw.rect(wx+1,wy+1,width-2,header-1,c.header,true,4*s)
                    draw.text(wx+18*s,wy+15*s,"GH",c.text,18*s)
                    draw.line(wx+1,wy+header,wx+width-1,wy+header,{accent[1],accent[2],accent[3],0.55},1)
                    imgui.set_cursor(width-34*s,9*s)
                    imgui.with_style({Button=c.clear,Border=c.clear,Text=c.muted},function()
                        if imgui.button("x##close",24*s,27*s) then features.set(visible,false) end
                    end)
                    if imgui.is_item_hovered() then imgui.tooltip("Close window - F10 to reopen") end
                    imgui.set_cursor(stacked and 12*s or width-tabWidth-48*s,stacked and 45*s or 10*s)
                    for i,name in ipairs({"Main","Visuals","Settings"}) do
                        if i>1 then imgui.same_line(0) end
                        local selected=page==name
                        imgui.with_style({Text=selected and accent or c.muted,Border=c.clear,Button=c.clear},function()
                            local buttonWidth=stacked and (width-24*s)/3 or imgui.text_size(name)+24*s
                            if imgui.button(name,buttonWidth,28*s) then page=name end
                        end)
                        if stacked and imgui.is_item_hovered() then imgui.tooltip(name) end
                        if selected then
                            local a,b,d,e=imgui.item_rect()
                            draw.line(a+12*s,wy+header,d-12*s,wy+header,accent,2)
                        end
                    end
                    local footer=showFooter and 29*s or 0
                    imgui.set_cursor(14*s,header+14*s)
                    local contentHeight=math.max(40*s,height-header-footer-28*s)
                    imgui.child("body",width-28*s,contentHeight,function()
                        if page=="Main" then mainPage() elseif page=="Visuals" then visualsPage() else settingsPage() end
                    end)
                    if showFooter then
                        local y=wy+height-footer
                        draw.line(wx+14*s,y,wx+width-14*s,y,c.border,1)
                        draw.text(wx+17*s,y+8*s,"Standalone",c.muted,11*s)
                        local hint="F10  Show / hide"
                        draw.text(wx+width-17*s-imgui.text_size(hint)*11/14,y+8*s,hint,c.muted,11*s)
                    end
                end)
            end)
        end)
    end)
end)
