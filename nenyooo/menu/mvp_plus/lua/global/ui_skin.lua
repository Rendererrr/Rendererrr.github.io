-- Default skin for the click-GUI widget set.
--
-- Every measure/draw function receives the merged skin as its last argument, so a theme restyles by
-- assigning fields here (or pushing a scoped overlay) and never has to touch layout, hit-testing or
-- scrolling. Colours default to the active theme's accent so a fresh theme looks coherent before it
-- has configured anything.

ui.skin = {
    -- metrics
    pad          = 12,
    gap          = 8,
    row_h        = 28,
    btn_h        = 26,
    card_head    = 32,
    card_bot     = 10,
    card_pad     = 10,
    radius       = 10,
    pill_radius  = 999,     -- clamped to h/2 by the widgets; "fully round"
    btn_radius   = 999,     -- action chips; set ~6 for the squarer reference look
    btn_pad      = 10,
    btn_fit      = false,   -- true = chip is sized to its label, not the full row
    rail_w       = 52,
    rail_cell    = 40,      -- icon strip pitch; tabs pack from the top at this pitch
    header_h     = 46,
    scrollbar_w  = 4,
    sep_h        = 9,
    sep_inset    = 8,
    track_h      = 4,
    knob_r       = 6,
    toggle_w     = 34,
    toggle_h     = 18,
    toggle_knob  = 6,
    toggle_style = "switch",  -- "switch" (sliding pill) or "circle" (check disc)
    toggle_r     = 9,
    card_top_edge = false,   -- thin accent hairline along the card's top edge
    stepper_btn  = 22,
    caret_w      = 9,
    combo_frac   = 0.52,
    combo_radius = 6,    -- dropdown box width as a fraction of the row; label takes the rest
    swatch_w     = 26,

    font = {
        title = font.item,
        label = font.item,
        value = font.value,
        small = font.small,
        card  = font.item,
        icon  = font.label,     -- slot a theme points at its icon font via text.set_icon_font
    },

    col = {
        bg         = { 16, 12, 24, 245 },
        panel      = { 24, 18, 38, 255 },
        card       = { 30, 22, 48, 255 },
        card_hover = { 36, 27, 57, 255 },
        card_bdr   = { 92, 56, 168, 90 },
        txt        = { 236, 232, 245, 255 },
        txt_dim    = { 168, 160, 190, 255 },
        txt_off    = { 120, 114, 140, 255 },
        acc        = { 150, 70, 240, 255 },
        acc_dim    = { 96, 48, 156, 255 },
        pill       = { 70, 38, 120, 255 },
        pill_hover = { 92, 50, 156, 255 },
        toggle_off = { 58, 48, 78, 255 },
        knob       = { 245, 242, 250, 255 },
        track      = { 54, 44, 74, 255 },
        field      = { 20, 15, 32, 255 },
        field_bdr  = { 78, 60, 118, 170 },
        div        = { 110, 90, 150, 90 },
        scrollbar  = { 150, 70, 240, 170 },
        rail       = { 20, 15, 32, 255 },
        rail_sel   = { 150, 70, 240, 255 },
        disabled   = { 90, 86, 104, 255 },
    },
}

-- Pull the accent from the live theme so the default skin tracks whatever the user picked. Called by
-- ui.begin_frame via ui.sync_theme(); cheap enough to run per frame.
-- Themes that own their whole palette set ui.auto_accent = false.
ui.auto_accent = true

function ui.sync_theme()
    if not ui.auto_accent then return end
    local r, g, b = theme.accent()
    if r then
        local c = ui.skin.col
        c.acc[1], c.acc[2], c.acc[3] = r, g, b
        c.scrollbar[1], c.scrollbar[2], c.scrollbar[3] = r, g, b
        c.rail_sel[1], c.rail_sel[2], c.rail_sel[3] = r, g, b
        c.acc_dim[1], c.acc_dim[2], c.acc_dim[3] = r * 0.62, g * 0.62, b * 0.62
        c.pill[1], c.pill[2], c.pill[3] = r * 0.45, g * 0.45, b * 0.45
        c.pill_hover[1], c.pill_hover[2], c.pill_hover[3] = r * 0.62, g * 0.62, b * 0.62
    end
end

-- Scoped restyle: push an overlay for a subtree, pop it after. Shallow per section (col/font/metrics
-- are merged one level deep) so `ui.push_skin{ col = { acc = {...} } }` does not wipe the rest of col.
ui._skin_stack = {}

local function shallow_merge(base, over)
    local out = {}
    for k, v in pairs(base) do out[k] = v end
    for k, v in pairs(over) do
        if type(v) == "table" and type(base[k]) == "table" then
            local sub = {}
            for k2, v2 in pairs(base[k]) do sub[k2] = v2 end
            for k2, v2 in pairs(v) do sub[k2] = v2 end
            out[k] = sub
        else
            out[k] = v
        end
    end
    return out
end

function ui.push_skin(over)
    ui._skin_stack[#ui._skin_stack + 1] = ui.skin
    ui.skin = shallow_merge(ui.skin, over or {})
    return ui.skin
end

function ui.pop_skin()
    local n = #ui._skin_stack
    if n > 0 then
        ui.skin = ui._skin_stack[n]
        ui._skin_stack[n] = nil
    end
end
