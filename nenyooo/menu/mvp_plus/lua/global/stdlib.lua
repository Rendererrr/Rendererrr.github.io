
-- Lua stdlib polyfills + a small json shim. Additive: extends the stdlib tables, never replaces them.
function string.startswith(s, p) return string.sub(s, 1, #p) == p end
function string.endswith(s, p) return p == "" or string.sub(s, -#p) == p end
function string.contains(s, sub) return string.find(s, sub, 1, true) ~= nil end
function string.lstrip(s) return (string.gsub(s, "^%s+", "")) end
function string.rstrip(s) return (string.gsub(s, "%s+$", "")) end
function string.strip(s) return (string.gsub(string.gsub(s, "^%s+", ""), "%s+$", "")) end
string.trim = string.strip
function string.split(s, sep)
    local out = {}
    sep = sep or "%s"
    for part in string.gmatch(s, "([^" .. sep .. "]+)") do out[#out + 1] = part end
    return out
end
function table.contains(t, val) for _, v in pairs(t) do if v == val then return true end end return false end
function table.find(t, val) for k, v in pairs(t) do if v == val then return k end end return nil end
function table.keys(t) local o = {} for k in pairs(t) do o[#o + 1] = k end return o end
function table.count(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end
function math.clamp(x, lo, hi) if x < lo then return lo elseif x > hi then return hi else return x end end
function math.round(x) return math.floor(x + 0.5) end
function math.lerp(a, b, t) return a + (b - a) * t end

-- json: compact encode + decode (objects/arrays/strings/numbers/bool/null). Enough for config files.
json = json or {}
local function j_enc(v, out)
    local t = type(v)
    if v == nil then out[#out+1] = "null"
    elseif t == "boolean" then out[#out+1] = v and "true" or "false"
    elseif t == "number" then out[#out+1] = tostring(v)
    elseif t == "string" then
        out[#out+1] = '"' .. v:gsub('[%z\1-\31\\"]', function(c)
            local m = { ['"']='\\"', ['\\']='\\\\', ['\n']='\\n', ['\r']='\\r', ['\t']='\\t' }
            return m[c] or string.format("\\u%04x", string.byte(c))
        end) .. '"'
    elseif t == "table" then
        local n = 0; local isarr = true
        for k in pairs(v) do n = n + 1; if type(k) ~= "number" then isarr = false end end
        if isarr and n == #v then
            out[#out+1] = "["
            for i = 1, #v do if i > 1 then out[#out+1] = "," end j_enc(v[i], out) end
            out[#out+1] = "]"
        else
            out[#out+1] = "{"; local first = true
            for k, val in pairs(v) do
                if not first then out[#out+1] = "," end
                first = false
                j_enc(tostring(k), out); out[#out+1] = ":"; j_enc(val, out)
            end
            out[#out+1] = "}"
        end
    else out[#out+1] = "null" end
end
function json.encode(v) local out = {}; j_enc(v, out); return table.concat(out) end
function json.decode(s)
    local i, n = 1, #s
    local function skip() while i <= n and s:sub(i,i):match("%s") do i = i + 1 end end
    local parse_val
    local function parse_str()
        i = i + 1; local buf = {}
        while i <= n do
            local c = s:sub(i, i)
            if c == '"' then i = i + 1; return table.concat(buf) end
            if c == '\\' then
                local e = s:sub(i+1, i+1)
                local m = { ['"']='"', ['\\']='\\', ['/']='/', n='\n', r='\r', t='\t', b='\b', f='\f' }
                if e == 'u' then local cp = tonumber(s:sub(i+2, i+5), 16) or 63; buf[#buf+1] = string.char(cp <= 255 and cp or 63); i = i + 6
                else buf[#buf+1] = m[e] or e; i = i + 2 end
            else buf[#buf+1] = c; i = i + 1 end
        end
        return table.concat(buf)
    end
    parse_val = function()
        skip(); local c = s:sub(i, i)
        if c == '"' then return parse_str()
        elseif c == '{' then
            i = i + 1; local o = {}; skip()
            if s:sub(i,i) == '}' then i = i + 1; return o end
            while i <= n do
                skip(); local k = parse_str(); skip(); i = i + 1   -- skip ':'
                o[k] = parse_val(); skip()
                local d = s:sub(i,i); i = i + 1
                if d ~= ',' then break end   -- '}' or malformed/EOF
            end
            return o
        elseif c == '[' then
            i = i + 1; local a = {}; skip()
            if s:sub(i,i) == ']' then i = i + 1; return a end
            while i <= n do
                a[#a+1] = parse_val(); skip()
                local d = s:sub(i,i); i = i + 1
                if d ~= ',' then break end   -- ']' or malformed/EOF
            end
            return a
        elseif c == 't' then i = i + 4; return true
        elseif c == 'f' then i = i + 5; return false
        elseif c == 'n' then i = i + 4; return nil
        else
            local num = s:match("^%-?%d+%.?%d*[eE]?[%+%-]?%d*", i)
            if num then i = i + #num; return tonumber(num) end
            i = i + 1; return nil
        end
    end
    local ok, res = pcall(parse_val)
    if ok then return res end
    return nil
end
