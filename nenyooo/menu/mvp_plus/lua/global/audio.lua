
local nv = native_invoker
-- audio.* — frontend sounds. Script-thread only.
audio = audio or {}
-- audio.play_frontend(sound, soundset): a UI/frontend sound (e.g. "SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET").
function audio.play_frontend(sound, soundset)
    nv.begin_call()
    nv.push_arg_int(-1); nv.push_arg_string(sound or ""); nv.push_arg_string(soundset or ""); nv.push_arg_bool(false)
    nv.end_call("67C540AA08E4A6F5")   -- PLAY_SOUND_FRONTEND
end
