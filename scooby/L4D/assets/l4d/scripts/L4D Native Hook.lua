-- Fill in the function-entry pattern and exact signature for your game/build.
local pattern = nil
local signature = nil
if not pattern or not signature then return end
if not l4d.native or not l4d.native.available then
    base.log("Native hooks 1.1 require an updated L4D host.")
    return
end

local feature = features.add {
    id = "native_hook", label = "My native hook",
    category = "Native hooks", default = false,
    capture_protection = "disable"
}
local tab = ui.tab("native_hooks", "Native hooks")
local hook, attempted

ui.subtab(tab, "main", "Hook", function()
    ui.group("Options", function()
        ui.feature(feature)
        if hook then
            local status = hook:status()
            ui.text(string.format("Calls: %d | Bypassed: %d",
                status.calls, status.bypassed))
        end
    end)
end)

events.on("update", function()
    if not attempted and l4d.native.available() then
        attempted = true -- Do not retry a bad signature on every frame.
        local address, err = l4d.native.scan("client.dll", pattern)
        if not address then base.log("Pattern lookup failed: " .. err); return end
        hook, err = l4d.native.hook(address, signature, [[
            return function(original, ...)
                shared.set("calls", (shared.get("calls") or 0) + 1)
                return original(...)
            end
        ]], {enabled=false})
        if not hook then base.log(err); return end
        hook:set("calls", 0) -- Initialize before enabling.
    end
    if not hook then return end
    local status = hook:status()
    if status.errors > 0 then
        -- The host reports the traceback once in Lua > Console.
        hook:remove()
        hook = nil
        return
    end
    local wanted = features.active(feature) and l4d.native.available()
    if status.enabled ~= wanted then hook:enable(wanted) end
end)
-- Stop/reload automatically retires this script's hook.
