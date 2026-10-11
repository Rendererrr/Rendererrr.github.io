-- Scooby's local MTA compatibility API. This is not the engine resource VM.
local nativeSession, scriptName = _scoobyMtaSession, _scoobyMtaName
_scoobyMtaSession, _scoobyMtaName = nil, nil
local pack, unpack = table.pack, table.unpack
local defined = {onClientRender=true, onClientResourceStart=true,
    onClientResourceStop=true, onScoobySessionStart=true, onScoobySessionEnd=true,
    onScoobyRegionChange=true, onScoobyFocusChange=true}
local handlers, customCount, handlerCount, depth = {}, 0, 0, 0
local started, stopped, previous = false, false, nil
local eventFrames = {}
local emit, renderInstalled
resourceRoot = root
localPlayer = getLocalPlayer()
local resource = {name=scriptName}
function getThisResource() return resource end
function getResourceName(value) return value == resource and scriptName or false end
function getRootElement() return root end
function outputDebugString(message, level)
    assert(type(message) == 'string' and #message <= 4096, 'Expected text up to 4096 bytes')
    print(message)
    return true
end
local function finite(value)
    return type(value)=='number' and value==value and math.abs(value)<1e12
end
local function validName(value)
    return type(value)=='string' and #value>0 and #value<=80
end
local function target(value) return isElement(value) end
local function priority(value)
    value = value or 'normal'
    assert(type(value)=='string', 'priority must be a string')
    local group, offset = value:match('^(%a+)([+-]%d+)$')
    if not group then group, offset = value, '0' end
    local ranks={high=1000000,normal=0,low=-1000000}
    assert(ranks[group] and math.abs(tonumber(offset))<=999999, 'Invalid event priority')
    return ranks[group]+tonumber(offset)
end
function addEvent(name, remote)
    assert(validName(name), 'Event name must contain 1-80 bytes')
    assert(remote==nil or remote==false, 'Remote/server events require the MTA resource runtime')
    assert(not name:match('^onClient') and not name:match('^onScooby'), 'Reserved host event name')
    if defined[name] then return false end
    assert(customCount<64, 'Custom event limit: 64 per script')
    defined[name]=true;customCount=customCount+1;return true
end
function addEventHandler(name, attached, callback, propagate, order)
    assert(defined[name], 'Unsupported event; use addEvent for script-local custom events')
    assert(target(attached), 'Expected a current element or root')
    assert(type(callback)=='function', 'Expected an event function')
    assert(propagate==nil or type(propagate)=='boolean', 'propagate must be boolean')
    assert(not stopped, 'Script is stopping')
    local rank=priority(order)
    local list=handlers[name] or {}
    for _,h in ipairs(list) do if h.active and h.element==attached and h.fn==callback then return false end end
    assert(handlerCount<128, 'Event handler limit: 128 per script')
    if name=='onClientRender' and not renderInstalled then
        -- Canonical UI registration belongs to script loading. Do not give
        -- scripts without render subscribers an otherwise empty UI callback.
        local draw=function() return emit('onClientRender',root,true) end
        if ui and ui.overlay then ui.overlay('__mta_client_render',draw)
        else events.on('update',draw) end
        renderInstalled=true
    end
    list[#list+1]={element=attached,fn=callback,propagate=propagate~=false,rank=rank,active=true}
    handlers[name]=list;handlerCount=handlerCount+1;return true
end
function removeEventHandler(name, attached, callback)
    for _,h in ipairs(handlers[name] or {}) do
        if h.active and h.element==attached and h.fn==callback then
            h.active=false;handlerCount=handlerCount-1;return true
        end
    end
    return false
end
function cancelEvent(cancel)
    local frame=eventFrames[#eventFrames]
    if not frame or frame.host then return false end
    assert(cancel==nil or type(cancel)=='boolean', 'cancel must be boolean')
    frame.cancelled=cancel~=false;return true
end
function wasEventCancelled()
    local frame=eventFrames[#eventFrames]
    return frame and frame.cancelled or false
end
emit=function(name, origin, hostEvent, ...)
    assert(depth<8, 'Event recursion limit: 8')
    assert(select('#',...)<=32, 'Event argument limit: 32')
    depth=depth+1
    local savedSource,savedThis,savedEvent=source,this,eventName
    local frame={cancelled=false,host=hostEvent};eventFrames[#eventFrames+1]=frame
    local calls={}
    for _,h in ipairs(handlers[name] or {}) do
        if h.active then calls[#calls+1]=h end
    end
    -- Stable priority ordering without changing the registration list mid-dispatch.
    for i=2,#calls do
        local h,j=calls[i],i-1
        while j>=1 and calls[j].rank<h.rank do calls[j+1]=calls[j];j=j-1 end
        calls[j+1]=h
    end
    for _,h in ipairs(calls) do
        if h.active and (h.element==origin or (h.element==root and h.propagate)) then
            source,this,eventName=origin,h.element,name
            local ok,err=pcall(h.fn,...)
            if not ok then
                if h.active then h.active=false;handlerCount=handlerCount-1 end
                print('[MTA Lua] '..name..' handler disabled: '..tostring(err))
            end
        end
    end
    source,this,eventName=savedSource,savedThis,savedEvent
    eventFrames[#eventFrames]=nil;depth=depth-1
    return not frame.cancelled
end
function triggerEvent(name, origin, ...)
    assert(defined[name] and not name:match('^onClient') and not name:match('^onScooby'),
        'Only script-local custom events can be triggered')
    assert(target(origin), 'Expected a current element or root')
    return emit(name,origin,false,...)
end

local timers, timerCount = {}, 0
function setTimer(fn, interval, repetitions, ...)
    assert(not stopped and type(fn)=='function', 'Expected a timer function in a running script')
    assert(finite(interval) and interval>=50 and interval<=86400000, 'Timer interval: 50..86400000 milliseconds')
    assert(finite(repetitions) and repetitions>=0 and repetitions<=1000000 and repetitions%1==0, 'Invalid timer repetitions')
    assert(select('#',...)<=32 and timerCount<64, 'Timer limit: 64 timers, 32 arguments')
    local token={}
    timers[token]={fn=fn,interval=interval,left=repetitions,due=getTickCount()+interval,args=pack(...)}
    timerCount=timerCount+1;return token
end
function isTimer(token) return timers[token]~=nil end
function killTimer(token)
    if not timers[token] then return false end
    timers[token]=nil;timerCount=timerCount-1;return true
end
function getTimerDetails(token)
    local t=timers[token];if not t then return false end
    return math.max(0,t.due-getTickCount()),t.left,t.interval
end
function resetTimer(token)
    local t=timers[token];if not t then return false end
    t.due=getTickCount()+t.interval;return true
end
local function tickTimers()
    local now=getTickCount();local due={}
    for token,t in pairs(timers) do if t.due<=now then due[#due+1]=token end end
    for _,token in ipairs(due) do
        local t=timers[token]
        if t and t.due<=now then
            t.due=now+t.interval
            local saved=sourceTimer;sourceTimer=token
            local ok,err=pcall(t.fn,unpack(t.args,1,t.args.n));sourceTimer=saved
            if not ok then print('[MTA Lua] Timer disabled: '..tostring(err));killTimer(token)
            elseif timers[token]==t and t.left>0 then
                t.left=t.left-1;if t.left==0 then killTimer(token) end
            end
        end
    end
end

local vectorMethods={}
local vectorMeta={__index=vectorMethods,__metatable='Vector3'}
function Vector3(x,y,z)
    assert(finite(x) and finite(y) and finite(z), 'Vector3 requires three finite numbers')
    return setmetatable({x=x,y=y,z=z},vectorMeta)
end
function vectorMethods:getLength() return math.sqrt(self.x*self.x+self.y*self.y+self.z*self.z) end
function vectorMethods:getNormalized()
    local length=self:getLength();if length==0 then return Vector3(0,0,0) end
    return Vector3(self.x/length,self.y/length,self.z/length)
end
function vectorMethods:dot(v) return self.x*v.x+self.y*v.y+self.z*v.z end
function vectorMethods:cross(v) return Vector3(self.y*v.z-self.z*v.y,self.z*v.x-self.x*v.z,self.x*v.y-self.y*v.x) end
vectorMeta.__add=function(a,b) return Vector3(a.x+b.x,a.y+b.y,a.z+b.z) end
vectorMeta.__sub=function(a,b) return Vector3(a.x-b.x,a.y-b.y,a.z-b.z) end
vectorMeta.__mul=function(a,b)
    if type(a)=='number' then a,b=b,a end
    assert(finite(b),'Vector3 multiplication expects a scalar');return Vector3(a.x*b,a.y*b,a.z*b)
end
function getDistanceBetweenPoints3D(x,y,z,a,b,c)
    return (Vector3(x,y,z)-Vector3(a,b,c)):getLength()
end
mta={apiVersion=1,runtime='scooby',getSession=nativeSession}
function mta.getCapabilities()
    return {snapshotElements=true,localEvents=true,timers=true,vector3=true,
        nativeResourceVM=false,serverEvents=false,compiledMtaBytecode=false}
end
local function unavailable()
    error('This function requires the native MTA resource runtime and is unavailable in Scooby Lua',2)
end
triggerServerEvent,triggerLatentServerEvent,setElementPosition,createVehicle,createPed,createObject =
    unavailable,unavailable,unavailable,unavailable,unavailable,unavailable

events.on('update',function()
    localPlayer=getLocalPlayer()
    local current=nativeSession()
    if not started then started=true;emit('onClientResourceStart',resourceRoot,true,resource) end
    if previous and previous.ready and (not current.ready or previous.localPlayer~=current.localPlayer) then
        emit('onScoobySessionEnd',root,true)
    end
    if current.ready and (not previous or not previous.ready or previous.localPlayer~=current.localPlayer) then
        emit('onScoobySessionStart',root,true)
    end
    if previous and current.ready and previous.ready and
       (previous.interior~=current.interior or previous.dimension~=current.dimension) then
        emit('onScoobyRegionChange',root,true,current.interior,current.dimension,previous.interior,previous.dimension)
    end
    if previous and previous.focused~=current.focused then emit('onScoobyFocusChange',root,true,current.focused) end
    previous=current
    tickTimers()
    -- Prune removed, failed and expired-element registrations to keep storage bounded.
    for name,list in pairs(handlers) do
        local kept={}
        for _,h in ipairs(list) do
            if h.active and target(h.element) then kept[#kept+1]=h
            elseif h.active then h.active=false;handlerCount=handlerCount-1 end
        end
        handlers[name]=kept
    end
end)
events.on('shutdown',function()
    stopped=true
    emit('onClientResourceStop',resourceRoot,true,resource)
    handlers,timers={},{};handlerCount,timerCount=0,0
end)
