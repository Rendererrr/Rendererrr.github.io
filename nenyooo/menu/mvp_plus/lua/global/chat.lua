
-- chat.* — PLACEHOLDER no-ops. We intentionally do NOT implement programmatic chat (no need). Every name a
-- Stand/dialect script might call is defined here as a safe no-op returning sensible defaults, so scripts
-- that reference chat.* run without nil-call errors instead of crashing. Nothing is sent or received.
chat = chat or {}
function chat.send_message(...) end           -- swallow (msg, team_only, ...) -> nothing sent
function chat.send_targeted_message(...) end  -- swallow (target, sender, msg, ...) -> nothing sent
function chat.is_open() return false end
function chat.get_state() return 0 end
function chat.get_draft() return "" end
function chat.get_history() return {} end
function chat.on_message(...) end             -- handler never fires (no chat events)
function chat.open() end
function chat.close() end
function chat.add_to_draft(...) end
function chat.remove_from_draft(...) end
function chat.ensure_open_with_empty_draft() end
-- internal_* variants Stand calls directly — all inert.
function chat.internal_open() end
function chat.internal_close() end
function chat.internal_open_impl() end
function chat.internal_close_impl() end
function chat.internal_lock() end
function chat.internal_unlock() end
function chat.internal_try_lock() return false end
function chat.internal_add_to_draft(...) end
