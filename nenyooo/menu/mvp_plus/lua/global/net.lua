
-- net.* — networking over the C++ async_http (WinHTTP). Callbacks are delivered on the script thread by
-- the http pump, so they may safely call natives. on_ok(body, status); on_err(message).
net = net or {}
net.http = async_http
-- net.get(host, path, on_ok, on_err): one-shot async HTTPS GET.
function net.get(host, path, on_ok, on_err)
    async_http.init(host, path, on_ok, on_err)
    async_http.dispatch()
end
-- net.post(host, path, body, on_ok, on_err): one-shot async HTTPS POST with a string body.
function net.post(host, path, body, on_ok, on_err)
    async_http.init(host, path, on_ok, on_err)
    async_http.set_post(body or "")
    async_http.dispatch()
end
