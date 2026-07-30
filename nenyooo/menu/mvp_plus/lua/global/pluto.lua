
-- Dialect-agnostic Lua stdlib polyfills + constants + a small json shim. Additive: extends the
-- stdlib tables, never replaces them. Shared by every dialect (NOT Stand-specific).
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

-- soup.* shim + require"pluto:<lib>" resolver. Only json is bundled (Stand scripts use soup.json /
-- require"pluto:json"); other pluto libs (crypto/socket/base64/...) fall through to the real require.
soup = soup or {}
soup.json = json
do
    local __orig_require = require
    require = function(name)
        if type(name) == "string" and (name == "pluto:json" or name == "json" or name == "soup.json") then
            return json
        end
        if __orig_require then return __orig_require(name) end
        error("module not available: " .. tostring(name))
    end
end

-- ===== Pluto string extensions (pure-Lua, best-effort) =====
function string.casefold(s) return s:lower() end
function string.isalpha(s) return #s > 0 and s:find("[^%a]") == nil end
function string.isalnum(s) return #s > 0 and s:find("[^%a%d]") == nil end
function string.isascii(s) return s:find("[\128-\255]") == nil end
function string.islower(s) return s:find("%l") ~= nil and s:find("%u") == nil end
function string.isupper(s) return s:find("%u") ~= nil and s:find("%l") == nil end
function string.iswhitespace(s) return #s > 0 and s:find("%S") == nil end
string.uformat = string.format
function string.lfind(s, sub, init) return (string.find(s, sub, init or 1, true)) end
function string.rfind(s, sub)
    local last, i = nil, 1
    while true do local f = string.find(s, sub, i, true); if not f then break end; last = f; i = f + 1 end
    return last
end
function string.replace(s, from, to)
    if from == "" then return s end
    local out, i = {}, 1
    while true do
        local a, b = string.find(s, from, i, true)
        if not a then out[#out+1] = string.sub(s, i); break end
        out[#out+1] = string.sub(s, i, a-1); out[#out+1] = to; i = b + 1
    end
    return table.concat(out)
end
function string.partition(s, sep)
    local a, b = string.find(s, sep, 1, true)
    if not a then return s, "", "" end
    return string.sub(s, 1, a-1), string.sub(s, a, b), string.sub(s, b+1)
end
function string.truncate(s, n, suffix)
    if #s <= n then return s end
    suffix = suffix or ""
    return string.sub(s, 1, math.max(0, n - #suffix)) .. suffix
end
function string.find_first_of(s, set, init) for i = (init or 1), #s do if set:find(s:sub(i,i), 1, true) then return i end end end
function string.find_first_not_of(s, set, init) for i = (init or 1), #s do if not set:find(s:sub(i,i), 1, true) then return i end end end
function string.find_last_of(s, set) for i = #s, 1, -1 do if set:find(s:sub(i,i), 1, true) then return i end end end
function string.find_last_not_of(s, set) for i = #s, 1, -1 do if not set:find(s:sub(i,i), 1, true) then return i end end end

-- ===== Pluto table extensions =====
table.size = table.count
function table.getn(t) return #t end
function table.clear(t) for k in pairs(t) do t[k] = nil end return t end
function table.foreach(t, fn) for k, v in pairs(t) do fn(k, v) end end
function table.mapped(t, fn) local o = {} for k, v in pairs(t) do o[k] = fn(v, k) end return o end
function table.map(t, fn) for k, v in pairs(t) do t[k] = fn(v, k) end return t end          -- in place
function table.filtered(t, pred) local o = {} for i = 1, #t do if pred(t[i], i) then o[#o+1] = t[i] end end return o end
function table.filter(t, pred)
    local w = 0
    for i = 1, #t do if pred(t[i], i) then w = w + 1; t[w] = t[i] end end
    for i = #t, w + 1, -1 do t[i] = nil end
    return t
end
function table.reduce(t, fn, acc) for i = 1, #t do acc = fn(acc, t[i], i) end return acc end
function table.reversed(t) local o = {} local n = #t for i = 1, n do o[i] = t[n - i + 1] end return o end
function table.reverse(t) local n = #t for i = 1, math.floor(n/2) do t[i], t[n-i+1] = t[n-i+1], t[i] end return t end
function table.sorted(t, cmp) local o = {} for i = 1, #t do o[i] = t[i] end table.sort(o, cmp) return o end
function table.reordered(t) local o = {} for _, v in pairs(t) do o[#o+1] = v end return o end
function table.reorder(t) local o = table.reordered(t) table.clear(t) for i = 1, #o do t[i] = o[i] end return t end
function table.checkall(t, pred) for i = 1, #t do if not pred(t[i], i) then return false end end return true end
function table.freeze(t) return t end          -- best-effort no-op (no real read-only in Lua 5.4)
function table.isfrozen(t) return false end

-- ===== Pluto os extensions (process-monotonic via os.clock — fine for deltas) =====
function os.seconds() return os.clock() end
function os.millis() return math.floor(os.clock() * 1000) end
function os.micros() return math.floor(os.clock() * 1000000) end
function os.nanos() return math.floor(os.clock() * 1000000000) end
function os.unixseconds() return os.time() end

-- ===== Pluto io extensions (over vanilla io + the filesystem backends; best-effort) =====
function io.exists(p)
    if __stand_is_dir and __stand_is_dir(p) then return true end
    local f = io.open(p, "r"); if f then f:close(); return true end; return false
end
function io.isfile(p)
    local f = io.open(p, "r"); if not f then return false end; f:close()
    return not (__stand_is_dir and __stand_is_dir(p))
end
function io.isdir(p) return __stand_is_dir ~= nil and __stand_is_dir(p) or false end
function io.filesize(p)
    local f = io.open(p, "rb"); if not f then return -1 end
    local sz = f:seek("end"); f:close(); return sz
end
function io.contents(p)
    local f = io.open(p, "rb"); if not f then return nil end
    local d = f:read("*a"); f:close(); return d
end
function io.copy(src, dst)
    local d = io.contents(src); if d == nil then return false end
    local f = io.open(dst, "wb"); if not f then return false end
    f:write(d); f:close(); return true
end
io.copyto = io.copy
function io.listdir(p) if __stand_list_files then return __stand_list_files(p) end return {} end
function io.makedir(p) if __stand_mkdirs then __stand_mkdirs(p) end end
io.makedirs = io.makedir
function io.parent(p) return (string.gsub(p, "[/\\][^/\\]*$", "")) end
function io.part(p) return (string.gsub(p, "^.*[/\\]", "")) end
function io.absolute(p) return p end
function io.relative(p) return p end
function io.currentdir() return "" end
function io.writetime(p) return 0 end
