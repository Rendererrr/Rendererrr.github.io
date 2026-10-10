-- Portable demo: these APIs work in the preview and every integration.
print("Hello from Scooby Simple Base")
base.set("esp.box", true)
base.set("esp.skeleton", true)
base.log("Box ESP enabled: " .. tostring(base.get("esp.box")))
