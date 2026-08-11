-- Real — a faithful Lua port of the "Custom Mod Menu" HTML mock-up.
-- Black vertical list, white-on-black inverted selection, a bouncing 3D "N"
-- header with floating PlayStation-button particles, a left white scrollbar,
-- a footer (brand · up/down nav · counter) and a detached description box.
-- Built on the flat menu.* API (one navigable column per page).

-- ── Fonts ──
-- Try to load Orbitron for the big "N" if the user dropped it in; otherwise the
-- default title font is used. Body text uses the standard slots.
-- Body + title fonts come from the translation manifest's `default_fonts` block (downloaded once by
-- font_assets::ensure); str.default_body_font()/str.default_title_font() return the on-disk rel path
-- when the file has landed, "" otherwise. The theme reloads once the download completes so the fonts
-- apply retroactively on first run. Must run body BEFORE title (per-slot override wins over global).
pcall(function()
    local p = str and str.default_body_font and str.default_body_font() or ""
    if p ~= "" then text.load_font(p) end
end)
pcall(function()
    local p = str and str.default_title_font and str.default_title_font() or ""
    if p ~= "" then text.set_font_for(font.title, p) end
end)
-- Font sizes & weights are driven by Settings ▸ Theme ▸ Fonts; applied (with
-- change-detection) by apply_fonts() defined below.

-- ── Icons ──
local IMG = {}
local function load_icon(key, file)
    local h = draw.load_image("textures/"..file)
    if h and h > 0 then IMG[key] = h end
end
load_icon("on",    "On.png")
load_icon("off",   "Off.png")
load_icon("left",  "Left Arrow.png")
load_icon("right", "Right Arrow.png")
load_icon("up",    "Up Arrow.png")
load_icon("down",  "Down Arrow.png")
load_icon("tick",  "tick.png")
load_icon("search","search.png")

-- ── Layout constants (defaults; live values come from Settings ▸ Theme, applied
--    each frame at the top of draw_menu via reload_layout) ──
local WIN_W      = 400
local HDR_H      = 120     -- big "N" header
local HDR_GAP    = -1      -- padding between header and subheader
local SUB_H      = 34      -- subheader / breadcrumb strip
local FOOT_H     = 40
local ROW_H      = 38      -- per option row (HTML padding:14px 20px @16px)
local VIS_ROWS   = 13      -- visible rows before scrolling (HTML max-height 336)
local PAD_X      = 20
local SCROLL_W   = 4
local DESC_GAP   = 8
local DESC_H     = 34

-- ── Palette (defaults; live values come from Settings ▸ Theme via reload_colors) ──
local COL = {
    glow    = {120, 40, 220, 255}, -- purple bloom behind the 3D N
    hdr_l   = {138, 43, 226, 255}, -- header gradient left  (purple)
    hdr_r   = {0, 209, 224, 255},  -- header gradient right (cyan)
    black   = {0, 0, 0, 255},
    sub_bg  = {12, 12, 12, 255},  -- #0c0c0c
    desc_bg = {12, 12, 12, 255},
    row_txt = {221, 221, 221},   -- #ddd
    sub_txt = {187, 187, 187},   -- #bbb
    foot_txt= {136, 136, 136},   -- #888
    desc_txt= {154, 154, 154},   -- #9a9a9a
    dim     = {119, 119, 119},   -- #777 value text
    on      = {62, 217, 138},    -- #3ed98a
    off     = {255, 68, 56},     -- #ff4438
    white   = {255, 255, 255},
    sel_l   = {238, 230, 250, 255},
    sel_r   = {226, 246, 250, 255},
    sel_txt = {0, 0, 0, 255},
}

-- Status-tag badge colours (player list). Any hint token not listed keeps the purple keycap look.
local TAG_COL = {
    Me      = { 90, 170, 255},   -- you
    H       = {245, 190,  60},   -- session host
    SH      = {245, 140,  60},   -- freemode script host
    F       = { 90, 220, 120},   -- friend
    OTR     = { 80, 215, 235},   -- off the radar
    Passive = {170, 170, 180},
    Ghost   = {190, 120, 245},   -- ghosted to us; deliberately off OTR's cyan, since ghost-org
                                 -- OTR sets both tags at once
}

-- ════════════════════ Customizable settings (Settings ▸ Theme) ════════════════════
-- Single source of truth for every customizable value. Drives registration, the
-- live readers, the reset action, and the persisted file — all stay in sync.
local SETTINGS_FILE = "theme_settings.ini"

-- Layout sliders (lk = key in the `l` table reload_layout returns)
local LAYOUT_DEFS = {
    {n="Menu Width",             d=400, mn=240, mx=800, st=10, lk="win_w",    ds="Width of the complete menu"},
    {n="Banner Height",          d=120, mn=50,  mx=300, st=2,  lk="hdr_h",    ds="Height of the gradient logo banner"},
    {n="Banner Gap",             d=-1,  mn=-10, mx=60,  st=1,  lk="hdr_gap",  ds="Space between the banner and breadcrumb"},
    {n="Breadcrumb Height",      d=34,  mn=20,  mx=80,  st=1,  lk="sub_h",    ds="Height of the page-title bar"},
    {n="Row Height",             d=38,  mn=24,  mx=80,  st=1,  lk="row_h",    ds="Height of each menu option"},
    {n="Rows Per Page",          d=12,  mn=3,   mx=30,  st=1,  lk="vis_rows", ds="Maximum visible options before scrolling"},
    {n="Footer Height",          d=40,  mn=20,  mx=100, st=1,  lk="foot_h",   ds="Height of the version and counter bar"},
    {n="Horizontal Padding",     d=20,  mn=4,   mx=60,  st=1,  lk="pad_x",    ds="Left and right spacing inside the menu"},
    {n="Scrollbar Width",        d=2,   mn=0,   mx=20,  st=1,  lk="scroll_w", ds="Width of the list scrollbar"},
    {n="Description Gap",        d=8,   mn=0,   mx=40,  st=1,  lk="desc_gap", ds="Space above the detached description box"},
    {n="Minimum Description Height", d=34, mn=20, mx=120, st=1, lk="desc_h", ds="Minimum height before wrapped text expands the box"},
}

-- Font sliders (f = slot, kind = "sz" size / "wt" weight)
local FONT_DEFS = {
    {n="Logo Size",        d=110, mn=20, mx=160, st=1,   f=font.title,      kind="sz", ds="Size of the Nenyoo banner wordmark"},
    {n="Logo Weight",      d=100, mn=100,mx=900, st=100, f=font.title,      kind="wt", ds="Weight of the banner wordmark font"},
    {n="Breadcrumb Size",  d=13,  mn=8,  mx=40,  st=1,   f=font.breadcrumb, kind="sz", ds="Size of the current page title"},
    {n="Breadcrumb Weight",d=600, mn=100,mx=900, st=100, f=font.breadcrumb, kind="wt", ds="Weight of the current page title"},
    {n="Item Size",        d=15,  mn=8,  mx=40,  st=1,   f=font.item,       kind="sz", ds="Size of option names"},
    {n="Item Weight",      d=600, mn=100,mx=900, st=100, f=font.item,       kind="wt", ds="Weight of option names"},
    {n="Value Size",       d=13,  mn=8,  mx=40,  st=1,   f=font.value,      kind="sz", ds="Size of values and control labels"},
    {n="Value Weight",     d=600, mn=100,mx=900, st=100, f=font.value,      kind="wt", ds="Weight of values and control labels"},
    {n="Description Size", d=13,  mn=8,  mx=40,  st=1,   f=font.desc,       kind="sz", ds="Size of description-box text"},
    {n="Description Weight",d=500,mn=100,mx=900, st=100, f=font.desc,       kind="wt", ds="Weight of description-box text"},
    {n="Footer Size",      d=13,  mn=8,  mx=40,  st=1,   f=font.small,      kind="sz", ds="Size of the version and row counter"},
    {n="Footer Weight",    d=600, mn=100,mx=900, st=100, f=font.small,      kind="wt", ds="Weight of footer text"},
    {n="Badge Size",       d=13,  mn=6,  mx=30,  st=1,   f=font.tiny,       kind="sz", ds="Size of hotkey badges and edition label"},
    {n="Badge Weight",     d=600, mn=100,mx=900, st=100, f=font.tiny,       kind="wt", ds="Weight of badge text"},
}

-- Core UI colors (k = key in COL)
local COLOR_MAP = {
    {n="Menu Background",        k="black",   d={0,0,0,255},       ds="Options list, footer and menu gaps"},
    {n="Breadcrumb Background",  k="sub_bg",  d={12,12,12,255},    ds="Background behind the current page title"},
    {n="Description Background", k="desc_bg", d={12,12,12,255},    ds="Background of the detached description box"},
    {n="Item Text",              k="row_txt", d={221,221,221,255}, ds="Normal option and section text"},
    {n="Value Text",             k="dim",     d={119,119,119,255}, ds="Slider values and inactive controls"},
    {n="Breadcrumb Text",        k="sub_txt", d={187,187,187,255}, ds="Current page title"},
    {n="Footer Text",            k="foot_txt",d={136,136,136,255}, ds="Version, row counter and hotkey hint"},
    {n="Description Text",       k="desc_txt",d={154,154,154,255}, ds="Description-box text"},
    {n="Selected Row Left",      k="sel_l",   d={238,230,250,255}, ds="Left side of the selected-row gradient"},
    {n="Selected Row Right",     k="sel_r",   d={226,246,250,255}, ds="Right side of the selected-row gradient"},
    {n="Selected Row Text",      k="sel_txt", d={0,0,0,255},       ds="Text and controls on the selected row"},
    {n="Icons and Badges",       k="white",   d={255,255,255,255}, ds="Navigation icons and normal hotkey badges"},
    {n="Toggle On",              k="on",      d={62,217,138,255},  ds="Enabled toggle color"},
    {n="Toggle Off",             k="off",     d={255,68,56,255},   ds="Disabled toggle color"},
}
-- Decorative accent colors
local ACCENT_MAP = {
    {n="Banner Left",  k="hdr_l", d={138,43,226,255}, ds="Left side of the banner and accent lines"},
    {n="Banner Right", k="hdr_r", d={0,209,224,255},  ds="Right side of the banner and accent lines"},
    {n="Global Accent",k="glow",  d={120,40,220,255}, ds="Section markers and shared Lua overlays"},
}
-- Effect toggles (fk = key in FX)
local FX = {glare=true, scrollbar=true, hint=true}
local FX_DEFS = {
    {n="Breadcrumb Glare", d=true, fk="glare",     ds="Animate a light sweep across the page-title bar"},
    {n="Show Scrollbar",   d=true, fk="scrollbar", ds="Draw the colored scrollbar at the left of the list"},
    {n="Show Hotkey Hint", d=true, fk="hint",      ds="Show hotkey instructions in the page-title bar"},
}
local PANEL_DEFS = {
    {n="Show Panel",   label="Performance", d=true, mode=0, ds="FPS, frame time and menu performance"},
    {n="Show Pools",   label="Game Pools",  d=true, mode=0, ds="Ped, vehicle and object pool usage"},
    {n="Show Render",  label="Render Counts",d=true,mode=0, ds="Entities drawn during the current frame"},
    {n="Show Coords",  label="Coordinates", d=true, mode=0, ds="Player position, heading and speed"},
    {n="Show Session", label="Session",     d=true, mode=0, ds="Current session and network information"},
}

-- name -> kind, for parsing the saved file back
local KIND = {}
for _,d in ipairs(LAYOUT_DEFS) do KIND[d.n]="num" end
for _,d in ipairs(FONT_DEFS)   do KIND[d.n]="num" end
for _,d in ipairs(COLOR_MAP)   do KIND[d.n]="col" end
for _,d in ipairs(ACCENT_MAP)  do KIND[d.n]="col" end
for _,d in ipairs(FX_DEFS)     do KIND[d.n]="tog" end
for _,d in ipairs(PANEL_DEFS)  do KIND[d.n]="panel" end

-- ── Readers (fall back to defaults if a setting is somehow absent) ──
local function sf(name, def)
    local s = menu.get_setting(name)
    if s and s.f_val then return s.f_val end
    return def
end
local function sc(name, def)
    local s = menu.get_setting(name)
    if s and s.r then return {s.r, s.g, s.b, s.a} end
    return def
end
local function sb(name, def)
    local s = menu.get_setting(name)
    if s and s.on ~= nil then return s.on end
    return def
end

-- ── Registration ──
local function register_settings()
    menu.clear_settings()
    menu.add_setting_submenu("Layout", "Menu size, spacing and visible rows")
    for _,d in ipairs(LAYOUT_DEFS) do menu.add_sub_slider(d.n, d.d, d.mn, d.mx, d.st, d.ds) end
    menu.add_setting_submenu("Typography", "Sizes and weights for every text role")
    for _,d in ipairs(FONT_DEFS) do menu.add_sub_slider(d.n, d.d, d.mn, d.mx, d.st, d.ds) end
    menu.add_setting_submenu("Menu Colors", "Every color drawn by the main menu")
    for _,d in ipairs(COLOR_MAP) do menu.add_sub_color(d.n, d.d[1],d.d[2],d.d[3],d.d[4], d.ds) end
    menu.add_setting_submenu("Branding", "Banner gradient and shared accent")
    for _,d in ipairs(ACCENT_MAP) do menu.add_sub_color(d.n, d.d[1],d.d[2],d.d[3],d.d[4], d.ds) end
    menu.add_setting_submenu("Effects", "Optional menu animations and hints")
    for _,d in ipairs(FX_DEFS) do menu.add_sub_toggle(d.n, d.d, d.ds) end
    menu.add_setting_submenu("HUD Panels", "Visibility of optional on-screen information panels")
    for _,d in ipairs(PANEL_DEFS) do
        menu.add_sub_array_toggle(d.n, {"Always", "In Menu"}, d.mode, d.d, d.label..": "..d.ds)
    end
    menu.add_setting_action("Reset Theme", "Reset all theme settings to defaults")
end

-- ── Live appliers ──
local function reload_layout()
    local l = {}
    for _,d in ipairs(LAYOUT_DEFS) do l[d.lk] = sf(d.n, d.d) end
    l.vis_rows = math.max(1, math.floor(l.vis_rows + 0.5))
    return l
end
local function reload_colors()
    for _,d in ipairs(COLOR_MAP)  do COL[d.k] = sc(d.n, d.d) end
    for _,d in ipairs(ACCENT_MAP) do COL[d.k] = sc(d.n, d.d) end
end
local function reload_fx()
    for _,d in ipairs(FX_DEFS) do FX[d.fk] = sb(d.n, d.d) end
end
-- fonts rebuild the atlas — only call set_size/set_weight on a changed value
local last_font = {}
local function apply_fonts()
    for _,d in ipairs(FONT_DEFS) do
        local v = math.floor(sf(d.n, d.d) + 0.5)
        if last_font[d.n] ~= v then
            if d.kind=="sz" then text.set_size(d.f, v) else text.set_weight(d.f, v) end
            last_font[d.n] = v
        end
    end
end

-- ── Persistence ──
local last_sig, save_pending, save_stamp = nil, false, 0
local function serialize()
    local out = {}
    for _,d in ipairs(LAYOUT_DEFS) do out[#out+1] = d.n.."="..tostring(sf(d.n,d.d)) end
    for _,d in ipairs(FONT_DEFS)   do out[#out+1] = d.n.."="..tostring(sf(d.n,d.d)) end
    for _,d in ipairs(COLOR_MAP)   do local c=sc(d.n,d.d); out[#out+1]=d.n.."="..c[1]..","..c[2]..","..c[3]..","..c[4] end
    for _,d in ipairs(ACCENT_MAP)  do local c=sc(d.n,d.d); out[#out+1]=d.n.."="..c[1]..","..c[2]..","..c[3]..","..c[4] end
    for _,d in ipairs(FX_DEFS)     do out[#out+1] = d.n.."="..(sb(d.n,d.d) and "1" or "0") end
    for _,d in ipairs(PANEL_DEFS)  do local s=menu.get_setting(d.n); out[#out+1]=d.n.."="..((s and s.on) and "1" or "0")..","..tostring((s and s.value_index) or d.mode) end
    return table.concat(out, "\n")
end
local function apply_saved()
    local data = file.read(SETTINGS_FILE)
    if not data then return end
    for line in data:gmatch("[^\r\n]+") do
        local k, v = line:match("^(.-)=(.*)$")
        local kind = k and KIND[k]
        if kind=="num" then
            local nv = tonumber(v); if nv then menu.set_setting(k, nv) end
        elseif kind=="col" then
            local r,g,b,a = v:match("(%d+),(%d+),(%d+),(%d+)")
            if r then menu.set_setting(k, tonumber(r),tonumber(g),tonumber(b),tonumber(a)) end
        elseif kind=="tog" then
            menu.set_setting(k, v=="1")
        elseif kind=="panel" then
            local on,mode = v:match("([01]),(%d+)")
            if on then menu.set_setting(k, on=="1", tonumber(mode)) end
        end
    end
end
local function reset_settings()
    for _,d in ipairs(LAYOUT_DEFS) do menu.set_setting(d.n, d.d) end
    for _,d in ipairs(FONT_DEFS)   do menu.set_setting(d.n, d.d) end
    for _,d in ipairs(COLOR_MAP)   do menu.set_setting(d.n, d.d[1],d.d[2],d.d[3],d.d[4]) end
    for _,d in ipairs(ACCENT_MAP)  do menu.set_setting(d.n, d.d[1],d.d[2],d.d[3],d.d[4]) end
    for _,d in ipairs(FX_DEFS)     do menu.set_setting(d.n, d.d) end
    for _,d in ipairs(PANEL_DEFS)  do menu.set_setting(d.n, d.d, d.mode) end
    file.remove(SETTINGS_FILE)
end
local function is_reset(it) return it and it.type==item_type.action and it.name=="Reset Theme" end

-- Register, restore saved values, apply, and seed the change-signature.
register_settings()
apply_saved()
apply_fonts()
last_sig = serialize()

-- ── Helpers ──
local function clamp(v,lo,hi) return math.max(lo, math.min(hi, v)) end
local function lerp(a,b,t) return a+(b-a)*t end
local function alpha(c) return c[4] or 255 end
local function hit(x1,y1,x2,y2)
    local mx,my = input.mouse_x(), input.mouse_y()
    return mx>=x1 and mx<x2 and my>=y1 and my<y2
end
local function clk(x1,y1,x2,y2) return hit(x1,y1,x2,y2) and input.mouse_clicked(0) end

-- draw an image keeping its aspect, fit to a target height, returns drawn width
local function icon_h(key, x, cy, target_h, r,g,b,a)
    local h = IMG[key]; if not h then return 0 end
    local iw, ih = draw.image_size(h)
    if not iw or iw==0 then return 0 end
    local w = iw * (target_h/ih)
    local y = cy - target_h*0.5
    if r then draw.image_colored(h, x, y, x+w, y+target_h, r,g,b,a)
    else draw.image(h, x, y, x+w, y+target_h) end
    return w
end

-- Language rows (info_type 40, Settings ▸ Language) carry i_val == index into lang.list(). That list
-- is static for the process (codes + flag bands come from lang_meta.hpp, not from the pack), so fetch
-- it once and reuse -- the row loop runs every frame. Cached lazily because lang.* only has entries
-- once the manifest has landed.
local LANGS = nil
local function lang_entry(i)
    if not LANGS then
        if not lang or not lang.list then return nil end
        local ok, l = pcall(lang.list)
        if not ok or type(l) ~= "table" or #l == 0 then return nil end
        LANGS = l
    end
    return LANGS[(i or -1) + 1]
end

-- "Flag" = 1-3 flat colour bands (no image assets), same shape welcome_screen.lua draws.
local function draw_flag(x, y, w, h, entry)
    local bands = entry.bands or {}
    local n = #bands
    draw.push_clip(x, y, x+w, y+h)
    if n == 0 then
        draw.rect(x, y, x+w, y+h, 90, 90, 100, 255, 3)
    elseif entry.vertical then
        local bw = w / n
        for i, c in ipairs(bands) do
            local bx = x + (i-1)*bw
            draw.rect(bx, y, bx+bw+1, y+h, c[1], c[2], c[3], 255, 0)
        end
    else
        local bh = h / n
        for i, c in ipairs(bands) do
            local by = y + (i-1)*bh
            draw.rect(x, by, x+w, by+bh+1, c[1], c[2], c[3], 255, 0)
        end
    end
    draw.pop_clip()
    draw.rect_outline(x, y, x+w, y+h, 0, 0, 0, 150, 3, 1)
end

-- ── State ──
local scroll, scroll_t = 0, 0
local desc_alpha = 0
-- inline string editor
local edit_on, edit_idx, edit_buf, edit_type = false, -1, "", 0
local edit_start_frame = -1   -- the Enter that opens the editor must not also commit it (same-frame guard)
-- inline color picker
local cpick, cpick_idx, cpick_frame = false, -1, 0
local cpick_v = {0,0,0,255}
local cpick_h, cpick_s, cpick_val = 0,1,1
local cpick_sv_drag, cpick_hue_drag, cpick_a_drag = false, false, false
local CPICK_W, CPICK_GAP = 190, 10
-- inline hotkey capture
local hk_bind, hk_idx = false, -1
local last_sel = -1

local NUM = {
    [item_type.slider]=true, [item_type.int_option]=true,
    [item_type.float_toggle]=true, [item_type.int_toggle]=true,
}
local CYCLE = {
    [item_type.array_option]=true, [item_type.loop_option]=true,
    [item_type.array_toggle]=true, [item_type.loop_toggle]=true,
}

local function reset_scroll() scroll=0; scroll_t=0 end
local function close_popups() cpick=false; edit_on=false; hk_bind=false end

-- Activate the selected item, intercepting the "Reset Theme" action.
local function do_activate()
    local it = menu.get_item(menu.selected_index())
    if is_reset(it) then
        reset_settings(); apply_fonts()
        last_sig = serialize()
        notify.push("Theme", "Reset to defaults", 1)
    else
        -- Only reset scroll when activation navigates to a different page (e.g. opening a submenu).
        -- For in-place items (toggle/action/slider) we stay on the same page at the same selection,
        -- so keep the scroll position — resetting it replays the slide-down animation every press.
        local before = menu.page_name()
        menu.activate()
        if menu.page_name() ~= before then reset_scroll() end
    end
end

-- ════════════════════ Right-hand controls per row ════════════════════
-- color args: pass the row's text color so icons/text invert with selection.
local function draw_right(item, x, y, w, sel)
    local tp = item.type
    local cy = y + ROW_H*0.5
    local rx = x + w - PAD_X        -- right edge to lay out from
    local tc = sel and COL.sel_txt or COL.dim
    -- inline hotkey capture: show "Press any key…" in place of the widget
    if hk_bind and hk_idx==item._idx then
        local s = "Press any key…"
        local col = sel and {20,86,201} or {79,139,255}
        local fw = text.width(font.value, s)
        text.draw(font.value, rx-fw, cy-text.height(font.value)*0.5, col[1],col[2],col[3],255, s)
        return
    end
    local function val_text(s, col)
        local fw = text.width(font.value, s)
        text.draw(font.value, rx-fw, cy-text.height(font.value)*0.5,
            col[1],col[2],col[3], alpha(col), s)
        return fw
    end
    local function arrow(key, ax)
        -- arrows: white normally, black when row selected (HTML invert)
        local c = sel and COL.sel_txt or COL.white
        return icon_h(key, ax, cy, sel and 13 or 15, c[1],c[2],c[3],alpha(c))
    end

    if tp==item_type.sub_menu then
        local c = sel and COL.sel_txt or COL.white
        local w2 = icon_h("right", rx-13, cy, 14, c[1],c[2],c[3],alpha(c))

    elseif tp==item_type.selected_tick then
        -- selected button: tick on the right (white normally, black-inverted on selected row)
        local c = sel and COL.sel_txt or COL.white
        icon_h("tick", rx-15, cy, 15, c[1],c[2],c[3],alpha(c))

    elseif tp==item_type.action then
        -- buttons have no arrow (arrows mark sub-menus only)

    elseif tp==item_type.toggle then
        local key = item.on and "on" or "off"
        local c = sel and COL.sel_txt or (item.on and COL.on or COL.off)
        icon_h(key, rx-20, cy, 20, c[1],c[2],c[3],alpha(c))

    elseif tp==item_type.color then
        -- just the swatch (no arrows — not a button)
        local sw, shh = 26, 14
        local sx = rx - sw
        draw.rect(sx, cy-shh*0.5, sx+sw, cy+shh*0.5, item.r,item.g,item.b,item.a)
        local bc = sel and COL.sel_txt or {85,85,85,255}
        draw.rect_outline(sx, cy-shh*0.5, sx+sw, cy+shh*0.5, bc[1],bc[2],bc[3],alpha(bc), 0, 1)

    elseif tp==item_type.search then
        -- search button: search.png on the right, current query (or edit buffer) to its left
        local ed = edit_on and edit_idx==item._idx
        local c = sel and COL.sel_txt or COL.white
        local iw = icon_h("search", rx-14, cy, 14, c[1],c[2],c[3],alpha(c))
        local q = ed and (edit_buf .. (math.floor(ctx.time()*2)%2==0 and "|" or ""))
                  or (item.text ~= "" and item.text or "Search…")
        local col = ed and (sel and {20,86,201} or {79,139,255}) or tc
        local qw = text.width(font.value, q)
        text.draw(font.value, rx-14-6-qw, cy-text.height(font.value)*0.5, col[1],col[2],col[3],255, q)

    elseif tp==item_type.input_text or tp==item_type.input_int or tp==item_type.input_float then
        local ed = edit_on and edit_idx==item._idx
        local disp
        if ed then disp = edit_buf .. (math.floor(ctx.time()*2)%2==0 and "|" or "")
        elseif tp==item_type.input_int then disp = tostring(item.i_val)
        elseif tp==item_type.input_float then disp = string.format("%.2f", item.f_val)
        else disp = item.text or "" end
        if disp=="" then disp = (item.empty_value and item.empty_value~="") and item.empty_value or "..." end
        local col = ed and (sel and {20,86,201} or {79,139,255}) or tc
        val_text(disp, col)

    elseif NUM[tp] or tp==item_type.slider then
        -- value only (no arrows); *_toggle types also show on/off icon to the left
        local s
        if tp==item_type.int_toggle then s = tostring(item.i_val)
        elseif tp==item_type.int_option then s = tostring(item.i_val)
        else s = string.format(item.f_step and item.f_step<1 and "%.1f" or "%.0f", item.f_val) end
        local vw = text.width(font.value, s)
        text.draw(font.value, rx-vw, cy-text.height(font.value)*0.5, tc[1],tc[2],tc[3],alpha(tc), s)
        if tp==item_type.int_toggle or tp==item_type.float_toggle then
            local c = sel and COL.sel_txt or (item.on and COL.on or COL.off)
            icon_h(item.on and "on" or "off", rx-vw-8-18, cy, 18, c[1],c[2],c[3],alpha(c))
        end

    elseif tp==item_type.array_option or tp==item_type.loop_option
        or tp==item_type.array_toggle or tp==item_type.loop_toggle then
        -- ‹ string value ›  like the HTML (current selection, NOT a count)
        local s = item.current_value
        if s==nil or s=="" then
            local vals = menu.get_item_values(item._idx) or {}
            s = vals[(item.value_index or 0)+1] or ""
        end
        arrow("right", rx-12)
        local vw = text.width(font.value, s)
        text.draw(font.value, rx-12-6-vw, cy-text.height(font.value)*0.5, tc[1],tc[2],tc[3],alpha(tc), s)
        local lx = rx-12-6-vw-6-12
        arrow("left", lx)
        local clicked_dir = 0
        if clk(rx-27, y, rx+2, y+ROW_H) then clicked_dir = 1
        elseif clk(lx-4, y, lx+24, y+ROW_H) then clicked_dir = -1 end
        if clicked_dir ~= 0 and item.value_count and item.value_count > 0 then
            local vi = ((item.value_index or 0) + clicked_dir) % item.value_count
            if vi < 0 then vi = vi + item.value_count end
            menu.set_value_index(item._idx, vi)
        end
        -- toggle variants also show the on/off icon to the left of the arrows
        if tp==item_type.array_toggle or tp==item_type.loop_toggle then
            local c = sel and COL.sel_txt or (item.on and COL.on or COL.off)
            icon_h(item.on and "on" or "off", lx-6-18, cy, 18, c[1],c[2],c[3],alpha(c))
        end
        return clicked_dir ~= 0
    end
    return false
end

-- ════════════════════ Inline color picker ════════════════════
local function draw_cpick(wx, wy, ww, wh)
    if not cpick then return end
    local item = menu.get_item(cpick_idx)
    if not item then cpick=false; return end
    local SV_W,SV_H,HUE_W,ALPHA_H,PADP = 150,120,16,12,8
    local HEAD_H, FOOT_H = 24, 18
    local PW = CPICK_W
    local PH = HEAD_H+SV_H+ALPHA_H+PADP*4+FOOT_H
    local screen_pad = 12
    local px = wx + ww + CPICK_GAP
    if px+PW > ctx.screen_w()-screen_pad then px = wx-PW-CPICK_GAP end
    px = clamp(px, screen_pad, ctx.screen_w()-PW-screen_pad)
    local anchor_y = wy + cpick_idx*ROW_H - scroll + ROW_H*0.5
    local py = clamp(anchor_y-PH*0.5, screen_pad, ctx.screen_h()-PH-screen_pad)

    draw.rect(px+3,py+4,px+PW+3,py+PH+4, 0,0,0,95, 7)
    draw.rect(px,py,px+PW,py+PH, 18,18,22,252, 7)
    draw.rect_outline(px,py,px+PW,py+PH, 74,74,82,220, 7, 1)
    draw.rect_gradient(px,py,px+PW,py+HEAD_H,
        COL.hdr_l[1],COL.hdr_l[2],COL.hdr_l[3],235,
        COL.hdr_r[1],COL.hdr_r[2],COL.hdr_r[3],235,
        COL.hdr_r[1],COL.hdr_r[2],COL.hdr_r[3],235,
        COL.hdr_l[1],COL.hdr_l[2],COL.hdr_l[3],235)
    text.draw_spaced(font.tiny, px+PADP, py+(HEAD_H-text.height(font.tiny))*0.5,
        255,255,255,255, "COLOR", 1.0)

    local svx,svy = px+PADP, py+HEAD_H+PADP
    local hr,hg,hb = util.hsv_to_rgb(cpick_h,1,1)
    draw.rect_gradient(svx,svy,svx+SV_W,svy+SV_H, 255,255,255,255, hr,hg,hb,255, hr,hg,hb,255, 255,255,255,255)
    draw.rect_gradient(svx,svy,svx+SV_W,svy+SV_H, 0,0,0,0, 0,0,0,0, 0,0,0,255, 0,0,0,255)
    draw.rect_outline(svx,svy,svx+SV_W,svy+SV_H, 100,100,108,220, 2, 1)
    local ccx = svx+cpick_s*SV_W; local ccy = svy+(1-cpick_val)*SV_H
    draw.circle_outline(ccx,ccy,5,255,255,255,255,1.5); draw.circle_outline(ccx,ccy,4,0,0,0,200,1)
    if input.mouse_clicked(0) and hit(svx,svy,svx+SV_W,svy+SV_H) then cpick_sv_drag=true end
    if cpick_sv_drag and input.mouse_down(0) then
        cpick_s=clamp((input.mouse_x()-svx)/SV_W,0,1); cpick_val=clamp(1-(input.mouse_y()-svy)/SV_H,0,1)
        local nr,ng,nb=util.hsv_to_rgb(cpick_h,cpick_s,cpick_val); cpick_v[1]=math.floor(nr);cpick_v[2]=math.floor(ng);cpick_v[3]=math.floor(nb)
    end
    -- hue strip
    local hx,hy = svx+SV_W+PADP, svy
    for hi=0,11 do
        local r1,g1,b1=util.hsv_to_rgb(hi/12*360,1,1); local r2,g2,b2=util.hsv_to_rgb((hi+1)/12*360,1,1)
        draw.rect_gradient(hx,hy+hi*SV_H/12,hx+HUE_W,hy+(hi+1)*SV_H/12, r1,g1,b1,255,r1,g1,b1,255,r2,g2,b2,255,r2,g2,b2,255)
    end
    draw.rect_outline(hx,hy,hx+HUE_W,hy+SV_H, 100,100,108,220, 1, 1)
    local hcy=hy+(cpick_h/360)*SV_H; draw.rect_outline(hx-2,hcy-2,hx+HUE_W+2,hcy+2,255,255,255,255,0,1)
    if input.mouse_clicked(0) and hit(hx-2,hy,hx+HUE_W+2,hy+SV_H) then cpick_hue_drag=true end
    if cpick_hue_drag and input.mouse_down(0) then
        cpick_h=clamp((input.mouse_y()-hy)/SV_H,0,0.999)*360
        local nr,ng,nb=util.hsv_to_rgb(cpick_h,cpick_s,cpick_val); cpick_v[1]=math.floor(nr);cpick_v[2]=math.floor(ng);cpick_v[3]=math.floor(nb)
    end
    -- alpha
    local ay=svy+SV_H+PADP; local aw=SV_W+PADP+HUE_W
    draw.rect(svx,ay,svx+aw,ay+ALPHA_H, 40,40,40,255, 1)
    local at=cpick_v[4]/255
    draw.rect_gradient(svx,ay,svx+at*aw,ay+ALPHA_H, cpick_v[1],cpick_v[2],cpick_v[3],60, cpick_v[1],cpick_v[2],cpick_v[3],255, cpick_v[1],cpick_v[2],cpick_v[3],255, cpick_v[1],cpick_v[2],cpick_v[3],60)
    draw.rect_outline(svx,ay,svx+aw,ay+ALPHA_H, 75,75,84,220, 1, 1)
    if input.mouse_clicked(0) and hit(svx,ay-2,svx+aw,ay+ALPHA_H+2) then cpick_a_drag=true end
    if cpick_a_drag and input.mouse_down(0) then cpick_v[4]=math.floor(clamp((input.mouse_x()-svx)/aw,0,1)*255+0.5) end
    if input.mouse_released(0) then cpick_sv_drag=false; cpick_hue_drag=false; cpick_a_drag=false end
    -- hex + done
    local fy=ay+ALPHA_H+PADP
    draw.rect(svx,fy,svx+18,fy+14, cpick_v[1],cpick_v[2],cpick_v[3],cpick_v[4], 3)
    draw.rect_outline(svx,fy,svx+18,fy+14, 105,105,112,220, 3, 1)
    text.draw(font.tiny, svx+24, fy+1, 205,205,212,255, string.format("#%02X%02X%02X", cpick_v[1],cpick_v[2],cpick_v[3]))
    local dbx=px+PW-PADP-40
    local dh=hit(dbx,fy,dbx+40,fy+14)
    draw.rect(dbx,fy,dbx+40,fy+14, dh and 255 or 232, dh and 255 or 232, dh and 255 or 238, 255, 3)
    text.draw(font.tiny, dbx+(40-text.width(font.tiny,"Done"))*0.5, fy+1, 18,18,22,255, "Done")
    if clk(dbx,fy,dbx+40,fy+14) then cpick=false end
    -- apply live
    if cpick_v[1]~=item.r or cpick_v[2]~=item.g or cpick_v[3]~=item.b or cpick_v[4]~=item.a then
        menu.set_item_color(cpick_idx, cpick_v[1],cpick_v[2],cpick_v[3],cpick_v[4])
    end
    if ctx.frame()>cpick_frame and input.mouse_clicked(0) and not hit(px,py,px+PW,py+PH) then cpick=false end
end

-- ════════════════════ String editor processing ════════════════════
local function apply_edit()
    if not edit_on then return end
    menu.set_selected(edit_idx)
    if edit_type==item_type.input_int then
        local v=tonumber(edit_buf); if v then menu.set_i_val(edit_idx, math.floor(v)) end
    elseif edit_type==item_type.input_float then
        local v=tonumber(edit_buf); if v then menu.set_f_val(edit_idx, v) end
    else
        menu.set_input_buffer(edit_buf); menu.confirm_input()
    end
    edit_on=false
end
local function proc_edit()
    if not edit_on then return end
    local chars = input.get_chars()
    if chars ~= "" then
        for ch in chars:gmatch(".") do
            local b = string.byte(ch)
            if edit_type==item_type.input_text or edit_type==item_type.search then
                if #edit_buf<63 then edit_buf=edit_buf..ch end
            else
                local ok = (b>=48 and b<=57) or (b==45 and #edit_buf==0)
                    or (b==46 and edit_type==item_type.input_float and not edit_buf:find("%."))
                if ok then edit_buf=edit_buf..ch end
            end
        end
    end
    if input.key_just_pressed(VK.BACK) and #edit_buf>0 then edit_buf=edit_buf:sub(1,-2) end
    if input.key_just_pressed(VK.RETURN) and ctx.frame() ~= edit_start_frame then apply_edit() end
    if input.key_just_pressed(VK.ESCAPE) then edit_on=false end
end

-- ════════════════════ MAIN DRAW ════════════════════
function draw_menu()
    reload_colors(); reload_fx()
    theme.set_body_bg(COL.black[1], COL.black[2], COL.black[3], alpha(COL.black))
    theme.set_menu_bg(COL.black[1], COL.black[2], COL.black[3], alpha(COL.black))
    theme.set_accent_palette(COL.glow[1], COL.glow[2], COL.glow[3], alpha(COL.glow))
    if not menu.is_visible() then return end

    -- pull live layout + fonts from Settings ▸ Theme (cheap; reassigns the
    -- file-scope locals so draw_right etc. see the updated values this frame)
    local l = reload_layout(); apply_fonts()
    WIN_W=l.win_w; HDR_H=l.hdr_h; HDR_GAP=l.hdr_gap; SUB_H=l.sub_h; FOOT_H=l.foot_h
    ROW_H=l.row_h; VIS_ROWS=l.vis_rows; PAD_X=l.pad_x; SCROLL_W=l.scroll_w
    DESC_GAP=l.desc_gap; DESC_H=l.desc_h

    local count = menu.item_count()
    local sel   = menu.selected_index()
    if sel ~= last_sel then close_popups(); desc_alpha=0; last_sel=sel end

    -- box geometry (centered horizontally, upper third vertically)
    -- list shrinks to the actual item count so empty rows don't leave a gap
    local rows_shown = math.max(1, math.min(count, VIS_ROWS))
    local body_h = HDR_H + HDR_GAP + SUB_H + rows_shown*ROW_H + FOOT_H
    -- anchor the top to a FULL page's height so the header stays put no matter the
    -- option count; the box still shrinks downward (no empty rows) on short pages
    local ref_total_h = HDR_H + HDR_GAP + SUB_H + VIS_ROWS*ROW_H + FOOT_H + DESC_GAP + DESC_H
    local group_w = cpick and (WIN_W+CPICK_GAP+CPICK_W) or WIN_W
    local x = math.floor((ctx.screen_w()-group_w)/2)
    local y = math.floor((ctx.screen_h()-ref_total_h)/2)

    -- draggable by the header
    local dox, doy = menu.drag_header(x, y, WIN_W, HDR_H)
    x = x + dox; y = y + doy

    -- ── Header (purple → cyan horizontal gradient + centered "Nenyoo" wordmark) ──
    draw.rect_gradient(x, y, x+WIN_W, y+HDR_H,
        COL.hdr_l[1],COL.hdr_l[2],COL.hdr_l[3],alpha(COL.hdr_l),
        COL.hdr_r[1],COL.hdr_r[2],COL.hdr_r[3],alpha(COL.hdr_r),
        COL.hdr_r[1],COL.hdr_r[2],COL.hdr_r[3],alpha(COL.hdr_r),
        COL.hdr_l[1],COL.hdr_l[2],COL.hdr_l[3],alpha(COL.hdr_l))
    draw.push_clip(x, y, x+WIN_W, y+HDR_H)
    local brand = "Nenyoo"
    local bw = text.width(font.title, brand)
    local bh = text.height(font.title)
    local bx = x + (WIN_W - bw)*0.5
    -- Pricedown's line box has a deep descent, so full-line-height centering drops
    -- the glyphs too low. Nudge up by a fraction of the line height to visually center.
    local TITLE_VOFF = 0.10
    local by = y + (HDR_H - bh)*0.5 - bh*TITLE_VOFF
    text.draw(font.title, bx+2, by+2, 0,0,0,90, brand)      -- soft shadow
    text.draw(font.title, bx, by, 255,255,255,255, brand)   -- white wordmark
    -- edition tag (Legacy / Enhanced): white rounded pill w/ black text, tucked under the first "o"
    do
        local tag = ctx.edition and ctx.edition() or "Legacy"
        local tw  = text.width(font.tiny, tag)
        local th  = text.height(font.tiny)
        local padx = 4
        local pady = 1
        -- center the pill under the first "o" of the centered "Nenyoo" wordmark (~78% across it)
        local cxo = bx + bw*0.815
        local tgx = math.floor(cxo - tw*0.5)
        local tgy = y + HDR_H - th - 8
        local rad = 3                        -- slightly rounded corners
        draw.rect(tgx-padx, tgy-pady, tgx+tw+padx, tgy+th+pady, 255,255,255,255, rad)
        text.draw(font.tiny, tgx, tgy, 0,0,0,255, tag)
    end
    draw.pop_clip()
    -- padding between header and subheader
    if HDR_GAP > 0 then
        draw.rect(x, y+HDR_H, x+WIN_W, y+HDR_H+HDR_GAP, COL.black[1],COL.black[2],COL.black[3],alpha(COL.black))
    end

    -- ── Subheader (breadcrumb + back) ──
    local sy = y + HDR_H + HDR_GAP
    draw.rect(x, sy, x+WIN_W, sy+SUB_H, COL.sub_bg[1],COL.sub_bg[2],COL.sub_bg[3],alpha(COL.sub_bg))
    local title_x = x + PAD_X
    local title = string.upper(menu.page_name() or "MENU")
    -- subtle glare sweep
    text.draw_spaced(font.breadcrumb, title_x, sy+(SUB_H-text.height(font.breadcrumb))*0.5,
        COL.sub_txt[1],COL.sub_txt[2],COL.sub_txt[3],alpha(COL.sub_txt), title, 1.0)
    if FX.glare then
        local gp = (ctx.time()*0.32) % 1.6
        local gxc = x - WIN_W*0.5 + gp*WIN_W
        draw.push_clip(x, sy, x+WIN_W, sy+SUB_H)
        draw.rect_gradient(gxc-50, sy, gxc+50, sy+SUB_H,
            200,155,255,0, 200,155,255,40, 200,155,255,40, 200,155,255,0)
        draw.pop_clip()
    end
    -- hotkey hint (right side of subheader) when the selected row can bind
    do
        local hi = menu.get_item(sel)
        if FX.hint and not hk_bind and hi and hi.type~=item_type.sub_menu and menu.page_can_hotkey() then
            local hint = (hi.hotkey and hi.hotkey~=0) and "[H] rebind  [Del] clear" or "[H] hotkey"
            text.draw(font.tiny, x+WIN_W-PAD_X-text.width(font.tiny,hint),
                sy+(SUB_H-text.height(font.tiny))*0.5,
                COL.foot_txt[1],COL.foot_txt[2],COL.foot_txt[3],alpha(COL.foot_txt), hint)
        end
    end

    -- purple → cyan gradient accent line under the breadcrumb (matches the header)
    do
        local ly = sy + SUB_H - 2
        draw.rect_gradient(x, ly, x+WIN_W, ly+2,
            COL.hdr_l[1],COL.hdr_l[2],COL.hdr_l[3],alpha(COL.hdr_l),
            COL.hdr_r[1],COL.hdr_r[2],COL.hdr_r[3],alpha(COL.hdr_r),
            COL.hdr_r[1],COL.hdr_r[2],COL.hdr_r[3],alpha(COL.hdr_r),
            COL.hdr_l[1],COL.hdr_l[2],COL.hdr_l[3],alpha(COL.hdr_l))
    end

    -- ── Options list ──
    local list_y = sy + SUB_H
    local list_h = rows_shown*ROW_H
    draw.rect(x, list_y, x+WIN_W, list_y+list_h, COL.black[1],COL.black[2],COL.black[3],alpha(COL.black))
    -- Publish the list band so overlays that draw INSIDE the menu (the wardrobe's Advanced Editor)
    -- can cover exactly the rows and leave the header/breadcrumb/footer chrome showing.
    menu.set_content_rect(x, list_y, WIN_W, list_h)

    -- scroll to keep selection visible
    local content_h = count*ROW_H
    local scroll_max = math.max(0, content_h - list_h)
    local sel_top = sel*ROW_H
    local sel_bot = sel_top + ROW_H
    if sel_top - scroll_t < 0 then scroll_t = sel_top
    elseif sel_bot - scroll_t > list_h then scroll_t = sel_bot - list_h end
    scroll_t = clamp(scroll_t, 0, scroll_max)
    scroll = lerp(scroll, scroll_t, clamp(ctx.delta()*18, 0, 1))
    if math.abs(scroll-scroll_t) < 0.5 then scroll = scroll_t end

    -- mouse wheel
    if hit(x, list_y, x+WIN_W, list_y+list_h) and not cpick and not hk_bind and not menu.overlay_active() then
        local wh = input.mouse_wheel()
        if wh ~= 0 then scroll_t = clamp(scroll_t - wh*ROW_H*1.5, 0, scroll_max) end
    end

    draw.push_clip(x+SCROLL_W, list_y, x+WIN_W, list_y+list_h)
    for i=0,count-1 do
        -- Visibility first: only fetch the item (a C++ round-trip building a Lua table) for on-screen
        -- rows. On huge dynamic pages (e.g. 1000-row anim search) fetching all rows each frame tanks FPS.
        local ry = list_y + i*ROW_H - scroll
        if ry+ROW_H >= list_y and ry <= list_y+list_h then
            local item = menu.get_item(i)
            if item then
              item._idx = i
              if item.is_header then
                -- Section divider: purple accent bar + UPPERCASE label. No highlight, no right
                -- widget, no click (nav skips headers). Wrapping dashes/spaces are stripped.
                local label = (item.name or ""):gsub("^[%-%s]+",""):gsub("[%-%s]+$",""):upper()
                local barw, barh = 3, ROW_H*0.5
                local bx = x+PAD_X
                draw.rect(bx, ry+(ROW_H-barh)*0.5, bx+barw, ry+(ROW_H+barh)*0.5,
                    COL.glow[1],COL.glow[2],COL.glow[3],alpha(COL.glow))
                text.draw(font.item, bx+barw+8, ry+(ROW_H-text.height(font.item))*0.5,
                    COL.row_txt[1],COL.row_txt[2],COL.row_txt[3],alpha(COL.row_txt), label)
              else
                local is_sel = (i==sel)
                local hov = hit(x+SCROLL_W, ry, x+WIN_W, ry+ROW_H)
                if is_sel or hov then
                    -- subtle tinted-white gradient: faint purple → faint cyan (stays
                    -- light enough that the black row text/icons remain readable)
                    draw.rect_gradient(x+SCROLL_W, ry, x+WIN_W, ry+ROW_H,
                        COL.sel_l[1],COL.sel_l[2],COL.sel_l[3],alpha(COL.sel_l),
                        COL.sel_r[1],COL.sel_r[2],COL.sel_r[3],alpha(COL.sel_r),
                        COL.sel_r[1],COL.sel_r[2],COL.sel_r[3],alpha(COL.sel_r),
                        COL.sel_l[1],COL.sel_l[2],COL.sel_l[3],alpha(COL.sel_l))
                end
                -- Player rows carry info_type==1 + i_val==GTA player index: draw the mugshot portrait
                -- at the left and indent the name. Other rows keep name_x = x+PAD_X (unchanged).
                local name_x = x+PAD_X
                if item.info_type == 1 then
                    local mug = ROW_H - 6
                    local mx0, my0 = x+PAD_X, ry+3
                    if not players.draw_mugshot(item.i_val or -1, mx0, my0, mx0+mug, my0+mug) then
                        draw.rect(mx0, my0, mx0+mug, my0+mug, COL.row_txt[1],COL.row_txt[2],COL.row_txt[3],40)
                    end
                    name_x = mx0 + mug + 8
                elseif item.info_type == 6 or item.info_type == 7 or item.info_type == 8 or item.info_type == 9 then
                    -- Friend / incoming / sent / blocked rows: draw the Social Club avatar portrait
                    -- at the left (info_type selects the list), indent the name.
                    local mug = ROW_H - 6
                    local mx0, my0 = x+PAD_X, ry+3
                    if not friends.draw_avatar(item.info_type, item.i_val or -1, mx0, my0, mx0+mug, my0+mug) then
                        draw.rect(mx0, my0, mx0+mug, my0+mug, COL.row_txt[1],COL.row_txt[2],COL.row_txt[3],40)
                    end
                    name_x = mx0 + mug + 8
                elseif item.info_type == 40 then
                    -- Language rows: colour-band flag at the left, name indented.
                    local fh = ROW_H - 14
                    local fw = math.floor(fh * 1.6)
                    local fx0, fy0 = x+PAD_X, ry+7
                    local e = lang_entry(item.i_val)
                    if e then draw_flag(fx0, fy0, fw, fh, e)
                    else draw.rect(fx0, fy0, fx0+fw, fy0+fh, COL.row_txt[1],COL.row_txt[2],COL.row_txt[3],40, 3) end
                    name_x = fx0 + fw + 10
                end
                local tcol = (is_sel or hov) and COL.sel_txt or COL.row_txt
                text.draw(font.item, name_x, ry+(ROW_H-text.height(font.item))*0.5,
                    tcol[1],tcol[2],tcol[3],alpha(tcol), item.name)
                -- hotkey tag: keycap-style badge (white bg, dark text); inverts on the
                -- selected/hovered row (which is white) so it stays readable
                if item.hotkey and item.hotkey ~= 0 then
                    local ks   = menu.vk_name(item.hotkey)
                    local kw   = text.width(font.tiny, ks)
                    local kh   = text.height(font.tiny)
                    local padx, pady = 6, 3
                    local tagw = kw + padx*2
                    local tagh = kh + pady*2
                    local bx   = name_x+text.width(font.item, item.name)+8
                    local by   = ry + (ROW_H-tagh)*0.5
                    local inv  = is_sel or hov
                    local bg   = inv and COL.sel_txt or COL.white
                    local fg   = inv and COL.sel_l or COL.black
                    draw.rect(bx, by, bx+tagw, by+tagh, bg[1],bg[2],bg[3],alpha(bg), 4)
                    text.draw(font.tiny, bx+padx, by+pady, fg[1],fg[2],fg[3],alpha(fg), ks)
                end
                -- static key-hint: purple keycaps (e.g. "X V" -> [X] + [V]). Informational only,
                -- not a bindable hotkey. Sits after the name (and after the hotkey badge if any).
                if item.hint and item.hint ~= "" then
                    local padx, pady = 6, 3
                    local kh   = text.height(font.tiny)
                    local tagh = kh + pady*2
                    local by   = ry + (ROW_H-tagh)*0.5
                    local hx   = name_x+text.width(font.item, item.name)+8
                    if item.hotkey and item.hotkey ~= 0 then
                        hx = hx + text.width(font.tiny, menu.vk_name(item.hotkey)) + padx*2 + 8
                    end
                    local first = true
                    for tok in string.gmatch(item.hint, "%S+") do
                        -- A leading "*" marks a status tag (the player-list badges); everything else is
                        -- a real keycap. Without the marker a tag like "F" would collide with the
                        -- favourites hint "F" and recolour it on every catalog row.
                        local is_tag = (string.sub(tok, 1, 1) == "*")
                        if is_tag then tok = string.sub(tok, 2) end
                        local c = is_tag and TAG_COL[tok] or nil
                        -- "+" only joins real key combos; status tags stand alone.
                        if not first and not is_tag then
                            text.draw(font.tiny, hx+3, by+pady, 154,154,160,255, "+")
                            hx = hx + text.width(font.tiny, "+") + 6
                        end
                        first = false
                        local kw   = text.width(font.tiny, tok)
                        local tagw = kw + padx*2
                        local r,g,b = 150,90,245
                        if c then r,g,b = c[1],c[2],c[3] end
                        draw.rect(hx, by, hx+tagw, by+tagh, r,g,b,255, 4)
                        -- dark text on light badges, white on dark ones (rough luminance test)
                        local lum = (r*299 + g*587 + b*114) / 1000
                        if lum > 150 then
                            text.draw(font.tiny, hx+padx, by+pady, 20,20,26,255, tok)
                        else
                            text.draw(font.tiny, hx+padx, by+pady, 255,255,255,255, tok)
                        end
                        hx = hx + tagw + 3
                    end
                end
                local value_clicked = draw_right(item, x, ry, WIN_W, is_sel or hov)
                -- click selects, then acts
                if hov and input.mouse_clicked(0) and not cpick and not hk_bind and not menu.overlay_active() then
                    menu.set_selected(i)
                    if value_clicked then
                        -- The left/right value arrow already applied the change.
                    elseif item.type==item_type.toggle then menu.toggle_item(i)
                    elseif item.type==item_type.sub_menu or item.type==item_type.array_toggle
                        or item.type==item_type.loop_toggle or item.type==item_type.action
                        or item.type==item_type.selected_tick then
                        do_activate()
                    elseif item.type==item_type.color then
                        cpick=true; cpick_idx=i; cpick_frame=ctx.frame()
                        cpick_v={item.r,item.g,item.b,item.a}
                        cpick_h,cpick_s,cpick_val=util.rgb_to_hsv(item.r,item.g,item.b)
                    elseif item.type==item_type.input_text or item.type==item_type.input_int or item.type==item_type.input_float or item.type==item_type.search then
                        edit_on=true; edit_idx=i; edit_type=item.type; edit_start_frame=ctx.frame()
                        edit_buf = item.type==item_type.input_int and tostring(item.i_val)
                            or item.type==item_type.input_float and string.format("%.2f",item.f_val)
                            or ((item.type==item_type.input_text or item.type==item_type.search) and (item.text or "")) or ""
                    end
                end
              end
            end
        end
    end
    draw.pop_clip()

    -- ── Left scrollbar (white thumb) ──
    if FX.scrollbar then
        local ratio = list_h/content_h
        local th = math.max(list_h*ratio, 20)
        local maxtop = list_h-th
        local sr = scroll_max>0 and (scroll/scroll_max) or 0
        local ty = list_y+sr*maxtop
        -- vertical gradient: purple (top) -> cyan (bottom)
        draw.rect_gradient(x, ty, x+SCROLL_W, ty+th,
            COL.hdr_l[1],COL.hdr_l[2],COL.hdr_l[3],alpha(COL.hdr_l),
            COL.hdr_l[1],COL.hdr_l[2],COL.hdr_l[3],alpha(COL.hdr_l),
            COL.hdr_r[1],COL.hdr_r[2],COL.hdr_r[3],alpha(COL.hdr_r),
            COL.hdr_r[1],COL.hdr_r[2],COL.hdr_r[3],alpha(COL.hdr_r))
    end

    -- ── Footer ──
    local fy = list_y + list_h
    draw.rect(x, fy, x+WIN_W, fy+FOOT_H, COL.black[1],COL.black[2],COL.black[3],alpha(COL.black))
    -- cyan → purple gradient accent line at the top of the footer (left cyan, right purple)
    draw.rect_gradient(x, fy, x+WIN_W, fy+2,
        COL.hdr_r[1],COL.hdr_r[2],COL.hdr_r[3],alpha(COL.hdr_r),
        COL.hdr_l[1],COL.hdr_l[2],COL.hdr_l[3],alpha(COL.hdr_l),
        COL.hdr_l[1],COL.hdr_l[2],COL.hdr_l[3],alpha(COL.hdr_l),
        COL.hdr_r[1],COL.hdr_r[2],COL.hdr_r[3],alpha(COL.hdr_r))
    local fcy = fy+FOOT_H*0.5
    local ver = (str.version and str.version ~= "") and str.version or "dev"
    text.draw(font.small, x+PAD_X, fcy-text.height(font.small)*0.5,
        COL.foot_txt[1],COL.foot_txt[2],COL.foot_txt[3],alpha(COL.foot_txt), "v"..ver)
    -- center up/down nav (overlapping like the HTML)
    local navx = x+WIN_W*0.5
    local uw = icon_h("up", navx-7, fcy-7, 22, COL.white[1],COL.white[2],COL.white[3], hit(navx-16,fy,navx+16,fcy) and alpha(COL.white) or math.min(alpha(COL.white),170))
    local dw = icon_h("down", navx-7, fcy+7, 22, COL.white[1],COL.white[2],COL.white[3], hit(navx-16,fcy,navx+16,fy+FOOT_H) and alpha(COL.white) or math.min(alpha(COL.white),170))
    if clk(navx-16, fy, navx+16, fcy) then menu.move_selection(-1) end
    if clk(navx-16, fcy, navx+16, fy+FOOT_H) then menu.move_selection(1) end
    -- counter
    local cnt = (count>0 and (sel+1) or 0).." / "..count
    text.draw(font.small, x+WIN_W-PAD_X-text.width(font.small,cnt), fcy-text.height(font.small)*0.5,
        COL.foot_txt[1],COL.foot_txt[2],COL.foot_txt[3],alpha(COL.foot_txt), cnt)

    -- ── Description box (detached, white left accent) — grows to fit wrapped text ──
    desc_alpha = lerp(desc_alpha, 1, clamp(ctx.delta()*10,0,1))
    local dy = fy + FOOT_H + DESC_GAP
    local di = menu.get_item(sel)
    local dtext = (di and di.desc and di.desc~="") and di.desc or (di and ("Adjust "..di.name..".") or "")
    local dmaxw = WIN_W - 54   -- leave room on the left for the info "i" glyph
    local dlh   = text.height(font.desc) * 1.32
    -- count wrapped lines (greedy word wrap, mirrors the renderer's word wrapping)
    local dlines, dcur = 1, ""
    for word in dtext:gmatch("%S+") do
        local cand = (dcur=="") and word or (dcur.." "..word)
        if text.width(font.desc, cand) > dmaxw and dcur~="" then dlines = dlines + 1; dcur = word
        else dcur = cand end
    end
    local dvpad = math.max(4, (DESC_H - dlh)*0.5)
    local desc_h = math.max(DESC_H, math.ceil(dlines*dlh + dvpad*2))
    draw.rect(x, dy, x+WIN_W, dy+desc_h, COL.desc_bg[1],COL.desc_bg[2],COL.desc_bg[3],alpha(COL.desc_bg))
    -- thin left accent: vertical gradient (cyan top -> purple bottom)
    draw.rect_gradient(x, dy, x+2, dy+desc_h,
        COL.hdr_r[1],COL.hdr_r[2],COL.hdr_r[3],alpha(COL.hdr_r),
        COL.hdr_r[1],COL.hdr_r[2],COL.hdr_r[3],alpha(COL.hdr_r),
        COL.hdr_l[1],COL.hdr_l[2],COL.hdr_l[3],alpha(COL.hdr_l),
        COL.hdr_l[1],COL.hdr_l[2],COL.hdr_l[3],alpha(COL.hdr_l))
    local a = math.floor(alpha(COL.desc_txt)*desc_alpha)
    -- info "i" glyph: white filled circle with a black "i", vertically centered on the left
    do
        local icx = x + 22
        local icy = dy + dvpad + text.height(font.desc)*0.5   -- align to the first text line
        local r   = 8
        local ia = math.floor(alpha(COL.white)*desc_alpha)
        draw.circle(icx, icy, r, COL.white[1],COL.white[2],COL.white[3],ia)
        draw.circle(icx, icy - r*0.46, 1.9, COL.black[1],COL.black[2],COL.black[3],ia)
        draw.rect(icx-1.4, icy - r*0.14, icx+1.4, icy + r*0.6, COL.black[1],COL.black[2],COL.black[3],ia)
    end
    draw.push_clip(x+38, dy, x+WIN_W-12, dy+desc_h)
    text.draw(font.desc, x+40, dy+dvpad,
        COL.desc_txt[1],COL.desc_txt[2],COL.desc_txt[3],a, dtext, dmaxw)
    draw.pop_clip()

    -- popups on top
    draw_cpick(x, list_y, WIN_W, list_h)
    proc_edit()
    menu.set_text_editing(edit_on)   -- tell the script thread to suppress game/cam input while typing

    -- persist settings to disk (debounced ~0.4s after the last change so dragging
    -- a slider / scrubbing the color picker doesn't thrash the file)
    local sig = serialize()
    if sig ~= last_sig then save_pending=true; save_stamp=ctx.time(); last_sig=sig end
    if save_pending and (ctx.time()-save_stamp) > 0.4 then
        file.write(SETTINGS_FILE, last_sig); save_pending=false
    end
end

-- ════════════════════ INPUT ════════════════════
function handle_input()
    if not menu.is_visible() then return end
    if edit_on then return end           -- editor consumes keys in proc_edit

    if cpick then
        if input.key_just_pressed(VK.ESCAPE) or input.key_just_pressed(VK.RETURN) then cpick=false end
        return
    end

    -- inline hotkey capture: consume the next key (skip esc/mouse/modifiers)
    if hk_bind then
        if input.key_just_pressed(VK.ESCAPE) then
            hk_bind=false
            notify.push("Hotkey", "Cancelled", 0)
            return
        end
        local skip = {[27]=true,[1]=true,[2]=true,[4]=true,
                      [16]=true,[17]=true,[18]=true,
                      [160]=true,[161]=true,[162]=true,[163]=true,[164]=true,[165]=true}
        for vk=1,255 do
            if not skip[vk] and input.key_just_pressed(vk) then
                menu.set_hotkey(hk_idx, vk)
                local it = menu.get_item(hk_idx)
                notify.push(it and it.name or "Hotkey", "Bound to "..menu.vk_name(vk), 1)
                menu.save_hotkeys()
                menu.rebuild_features()
                hk_bind=false
                return
            end
        end
        return
    end

    if input.key_pressed(VK.DOWN) then menu.move_selection(1) end
    if input.key_pressed(VK.UP)   then menu.move_selection(-1) end

    local item = menu.get_item(menu.selected_index())
    local tp = item and item.type

    -- H = bind hotkey, Del = clear (only on hotkeyable, non-submenu rows)
    if item and tp~=item_type.sub_menu and menu.page_can_hotkey() then
        if input.key_just_pressed(0x48) then
            hk_bind=true; hk_idx=menu.selected_index(); return
        end
        if input.key_just_pressed(VK.DELETE) and item.hotkey and item.hotkey~=0 then
            menu.set_hotkey(menu.selected_index(), 0)
            menu.save_hotkeys(); menu.rebuild_features()
            notify.push(item.name, "Hotkey cleared", 0)
            return
        end
    end

    -- LEFT / RIGHT adjust value-style controls (dir = -1 / +1)
    local function adjust(dir)
        local idx = menu.selected_index()
        if tp==item_type.array_option or tp==item_type.loop_option
            or tp==item_type.array_toggle or tp==item_type.loop_toggle then
            local cnt2 = (item.value_count and item.value_count>0) and item.value_count or 1
            local vi = ((item.value_index or 0) + dir) % cnt2
            if vi < 0 then vi = vi + cnt2 end
            menu.set_value_index(idx, vi)
        elseif tp==item_type.int_option or tp==item_type.int_toggle then
            local st = (item.i_step and item.i_step~=0) and item.i_step or 1
            menu.set_i_val(idx, (item.i_val or 0) + dir*st)
        elseif tp==item_type.slider or tp==item_type.float_toggle then
            local st = (item.f_step and item.f_step~=0) and item.f_step or 0.1
            menu.set_f_val(idx, (item.f_val or 0) + dir*st)
        else
            return false
        end
        return true
    end

    -- Value controls auto-repeat while LEFT/RIGHT is held (same cadence as UP/DOWN nav);
    -- activate / go-back stay edge-only so holding doesn't re-fire them.
    if input.key_pressed(VK.RIGHT) and item and adjust(1) then
        -- adjusted (repeats while held)
    elseif input.key_just_pressed(VK.RIGHT) and item then
        do_activate()
    end
    if input.key_pressed(VK.LEFT) and item and adjust(-1) then
        -- adjusted (repeats while held)
    elseif input.key_just_pressed(VK.LEFT) then
        menu.go_back(); reset_scroll()
    end

    if input.key_just_pressed(VK.RETURN) then
        if item and tp==item_type.color then
            cpick=true; cpick_idx=menu.selected_index(); cpick_frame=ctx.frame()
            cpick_v={item.r,item.g,item.b,item.a}
            cpick_h,cpick_s,cpick_val=util.rgb_to_hsv(item.r,item.g,item.b)
        elseif item and (tp==item_type.input_text or tp==item_type.input_int or tp==item_type.input_float or tp==item_type.search) then
            edit_on=true; edit_idx=menu.selected_index(); edit_type=tp; edit_start_frame=ctx.frame()
            edit_buf = tp==item_type.input_int and tostring(item.i_val)
                or tp==item_type.input_float and string.format("%.2f",item.f_val)
                or ((tp==item_type.input_text or tp==item_type.search) and (item.text or "")) or ""
        else
            do_activate()
        end
    end

    if input.key_just_pressed(VK.BACK) or input.key_just_pressed(VK.ESCAPE) then
        menu.go_back(); reset_scroll()
    end
end
