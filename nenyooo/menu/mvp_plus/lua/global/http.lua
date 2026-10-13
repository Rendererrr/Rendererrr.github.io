-- http.* — stateful asynchronous HTTPS requests over Nenyoo's WinHTTP transport.
http = http or {}
http.ok = 0
http.failed = 1

local client_mt = {}
client_mt.__index = client_mt

function http.client()
    return setmetatable({ url = "", method = "GET", body = nil, headers = {}, done = false,
        result = "", code = http.failed }, client_mt)
end

function client_mt:set_url(value) self.url = tostring(value or ""); return self end
function client_mt:set_method(value) self.method = tostring(value or "GET"); return self end
function client_mt:set_body(value) self.body = tostring(value or ""); return self end
function client_mt:add_header(value) self.headers[#self.headers + 1] = tostring(value or ""); return self end
function client_mt:quiet() return self end
function client_mt:finished() return self.done end
function client_mt:response() return self.code, self.result end

local function split_url(url)
    local host, path = tostring(url or ""):match("^https://([^/]+)(/.*)$")
    if not host then host = tostring(url or ""):match("^https://([^/]+)$"); path = "/" end
    return host, path
end

function client_mt:perform()
    self.done, self.code, self.result = false, http.failed, ""
    local host, path = split_url(self.url)
    if not host then self.done = true; return false end
    async_http.init(host, path, function(body)
        self.result, self.code, self.done = body or "", http.ok, true
    end, function()
        self.result, self.code, self.done = "", http.failed, true
    end)
    async_http.set_method(self.method)
    if self.body ~= nil then async_http.set_post(self.body) end
    for _, header in ipairs(self.headers) do async_http.add_header(header) end
    async_http.dispatch()
    return true
end
