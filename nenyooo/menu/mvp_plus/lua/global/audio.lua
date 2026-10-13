
local nv = native_invoker
-- audio.* — frontend sounds. Script-thread only.
audio = audio or {}
-- audio.play_frontend(sound, soundset): a UI/frontend sound (e.g. "SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET").
function audio.play_frontend(sound, soundset)
    nv.begin_call()
    nv.push_arg_int(-1); nv.push_arg_string(sound or ""); nv.push_arg_string(soundset or ""); nv.push_arg_bool(false)
    nv.end_call("67C540AA08E4A6F5")   -- PLAY_SOUND_FRONTEND
end

-- audio.command(command): small MCI-style command bridge for scripts that manage streamed files.
local aliases = {}
local current_alias
function audio.command(command)
    command = tostring(command or "")
    local path, alias = command:match('^open%s+"(.-)".-alias%s+(%S+)')
    if path and alias then aliases[alias] = path; return true end
    alias = command:match("^close%s+(%S+)")
    if alias == "all" then aliases = {}; current_alias = nil; audio.stop_file(); return true end
    if alias then
        aliases[alias] = nil
        if current_alias == alias then audio.stop_file(); current_alias = nil end
        return true
    end
    alias = command:match("^stop%s+(%S+)")
    if alias then
        audio.stop_file()
        if alias == "all" or alias == current_alias then current_alias = nil end
        return true
    end
    alias = command:match("^pause%s+(%S+)")
    if alias then audio.pause_file(); return true end
    local play_alias, from = command:match("^play%s+(%S+)%s+from%s+(%d+)")
    if play_alias then
        local file = aliases[play_alias]
        if file and not audio.play_path(file) then return false end
        current_alias = play_alias
        audio.seek((tonumber(from) or 0) / 1000)
        audio.resume_file()
        return true
    end
    local seek_alias, to = command:match("^seek%s+(%S+)%s+to%s+(%d+)")
    if seek_alias then audio.seek((tonumber(to) or 0) / 1000); return true end
    local volume_alias, volume = command:match("^setaudio%s+(%S+)%s+volume%s+to%s+(%d+)")
    if volume_alias then audio.set_volume((tonumber(volume) or 1000) / 1000); return true end
    if command:match("^window%s+") then return true end
    return false
end
