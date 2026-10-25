features.on_draw("Animation History", function(f)
    if __panelkit then __panelkit.panel("Animation History",40,400,"Recent animation",{{"Dictionary",f.dictionary or ""},{"Clip",f.clip or ""}}) end
end)
