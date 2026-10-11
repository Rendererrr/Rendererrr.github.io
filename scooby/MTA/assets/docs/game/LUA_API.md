# MTA scripting

## mta.getCapabilities()
```lua
local api = mta.getCapabilities()
assert(mta.runtime == 'scooby' and mta.apiVersion == 1)
-- snapshotElements, localEvents, timers, vector3: true
-- nativeResourceVM, serverEvents, compiledMtaBytecode: false
```

## mta.getSession()
```lua
local session = mta.getSession()
-- ready, focused, localPlayer, interior, dimension
if session.ready then print(session.interior, session.dimension) end
```

## getLocalPlayer() / localPlayer
```lua
local player = getLocalPlayer() -- element or false
-- localPlayer is refreshed before each onClientRender callback.
```

## getElementsByType(type, root?, streamedIn?)
```lua
for _, player in ipairs(getElementsByType('player')) do
    print(getPlayerName(player))
end
-- 'player', 'ped' (NPCs), 'vehicle'; only currently enumerated elements.
-- root is the only supported parent. streamedIn cannot expose unseen elements.
```

## isElement(element) / getElementType(element)
```lua
if isElement(localPlayer) then print(getElementType(localPlayer)) end
-- Expired/replaced/disconnected handles return false and never revive.
```

## getElementPosition(element) / element:getPosition()
```lua
local x, y, z = getElementPosition(getLocalPlayer())
if x then print(x, y, z) end -- native MTA X/Y/Z, meters
-- Returns false for an expired handle or root.
```

## getElementHealth(element) / element:getHealth()
```lua
local player = getLocalPlayer()
if player then print(player:getHealth()) end -- false when unavailable
```

## getPlayerName(player) / player:getName()
```lua
local player = getLocalPlayer()
if player then print(player:getName(), player:getType()) end
```

## addEventHandler(name, attachedTo, callback, propagate?, priority?)
```lua
addEventHandler('onClientRender', root, function()
    local player = getLocalPlayer()
    if player then
        render.text(24, 64, player:getName(), {1, 1, 1, 1}, 16)
    end
end)
-- Local compatibility callbacks, not hooks into the native MTA event bus.
-- onClientRender: Scooby render update, no arguments.
-- Register the first onClientRender handler while the script loads, before callbacks.
-- onClientResourceStart / Stop: this script starts/stops, argument getThisResource().
-- onScoobySessionStart / End: supported living-local-player snapshot appears/disappears.
-- onScoobyRegionChange: newInterior, newDimension, oldInterior, oldDimension.
-- onScoobyFocusChange: focused boolean.
-- source, this and eventName exist during callbacks and restore after nested calls.
-- root/resourceRoot refer to this script's local event root.
-- Priority: high, normal, low, optionally +N/-N; equal priority follows registration order.
-- 128 active handlers per script. A failing handler is disabled and logged.
```

## addEvent(name, allowRemoteTrigger?) / triggerEvent(name, source, ...)
```lua
addEvent('friends:greeting', false)
addEventHandler('friends:greeting', root, function(text) print(text) end)
triggerEvent('friends:greeting', root, 'Hello!')
-- Custom events are isolated to this script. Remote events are unavailable.
-- Up to 64 custom event names, 32 arguments, 8 nested dispatches.
```

## removeEventHandler(name, attachedTo, callback)
```lua
local function tick() print('tick') end
addEventHandler('onClientRender', root, tick)
removeEventHandler('onClientRender', root, tick)
```

## cancelEvent(cancel?) / wasEventCancelled()
```lua
addEvent('friends:check', false)
addEventHandler('friends:check', root, function()
    cancelEvent()
    assert(wasEventCancelled())
end)
assert(not triggerEvent('friends:check', root))
-- Cancellation only affects the return value of a custom event.
```

## setTimer(callback, intervalMs, repetitions, ...)
```lua
local timer = setTimer(function(label) print(label) end, 1000, 5, 'Hello')
-- 0 repetitions means repeat until killed/stopped.
-- 64 timers per script; interval 50..86400000 ms; up to 32 arguments.
-- Render-driven, at most one call per timer per frame; no catch-up burst.
-- sourceTimer is the current timer during its callback.
```

## isTimer(timer) / killTimer(timer) / resetTimer(timer) / getTimerDetails(timer)
```lua
local timer = setTimer(function() end, 1000, 0)
local remainingMs, repetitions, intervalMs = getTimerDetails(timer)
resetTimer(timer)
killTimer(timer)
assert(not isTimer(timer))
```

## Vector3(x, y, z)
```lua
local a, b = Vector3(1, 2, 3), Vector3(4, 5, 6)
local sum, difference, scaled = a + b, b - a, a * 2
print(a:getLength(), a:dot(b))
local normal, cross = a:getNormalized(), a:cross(b)
print(getDistanceBetweenPoints3D(0, 0, 0, 3, 4, 0)) -- 5
```

## guiGetScreenSize() / getTickCount()
```lua
local width, height = guiGetScreenSize()
local milliseconds = getTickCount() -- monotonic clock; no fixed epoch
```

## getThisResource() / getResourceName(resource) / getRootElement()
```lua
print(getResourceName(getThisResource())) -- this Scooby script's name
assert(getRootElement() == root)
```

## outputDebugString(text, level?)
```lua
outputDebugString('Hello from my script') -- Scooby Lua console, max 4096 bytes
```
