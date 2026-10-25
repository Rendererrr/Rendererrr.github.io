features.on_draw("Location Bookmarks", function(f)
    if not __panelkit or not f.image then return end
    local texture=draw.load_image("textures/"..f.image)
    local w,h=draw.image_size(texture)
    if not w or w<=0 or not h or h<=0 then return end
    local width=320; local height=math.min(320,width*h/w)
    local x,y=__panelkit.move("Location Bookmarks",40,400,width,height)
    draw.image(texture,x,y,x+width,y+height,1)
end)
