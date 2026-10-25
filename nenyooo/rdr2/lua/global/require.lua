-- Per-script require(). Every user script gets its own require (installed by the engine when the script
-- loads), so a script can ship its own modules beside it:
--
--   Scripts\User\MyScript\main.lua            -- the entry script
--   Scripts\User\MyScript\includes\helpers.lua -- require("includes.helpers")
--
-- Lookup order: <script folder>\a\b.lua, <script folder>\a\b\init.lua, then the global require
-- (standard library modules and package.path). Modules run in the requiring script's environment and are
-- cached per script, so a script reload discards them together with the script. A module that requires
-- itself (directly or through others) raises an error instead of hanging.

local LOADING = {}

function __make_require(env, dir)
    local cache = {}
    local global_require = require
    local root = tostring(dir or "")

    local function read_all(path)
        local fh = io.open(path, "rb")
        if not fh then return nil end
        local src = fh:read("a")
        fh:close()
        return src
    end

    return function(name)
        if type(name) ~= "string" or name == "" then
            error("bad argument #1 to 'require' (module name expected)", 2)
        end
        local hit = cache[name]
        if hit == LOADING then error("circular require of module '" .. name .. "'", 2) end
        if hit ~= nil then return hit end

        local rel = name:gsub("%.", "\\")
        local candidates = { root .. "\\" .. rel .. ".lua", root .. "\\" .. rel .. "\\init.lua" }
        for _, path in ipairs(candidates) do
            local src = read_all(path)
            if src then
                local chunk, err = load(src, "@" .. path, "t", env)
                if not chunk then error(err, 2) end
                cache[name] = LOADING
                local ok, result = pcall(chunk, name, path)
                if not ok then
                    cache[name] = nil
                    error(result, 0)
                end
                if result == nil then result = true end
                cache[name] = result
                return result
            end
        end
        return global_require(name)
    end
end
