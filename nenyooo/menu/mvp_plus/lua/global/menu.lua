
-- Nenyoo menu builder API (foundation -- our own, always loaded, CDN-independent).
-- Thin OOP veneer over the C++ __smenu builders. A ref is an object {id=N} whose metatable exposes the
-- builder/query methods plus a `.value` property mapping to get_value/set_value. The optional Stand
-- dialect layer (lib\api\stand) adds Stand-specific composites/shims ON TOP of this; the generic
-- builders + set_ticked live here so every script (native or dialect) gets them without the CDN layer.
__ref_methods = __ref_methods or {}
__ref_mt = __ref_mt or {}
__ref_mt.__index = function(self, k)
    if k == "value" then return menu.get_value(self) end
    return __ref_methods[k]
end
__ref_mt.__newindex = function(self, k, v)
    if k == "value" then menu.set_value(self, v); return end
    rawset(self, k, v)
end
local function __wrap(id) if id == nil then return nil end return setmetatable({ id = id }, __ref_mt) end
local function __rid(r) if type(r) == "table" then return r.id end return r end
__stand_wrap = __wrap   -- exposed for dialect helpers / other layer files

for _, name in ipairs({ "list", "action", "toggle", "slider", "slider_float", "click_slider", "readonly", "divider", "hyperlink" }) do
    menu[name] = function(parent, ...) return __wrap(__smenu[name](__rid(parent), ...)) end
    __ref_methods[name] = function(self, ...) return menu[name](self, ...) end
end

-- colour: two signatures normalized to the C++ builder (cb, r, g, b, a). cb gets a {r,g,b,a} table.
function menu.colour(parent, name, cmds, help, a5, a6, a7, a8, a9)
    local cb, r, g, b, al
    if type(a5) == "table" then
        r, g, b, al = a5.r or 255, a5.g or 255, a5.b or 255, a5.a or 255
        cb = (type(a7) == "function") and a7 or (type(a6) == "function") and a6 or nil
    else
        cb = (type(a5) == "function") and a5 or nil
        r, g, b, al = a6 or 255, a7 or 255, a8 or 255, a9 or 255
    end
    return __wrap(__smenu.colour(__rid(parent), name, cmds, help, cb or function() end, r, g, b, al))
end
menu.color = menu.colour
function menu.rainbow(parent, name, cmds, help, cb) return menu.colour(parent, name, cmds, help, cb, 255, 0, 0, 255) end
__ref_methods.colour  = function(self, ...) return menu.colour(self, ...) end
__ref_methods.color   = __ref_methods.colour
__ref_methods.rainbow = function(self, ...) return menu.rainbow(self, ...) end

function menu.my_root() return __wrap(__smenu.root()) end
function menu.get_value(r) return __smenu.get_value(__rid(r)) end
function menu.set_value(r, v) return __smenu.set_value(__rid(r), v) end
function menu.is_ref_valid(r) return __smenu.is_ref_valid(__rid(r)) end

-- Tree introspection / mutation.
function menu.get_menu_name(r) return __smenu.get_menu_name(__rid(r)) end
function menu.set_menu_name(r, n) __smenu.set_menu_name(__rid(r), n) end
function menu.get_help_text(r) return __smenu.get_help_text(__rid(r)) end
function menu.set_help_text(r, t) __smenu.set_help_text(__rid(r), tostring(t or "")) end
-- Tick state for an action row: render it as a selected_tick (button with a tick) when on.
function menu.set_ticked(r, on) __smenu.set_ticked(__rid(r), on and true or false) end
function menu.get_ticked(r) return __smenu.get_ticked(__rid(r)) end
function menu.get_parent(r) return __wrap(__smenu.get_parent(__rid(r))) end
function menu.get_children(r)
    local ids, out = __smenu.get_children(__rid(r)), {}
    for i, id in ipairs(ids) do out[i] = __wrap(id) end
    return out
end
function menu.ref_by_command_name(name) return __wrap(__smenu.ref_by_command_name(name)) end
function menu.get_default_state(r) return __smenu.get_default_state(__rid(r)) end
function menu.apply_default_state(r) __smenu.apply_default_state(__rid(r)) end
function menu.delete(r) __smenu.delete(__rid(r)) end
function menu.trigger(r) __smenu.trigger(__rid(r)) end

-- Ref-object method forms.
__ref_methods.get_value          = function(self) return menu.get_value(self) end
__ref_methods.set_value          = function(self, v) return menu.set_value(self, v) end
__ref_methods.get_menu_name      = function(self) return menu.get_menu_name(self) end
__ref_methods.set_menu_name      = function(self, n) return menu.set_menu_name(self, n) end
__ref_methods.get_help_text      = function(self) return menu.get_help_text(self) end
__ref_methods.set_help_text      = function(self, t) return menu.set_help_text(self, t) end
__ref_methods.set_ticked         = function(self, on) return menu.set_ticked(self, on) end
__ref_methods.get_ticked         = function(self) return menu.get_ticked(self) end
__ref_methods.get_parent         = function(self) return menu.get_parent(self) end
__ref_methods.get_children       = function(self) return menu.get_children(self) end
__ref_methods.delete             = function(self) return menu.delete(self) end
__ref_methods.trigger            = function(self) return menu.trigger(self) end
__ref_methods.is_ref_valid       = function(self) return menu.is_ref_valid(self) end

-- Held toggle: spawn a worker that runs loop_fn every tick while the toggle is on.
function menu.toggle_loop(parent, label, cmds, help, loop_fn, on_stop)
    local ref = menu.toggle(parent, label, cmds, help, function(on) end, false)
    util.create_thread(function()
        local was_on = false
        while true do
            local on = menu.get_value(ref)
            if on then loop_fn()
            elseif was_on and on_stop then on_stop() end
            was_on = on
            util.yield()
        end
    end)
    return ref
end

-- Run fn each frame only while ref's page is open (in viewport).
function menu.on_tick_in_viewport(ref, fn)
    local rid = __rid(ref)
    return util.create_thread(function()
        while true do
            if __smenu.node_in_viewport(rid) then fn() end
            util.yield()
        end
    end)
end
