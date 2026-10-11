-- Run from Lua > Scripts or the Lua Editor. Stop removes this script's handlers.
-- Uses Scooby's local compatibility API, not the native MTA resource VM.
addEventHandler('onClientResourceStart', resourceRoot, function()
    outputDebugString('Player HUD started')
end)

addEventHandler('onClientRender', root, function()
    local player = getLocalPlayer()
    if not player then
        render.text(24, 64, 'MTA: waiting for a supported session', {1, 1, 1, 1}, 16)
        return
    end
    local x, y, z = player:getPosition()
    local label = string.format('%s | HP: %s | %.1f, %.1f, %.1f',
        player:getName(), tostring(player:getHealth()), x, y, z)
    render.text(24, 64, label, {1, 1, 1, 1}, 16)
end)
