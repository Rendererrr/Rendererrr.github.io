-- ImGui.* — Dear ImGui-compatible immediate-mode API for Lua scripts (YimMenu / sol_ImGui conventions).
--
-- WHY THIS EXISTS
-- Scripts written for YimMenu build their UI with ImGui.Begin / ImGui.Button / ImGui.Checkbox ... inside
-- a callback registered with gui.add_imgui(fn). Our overlay is Direct2D, not Dear ImGui, so instead of a
-- second renderer this file re-implements the ImGui API on top of draw.* / text.* / input.* / ui.*. The
-- result looks native (colours come from the active theme via ui.skin) and scripts run unchanged.
--
-- CONVENTIONS (identical to sol_ImGui, which YimMenu exposes):
--   * values come back first, the "changed" flag second:   v, pressed = ImGui.Checkbox("God mode", v)
--   * colours are floats 0..1 ({r,g,b,a} tables or 4 numbers); Combo/ListBox indices are 0-based
--   * every Begin* that returned true needs its End*; ImGui.Begin/End and BeginChild/EndChild ALWAYS pair
--   * enums: ImGuiWindowFlags.NoTitleBar, ImGuiCol.Button, ImGuiCond.FirstUseEver, ImGuiKey.F5, ...
--     numeric values match Dear ImGui 1.92, so scripts that pass raw numbers work too
--
-- THREADING: ImGui callbacks run on the RENDER thread. Never call game natives from them -- queue game
-- work with fiber.run(fn) / script.on_tick(fn) instead (same rule as YimMenu's script.run_in_fiber).
--
-- MODEL: widgets record draw commands into their window; after every callback ran, windows are painted
-- back to front (popups, tooltips, foreground list last). Hover is resolved from LAST frame's window
-- rects in z-order, so a window underneath never reacts. The hovered window claims input layer 100 in
-- ui_input, so the theme menu underneath yields the mouse while an ImGui window covers it.
--
-- Loaded into _G by load_api_foundation(). Sorts before ui.lua/util.lua: nothing here may CALL those
-- at load time (call time is fine).

ImGui = ImGui or {}
local im = ImGui
local floor, max, min, abs = math.floor, math.max, math.min, math.abs

-- ── enums ────────────────────────────────────────────────────────────────────

local function seq(names, start)
    local t, v = {}, start or 0
    for i = 1, #names do t[names[i]] = v; v = v + 1 end
    return t
end

ImGuiWindowFlags = {
    None = 0, NoTitleBar = 1, NoResize = 2, NoMove = 4, NoScrollbar = 8, NoScrollWithMouse = 16,
    NoCollapse = 32, AlwaysAutoResize = 64, NoBackground = 128, NoSavedSettings = 256,
    NoMouseInputs = 512, MenuBar = 1024, HorizontalScrollbar = 2048, NoFocusOnAppearing = 4096,
    NoBringToFrontOnFocus = 8192, AlwaysVerticalScrollbar = 16384, AlwaysHorizontalScrollbar = 32768,
    NoNavInputs = 65536, NoNavFocus = 131072, UnsavedDocument = 262144,
    NoNav = 65536 | 131072, NoDecoration = 1 | 2 | 8 | 32, NoInputs = 512 | 65536 | 131072,
}
ImGuiChildFlags = {
    None = 0, Borders = 1, Border = 1, AlwaysUseWindowPadding = 2, ResizeX = 4, ResizeY = 8,
    AutoResizeX = 16, AutoResizeY = 32, AlwaysAutoResize = 64, FrameStyle = 128, NavFlattened = 256,
}
local COL_NAMES = {
    "Text", "TextDisabled", "WindowBg", "ChildBg", "PopupBg", "Border", "BorderShadow", "FrameBg",
    "FrameBgHovered", "FrameBgActive", "TitleBg", "TitleBgActive", "TitleBgCollapsed", "MenuBarBg",
    "ScrollbarBg", "ScrollbarGrab", "ScrollbarGrabHovered", "ScrollbarGrabActive", "CheckMark",
    "SliderGrab", "SliderGrabActive", "Button", "ButtonHovered", "ButtonActive", "Header", "HeaderHovered",
    "HeaderActive", "Separator", "SeparatorHovered", "SeparatorActive", "ResizeGrip", "ResizeGripHovered",
    "ResizeGripActive", "InputTextCursor", "TabHovered", "Tab", "TabSelected", "TabSelectedOverline",
    "TabDimmed", "TabDimmedSelected", "TabDimmedSelectedOverline", "PlotLines", "PlotLinesHovered",
    "PlotHistogram", "PlotHistogramHovered", "TableHeaderBg", "TableBorderStrong", "TableBorderLight",
    "TableRowBg", "TableRowBgAlt", "TextLink", "TextSelectedBg", "TreeLines", "DragDropTarget", "NavCursor",
    "NavWindowingHighlight", "NavWindowingDimBg", "ModalWindowDimBg", "COUNT",
}
ImGuiCol = seq(COL_NAMES)
ImGuiCol.TabActive, ImGuiCol.TabUnfocused = ImGuiCol.TabSelected, ImGuiCol.TabDimmed
ImGuiCol.TabUnfocusedActive, ImGuiCol.NavHighlight = ImGuiCol.TabDimmedSelected, ImGuiCol.NavCursor
ImGuiStyleVar = seq({
    "Alpha", "DisabledAlpha", "WindowPadding", "WindowRounding", "WindowBorderSize", "WindowMinSize",
    "WindowTitleAlign", "ChildRounding", "ChildBorderSize", "PopupRounding", "PopupBorderSize",
    "FramePadding", "FrameRounding", "FrameBorderSize", "ItemSpacing", "ItemInnerSpacing", "IndentSpacing",
    "CellPadding", "ScrollbarSize", "ScrollbarRounding", "GrabMinSize", "GrabRounding", "ImageBorderSize",
    "TabRounding", "TabBorderSize", "TabBarBorderSize", "TabBarOverlineSize", "TableAngledHeadersAngle",
    "TableAngledHeadersTextAlign", "TreeLinesSize", "TreeLinesRounding", "ButtonTextAlign",
    "SelectableTextAlign", "SeparatorTextBorderSize", "SeparatorTextAlign", "SeparatorTextPadding", "COUNT",
})
ImGuiCond = { None = 0, Always = 1, Once = 2, FirstUseEver = 4, Appearing = 8 }
ImGuiTreeNodeFlags = {
    None = 0, Selected = 1, Framed = 2, AllowOverlap = 4, AllowItemOverlap = 4, NoTreePushOnOpen = 8,
    NoAutoOpenOnLog = 16, DefaultOpen = 32, OpenOnDoubleClick = 64, OpenOnArrow = 128, Leaf = 256,
    Bullet = 512, FramePadding = 1024, SpanAvailWidth = 2048, SpanFullWidth = 4096, SpanLabelWidth = 8192,
    SpanTextWidth = 8192, SpanAllColumns = 16384, CollapsingHeader = 2 | 8 | 16,
}
ImGuiInputTextFlags = {
    None = 0, CharsDecimal = 1, CharsHexadecimal = 2, CharsScientific = 4, CharsUppercase = 8,
    CharsNoBlank = 16, AllowTabInput = 32, EnterReturnsTrue = 64, EscapeClearsAll = 128,
    CtrlEnterForNewLine = 256, ReadOnly = 512, Password = 1024, AlwaysOverwrite = 2048, AutoSelectAll = 4096,
    ParseEmptyRefVal = 8192, DisplayEmptyRefVal = 16384, NoHorizontalScroll = 32768, NoUndoRedo = 65536,
    ElideLeft = 131072, CallbackCompletion = 262144, CallbackHistory = 524288, CallbackAlways = 1048576,
    CallbackCharFilter = 2097152, CallbackResize = 4194304, CallbackEdit = 8388608,
}
ImGuiSelectableFlags = {
    None = 0, NoAutoClosePopups = 1, DontClosePopups = 1, SpanAllColumns = 2, AllowDoubleClick = 4,
    Disabled = 8, AllowOverlap = 16, AllowItemOverlap = 16, Highlight = 32,
}
ImGuiComboFlags = {
    None = 0, PopupAlignLeft = 1, HeightSmall = 2, HeightRegular = 4, HeightLarge = 8, HeightLargest = 16,
    NoArrowButton = 32, NoPreview = 64, WidthFitPreview = 128,
}
ImGuiTabBarFlags = {
    None = 0, Reorderable = 1, AutoSelectNewTabs = 2, TabListPopupButton = 4,
    NoCloseWithMiddleMouseButton = 8, NoTabListScrollingButtons = 16, NoTooltip = 32,
    DrawSelectedOverline = 64, FittingPolicyResizeDown = 128, FittingPolicyScroll = 256,
}
ImGuiTabItemFlags = {
    None = 0, UnsavedDocument = 1, SetSelected = 2, NoCloseWithMiddleMouseButton = 4, NoPushId = 8,
    NoTooltip = 16, NoReorder = 32, Leading = 64, Trailing = 128, NoAssumedClosure = 256,
}
ImGuiHoveredFlags = {
    None = 0, ChildWindows = 1, RootWindow = 2, AnyWindow = 4, NoPopupHierarchy = 8,
    AllowWhenBlockedByPopup = 32, AllowWhenBlockedByActiveItem = 128, AllowWhenOverlappedByItem = 256,
    AllowWhenOverlappedByWindow = 512, AllowWhenDisabled = 1024, NoNavOverride = 2048,
    AllowWhenOverlapped = 256 | 512, RectOnly = 32 | 128 | 256 | 512, RootAndChildWindows = 1 | 2,
    ForTooltip = 4096, Stationary = 8192, DelayNone = 16384, DelayShort = 32768, DelayNormal = 65536,
    NoSharedDelay = 131072,
}
ImGuiFocusedFlags = { None = 0, ChildWindows = 1, RootWindow = 2, AnyWindow = 4, NoPopupHierarchy = 8, RootAndChildWindows = 3 }
ImGuiPopupFlags = {
    None = 0, MouseButtonLeft = 0, MouseButtonRight = 1, MouseButtonMiddle = 2, NoReopen = 32,
    NoOpenOverExistingPopup = 128, NoOpenOverItems = 256, AnyPopupId = 1024, AnyPopupLevel = 2048,
    AnyPopup = 1024 | 2048,
}
ImGuiSliderFlags = {
    None = 0, Logarithmic = 32, NoRoundToFormat = 64, NoInput = 128, WrapAround = 256, ClampOnInput = 512,
    ClampZeroRange = 1024, NoSpeedTweaks = 2048, AlwaysClamp = 512 | 1024,
}
ImGuiColorEditFlags = {
    None = 0, NoAlpha = 2, NoPicker = 4, NoOptions = 8, NoSmallPreview = 16, NoInputs = 32, NoTooltip = 64,
    NoLabel = 128, NoSidePreview = 256, NoDragDrop = 512, NoBorder = 1024, AlphaOpaque = 2048,
    AlphaNoBg = 4096, AlphaPreviewHalf = 8192, AlphaPreview = 0, AlphaBar = 65536, HDR = 524288,
    DisplayRGB = 1048576, DisplayHSV = 2097152, DisplayHex = 4194304, Uint8 = 8388608, Float = 16777216,
    PickerHueBar = 33554432, PickerHueWheel = 67108864, InputRGB = 134217728, InputHSV = 268435456,
}
ImGuiTableFlags = {
    None = 0, Resizable = 1, Reorderable = 2, Hideable = 4, Sortable = 8, NoSavedSettings = 16,
    ContextMenuInBody = 32, RowBg = 64, BordersInnerH = 128, BordersOuterH = 256, BordersInnerV = 512,
    BordersOuterV = 1024, BordersH = 128 | 256, BordersV = 512 | 1024, BordersInner = 128 | 512,
    BordersOuter = 256 | 1024, Borders = 128 | 256 | 512 | 1024, NoBordersInBody = 2048,
    NoBordersInBodyUntilResize = 4096, SizingFixedFit = 8192, SizingFixedSame = 16384,
    SizingStretchProp = 24576, SizingStretchSame = 32768, NoHostExtendX = 65536, NoHostExtendY = 131072,
    NoKeepColumnsVisible = 262144, PreciseWidths = 524288, NoClip = 1048576, PadOuterX = 2097152,
    NoPadOuterX = 4194304, NoPadInnerX = 8388608, ScrollX = 16777216, ScrollY = 33554432,
    SortMulti = 67108864, SortTristate = 134217728, HighlightHoveredColumn = 268435456,
}
ImGuiTableColumnFlags = {
    None = 0, Disabled = 1, DefaultHide = 2, DefaultSort = 4, WidthStretch = 8, WidthFixed = 16,
    NoResize = 32, NoReorder = 64, NoHide = 128, NoClip = 256, NoSort = 512, NoSortAscending = 1024,
    NoSortDescending = 2048, NoHeaderLabel = 4096, NoHeaderWidth = 8192, PreferSortAscending = 16384,
    PreferSortDescending = 32768, IndentEnable = 65536, IndentDisable = 131072, AngledHeader = 262144,
    IsEnabled = 1 << 24, IsVisible = 1 << 25, IsSorted = 1 << 26, IsHovered = 1 << 27,
}
ImGuiTableRowFlags = { None = 0, Headers = 1 }
ImGuiTableBgTarget = { None = 0, RowBg0 = 1, RowBg1 = 2, CellBg = 3 }
ImGuiMouseButton = { Left = 0, Right = 1, Middle = 2 }
ImGuiDir = { None = -1, Left = 0, Right = 1, Up = 2, Down = 3 }
ImGuiItemFlags = {
    None = 0, NoTabStop = 1, NoNav = 2, NoNavDefaultFocus = 4, ButtonRepeat = 8, AutoClosePopups = 16,
    AllowDuplicateId = 32,
}
ImGuiDragDropFlags = {
    None = 0, SourceNoPreviewTooltip = 1, SourceNoDisableHover = 2, SourceNoHoldToOpenOthers = 4,
    SourceAllowNullID = 8, SourceExtern = 16, PayloadAutoExpire = 32, SourceAutoExpirePayload = 32,
    PayloadNoCrossContext = 64, PayloadNoCrossProcess = 128, AcceptBeforeDelivery = 1024,
    AcceptNoDrawDefaultRect = 2048, AcceptNoPreviewTooltip = 4096, AcceptPeekOnly = 1024 | 2048,
}
ImGuiSortDirection = { None = 0, Ascending = 1, Descending = 2 }
ImGuiMouseCursor = { None = -1, Arrow = 0, TextInput = 1, ResizeAll = 2, ResizeNS = 3, ResizeEW = 4, ResizeNESW = 5, ResizeNWSE = 6, Hand = 7, NotAllowed = 8 }

local KEY_NAMES = {
    "Tab", "LeftArrow", "RightArrow", "UpArrow", "DownArrow", "PageUp", "PageDown", "Home", "End", "Insert",
    "Delete", "Backspace", "Space", "Enter", "Escape", "LeftCtrl", "LeftShift", "LeftAlt", "LeftSuper",
    "RightCtrl", "RightShift", "RightAlt", "RightSuper", "Menu",
    "0", "1", "2", "3", "4", "5", "6", "7", "8", "9",
    "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T",
    "U", "V", "W", "X", "Y", "Z",
    "F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12", "F13", "F14", "F15", "F16",
    "F17", "F18", "F19", "F20", "F21", "F22", "F23", "F24",
    "Apostrophe", "Comma", "Minus", "Period", "Slash", "Semicolon", "Equal", "LeftBracket", "Backslash",
    "RightBracket", "GraveAccent", "CapsLock", "ScrollLock", "NumLock", "PrintScreen", "Pause",
    "Keypad0", "Keypad1", "Keypad2", "Keypad3", "Keypad4", "Keypad5", "Keypad6", "Keypad7", "Keypad8",
    "Keypad9", "KeypadDecimal", "KeypadDivide", "KeypadMultiply", "KeypadSubtract", "KeypadAdd",
    "KeypadEnter", "KeypadEqual",
}
ImGuiKey = seq(KEY_NAMES, 512)
ImGuiKey.None = 0
ImGuiKey.MouseLeft, ImGuiKey.MouseRight, ImGuiKey.MouseMiddle = 655, 656, 657
ImGuiMod = { None = 0, Ctrl = 4096, Shift = 8192, Alt = 16384, Super = 32768 }

-- ImGuiKey value -> Windows virtual-key code.
local KEY_VK = {}
do
    local fixed = {
        Tab = 0x09, LeftArrow = 0x25, RightArrow = 0x27, UpArrow = 0x26, DownArrow = 0x28, PageUp = 0x21,
        PageDown = 0x22, Home = 0x24, End = 0x23, Insert = 0x2D, Delete = 0x2E, Backspace = 0x08,
        Space = 0x20, Enter = 0x0D, Escape = 0x1B, LeftCtrl = 0xA2, LeftShift = 0xA0, LeftAlt = 0xA4,
        LeftSuper = 0x5B, RightCtrl = 0xA3, RightShift = 0xA1, RightAlt = 0xA5, RightSuper = 0x5C,
        Menu = 0x5D, Apostrophe = 0xDE, Comma = 0xBC, Minus = 0xBD, Period = 0xBE, Slash = 0xBF,
        Semicolon = 0xBA, Equal = 0xBB, LeftBracket = 0xDB, Backslash = 0xDC, RightBracket = 0xDD,
        GraveAccent = 0xC0, CapsLock = 0x14, ScrollLock = 0x91, NumLock = 0x90, PrintScreen = 0x2C,
        Pause = 0x13, KeypadDecimal = 0x6E, KeypadDivide = 0x6F, KeypadMultiply = 0x6A,
        KeypadSubtract = 0x6D, KeypadAdd = 0x6B, KeypadEnter = 0x0D, KeypadEqual = 0xBB,
        MouseLeft = 0x01, MouseRight = 0x02, MouseMiddle = 0x04,
    }
    for name, vk in pairs(fixed) do KEY_VK[ImGuiKey[name]] = vk end
    for i = 0, 9 do
        KEY_VK[ImGuiKey[tostring(i)]] = 0x30 + i
        KEY_VK[ImGuiKey["Keypad" .. i]] = 0x60 + i
    end
    for i = 0, 25 do KEY_VK[ImGuiKey[string.char(65 + i)]] = 0x41 + i end
    for i = 1, 24 do KEY_VK[ImGuiKey["F" .. i]] = 0x6F + i end
end

-- ── state ────────────────────────────────────────────────────────────────────

local S = {
    frame = 0,
    windows = {},       -- name -> window (roots, children, popups, tooltips)
    order = {},         -- root windows, back to front
    stack = {},         -- current window stack (Begin / BeginChild / popups)
    cur = nil,
    storage = {},       -- id -> persistent widget state (tree open, tab selection, hsv ...)
    popups = {},        -- open popup stack { id, x, y, modal }
    popup_depth = 0,    -- how many popups are being submitted right now
    next_win = {},
    next_item_w = nil,
    next_open = nil,
    id_seeds = {},
    col_stack = {}, col_over = {}, col_user = {}, preset = nil,
    iflags = 16, iflag_stack = {},             -- ImGuiItemFlags; AutoClosePopups on by default
    hovered_id = nil, hovered_allow = false, hovered_prev = nil, next_allow_overlap = nil,
    activated_id = nil, activated_frame = -1, deactivated_id = nil, deactivated_frame = -1,
    nav_root = nil, nav_win = nil, nav_active = false, nav_id = nil, nav_items = {}, nav_prev_items = {},
    nav_return = {}, nav_depth = 0, nav_activate = nil, nav_adjust = 0, nav_scroll_to = nil,
    kbd_focus = nil, key_t0 = {}, key_n = {}, key_cache = {}, key_cache_frame = -1,
    cursor = 0, want_kbd_frame = -1, want_mouse_frame = -1, owns_text_editing = false,
    dd = nil, log = nil, atlas = nil,
    var_stack = {},
    disabled = 0,
    wrap_stack = {},
    font_stack = {},
    last = { id = 0, x1 = 0, y1 = 0, x2 = 0, y2 = 0, hovered = false, active = false, clicked = false, edited = false },
    active_id = nil, active_just = false, active_edited = false, prev_active = nil,
    drag_x = 0, drag_y = 0,
    text_id = nil, text_owner = nil, text_committed = nil,
    hover_root = nil, hover_rects = {},
    wheel_target = nil, wheel_next = nil,
    input_ok = false,
    cap_id = 0,
    bg_cmds = {}, fg_cmds = {},
    tooltip = nil,
    cbs = {},
    errors = {},
    last_click_t = -10, last_click_x = 0, last_click_y = 0, dbl = false,
}
im._state = S

-- ── helpers ──────────────────────────────────────────────────────────────────

local function now() return ctx.time() end
local function has(flags, bit) return flags and (flags & bit) ~= 0 end
local function clamp(v, a, b) if v < a then return a elseif v > b then return b end return v end

local function parse_label(label)
    label = tostring(label == nil and "" or label)
    local p = label:find("###", 1, true)
    if p then return label:sub(1, p - 1), label:sub(p) end
    local q = label:find("##", 1, true)
    if q then return label:sub(1, q - 1), label end
    return label, label
end

local function seed() return S.id_seeds[#S.id_seeds] or "" end
local function get_id(str) return ui.hash(seed() .. "\31" .. tostring(str)) end

-- The current font is { id = <font.* id>, scale = n } (PushFont); SetWindowFontScale multiplies it.
local function font_body() local f = S.font_stack[#S.font_stack]; return f and f.id or S.default_font or font.item end
local function font_scale()
    local f = S.font_stack[#S.font_stack]
    local s = ((f and f.scale) or 1) * ((S.io and S.io.FontGlobalScale) or 1)
    local w = S.cur
    if w then s = s * (w.font_scale or (w.root and w.root.font_scale) or 1) end
    return clamp(s, 0.5, 2)
end
local function font_h(f) return text.height(f or font_body()) * font_scale() end
local function text_w(s, f) if s == "" then return 0 end return text.width(f or font_body(), s) * font_scale() end

-- Key press with ImGui-style auto-repeat (0.275 s delay, 0.05 s rate), cached per frame per key.
local function key_rep(vk, rep)
    if S.key_cache_frame ~= S.frame then S.key_cache, S.key_cache_frame = {}, S.frame end
    local ck = vk * 2 + ((rep == false) and 1 or 0)
    local cached = S.key_cache[ck]
    if cached ~= nil then return cached end
    local r = false
    if input.key_just_pressed(vk) then
        S.key_t0[vk], S.key_n[vk] = now(), -1
        r = true
    elseif rep ~= false and input.key_down(vk) then
        local t0 = S.key_t0[vk]
        if not t0 then
            S.key_t0[vk], S.key_n[vk] = now(), -1
        else
            local e = now() - t0 - 0.275
            if e >= 0 then
                local n = floor(e / 0.05)
                if n > S.key_n[vk] then S.key_n[vk] = n; r = true end
            end
        end
    elseif not input.key_down(vk) then
        S.key_t0[vk] = nil
    end
    S.key_cache[ck] = r
    return r
end

local function st_get(id, default)
    local v = S.storage[id]
    if v == nil then return default end
    return v
end

-- u32 (IM_COL32 packing: A<<24 | B<<16 | G<<8 | R) <-> float4
local function u32_to_f4(c)
    c = floor(c or 0)
    return { (c & 255) / 255, ((c >> 8) & 255) / 255, ((c >> 16) & 255) / 255, ((c >> 24) & 255) / 255 }
end
local function f4_to_u32(r, g, b, a)
    local function b8(v) return clamp(floor((v or 0) * 255 + 0.5), 0, 255) end
    return (b8(a == nil and 1 or a) << 24) | (b8(b) << 16) | (b8(g) << 8) | b8(r)
end

-- Accepts: u32 | {r,g,b,a} | {x=,y=,z=,w=} | r,g,b,a  -> float4 table (new)
local function to_f4(a, b, c, d)
    if type(a) == "table" then
        return { a[1] or a.x or a.r or 0, a[2] or a.y or a.g or 0, a[3] or a.z or a.b or 0, a[4] or a.w or a.a or 1 }
    end
    if b ~= nil then return { a or 0, b or 0, c or 0, d == nil and 1 or d } end
    return u32_to_f4(a)
end

local function style_alpha()
    local a = S.style.Alpha
    if S.disabled > 0 then a = a * S.style.DisabledAlpha end
    return a
end

-- float4 -> 0..255 ints with global alpha applied
local function rgba(c, alpha_mul)
    local a = (c[4] or 1) * style_alpha() * (alpha_mul or 1)
    return floor(clamp(c[1], 0, 1) * 255 + 0.5), floor(clamp(c[2], 0, 1) * 255 + 0.5),
           floor(clamp(c[3], 0, 1) * 255 + 0.5), floor(clamp(a, 0, 1) * 255 + 0.5)
end

local function vec_args(args, i)
    local v = args[i]
    if type(v) == "table" then return v.x or v[1] or 0, v.y or v[2] or 0, i + 1 end
    return v or 0, args[i + 1] or 0, i + 2
end

-- ── style ────────────────────────────────────────────────────────────────────

local function v2(x, y) return { x = x, y = y } end

S.style = {
    Alpha = 1.0, DisabledAlpha = 0.5,
    WindowPadding = v2(10, 10), WindowRounding = 8, WindowBorderSize = 1, WindowMinSize = v2(48, 32),
    WindowTitleAlign = v2(0, 0.5), ChildRounding = 6, ChildBorderSize = 1, PopupRounding = 6,
    PopupBorderSize = 1, FramePadding = v2(6, 4), FrameRounding = 4, FrameBorderSize = 0,
    ItemSpacing = v2(8, 6), ItemInnerSpacing = v2(6, 4), IndentSpacing = 18, CellPadding = v2(6, 3),
    ScrollbarSize = 8, ScrollbarRounding = 4, GrabMinSize = 12, GrabRounding = 4, ImageBorderSize = 0,
    TabRounding = 5, TabBorderSize = 0, TabBarBorderSize = 1, TabBarOverlineSize = 2,
    TableAngledHeadersAngle = 0.61, TableAngledHeadersTextAlign = v2(0.5, 0), TreeLinesSize = 1,
    TreeLinesRounding = 0, ButtonTextAlign = v2(0.5, 0.5), SelectableTextAlign = v2(0, 0),
    SeparatorTextBorderSize = 2, SeparatorTextAlign = v2(0, 0.5), SeparatorTextPadding = v2(16, 3),
    Colors = {},
}
local VAR_NAME = {}
for name, idx in pairs(ImGuiStyleVar) do VAR_NAME[idx] = name end

-- Base palette, rebuilt from ui.skin (theme accent) every frame. Pushes override on top.
local BASE = {}
local function c255(t, a) return { t[1] / 255, t[2] / 255, t[3] / 255, a or ((t[4] or 255) / 255) } end
local function sync_palette()
    local sk = ui and ui.skin
    local c = sk and sk.col
    if not c then
        local r, g, b = 150, 70, 240
        if theme and theme.accent then r, g, b = theme.accent() end
        c = { txt = { 236, 232, 245 }, txt_off = { 120, 114, 140 }, bg = { 16, 12, 24, 245 },
              panel = { 24, 18, 38 }, card = { 30, 22, 48 }, card_hover = { 36, 27, 57 },
              card_bdr = { 92, 56, 168, 90 }, field = { 20, 15, 32 }, acc = { r, g, b },
              acc_dim = { r * 0.62, g * 0.62, b * 0.62 }, pill = { r * 0.45, g * 0.45, b * 0.45 },
              pill_hover = { r * 0.62, g * 0.62, b * 0.62 }, knob = { 245, 242, 250 }, div = { 110, 90, 150, 90 },
              scrollbar = { r, g, b, 170 }, track = { 54, 44, 74 } }
    end
    local K = ImGuiCol
    BASE[K.Text] = c255(c.txt)
    BASE[K.TextDisabled] = c255(c.txt_off)
    BASE[K.WindowBg] = c255(c.bg)
    BASE[K.ChildBg] = { 0, 0, 0, 0 }
    BASE[K.PopupBg] = c255(c.panel, 0.98)
    BASE[K.Border] = c255(c.card_bdr)
    BASE[K.BorderShadow] = { 0, 0, 0, 0 }
    BASE[K.FrameBg] = c255(c.field)
    BASE[K.FrameBgHovered] = c255(c.card_hover)
    BASE[K.FrameBgActive] = c255(c.pill)
    BASE[K.TitleBg] = c255(c.panel)
    BASE[K.TitleBgActive] = c255(c.card)
    BASE[K.TitleBgCollapsed] = c255(c.panel, 0.8)
    BASE[K.MenuBarBg] = c255(c.panel)
    BASE[K.ScrollbarBg] = { 0, 0, 0, 0.15 }
    BASE[K.ScrollbarGrab] = c255(c.scrollbar)
    BASE[K.ScrollbarGrabHovered] = c255(c.acc)
    BASE[K.ScrollbarGrabActive] = c255(c.acc)
    BASE[K.CheckMark] = c255(c.acc)
    BASE[K.SliderGrab] = c255(c.acc)
    BASE[K.SliderGrabActive] = c255(c.knob)
    BASE[K.Button] = c255(c.pill)
    BASE[K.ButtonHovered] = c255(c.pill_hover)
    BASE[K.ButtonActive] = c255(c.acc_dim)
    BASE[K.Header] = c255(c.pill)
    BASE[K.HeaderHovered] = c255(c.pill_hover)
    BASE[K.HeaderActive] = c255(c.acc_dim)
    BASE[K.Separator] = c255(c.div)
    BASE[K.SeparatorHovered] = c255(c.acc_dim)
    BASE[K.SeparatorActive] = c255(c.acc)
    BASE[K.ResizeGrip] = c255(c.acc_dim, 0.35)
    BASE[K.ResizeGripHovered] = c255(c.acc_dim, 0.7)
    BASE[K.ResizeGripActive] = c255(c.acc)
    BASE[K.InputTextCursor] = c255(c.txt)
    BASE[K.TabHovered] = c255(c.pill_hover)
    BASE[K.Tab] = c255(c.field)
    BASE[K.TabSelected] = c255(c.pill)
    BASE[K.TabSelectedOverline] = c255(c.acc)
    BASE[K.TabDimmed] = c255(c.field)
    BASE[K.TabDimmedSelected] = c255(c.pill)
    BASE[K.TabDimmedSelectedOverline] = c255(c.acc_dim)
    BASE[K.PlotLines] = c255(c.acc)
    BASE[K.PlotLinesHovered] = c255(c.knob)
    BASE[K.PlotHistogram] = c255(c.acc)
    BASE[K.PlotHistogramHovered] = c255(c.knob)
    BASE[K.TableHeaderBg] = c255(c.panel)
    BASE[K.TableBorderStrong] = c255(c.div, 0.8)
    BASE[K.TableBorderLight] = c255(c.div, 0.45)
    BASE[K.TableRowBg] = { 0, 0, 0, 0 }
    BASE[K.TableRowBgAlt] = { 1, 1, 1, 0.04 }
    BASE[K.TextLink] = c255(c.acc)
    BASE[K.TextSelectedBg] = c255(c.acc, 0.35)
    BASE[K.TreeLines] = c255(c.div)
    BASE[K.DragDropTarget] = c255(c.acc)
    BASE[K.NavCursor] = c255(c.acc)
    BASE[K.NavWindowingHighlight] = { 1, 1, 1, 0.7 }
    BASE[K.NavWindowingDimBg] = { 0.8, 0.8, 0.8, 0.2 }
    BASE[K.ModalWindowDimBg] = { 0, 0, 0, 0.45 }
    if S.preset then for i, c in pairs(S.preset) do BASE[i] = c end end
    if sk and sk.radius and not S.rounding_synced then
        S.style.WindowRounding = min(sk.radius, 10)
        S.rounding_synced = true
    end
end

local function col(idx) return S.col_over[idx] or S.col_user[idx] or BASE[idx] or { 1, 0, 1, 1 } end

-- GetStyle().Colors[ImGuiCol.X] reads the live colour; assigning one stores a persistent override.
S.style.Colors = setmetatable({}, {
    __index = function(_, i) return col(i) end,
    __newindex = function(_, i, v) S.col_user[i] = (v ~= nil) and to_f4(v) or nil end,
})

-- Dear ImGui's stock palettes (StyleColorsDark / Light / Classic), resolved to ImGuiCol index -> float4.
local PRESETS = {
    dark = {
        Text = { 1.00, 1.00, 1.00, 1.00 }, TextDisabled = { 0.50, 0.50, 0.50, 1.00 },
        WindowBg = { 0.06, 0.06, 0.06, 0.94 }, ChildBg = { 0.00, 0.00, 0.00, 0.00 },
        PopupBg = { 0.08, 0.08, 0.08, 0.94 }, Border = { 0.43, 0.43, 0.50, 0.50 },
        BorderShadow = { 0.00, 0.00, 0.00, 0.00 }, FrameBg = { 0.16, 0.29, 0.48, 0.54 },
        FrameBgHovered = { 0.26, 0.59, 0.98, 0.40 }, FrameBgActive = { 0.26, 0.59, 0.98, 0.67 },
        TitleBg = { 0.04, 0.04, 0.04, 1.00 }, TitleBgActive = { 0.16, 0.29, 0.48, 1.00 },
        TitleBgCollapsed = { 0.00, 0.00, 0.00, 0.51 }, MenuBarBg = { 0.14, 0.14, 0.14, 1.00 },
        ScrollbarBg = { 0.02, 0.02, 0.02, 0.53 }, ScrollbarGrab = { 0.31, 0.31, 0.31, 1.00 },
        ScrollbarGrabHovered = { 0.41, 0.41, 0.41, 1.00 }, ScrollbarGrabActive = { 0.51, 0.51, 0.51, 1.00 },
        CheckMark = { 0.26, 0.59, 0.98, 1.00 }, SliderGrab = { 0.24, 0.52, 0.88, 1.00 },
        SliderGrabActive = { 0.26, 0.59, 0.98, 1.00 }, Button = { 0.26, 0.59, 0.98, 0.40 },
        ButtonHovered = { 0.26, 0.59, 0.98, 1.00 }, ButtonActive = { 0.06, 0.53, 0.98, 1.00 },
        Header = { 0.26, 0.59, 0.98, 0.31 }, HeaderHovered = { 0.26, 0.59, 0.98, 0.80 },
        HeaderActive = { 0.26, 0.59, 0.98, 1.00 }, Separator = { ref = "Border" },
        SeparatorHovered = { 0.10, 0.40, 0.75, 0.78 }, SeparatorActive = { 0.10, 0.40, 0.75, 1.00 },
        ResizeGrip = { 0.26, 0.59, 0.98, 0.20 }, ResizeGripHovered = { 0.26, 0.59, 0.98, 0.67 },
        ResizeGripActive = { 0.26, 0.59, 0.98, 0.95 }, InputTextCursor = { ref = "Text" },
        TabHovered = { ref = "HeaderHovered" }, Tab = { lerp = "Header", b = "TitleBgActive", t = 0.80 },
        TabSelected = { lerp = "HeaderActive", b = "TitleBgActive", t = 0.60 },
        TabSelectedOverline = { ref = "HeaderActive" }, TabDimmed = { lerp = "Tab", b = "TitleBg", t = 0.80 },
        TabDimmedSelected = { lerp = "TabSelected", b = "TitleBg", t = 0.40 },
        TabDimmedSelectedOverline = { 0.50, 0.50, 0.50, 0.00 }, PlotLines = { 0.61, 0.61, 0.61, 1.00 },
        PlotLinesHovered = { 1.00, 0.43, 0.35, 1.00 }, PlotHistogram = { 0.90, 0.70, 0.00, 1.00 },
        PlotHistogramHovered = { 1.00, 0.60, 0.00, 1.00 }, TableHeaderBg = { 0.19, 0.19, 0.20, 1.00 },
        TableBorderStrong = { 0.31, 0.31, 0.35, 1.00 }, TableBorderLight = { 0.23, 0.23, 0.25, 1.00 },
        TableRowBg = { 0.00, 0.00, 0.00, 0.00 }, TableRowBgAlt = { 1.00, 1.00, 1.00, 0.06 },
        TextLink = { ref = "HeaderActive" }, TextSelectedBg = { 0.26, 0.59, 0.98, 0.35 },
        TreeLines = { ref = "Border" }, DragDropTarget = { 1.00, 1.00, 0.00, 0.90 },
        NavCursor = { 0.26, 0.59, 0.98, 1.00 }, NavWindowingHighlight = { 1.00, 1.00, 1.00, 0.70 },
        NavWindowingDimBg = { 0.80, 0.80, 0.80, 0.20 }, ModalWindowDimBg = { 0.80, 0.80, 0.80, 0.35 },
    },
    classic = {
        Text = { 0.90, 0.90, 0.90, 1.00 }, TextDisabled = { 0.60, 0.60, 0.60, 1.00 },
        WindowBg = { 0.00, 0.00, 0.00, 0.85 }, ChildBg = { 0.00, 0.00, 0.00, 0.00 },
        PopupBg = { 0.11, 0.11, 0.14, 0.92 }, Border = { 0.50, 0.50, 0.50, 0.50 },
        BorderShadow = { 0.00, 0.00, 0.00, 0.00 }, FrameBg = { 0.43, 0.43, 0.43, 0.39 },
        FrameBgHovered = { 0.47, 0.47, 0.69, 0.40 }, FrameBgActive = { 0.42, 0.41, 0.64, 0.69 },
        TitleBg = { 0.27, 0.27, 0.54, 0.83 }, TitleBgActive = { 0.32, 0.32, 0.63, 0.87 },
        TitleBgCollapsed = { 0.40, 0.40, 0.80, 0.20 }, MenuBarBg = { 0.40, 0.40, 0.55, 0.80 },
        ScrollbarBg = { 0.20, 0.25, 0.30, 0.60 }, ScrollbarGrab = { 0.40, 0.40, 0.80, 0.30 },
        ScrollbarGrabHovered = { 0.40, 0.40, 0.80, 0.40 }, ScrollbarGrabActive = { 0.41, 0.39, 0.80, 0.60 },
        CheckMark = { 0.90, 0.90, 0.90, 0.50 }, SliderGrab = { 1.00, 1.00, 1.00, 0.30 },
        SliderGrabActive = { 0.41, 0.39, 0.80, 0.60 }, Button = { 0.35, 0.40, 0.61, 0.62 },
        ButtonHovered = { 0.40, 0.48, 0.71, 0.79 }, ButtonActive = { 0.46, 0.54, 0.80, 1.00 },
        Header = { 0.40, 0.40, 0.90, 0.45 }, HeaderHovered = { 0.45, 0.45, 0.90, 0.80 },
        HeaderActive = { 0.53, 0.53, 0.87, 0.80 }, Separator = { 0.50, 0.50, 0.50, 0.60 },
        SeparatorHovered = { 0.60, 0.60, 0.70, 1.00 }, SeparatorActive = { 0.70, 0.70, 0.90, 1.00 },
        ResizeGrip = { 1.00, 1.00, 1.00, 0.10 }, ResizeGripHovered = { 0.78, 0.82, 1.00, 0.60 },
        ResizeGripActive = { 0.78, 0.82, 1.00, 0.90 }, InputTextCursor = { ref = "Text" },
        TabHovered = { ref = "HeaderHovered" }, Tab = { lerp = "Header", b = "TitleBgActive", t = 0.80 },
        TabSelected = { lerp = "HeaderActive", b = "TitleBgActive", t = 0.60 },
        TabSelectedOverline = { ref = "HeaderActive" }, TabDimmed = { lerp = "Tab", b = "TitleBg", t = 0.80 },
        TabDimmedSelected = { lerp = "TabSelected", b = "TitleBg", t = 0.40 },
        TabDimmedSelectedOverline = { 0.53, 0.53, 0.87, 0.00 }, PlotLines = { 1.00, 1.00, 1.00, 1.00 },
        PlotLinesHovered = { 0.90, 0.70, 0.00, 1.00 }, PlotHistogram = { 0.90, 0.70, 0.00, 1.00 },
        PlotHistogramHovered = { 1.00, 0.60, 0.00, 1.00 }, TableHeaderBg = { 0.27, 0.27, 0.38, 1.00 },
        TableBorderStrong = { 0.31, 0.31, 0.45, 1.00 }, TableBorderLight = { 0.26, 0.26, 0.28, 1.00 },
        TableRowBg = { 0.00, 0.00, 0.00, 0.00 }, TableRowBgAlt = { 1.00, 1.00, 1.00, 0.07 },
        TextLink = { ref = "HeaderActive" }, TextSelectedBg = { 0.00, 0.00, 1.00, 0.35 },
        TreeLines = { ref = "Border" }, DragDropTarget = { 1.00, 1.00, 0.00, 0.90 },
        NavCursor = { ref = "HeaderHovered" }, NavWindowingHighlight = { 1.00, 1.00, 1.00, 0.70 },
        NavWindowingDimBg = { 0.80, 0.80, 0.80, 0.20 }, ModalWindowDimBg = { 0.20, 0.20, 0.20, 0.35 },
    },
    light = {
        Text = { 0.00, 0.00, 0.00, 1.00 }, TextDisabled = { 0.60, 0.60, 0.60, 1.00 },
        WindowBg = { 0.94, 0.94, 0.94, 1.00 }, ChildBg = { 0.00, 0.00, 0.00, 0.00 },
        PopupBg = { 1.00, 1.00, 1.00, 0.98 }, Border = { 0.00, 0.00, 0.00, 0.30 },
        BorderShadow = { 0.00, 0.00, 0.00, 0.00 }, FrameBg = { 1.00, 1.00, 1.00, 1.00 },
        FrameBgHovered = { 0.26, 0.59, 0.98, 0.40 }, FrameBgActive = { 0.26, 0.59, 0.98, 0.67 },
        TitleBg = { 0.96, 0.96, 0.96, 1.00 }, TitleBgActive = { 0.82, 0.82, 0.82, 1.00 },
        TitleBgCollapsed = { 1.00, 1.00, 1.00, 0.51 }, MenuBarBg = { 0.86, 0.86, 0.86, 1.00 },
        ScrollbarBg = { 0.98, 0.98, 0.98, 0.53 }, ScrollbarGrab = { 0.69, 0.69, 0.69, 0.80 },
        ScrollbarGrabHovered = { 0.49, 0.49, 0.49, 0.80 }, ScrollbarGrabActive = { 0.49, 0.49, 0.49, 1.00 },
        CheckMark = { 0.26, 0.59, 0.98, 1.00 }, SliderGrab = { 0.26, 0.59, 0.98, 0.78 },
        SliderGrabActive = { 0.46, 0.54, 0.80, 0.60 }, Button = { 0.26, 0.59, 0.98, 0.40 },
        ButtonHovered = { 0.26, 0.59, 0.98, 1.00 }, ButtonActive = { 0.06, 0.53, 0.98, 1.00 },
        Header = { 0.26, 0.59, 0.98, 0.31 }, HeaderHovered = { 0.26, 0.59, 0.98, 0.80 },
        HeaderActive = { 0.26, 0.59, 0.98, 1.00 }, Separator = { 0.39, 0.39, 0.39, 0.62 },
        SeparatorHovered = { 0.14, 0.44, 0.80, 0.78 }, SeparatorActive = { 0.14, 0.44, 0.80, 1.00 },
        ResizeGrip = { 0.35, 0.35, 0.35, 0.17 }, ResizeGripHovered = { 0.26, 0.59, 0.98, 0.67 },
        ResizeGripActive = { 0.26, 0.59, 0.98, 0.95 }, InputTextCursor = { ref = "Text" },
        TabHovered = { ref = "HeaderHovered" }, Tab = { lerp = "Header", b = "TitleBgActive", t = 0.90 },
        TabSelected = { lerp = "HeaderActive", b = "TitleBgActive", t = 0.60 },
        TabSelectedOverline = { ref = "HeaderActive" }, TabDimmed = { lerp = "Tab", b = "TitleBg", t = 0.80 },
        TabDimmedSelected = { lerp = "TabSelected", b = "TitleBg", t = 0.40 },
        TabDimmedSelectedOverline = { 0.26, 0.59, 1.00, 0.00 }, PlotLines = { 0.39, 0.39, 0.39, 1.00 },
        PlotLinesHovered = { 1.00, 0.43, 0.35, 1.00 }, PlotHistogram = { 0.90, 0.70, 0.00, 1.00 },
        PlotHistogramHovered = { 1.00, 0.45, 0.00, 1.00 }, TableHeaderBg = { 0.78, 0.87, 0.98, 1.00 },
        TableBorderStrong = { 0.57, 0.57, 0.64, 1.00 }, TableBorderLight = { 0.68, 0.68, 0.74, 1.00 },
        TableRowBg = { 0.00, 0.00, 0.00, 0.00 }, TableRowBgAlt = { 0.30, 0.30, 0.30, 0.09 },
        TextLink = { ref = "HeaderActive" }, TextSelectedBg = { 0.26, 0.59, 0.98, 0.35 },
        TreeLines = { ref = "Border" }, DragDropTarget = { 0.26, 0.59, 0.98, 0.95 },
        NavCursor = { ref = "HeaderHovered" }, NavWindowingHighlight = { 0.70, 0.70, 0.70, 0.70 },
        NavWindowingDimBg = { 0.20, 0.20, 0.20, 0.20 }, ModalWindowDimBg = { 0.20, 0.20, 0.20, 0.35 },
    },
}

local function build_preset(name)
    local src = PRESETS[name]
    if not src then return nil end
    local byname = {}
    for _, n in ipairs(COL_NAMES) do
        local v = src[n]
        if v then
            if v.ref then
                byname[n] = byname[v.ref]
            elseif v.lerp then
                local a, b, t = byname[v.lerp], byname[v.b], v.t
                byname[n] = { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t, a[4] + (b[4] - a[4]) * t }
            else
                byname[n] = { v[1], v[2], v[3], v[4] }
            end
        end
    end
    local out = {}
    for n, c in pairs(byname) do out[ImGuiCol[n]] = c end
    return out
end

-- ── command recording ────────────────────────────────────────────────────────
-- Commands are flat tables so a window can be painted after its content is known (auto-size, z-order).

local OP_RECT, OP_OUTLINE, OP_LINE, OP_CIRCLE, OP_CIRCLE_OUT, OP_TEXT, OP_IMAGE, OP_CLIP, OP_UNCLIP, OP_GRAD =
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10

local function r_rect(L, x1, y1, x2, y2, c, rounding, amul)
    local r, g, b, a = rgba(c, amul)
    if a <= 0 then return end
    L[#L + 1] = { OP_RECT, x1, y1, x2, y2, r, g, b, a, rounding or 0 }
end
local function r_outline(L, x1, y1, x2, y2, c, rounding, thick, amul)
    local r, g, b, a = rgba(c, amul)
    if a <= 0 then return end
    L[#L + 1] = { OP_OUTLINE, x1, y1, x2, y2, r, g, b, a, rounding or 0, thick or 1 }
end
local function r_line(L, x1, y1, x2, y2, c, thick, amul)
    local r, g, b, a = rgba(c, amul)
    if a <= 0 then return end
    L[#L + 1] = { OP_LINE, x1, y1, x2, y2, r, g, b, a, thick or 1 }
end
local function r_circle(L, x, y, rad, c, filled, thick, amul)
    local r, g, b, a = rgba(c, amul)
    if a <= 0 then return end
    L[#L + 1] = { filled and OP_CIRCLE or OP_CIRCLE_OUT, x, y, rad, r, g, b, a, thick or 1 }
end
local function r_text(L, x, y, s, c, f, amul)
    if s == nil or s == "" then return end
    local r, g, b, a = rgba(c, amul)
    if a <= 0 then return end
    L[#L + 1] = { OP_TEXT, f or font_body(), x, y, r, g, b, a, s, font_scale() }
end
local function r_image(L, h, x1, y1, x2, y2, tint)
    local r, g, b, a = 255, 255, 255, floor(255 * style_alpha())
    if tint then r, g, b, a = rgba(tint) end
    L[#L + 1] = { OP_IMAGE, h, x1, y1, x2, y2, r, g, b, a }
end
local function r_grad(L, x1, y1, x2, y2, tl, tr, br, bl)
    L[#L + 1] = { OP_GRAD, x1, y1, x2, y2, tl, tr, br, bl }
end
local function r_clip(L, x1, y1, x2, y2) L[#L + 1] = { OP_CLIP, x1, y1, x2, y2 } end
local function r_unclip(L) L[#L + 1] = { OP_UNCLIP } end

local clip_depth = 0
local function flush(L)
    for i = 1, #L do
        local c = L[i]
        local op = c[1]
        if op == OP_RECT then
            draw.rect(c[2], c[3], c[4], c[5], c[6], c[7], c[8], c[9], c[10])
        elseif op == OP_TEXT then
            local sc = c[10] or 1
            if sc == 1 then
                text.draw(c[2], c[3], c[4], c[5], c[6], c[7], c[8], c[9])
            else
                -- draw_scaled scales about the text centre; shift so the top-left stays anchored
                local w0, h0 = text.width(c[2], c[9]), text.height(c[2])
                text.draw_scaled(c[2], c[3] - (1 - sc) * w0 * 0.5, c[4] - (1 - sc) * h0 * 0.5,
                    c[5], c[6], c[7], c[8], sc, c[9])
            end
        elseif op == OP_OUTLINE then
            draw.rect_outline(c[2], c[3], c[4], c[5], c[6], c[7], c[8], c[9], c[10], c[11])
        elseif op == OP_LINE then
            draw.line(c[2], c[3], c[4], c[5], c[6], c[7], c[8], c[9], c[10])
        elseif op == OP_CIRCLE then
            draw.circle(c[2], c[3], c[4], c[5], c[6], c[7], c[8])
        elseif op == OP_CIRCLE_OUT then
            draw.circle_outline(c[2], c[3], c[4], c[5], c[6], c[7], c[8], c[9])
        elseif op == OP_IMAGE then
            if c[7] == 255 and c[8] == 255 and c[9] == 255 then
                draw.image(c[2], c[3], c[4], c[5], c[6], c[10] / 255)
            else
                draw.image_colored(c[2], c[3], c[4], c[5], c[6], c[7], c[8], c[9], c[10])
            end
        elseif op == OP_GRAD then
            local tl, tr, br, bl = c[6], c[7], c[8], c[9]
            draw.rect_gradient(c[2], c[3], c[4], c[5], tl[1], tl[2], tl[3], tl[4], tr[1], tr[2], tr[3], tr[4],
                br[1], br[2], br[3], br[4], bl[1], bl[2], bl[3], bl[4])
        elseif op == OP_CLIP then
            ui.push_clip(c[2], c[3], c[4], c[5]); clip_depth = clip_depth + 1
        elseif op == OP_UNCLIP then
            if clip_depth > 0 then ui.pop_clip(); clip_depth = clip_depth - 1 end
        end
    end
    while clip_depth > 0 do ui.pop_clip(); clip_depth = clip_depth - 1 end
end

-- ── window / layout core ─────────────────────────────────────────────────────

local function frame_h() return font_h() + S.style.FramePadding.y * 2 end
local function title_h() return font_h() + S.style.FramePadding.y * 2 + 2 end

local function bring_to_front(win)
    if not win or win.is_popup or win.is_child or has(win.flags, ImGuiWindowFlags.NoBringToFrontOnFocus) then return end
    for i = #S.order, 1, -1 do
        if S.order[i] == win then table.remove(S.order, i) break end
    end
    S.order[#S.order + 1] = win
end

-- A window hidden for its first layout pass (size unknown yet) is neither drawn nor hoverable.
local function shown_on(w, f) return not w.skip and (not w.hide_until or f >= w.hide_until) end

local function avail_w()
    local w = S.cur
    local dc = w.dc
    local x = dc.same and dc.same_x or dc.cx
    return max(0, dc.right - x)
end

local function calc_item_w()
    local w
    local dc = S.cur.dc
    if S.next_item_w then
        w = S.next_item_w
        S.next_item_w = nil
    elseif dc.item_w[#dc.item_w] then
        w = dc.item_w[#dc.item_w]
    elseif dc.col_w then
        w = dc.col_w
    elseif dc.fixed_item_w then
        w = dc.fixed_item_w
    else
        w = floor((dc.right - dc.start_x) * 0.65)
    end
    if w < 0 then w = max(1, avail_w() + w) end
    return max(1, w)
end

local function item_pos()
    local dc = S.cur.dc
    if dc.same then return dc.same_x, dc.same_y end
    return dc.cx, dc.cy
end

-- Advance the layout cursor past an item of size w x h placed at (x, y).
local function item_add(x, y, w, h)
    local dc = S.cur.dc
    if dc.same then
        dc.line_h = max(dc.line_h, (y - dc.line_top) + h)
    else
        dc.line_top = y
        dc.line_h = h
        dc.line_frame = false
    end
    dc.same = false
    dc.last_x2 = x + w
    dc.cx = dc.start_x + dc.indent
    dc.cy = dc.line_top + dc.line_h + S.style.ItemSpacing.y
    if x + w > dc.max_x then dc.max_x = x + w end
    if y + h > dc.max_y then dc.max_y = y + h end
    for gi = 1, #dc.groups do
        local g = dc.groups[gi]
        if x + w > g.max_x then g.max_x = x + w end
        if y + h > g.max_y then g.max_y = y + h end
    end
    local L = S.last
    L.x1, L.y1, L.x2, L.y2 = x, y, x + w, y + h
    L.id, L.hovered, L.active, L.clicked, L.edited, L.toggled, L.deactivated = 0, false, false, false, false, false, false
    L.win = S.cur
    S.next_allow_overlap = nil
end

local function in_clip(x, y)
    local c = S.cur.clip
    return x >= c[1] and x < c[3] and y >= c[2] and y < c[4]
end

local function mouse_in(x1, y1, x2, y2)
    return S.mx >= x1 and S.mx < x2 and S.my >= y1 and S.my < y2
end

-- Raw hover test for the current window: right window on top, inside the clip, not blocked.
local function hover_rect(x1, y1, x2, y2)
    if not S.input_ok or not S.cur then return false end
    if S.hover_root ~= S.cur.root then return false end
    if has(S.cur.root.flags, ImGuiWindowFlags.NoMouseInputs) then return false end
    if not in_clip(S.mx, S.my) then return false end
    return mouse_in(x1, y1, x2, y2)
end

-- First item to claim the mouse keeps it, unless it allows overlap; an overlap-allowing item yields to
-- whatever overlapped it and won the mouse last frame (SetNextItemAllowOverlap / AllowOverlap flags).
local function item_hoverable(id, x1, y1, x2, y2, allow)
    allow = allow or S.next_allow_overlap
    if S.disabled > 0 then return false end
    if S.active_id and S.active_id ~= id then return false end
    if not hover_rect(x1, y1, x2, y2) then return false end
    if S.hovered_id and S.hovered_id ~= id and not S.hovered_allow then return false end
    if allow and S.hovered_prev and S.hovered_prev ~= id and S.active_id ~= id then return false end
    S.hovered_id, S.hovered_allow = id, allow and true or false
    return true
end

local function set_active(id)
    S.active_id = id
    S.active_just = true
    S.active_edited = false
    S.active_t0, S.repeat_n = now(), -1
    S.activated_id, S.activated_frame = id, S.frame
    S.drag_x, S.drag_y = S.mx, S.my
    if S.cur then
        bring_to_front(S.cur.root)
        if not S.cur.root.is_popup then S.nav_root = S.cur.root end
    end
    S.nav_id = id
    ui.consume_click(0)
    ui.capture(S.cap_id, 0)
end

-- next_frame: the release was noticed outside the widget (end of frame), so report it on the next frame
local function clear_active(next_frame)
    if S.active_id then
        S.deactivated_id, S.deactivated_edited = S.active_id, S.active_edited
        S.deactivated_frame = next_frame and (S.frame + 1) or S.frame
    end
    S.active_id = nil
    ui.release(S.cap_id)
end

-- Keyboard/controller navigation: interactive items of the navigation window register every frame.
-- Returns true when this item holds nav focus while navigation is active.
local function nav_item(id, x1, y1, x2, y2, kind)
    local w = S.cur
    if not w or S.disabled > 0 then return false end
    local kf = S.kbd_focus
    if kf and kf.win == w.root then
        if kf.n <= 0 then
            S.kbd_focus = nil
            S.focus_take = id
            S.nav_id, S.nav_scroll_to = id, id
            if not w.root.is_popup then S.nav_root = w.root end
        else
            kf.n = kf.n - 1
        end
    end
    if w.root ~= S.nav_win or has(S.iflags, ImGuiItemFlags.NoNav) then return false end
    local L = S.nav_items
    L[#L + 1] = { id = id, x1 = x1, y1 = y1, x2 = x2, y2 = y2, kind = kind, notab = has(S.iflags, ImGuiItemFlags.NoTabStop) }
    if id ~= S.nav_id then return false end
    if S.nav_scroll_to == id then
        S.nav_scroll_to = nil
        local c = w.clip
        if y2 > c[4] then w.scroll = w.scroll + (y2 - c[4]) + S.style.ItemSpacing.y
        elseif y1 < c[2] then w.scroll = max(0, w.scroll - (c[2] - y1) - S.style.ItemSpacing.y) end
    end
    if S.nav_active then
        r_outline(w.root.cmds, x1 - 2, y1 - 2, x2 + 2, y2 + 2, col(ImGuiCol.NavCursor), S.style.FrameRounding + 2, 2)
    end
    return S.nav_active
end

-- -> pressed, hovered, held. ImGui semantics: a press registers on RELEASE over the item (on PRESS for
-- on_press items and ButtonRepeat, which then repeats while held).
local function button_behavior(id, x1, y1, x2, y2, on_press, allow)
    local hov = item_hoverable(id, x1, y1, x2, y2, allow)
    local pressed, held = false, false
    local rep = has(S.iflags, ImGuiItemFlags.ButtonRepeat)
    if hov and S.clicked[0] and S.active_id == nil then
        set_active(id)
        if on_press or rep then pressed = true end
    end
    if S.active_id == id then
        held = S.down[0]
        if held and rep and hov then
            local e = now() - S.active_t0 - 0.275
            if e >= 0 then
                local n = floor(e / 0.05)
                if n > S.repeat_n then S.repeat_n = n; pressed = true end
            end
        end
        if not held then
            if not on_press and not rep and hov then pressed = true end
            clear_active()
        end
    end
    if nav_item(id, x1, y1, x2, y2, "button") and S.nav_activate == id then
        pressed = true
        S.nav_activate = nil
    end
    local L = S.last
    L.id, L.hovered, L.active, L.clicked = id, hov, S.active_id == id, pressed
    return pressed, hov, held
end

-- title-bar buttons are not keyboard-navigation stops
local function chrome_button(id, x1, y1, x2, y2)
    local sv = S.iflags
    S.iflags = sv | ImGuiItemFlags.NoNav
    local p, h, d = button_behavior(id, x1, y1, x2, y2)
    S.iflags = sv
    return p, h, d
end

local function new_dc(win, x, y)
    local pad = win.pad
    local dc = win.dc or {}
    win.dc = dc
    dc.start_x = x + pad.x - (win.scroll_x or 0)
    dc.origin_x = dc.start_x
    dc.cx = dc.start_x
    dc.cy = y + pad.y - (win.scroll or 0)
    dc.content_y0 = dc.cy + (win.scroll or 0)   -- unscrolled content origin
    dc.start_y = dc.cy                          -- scrolled origin: content height = max_y - start_y
    dc.line_top, dc.line_h = dc.cy, 0
    dc.same, dc.same_x, dc.same_y = false, 0, 0
    dc.last_x2 = dc.cx
    dc.indent = 0
    dc.max_x, dc.max_y = dc.cx, dc.cy
    dc.item_w = {}
    dc.groups = {}
    dc.col_w, dc.col_x2 = nil, nil
    dc.fixed_item_w = nil
    dc.line_frame = false
    dc.align_text = false
    return dc
end

local function get_window(name, kind)
    local w = S.windows[name]
    if not w then
        w = { name = name, x = 0, y = 0, w = 0, h = 0, scroll = 0, scroll_max = 0, scroll_x = 0, scroll_x_max = 0, collapsed = false,
              first = S.frame, last_frame = -1, content_w = 0, content_h = 0, fresh = true, cmds = {} }
        S.windows[name] = w
        if kind == "root" then S.order[#S.order + 1] = w end
    end
    return w
end

local function push_window(w)
    S.stack[#S.stack + 1] = w
    S.cur = w
end
local function pop_window()
    S.stack[#S.stack] = nil
    S.cur = S.stack[#S.stack]
end

local function apply_next_window(w)
    local nw = S.next_win
    local appearing = w.last_frame < S.frame - 1
    local function ok(cond)
        cond = cond or ImGuiCond.Always
        if cond == 0 or has(cond, ImGuiCond.Always) then return true end
        if has(cond, ImGuiCond.Once) or has(cond, ImGuiCond.FirstUseEver) then return w.first == S.frame end
        if has(cond, ImGuiCond.Appearing) then return appearing end
        return false
    end
    if nw.pos and ok(nw.pos_cond) then
        w.pos_req = { nw.pos[1], nw.pos[2], nw.pivot_x or 0, nw.pivot_y or 0 }
    end
    if nw.size and ok(nw.size_cond) then
        w.size_set = true
        if nw.size[1] > 0 then w.w = nw.size[1] else w.auto_w = true end
        if nw.size[2] > 0 then w.h = nw.size[2] else w.auto_h = true end
    end
    if nw.collapsed ~= nil and ok(nw.collapsed_cond) then w.collapsed = nw.collapsed end
    if nw.focus then bring_to_front(w) end
    w.bg_alpha = nw.bg_alpha
    w.scroll_req = nw.scroll_y
    w.scroll_x_req = nw.scroll_x
    w.content_req = nw.content
    w.cons = nw.cons
    S.next_win = {}
end

local function seed_push(s) S.id_seeds[#S.id_seeds + 1] = s end
local function seed_pop() if #S.id_seeds > 0 then S.id_seeds[#S.id_seeds] = nil end end

-- Shared body of Begin / popups / tooltips. kind = "root" | "popup" | "tooltip"
local function begin_window(name, flags, kind, p_open, key)
    flags = flags or 0
    local title, idpart = parse_label(name)
    local w = get_window(kind .. ":" .. (key or idpart), kind)
    local appearing = w.last_frame < S.frame - 1
    w.title = title
    w.flags = flags
    w.kind = kind
    w.is_popup = kind ~= "root"
    w.is_child = false
    w.root = w
    w.cmds = {}
    w.last_frame = S.frame
    w.has_close = p_open ~= nil and kind == "root" or (p_open ~= nil and w.modal)
    w.skip = p_open == false
    w.pad = S.style.WindowPadding
    w.menubar = has(flags, ImGuiWindowFlags.MenuBar)
    if appearing and kind == "root" and not has(flags, ImGuiWindowFlags.NoFocusOnAppearing) then bring_to_front(w) end
    apply_next_window(w)
    w.has_title = not has(flags, ImGuiWindowFlags.NoTitleBar) and (kind == "root" or (kind == "popup" and w.modal == true))
    local th = w.has_title and title_h() or 0
    w.menubar_h = w.menubar and frame_h() or 0

    -- Auto-fit: popups/tooltips/AlwaysAutoResize every frame, plain windows only on their first frames.
    -- A window whose content was never laid out is sized to a placeholder and hidden for that frame.
    if w.autofit == nil then w.autofit = w.size_set and 0 or 2 end
    local always_fit = has(flags, ImGuiWindowFlags.AlwaysAutoResize) or w.is_popup
    if always_fit or w.autofit > 0 then
        if not w.laid then
            if not w.size_set then w.w, w.h = floor(font_h() * 16 / 0.65) + w.pad.x * 2, 240 end
            w.hide_until = S.frame + 1
        elseif always_fit or not w.size_set then
            local tw = w.has_title and (text_w(w.title) + th * 2 + S.style.FramePadding.x * 2) or 0
            w.w = max(w.content_w + w.pad.x * 2, tw)
            w.h = w.content_h + w.pad.y * 2 + th + w.menubar_h
        end
    end
    if w.auto_w then w.w = max(w.w, w.content_w + w.pad.x * 2) end
    if w.auto_h then w.h = w.content_h + w.pad.y * 2 + th + w.menubar_h end
    if w.min_w then w.w = max(w.w, w.min_w); w.min_w = nil end
    if kind == "popup" and w.max_h then w.h = min(w.h, w.max_h) end
    local mn = S.style.WindowMinSize
    w.w = max(w.w, mn.x)
    w.h = max(w.h, mn.y)
    if w.cons then
        local c = w.cons
        if c[1] >= 0 then w.w = max(w.w, c[1]) end
        if c[3] >= 0 then w.w = min(w.w, c[3]) end
        if c[2] >= 0 then w.h = max(w.h, c[2]) end
        if c[4] >= 0 then w.h = min(w.h, c[4]) end
    end

    local sw, sh = ctx.screen_w(), ctx.screen_h()
    if w.pos_req then
        w.x = w.pos_req[1] - w.w * w.pos_req[3]
        w.y = w.pos_req[2] - w.h * w.pos_req[4]
        w.pos_req = nil
    elseif w.fresh and kind == "root" then
        local n = #S.order
        w.x, w.y = 60 + (n % 8) * 24, 60 + (n % 8) * 24
    end
    if kind ~= "root" then
        w.x = clamp(w.x, 0, max(0, sw - w.w))
        w.y = clamp(w.y, 0, max(0, sh - w.h))
    end
    w.draw_h = (w.collapsed and w.has_title) and th or w.h

    -- vertical scrollbar (from last frame's content height)
    local sb = 0
    if (w.scroll_max > 0 and not has(flags, ImGuiWindowFlags.NoScrollbar)) or has(flags, ImGuiWindowFlags.AlwaysVerticalScrollbar) then
        sb = S.style.ScrollbarSize + 2
    end
    w.sb_w = sb
    if w.scroll_req then w.scroll = w.scroll_req; w.scroll_req = nil end
    w.scroll = clamp(w.scroll, 0, w.scroll_max)
    w.hscroll = has(flags, ImGuiWindowFlags.HorizontalScrollbar) or has(flags, ImGuiWindowFlags.AlwaysHorizontalScrollbar)
    local sbh = 0
    if w.hscroll and not has(flags, ImGuiWindowFlags.NoScrollbar)
       and (w.scroll_x_max > 0 or has(flags, ImGuiWindowFlags.AlwaysHorizontalScrollbar)) then
        sbh = S.style.ScrollbarSize + 2
    end
    w.sb_h = sbh
    if w.scroll_x_req then w.scroll_x = w.scroll_x_req; w.scroll_x_req = nil end
    w.scroll_x = clamp(w.scroll_x, 0, w.scroll_x_max)

    local cy = w.y + th + w.menubar_h
    local content_clip = { w.x + 1, cy, w.x + w.w - 1 - sb, (w.collapsed and w.has_title) and cy or (w.y + w.h - 1 - sbh) }
    local dc = new_dc(w, w.x, cy)
    dc.right = w.x + w.w - w.pad.x - sb - w.scroll_x
    if w.content_req then dc.right = dc.start_x + w.content_req[1] end
    if always_fit then dc.fixed_item_w = floor(font_h() * 16) end

    -- chrome is hit-tested against the whole window, content against the content clip
    w.clip = { w.x, w.y, w.x + w.w, w.y + w.draw_h }
    push_window(w)
    seed_push(w.name)
    w.close_req = false

    if w.has_title then
        local tx1, ty1, tx2, ty2 = w.x, w.y, w.x + w.w, w.y + th
        if w.has_close then
            local cid = get_id("#CLOSE")
            local pressed, hov = chrome_button(cid, tx2 - th + 2, ty1 + 2, tx2 - 2, ty2 - 2)
            if pressed then w.close_req = true end
            w.close_hov = hov
        end
        if not has(flags, ImGuiWindowFlags.NoCollapse) and kind == "root" then
            local cid = get_id("#COLLAPSE")
            local pressed, hov = chrome_button(cid, w.x + 2, ty1 + 2, w.x + th - 2, ty2 - 2)
            if pressed then w.collapsed = not w.collapsed end
            w.collapse_hov = hov
        end
        if not has(flags, ImGuiWindowFlags.NoMove) then
            local mid = get_id("#MOVE")
            if S.active_id == nil and S.clicked[0] and hover_rect(tx1, ty1, tx2, ty2) then
                set_active(mid)
                w.move_ox, w.move_oy = S.mx - w.x, S.my - w.y
            end
            if S.active_id == mid then
                if S.down[0] then
                    w.x = clamp(S.mx - w.move_ox, -w.w + 40, sw - 40)
                    w.y = clamp(S.my - w.move_oy, 0, sh - 20)
                    w.user_moved = true
                else
                    clear_active()
                end
            end
        end
    end
    if not w.collapsed and kind == "root" and not has(flags, ImGuiWindowFlags.NoResize)
       and not has(flags, ImGuiWindowFlags.AlwaysAutoResize) then
        local rid = get_id("#RESIZE")
        local g = 14
        local gx1, gy1 = w.x + w.w - g, w.y + w.h - g
        local hov = (S.active_id == nil or S.active_id == rid) and hover_rect(gx1, gy1, w.x + w.w, w.y + w.h)
        if hov or S.active_id == rid then S.cursor = ImGuiMouseCursor.ResizeNWSE end
        if hov and S.clicked[0] and S.active_id == nil then
            set_active(rid)
            w.rs_ox, w.rs_oy = w.x + w.w - S.mx, w.y + w.h - S.my
        end
        if S.active_id == rid then
            if S.down[0] then
                w.w = max(mn.x, S.mx + w.rs_ox - w.x)
                w.h = max(mn.y, S.my + w.rs_oy - w.y)
                w.size_set, w.autofit = true, 0
                w.auto_w, w.auto_h = nil, nil
            else
                clear_active()
            end
        end
        w.grip_state = (S.active_id == rid) and 2 or (hov and 1 or 0)
    else
        w.grip_state = nil
    end

    w.clip = content_clip
    r_clip(w.cmds, content_clip[1], content_clip[2], content_clip[3], content_clip[4])
    local visible = not w.collapsed and not w.close_req and p_open ~= false
    return w, visible
end

local function draw_scrollbar(L, w, x1, y1, x2, y2, horiz)
    local smax = horiz and w.scroll_x_max or w.scroll_max
    if smax <= 0 then return end
    local sid = get_id(horiz and "#SCROLLX" or "#SCROLLY")
    local p1 = horiz and x1 or y1
    local len = (horiz and x2 or y2) - p1
    local cur = horiz and w.scroll_x or w.scroll
    local gl = min(len, max(S.style.GrabMinSize * 2, len * len / (len + smax)))
    local gp = p1 + (len - gl) * (cur / smax)
    local m = horiz and S.mx or S.my
    local hov = S.input_ok and S.hover_root == w.root and mouse_in(x1, y1, x2, y2) and (S.active_id == nil or S.active_id == sid)
    if hov and S.clicked[0] and S.active_id == nil then
        set_active(sid)
        w.sb_off = (m >= gp and m < gp + gl) and (m - gp) or gl * 0.5
    end
    if S.active_id == sid then
        if S.down[0] then
            local t = clamp((m - w.sb_off - p1) / max(1, len - gl), 0, 1)
            if horiz then w.scroll_x = t * smax else w.scroll = t * smax end
            gp = p1 + (len - gl) * t
        else
            clear_active()
        end
    end
    r_rect(L, x1, y1, x2, y2, col(ImGuiCol.ScrollbarBg), S.style.ScrollbarRounding)
    local gc = S.active_id == sid and ImGuiCol.ScrollbarGrabActive or (hov and ImGuiCol.ScrollbarGrabHovered or ImGuiCol.ScrollbarGrab)
    if horiz then
        r_rect(L, gp, y1 + 1, gp + gl, y2 - 1, col(gc), S.style.ScrollbarRounding)
    else
        r_rect(L, x1 + 1, gp, x2 - 1, gp + gl, col(gc), S.style.ScrollbarRounding)
    end
end

local function end_window()
    local w = S.cur
    if not w then return end
    local dc = w.dc
    local L = w.cmds
    r_unclip(L)
    w.content_w = max(0, dc.max_x - dc.origin_x)
    w.content_h = max(0, dc.max_y - dc.start_y)
    local view_h = w.h - (w.has_title and title_h() or 0) - w.menubar_h - w.pad.y * 2 - w.sb_h
    w.scroll_max = w.collapsed and 0 or max(0, w.content_h - view_h)
    if w.scroll > w.scroll_max then w.scroll = w.scroll_max end
    local view_w = w.w - w.pad.x * 2 - w.sb_w
    w.scroll_x_max = (w.hscroll and not w.collapsed) and max(0, w.content_w - view_w) or 0
    if w.scroll_x > w.scroll_x_max then w.scroll_x = w.scroll_x_max end

    -- wheel target: deepest hovered scrollable region wins (children run after their parent)
    if S.input_ok and S.hover_root == w and not has(w.flags, ImGuiWindowFlags.NoScrollWithMouse)
       and mouse_in(w.clip[1], w.clip[2], w.clip[3] + w.sb_w, w.clip[4] + w.sb_h) then
        if S.wheel_claim ~= S.frame and not (S.wheel_next and S.wheel_next.root == w) then S.wheel_next = w end
    end

    -- chrome, prepended so it paints beneath the content
    local P = {}
    local th = w.has_title and title_h() or 0
    local x1, y1, x2, y2 = w.x, w.y, w.x + w.w, w.y + w.draw_h
    local rnd = w.is_popup and S.style.PopupRounding or S.style.WindowRounding
    if w.modal then r_rect(P, 0, 0, ctx.screen_w(), ctx.screen_h(), col(ImGuiCol.ModalWindowDimBg)) end
    if not has(w.flags, ImGuiWindowFlags.NoBackground) then
        local bgc = col(w.is_popup and ImGuiCol.PopupBg or ImGuiCol.WindowBg)
        if w.bg_alpha then bgc = { bgc[1], bgc[2], bgc[3], w.bg_alpha } end
        r_rect(P, x1, y1, x2, y2, bgc, rnd)
    end
    if w.has_title then
        local focused = S.order[#S.order] == w
        local tc = w.collapsed and ImGuiCol.TitleBgCollapsed or (focused and ImGuiCol.TitleBgActive or ImGuiCol.TitleBg)
        r_rect(P, x1, y1, x2, y1 + th, col(tc), rnd)
        if not w.collapsed then r_rect(P, x1, y1 + th - rnd, x2, y1 + th, col(tc)) end
        local tx = x1 + S.style.FramePadding.x
        if not has(w.flags, ImGuiWindowFlags.NoCollapse) and w.kind == "root" then
            local cx, cy = x1 + th * 0.5, y1 + th * 0.5
            if w.collapse_hov then r_circle(P, cx, cy, th * 0.36, col(ImGuiCol.ButtonHovered), true) end
            local s = th * 0.18
            if w.collapsed then
                r_line(P, cx - s * 0.5, cy - s, cx + s * 0.6, cy, col(ImGuiCol.Text), 1.5)
                r_line(P, cx + s * 0.6, cy, cx - s * 0.5, cy + s, col(ImGuiCol.Text), 1.5)
            else
                r_line(P, cx - s, cy - s * 0.5, cx, cy + s * 0.6, col(ImGuiCol.Text), 1.5)
                r_line(P, cx, cy + s * 0.6, cx + s, cy - s * 0.5, col(ImGuiCol.Text), 1.5)
            end
            tx = x1 + th
        end
        local right = x2
        if w.has_close then
            local cx, cy = x2 - th * 0.5, y1 + th * 0.5
            if w.close_hov then r_circle(P, cx, cy, th * 0.36, col(ImGuiCol.ButtonHovered), true) end
            local s = th * 0.16
            r_line(P, cx - s, cy - s, cx + s, cy + s, col(ImGuiCol.Text), 1.5)
            r_line(P, cx + s, cy - s, cx - s, cy + s, col(ImGuiCol.Text), 1.5)
            right = x2 - th
        end
        local ttw = text_w(w.title)
        local avail = right - tx - S.style.FramePadding.x
        local ax = S.style.WindowTitleAlign.x
        local tx2 = tx + max(0, (avail - ttw) * ax)
        P[#P + 1] = { OP_CLIP, tx, y1, right, y1 + th }
        r_text(P, tx2, y1 + (th - font_h()) * 0.5, w.title, col(ImGuiCol.Text))
        P[#P + 1] = { OP_UNCLIP }
    end
    if w.menubar and not w.collapsed then
        r_rect(P, x1, y1 + th, x2, y1 + th + w.menubar_h, col(ImGuiCol.MenuBarBg))
    end

    -- post: scrollbar, resize grip, border
    local Q = {}
    if not w.collapsed then
        if w.sb_w > 0 then
            draw_scrollbar(Q, w, x2 - S.style.ScrollbarSize - 2, w.clip[2] + 2, x2 - 2, w.y + w.h - 2 - max(w.sb_h, w.grip_state and 10 or 0))
        end
        if w.sb_h > 0 then
            draw_scrollbar(Q, w, x1 + 2, y2 - S.style.ScrollbarSize - 2, x2 - 2 - max(w.sb_w, w.grip_state and 10 or 0), y2 - 2, true)
        end
        if w.grip_state then
            local gc = w.grip_state == 2 and ImGuiCol.ResizeGripActive or (w.grip_state == 1 and ImGuiCol.ResizeGripHovered or ImGuiCol.ResizeGrip)
            local c = col(gc)
            for i = 1, 3 do
                local o = i * 4
                r_line(Q, x2 - o - 2, y2 - 3, x2 - 3, y2 - o - 2, c, 1.5)
            end
        end
    end
    if S.style.WindowBorderSize > 0 and not has(w.flags, ImGuiWindowFlags.NoBackground) then
        r_outline(Q, x1, y1, x2, y2, col(ImGuiCol.Border), rnd, S.style.WindowBorderSize)
    end
    w.pre, w.post = P, Q
    w.rect = { x1, y1, x2, y2 }
    w.fresh = false
    w.laid = true
    if w.autofit > 0 then w.autofit = w.autofit - 1 end
    seed_pop()
    pop_window()
end

-- ── frame ────────────────────────────────────────────────────────────────────

local function popup_level_of(win)
    for i = 1, #S.popups do
        if S.popups[i].win == win then return i end
    end
    return nil
end

local function any_modal()
    for i = #S.popups, 1, -1 do if S.popups[i].modal then return i end end
    return nil
end

local function nav_find(id)
    for _, it in ipairs(S.nav_prev_items) do if it.id == id then return it end end
    return nil
end

-- Move nav focus using last frame's item list: next/prev follow submission order (Tab skips NoTabStop),
-- up/down/left/right pick the nearest item in that direction.
local function nav_move(dir)
    local list = S.nav_prev_items
    local n = #list
    if n == 0 then return end
    local cur, ci
    for i = 1, n do if list[i].id == S.nav_id then cur, ci = list[i], i break end end
    local pick
    if not cur then
        pick = (dir == "prev" or dir == "up") and list[n] or list[1]
    elseif dir == "next" or dir == "prev" then
        local step = (dir == "next") and 1 or -1
        local i = ci
        for _ = 1, n do
            i = (i - 1 + step) % n + 1
            if not list[i].notab then pick = list[i] break end
        end
    else
        local cx, cy = (cur.x1 + cur.x2) * 0.5, (cur.y1 + cur.y2) * 0.5
        local bd = math.huge
        for i = 1, n do
            local it = list[i]
            if it ~= cur then
                local ix, iy = (it.x1 + it.x2) * 0.5, (it.y1 + it.y2) * 0.5
                local same_row = it.y1 < cur.y2 and it.y2 > cur.y1
                local d
                if dir == "down" and it.y1 >= cur.y2 - 1 then d = (iy - cy) * 4 + abs(ix - cx)
                elseif dir == "up" and it.y2 <= cur.y1 + 1 then d = (cy - iy) * 4 + abs(ix - cx)
                elseif dir == "right" and same_row and it.x1 >= cur.x2 - 1 then d = ix - cx
                elseif dir == "left" and same_row and it.x2 <= cur.x1 + 1 then d = cx - ix end
                if d and d < bd then pick, bd = it, d end
            end
        end
        if not pick and dir == "down" then pick = list[1] end
        if not pick and dir == "up" then pick = list[n] end
    end
    if pick then S.nav_id, S.nav_scroll_to = pick.id, pick.id end
end

local function ui_act(name, fn)
    local f = input[fn]
    local a = UI and UI[name]
    if not f or not a then return false end
    return f(a) and true or false
end

local function nav_frame(input_ok)
    S.nav_prev_items, S.nav_items = S.nav_items, {}
    S.nav_activate, S.nav_adjust = nil, 0
    if not input_ok then S.nav_active = false end
    if S.nav_root and (S.nav_root.last_frame < S.frame - 1 or S.nav_root.skip) then
        S.nav_root, S.nav_active = nil, false
    end
    -- the top popup takes navigation while navigating; leaving it returns focus to its opener
    local top = S.popups[#S.popups]
    S.nav_win = (top and top.win and (S.nav_active or top.modal)) and top.win or S.nav_root
    local depth = (S.nav_active and S.nav_win and S.nav_win.is_popup) and #S.popups or 0
    while S.nav_depth < depth do
        S.nav_return[#S.nav_return + 1] = S.nav_id or false
        S.nav_id = nil
        S.nav_depth = S.nav_depth + 1
    end
    while S.nav_depth > depth do
        local r = table.remove(S.nav_return)
        if r then S.nav_id = r end
        S.nav_depth = S.nav_depth - 1
    end
    if not input_ok or not S.nav_win or S.text_id then return end
    if S.clicked[0] or S.clicked[1] then S.nav_active = false end

    if key_rep(0x09) then
        if not S.nav_active then
            S.nav_active = true
            if not nav_find(S.nav_id) then S.nav_id = nil; nav_move("next") end
        else
            nav_move(input.key_down(0x10) and "prev" or "next")
        end
    end
    if not S.nav_active then return end
    if key_rep(0x28) or ui_act("DOWN", "ui_just_pressed") then nav_move("down") end
    if key_rep(0x26) or ui_act("UP", "ui_just_pressed") then nav_move("up") end
    local lr = 0
    if key_rep(0x27) or ui_act("RIGHT", "ui_just_pressed") then lr = 1 end
    if key_rep(0x25) or ui_act("LEFT", "ui_just_pressed") then lr = -1 end
    if lr ~= 0 then
        local it = nav_find(S.nav_id)
        if it and (it.kind == "slider" or it.kind == "drag") then
            S.nav_adjust = lr
        else
            nav_move(lr > 0 and "right" or "left")
        end
    end
    if input.key_just_pressed(0x0D) or input.key_just_pressed(0x20) or ui_act("ACCEPT", "ui_just_pressed") then
        S.nav_activate = S.nav_id
    end
    if input.key_just_pressed(0x1B) or ui_act("CANCEL", "ui_just_pressed") then
        local tp = S.popups[#S.popups]
        if tp and not tp.modal then
            S.just_closed[tp.id] = true
            S.popups[#S.popups] = nil
        else
            S.nav_active = false
        end
    end
end

local function new_frame(input_ok)
    S.frame = S.frame + 1
    S.mx, S.my = input.mouse_x(), input.mouse_y()
    S.clicked, S.down, S.released = {}, {}, {}
    for b = 0, 2 do
        S.clicked[b] = input_ok and input.mouse_clicked(b) or false
        S.down[b] = input_ok and input.mouse_down(b) or false
        S.released[b] = input_ok and input.mouse_released(b) or false
    end
    local t = now()
    S.dbl = false
    if S.clicked[0] then
        if t - S.last_click_t < 0.30 and abs(S.mx - S.last_click_x) < 6 and abs(S.my - S.last_click_y) < 6 then
            S.dbl = true
            S.last_click_t = -10
        else
            S.last_click_t = t
        end
        S.last_click_x, S.last_click_y = S.mx, S.my
    end
    S.cap_id = S.cap_id ~= 0 and S.cap_id or ui.hash("##imgui.capture")
    S.just_closed = {}
    S.hovered_id, S.hovered_allow = nil, false
    S.cursor = ImGuiMouseCursor.Arrow
    sync_palette()

    -- hovered root window from last frame's rects: tooltips never, popups first, then z-order
    S.hover_root = nil
    if input_ok then
        for i = #S.popups, 1, -1 do
            local p = S.popups[i].win
            if p and p.rect and p.last_frame == S.frame - 1 and shown_on(p, S.frame - 1) and mouse_in(p.rect[1], p.rect[2], p.rect[3], p.rect[4]) then
                S.hover_root = p
                break
            end
        end
        local modal = any_modal()
        if not S.hover_root and not modal then
            for pass = 1, 2 do
                for i = #S.order, 1, -1 do
                    local w = S.order[i]
                    if (w.topmost and true or false) == (pass == 1) and w.rect and w.last_frame == S.frame - 1
                       and shown_on(w, S.frame - 1) and mouse_in(w.rect[1], w.rect[2], w.rect[3], w.rect[4]) then
                        S.hover_root = w
                        break
                    end
                end
                if S.hover_root then break end
            end
        end
        -- claim the mouse from the theme menu underneath (ui_input layer arbitration)
        if S.hover_root or S.active_id then
            local prev = ui.layer(100)
            local ok = ui.hovered(0, 0, ctx.screen_w(), ctx.screen_h()) or ui.captured() == S.cap_id
            ui.layer(prev)
            if not ok then S.hover_root = nil end
        end
        -- click outside popups closes them (modals only close via CloseCurrentPopup)
        if S.clicked[0] or S.clicked[1] then
            local lvl = S.hover_root and popup_level_of(S.hover_root) or 0
            local keep = max(lvl, any_modal() or 0)
            for i = #S.popups, keep + 1, -1 do
                S.just_closed[S.popups[i].id] = true
                S.popups[i] = nil
            end
        end
        if S.clicked[0] and S.hover_root and not S.hover_root.is_popup then bring_to_front(S.hover_root) end
        if S.clicked[0] or S.clicked[1] then
            if S.hover_root then
                if not S.hover_root.is_popup then S.nav_root = S.hover_root end
            else
                S.nav_root, S.nav_active = nil, false
            end
        end
        if (S.clicked[0] or S.clicked[1]) and S.hover_root then ui.consume_click(0) end
    end
    -- mouse wheel scrolls the region hovered last frame
    local wt = S.wheel_target
    if input_ok and wt and S.hover_root == wt.root and S.active_id == nil then
        local wh = input.mouse_wheel()
        if wh ~= 0 then
            if (input.key_down(0x10) or wt.scroll_max <= 0) and (wt.scroll_x_max or 0) > 0 then
                wt.scroll_x = clamp(wt.scroll_x - wh * frame_h() * 3, 0, wt.scroll_x_max)
            else
                wt.scroll = clamp(wt.scroll - wh * frame_h() * 3, 0, wt.scroll_max)
            end
        end
    end
    S.wheel_next = nil
    S.bg_cmds, S.fg_cmds = {}, {}
    S.tooltip = nil
    S.popup_depth = 0
    S.next_win = {}
    S.id_seeds = {}
    S.text_seen = false
    nav_frame(input_ok)
end

local function unwind()
    while S.cur do
        local w = S.cur
        if w.is_child then im.EndChild() else end_window() end
    end
    for i = #S.col_stack, 1, -1 do
        local e = S.col_stack[i]
        S.col_over[e[1]] = e[2]
        S.col_stack[i] = nil
    end
    for i = #S.var_stack, 1, -1 do
        local e = S.var_stack[i]
        S.style[e[1]] = e[2]
        S.var_stack[i] = nil
    end
    S.disabled, S.dis_stack = 0, {}
    S.iflags, S.iflag_stack = ImGuiItemFlags.AutoClosePopups, {}
    S.wrap_stack, S.font_stack, S.id_seeds = {}, {}, {}
    S.popup_depth = 0
    S.table, S.tab_bar, S.menubar, S.menubar_saved, S.lb_label = nil, nil, nil, nil, nil
end

local function end_frame()
    unwind()
    if S.active_id and not S.down[0] and not S.active_just then clear_active(true) end
    S.active_just = false
    S.hovered_prev = S.hovered_id
    S.next_allow_overlap = nil
    if S.kbd_focus and S.kbd_focus.frame < S.frame then S.kbd_focus = nil end
    if S.nav_id and S.nav_active and #S.nav_items > 0 then
        local found = false
        for _, it in ipairs(S.nav_items) do if it.id == S.nav_id then found = true break end end
        if not found and not nav_find(S.nav_id) then S.nav_id = nil end
    end
    if S.dd and not S.down[0] then S.dd = nil end
    S.wheel_target = S.wheel_next
    -- a focused text field that was not submitted this frame loses focus
    if S.text_id and not S.text_seen then
        if ui.focused() == S.text_id then ui.blur() end
        S.deactivated_id, S.deactivated_frame, S.deactivated_edited = S.text_id, S.frame + 1, S.text_edited or false
        S.text_id = nil
        menu.set_text_editing(false)
    end
    -- popups that were not submitted this frame are closed
    for i = #S.popups, 1, -1 do
        local p = S.popups[i]
        if not p.win or p.win.last_frame ~= S.frame then
            if p.opened_frame ~= S.frame then
                for j = #S.popups, i, -1 do S.popups[j] = nil end
            end
        end
    end
end

local function render()
    flush(S.bg_cmds)
    local function paint(w)
        if w.last_frame ~= S.frame or not shown_on(w, S.frame) then return end
        flush(w.pre)
        flush(w.cmds)
        flush(w.post)
    end
    for i = 1, #S.order do if not S.order[i].topmost then paint(S.order[i]) end end
    for i = 1, #S.order do if S.order[i].topmost then paint(S.order[i]) end end
    for i = 1, #S.popups do if S.popups[i].win then paint(S.popups[i].win) end end
    if S.tooltip then paint(S.tooltip) end
    flush(S.fg_cmds)
end

-- ── registration (YimMenu gui.* surface) ─────────────────────────────────────

local function is_user_script()
    return script and script.loading_user_scripts and script.loading_user_scripts() or false
end

gui = gui or {}
function gui.add_imgui(fn)
    if type(fn) ~= "function" then return end
    S.cbs[#S.cbs + 1] = { fn = fn, always = false, user = is_user_script() }
end
function gui.add_always_draw_imgui(fn)
    if type(fn) ~= "function" then return end
    S.cbs[#S.cbs + 1] = { fn = fn, always = true, user = is_user_script() }
end
gui.is_open = gui.is_open or function() return menu.is_visible() end
gui.toggle = gui.toggle or function(v) if v == nil then v = not menu.is_visible() end menu.set_visible(v) end
gui.show_message = gui.show_message or function(title, msg) notify.push(tostring(title), tostring(msg), 0) end
gui.show_success = gui.show_success or function(title, msg) notify.push(tostring(title), tostring(msg), 1) end
gui.show_warning = gui.show_warning or function(title, msg) notify.push(tostring(title), tostring(msg), 3) end
gui.show_error = gui.show_error or function(title, msg) notify.push(tostring(title), tostring(msg), 2) end

-- Called by lua_engine::reload_user_scripts: drop every callback a user script registered.
__on_user_scripts_reload = __on_user_scripts_reload or {}
__on_user_scripts_reload[#__on_user_scripts_reload + 1] = function()
    local keep = {}
    for i = 1, #S.cbs do if not S.cbs[i].user then keep[#keep + 1] = S.cbs[i] end end
    S.cbs = keep
end

local function cursor_visible()
    if menu.is_visible() then return true end
    if ui.cursor_forced and ui.cursor_forced() then return true end
    if teleport and teleport.map_is_open and teleport.map_is_open() then return true end
    return false
end

-- While an ImGui text field is edited or keyboard navigation is active, the theme's menu input is skipped
-- (ui.capture_keyboard) and game input is suppressed (menu.set_text_editing). Re-claimed every frame.
local function claim_input()
    local want_kbd = S.input_ok and (S.text_id ~= nil or (S.nav_active and S.nav_win ~= nil)
        or S.want_kbd_frame == S.frame)
    if want_kbd then
        if ui.capture_keyboard then ui.capture_keyboard() end
        menu.set_text_editing(true)
        S.owns_text_editing = true
    elseif S.owns_text_editing then
        menu.set_text_editing(false)
        S.owns_text_editing = false
    end
    if S.input_ok and S.want_mouse_frame == S.frame then
        local prev = ui.layer(100)
        ui.hovered(0, 0, ctx.screen_w(), ctx.screen_h())
        ui.layer(prev)
    end
end

local function imgui_frame()
    if #S.cbs == 0 then
        if S.text_id then ui.blur(); S.text_id = nil; menu.set_text_editing(false) end
        if S.owns_text_editing then menu.set_text_editing(false); S.owns_text_editing = false end
        S.nav_active = false
        S.cursor = ImGuiMouseCursor.Arrow
        return
    end
    local visible = menu.is_visible()
    S.input_ok = cursor_visible()
    new_frame(S.input_ok)
    local dead = nil
    for i = 1, #S.cbs do
        local cb = S.cbs[i]
        if cb.always or visible then
            local ok, err = pcall(cb.fn)
            if not ok then
                unwind()
                dead = dead or {}
                dead[#dead + 1] = cb
                local msg = tostring(err)
                if notify and notify.push then notify.push("ImGui", msg, 2, 6.0) end
            end
        end
    end
    if dead then
        local keep = {}
        for i = 1, #S.cbs do
            local d = false
            for j = 1, #dead do if dead[j] == S.cbs[i] then d = true end end
            if not d then keep[#keep + 1] = S.cbs[i] end
        end
        S.cbs = keep
    end
    end_frame()
    claim_input()
    render()
end

overlay.on_draw("imgui", imgui_frame)

-- ════════════════════════════════════════════════════════════════════════════
-- Public API
-- ════════════════════════════════════════════════════════════════════════════

-- ── windows ──────────────────────────────────────────────────────────────────

-- Begin(name) -> draw | Begin(name, flags) -> draw | Begin(name, open[, flags]) -> open, draw
function im.Begin(name, a, b)
    local p_open, flags = nil, 0
    if type(a) == "boolean" then p_open, flags = a, b or 0 elseif a == nil then flags = b or 0 else flags = a end
    local w, visible = begin_window(tostring(name), flags, "root", p_open)
    if p_open ~= nil then
        local open = p_open and not w.close_req
        return open, visible and open
    end
    return visible
end

function im.End()
    if S.cur and S.cur.is_child then im.EndChild() end
    if S.cur and S.cur.kind == "root" then end_window() end
end

-- BeginChild(name[, w, h, border_or_childflags, window_flags]) -> visible
function im.BeginChild(name, sx, sy, border, flags)
    local parent = S.cur
    if not parent then return false end
    flags = flags or 0
    local cflags = type(border) == "number" and border or (border and ImGuiChildFlags.Borders or 0)
    local id = get_id(name)
    local w = get_window("child:" .. id, "child")
    local x, y = item_pos()
    local aw = parent.dc.right - x
    local ah = parent.clip[4] - y - parent.pad.y
    sx, sy = sx or 0, sy or 0
    local cw = sx > 0 and sx or max(4, aw + sx)
    local ch
    if has(cflags, ImGuiChildFlags.AutoResizeY) or has(cflags, ImGuiChildFlags.AlwaysAutoResize) then
        ch = (w.content_h or 0) + ((has(cflags, ImGuiChildFlags.Borders) or has(cflags, ImGuiChildFlags.AlwaysUseWindowPadding)) and S.style.WindowPadding.y * 2 or 0)
        if sy > 0 then ch = min(ch, sy) end
        ch = max(ch, 4)
    else
        ch = sy > 0 and sy or max(4, ah + sy)
    end
    if has(cflags, ImGuiChildFlags.FrameStyle) then cflags = cflags | ImGuiChildFlags.Borders end
    w.flags, w.cflags = flags, cflags
    w.is_child, w.is_popup, w.kind = true, false, "child"
    w.parent, w.root = parent, parent.root
    w.x, w.y, w.w, w.h = x, y, cw, ch
    w.last_frame = S.frame
    local bordered = has(cflags, ImGuiChildFlags.Borders) or has(cflags, ImGuiChildFlags.AlwaysUseWindowPadding)
    w.pad = bordered and S.style.WindowPadding or v2(0, 0)
    w.has_title, w.menubar_h = false, 0
    local L = parent.root.cmds
    local bg = has(cflags, ImGuiChildFlags.FrameStyle) and col(ImGuiCol.FrameBg) or col(ImGuiCol.ChildBg)
    r_rect(L, x, y, x + cw, y + ch, bg, S.style.ChildRounding)
    if has(cflags, ImGuiChildFlags.Borders) and S.style.ChildBorderSize > 0 then
        r_outline(L, x, y, x + cw, y + ch, col(ImGuiCol.Border), S.style.ChildRounding, S.style.ChildBorderSize)
    end
    local sb = (w.scroll_max > 0 and not has(flags, ImGuiWindowFlags.NoScrollbar)) and (S.style.ScrollbarSize + 2) or 0
    w.sb_w = sb
    w.scroll = clamp(w.scroll, 0, w.scroll_max)
    w.hscroll = has(flags, ImGuiWindowFlags.HorizontalScrollbar) or has(flags, ImGuiWindowFlags.AlwaysHorizontalScrollbar)
    local sbh = (w.hscroll and not has(flags, ImGuiWindowFlags.NoScrollbar)
        and (w.scroll_x_max > 0 or has(flags, ImGuiWindowFlags.AlwaysHorizontalScrollbar))) and (S.style.ScrollbarSize + 2) or 0
    w.sb_h = sbh
    w.scroll_x = clamp(w.scroll_x or 0, 0, w.scroll_x_max or 0)
    local pc = parent.clip
    w.clip = { max(pc[1], x + 1), max(pc[2], y + 1), min(pc[3], x + cw - 1 - sb), min(pc[4], y + ch - 1 - sbh) }
    local dc = new_dc(w, x, y)
    dc.right = x + cw - w.pad.x - sb - w.scroll_x
    r_clip(L, w.clip[1], w.clip[2], w.clip[3], w.clip[4])
    push_window(w)
    seed_push(tostring(id))
    return true
end

function im.EndChild()
    local w = S.cur
    if not w or not w.is_child then return end
    local dc = w.dc
    local L = w.root.cmds
    r_unclip(L)
    w.content_w = max(0, dc.max_x - dc.origin_x)
    w.content_h = max(0, dc.max_y - dc.start_y)
    w.scroll_max = max(0, w.content_h - (w.h - w.pad.y * 2 - w.sb_h))
    w.scroll_x_max = w.hscroll and max(0, w.content_w - (w.w - w.pad.x * 2 - w.sb_w)) or 0
    local pc = w.parent.clip
    if S.input_ok and S.hover_root == w.root and not has(w.flags, ImGuiWindowFlags.NoScrollWithMouse)
       and (w.scroll_max > 0 or w.scroll_x_max > 0) and S.wheel_claim ~= S.frame
       and mouse_in(max(pc[1], w.x), max(pc[2], w.y), min(pc[3], w.x + w.w), min(pc[4], w.y + w.h)) then
        S.wheel_next = w
    end
    if w.sb_w > 0 then
        draw_scrollbar(L, w, w.x + w.w - S.style.ScrollbarSize - 2, w.y + 2, w.x + w.w - 2, w.y + w.h - 2 - w.sb_h)
    end
    if w.sb_h > 0 then
        draw_scrollbar(L, w, w.x + 2, w.y + w.h - S.style.ScrollbarSize - 2, w.x + w.w - 2 - w.sb_w, w.y + w.h - 2, true)
    end
    seed_pop()
    pop_window()
    item_add(w.x, w.y, w.w, w.h)
    S.last.hovered = hover_rect(w.x, w.y, w.x + w.w, w.y + w.h)
end

function im.SetNextWindowPos(x, y, cond, px, py)
    if type(x) == "table" then x, y, cond, px, py = x.x or x[1], x.y or x[2], y, cond, px end
    S.next_win.pos, S.next_win.pos_cond = { x or 0, y or 0 }, cond
    S.next_win.pivot_x, S.next_win.pivot_y = px, py
end
function im.SetNextWindowSize(w, h, cond)
    if type(w) == "table" then w, h, cond = w.x or w[1], w.y or w[2], h end
    S.next_win.size, S.next_win.size_cond = { w or 0, h or 0 }, cond
end
-- SetNextWindowSizeConstraints(min_w, min_h, max_w, max_h) or (ImVec2 min, ImVec2 max); -1 leaves an axis free
function im.SetNextWindowSizeConstraints(a, b, c, d)
    if type(a) == "table" then
        local mn, mx = a, b or {}
        a, b, c, d = mn.x or mn[1], mn.y or mn[2], mx.x or mx[1], mx.y or mx[2]
    end
    S.next_win.cons = { a or -1, b or -1, c or -1, d or -1 }
end
function im.SetNextWindowContentSize(w, h) S.next_win.content = { w or 0, h or 0 } end
function im.SetNextWindowCollapsed(c, cond) S.next_win.collapsed, S.next_win.collapsed_cond = c and true or false, cond end
function im.SetNextWindowFocus() S.next_win.focus = true end
function im.SetNextWindowBgAlpha(a) S.next_win.bg_alpha = a end
function im.SetNextWindowScroll(x, y)
    if type(x) == "table" then x, y = x.x or x[1], x.y or x[2] end
    if y and y >= 0 then S.next_win.scroll_y = y end
    if x and x >= 0 then S.next_win.scroll_x = x end
end

local function named_or_cur(name)
    if type(name) == "string" then return S.windows["root:" .. name] end
    return S.cur and S.cur.root
end
function im.SetWindowPos(a, b, c, d)
    if type(a) == "string" then
        local w = named_or_cur(a); if w then w.x, w.y = b or 0, c or 0 end
    elseif S.cur then S.cur.root.x, S.cur.root.y = a or 0, b or 0 end
end
function im.SetWindowSize(a, b, c)
    local w, x, y = S.cur and S.cur.root, a, b
    if type(a) == "string" then w, x, y = named_or_cur(a), b, c end
    if w then
        if x and x > 0 then w.w = x end
        if y and y > 0 then w.h = y end
        w.size_set = true
    end
end
function im.SetWindowCollapsed(a, b)
    if type(a) == "string" then local w = named_or_cur(a); if w then w.collapsed = b and true or false end
    elseif S.cur then S.cur.root.collapsed = a and true or false end
end
function im.SetWindowFocus(name) local w = named_or_cur(name); if w then bring_to_front(w) end end
function im.SetWindowFontScale(scale) if S.cur then S.cur.font_scale = scale or 1 end end

function im.GetWindowPos() local w = S.cur; if not w then return 0, 0 end return w.x, w.y end
function im.GetWindowSize() local w = S.cur; if not w then return 0, 0 end return w.w, w.h end
function im.GetWindowWidth() return S.cur and S.cur.w or 0 end
function im.GetWindowHeight() return S.cur and S.cur.h or 0 end
function im.IsWindowCollapsed() return S.cur and S.cur.collapsed or false end
function im.IsWindowAppearing() return S.cur and S.cur.first == S.frame or false end
function im.IsWindowFocused(flags)
    if has(flags, ImGuiFocusedFlags.AnyWindow) then return S.order[#S.order] ~= nil end
    return S.cur ~= nil and S.order[#S.order] == S.cur.root
end
function im.IsWindowHovered(flags)
    if has(flags, ImGuiHoveredFlags.AnyWindow) then return S.hover_root ~= nil end
    if not S.cur or S.hover_root ~= S.cur.root then return false end
    if has(flags, ImGuiHoveredFlags.RootWindow) or has(flags, ImGuiHoveredFlags.ChildWindows) then return true end
    local c = S.cur.clip
    return mouse_in(S.cur.x, S.cur.y, S.cur.x + S.cur.w, S.cur.y + S.cur.h)
end
function im.GetScrollY() return S.cur and S.cur.scroll or 0 end
function im.GetScrollX() return S.cur and S.cur.scroll_x or 0 end
function im.GetScrollMaxY() return S.cur and S.cur.scroll_max or 0 end
function im.GetScrollMaxX() return S.cur and S.cur.scroll_x_max or 0 end
function im.SetScrollY(v) if S.cur then S.cur.scroll = clamp(v or 0, 0, max(S.cur.scroll_max, v or 0)) end end
function im.SetScrollX(v) if S.cur then S.cur.scroll_x = max(0, v or 0) end end
function im.SetScrollHereX(ratio)
    local w = S.cur
    if not w then return end
    ratio = ratio or 0.5
    local L = S.last
    local target = (L.x1 - w.dc.origin_x) + (L.x2 - L.x1) * ratio - (w.clip[3] - w.clip[1]) * ratio
    w.scroll_x = clamp(target, 0, max(w.scroll_x_max, 0))
end
function im.SetScrollFromPosX(x, ratio)
    local w = S.cur
    if not w then return end
    w.scroll_x = max(0, w.scroll_x + (x - w.pad.x) - (w.clip[3] - w.clip[1]) * (ratio or 0.5))
end
function im.SetScrollHereY(ratio)
    local w = S.cur
    if not w then return end
    local dc = w.dc
    local target = (dc.cy + w.scroll) - dc.content_y0 - (w.clip[4] - w.clip[2]) * (ratio or 0.5)
    w.scroll = clamp(target, 0, w.scroll_max)
end
function im.SetScrollFromPosY(y, ratio) im.SetScrollY(y - (S.cur and S.cur.h or 0) * (ratio or 0.5)) end

-- ── layout ───────────────────────────────────────────────────────────────────

function im.SameLine(offset, spacing)
    local w = S.cur
    if not w then return end
    local dc = w.dc
    dc.same = true
    dc.same_y = dc.line_top
    if offset and offset > 0 then
        dc.same_x = w.x + offset
    else
        dc.same_x = dc.last_x2 + ((spacing and spacing >= 0) and spacing or S.style.ItemSpacing.x)
    end
end
function im.NewLine()
    if not S.cur then return end
    local x, y = item_pos()
    item_add(x, y, 0, font_h())
end
function im.Spacing()
    if not S.cur then return end
    local x, y = item_pos()
    item_add(x, y, 0, 0)
end
function im.Dummy(w, h)
    if not S.cur then return end
    if type(w) == "table" then w, h = w.x or w[1], w.y or w[2] end
    local x, y = item_pos()
    item_add(x, y, w or 0, h or 0)
end
function im.Indent(v)
    if not S.cur then return end
    local dc = S.cur.dc
    dc.indent = dc.indent + ((v and v > 0) and v or S.style.IndentSpacing)
    dc.cx = dc.start_x + dc.indent
end
function im.Unindent(v)
    if not S.cur then return end
    local dc = S.cur.dc
    dc.indent = dc.indent - ((v and v > 0) and v or S.style.IndentSpacing)
    dc.cx = dc.start_x + dc.indent
end
function im.BeginGroup()
    if not S.cur then return end
    local dc = S.cur.dc
    local x, y = item_pos()
    dc.groups[#dc.groups + 1] = { x = x, y = y, start_x = dc.start_x, indent = dc.indent, max_x = x, max_y = y }
    dc.start_x = x - dc.indent
    dc.cx, dc.cy = x, y
    dc.same = false
    dc.line_top, dc.line_h = y, 0
end
function im.EndGroup()
    if not S.cur then return end
    local dc = S.cur.dc
    local g = dc.groups[#dc.groups]
    if not g then return end
    dc.groups[#dc.groups] = nil
    dc.start_x, dc.indent = g.start_x, g.indent
    dc.same = true
    dc.same_x, dc.same_y = g.x, g.y
    dc.line_top = g.y
    local hov_x1, hov_y1 = g.x, g.y
    item_add(g.x, g.y, g.max_x - g.x, g.max_y - g.y)
    S.last.hovered = hover_rect(hov_x1, hov_y1, g.max_x, g.max_y)
end
function im.AlignTextToFramePadding()
    if S.cur then S.cur.dc.align_text = true end
end
function im.Separator()
    local w = S.cur
    if not w then return end
    local x, y = item_pos()
    local x1 = w.dc.start_x + w.dc.indent
    if w.dc.same then x1 = x end
    r_line(w.root.cmds, x1, y + 1, w.dc.right, y + 1, col(ImGuiCol.Separator), 1)
    item_add(x1, y, 0, 2)
end
function im.SeparatorText(label)
    local w = S.cur
    if not w then return end
    local disp = parse_label(label)
    local x, y = item_pos()
    local pad = S.style.SeparatorTextPadding
    local fh = font_h()
    local h = fh + pad.y * 2
    local tw = text_w(disp)
    local tx = x + pad.x
    local my = y + h * 0.5
    local L = w.root.cmds
    local c = col(ImGuiCol.Separator)
    local th = S.style.SeparatorTextBorderSize
    if pad.x > 0 then r_line(L, x, my, tx - 4, my, c, th) end
    r_text(L, tx, y + pad.y, disp, col(ImGuiCol.Text))
    r_line(L, tx + tw + 6, my, w.dc.right, my, c, th)
    item_add(x, y, pad.x + tw, h)
end
function im.GetCursorPos()
    if not S.cur then return 0, 0 end
    local x, y = item_pos()
    return x - S.cur.x, y - S.cur.y + S.cur.scroll
end
function im.GetCursorPosX() local x = im.GetCursorPos(); return x end
function im.GetCursorPosY() local _, y = im.GetCursorPos(); return y end
function im.GetCursorScreenPos() if not S.cur then return 0, 0 end return item_pos() end
function im.GetCursorStartPos() if not S.cur then return 0, 0 end return S.cur.pad.x, S.cur.dc.content_y0 - S.cur.y end
local function set_cursor(x, y)
    local dc = S.cur.dc
    dc.same = false
    if x then dc.cx = x end
    if y then dc.cy = y; dc.line_top = y; dc.line_h = 0 end
    if x and x > dc.max_x then dc.max_x = x end
    if y and y > dc.max_y then dc.max_y = y end
end
function im.SetCursorPos(x, y)
    if not S.cur then return end
    if type(x) == "table" then x, y = x.x or x[1], x.y or x[2] end
    set_cursor(S.cur.x + x, S.cur.y + y - S.cur.scroll)
end
function im.SetCursorPosX(x) if S.cur then set_cursor(S.cur.x + x, nil) end end
function im.SetCursorPosY(y) if S.cur then set_cursor(nil, S.cur.y + y - S.cur.scroll) end end
function im.SetCursorScreenPos(x, y)
    if not S.cur then return end
    if type(x) == "table" then x, y = x.x or x[1], x.y or x[2] end
    set_cursor(x, y)
end
function im.GetContentRegionAvail()
    if not S.cur then return 0, 0 end
    local x, y = item_pos()
    return max(0, S.cur.dc.right - x), max(0, S.cur.clip[4] - y - S.cur.pad.y + (S.cur.is_child and S.cur.pad.y or 0))
end
function im.GetContentRegionMax()
    if not S.cur then return 0, 0 end
    return S.cur.dc.right - S.cur.x, S.cur.h - S.cur.pad.y
end
function im.GetWindowContentRegionMin() if not S.cur then return 0, 0 end return S.cur.pad.x, S.cur.dc.content_y0 - S.cur.y end
function im.GetWindowContentRegionMax() return im.GetContentRegionMax() end
function im.GetWindowContentRegionWidth() if not S.cur then return 0 end return S.cur.dc.right - S.cur.dc.start_x end
function im.PushItemWidth(w) if S.cur then local s = S.cur.dc.item_w; s[#s + 1] = (w == 0) and nil or w end end
function im.PopItemWidth() if S.cur then local s = S.cur.dc.item_w; s[#s] = nil end end
function im.SetNextItemWidth(w) S.next_item_w = w end
function im.CalcItemWidth() if not S.cur then return 0 end local v = S.next_item_w; local r = calc_item_w(); S.next_item_w = v; return r end
function im.GetTextLineHeight() return font_h() end
function im.GetTextLineHeightWithSpacing() return font_h() + S.style.ItemSpacing.y end
function im.GetFrameHeight() return frame_h() end
function im.GetFrameHeightWithSpacing() return frame_h() + S.style.ItemSpacing.y end
function im.GetFontSize() return font_h() end
function im.CalcTextSize(s, hide_after_hash, wrap_w)
    s = tostring(s or "")
    if hide_after_hash then s = parse_label(s) end
    local fh = font_h()
    local wmax, lines = 0, 0
    for line in (s .. "\n"):gmatch("(.-)\n") do
        lines = lines + 1
        local lw = text_w(line)
        if wrap_w and wrap_w > 0 and lw > wrap_w then
            lines = lines + floor(lw / wrap_w)
            lw = wrap_w
        end
        if lw > wmax then wmax = lw end
    end
    return wmax, lines * fh
end

-- ── ids / style stacks ───────────────────────────────────────────────────────

function im.PushID(...)
    local parts = { ... }
    for i = 1, #parts do parts[i] = tostring(parts[i]) end
    seed_push(seed() .. "/" .. table.concat(parts, ":"))
end
function im.PopID() seed_pop() end
function im.GetID(s) return get_id(s) end

function im.PushStyleColor(idx, a, b, c, d)
    S.col_stack[#S.col_stack + 1] = { idx, S.col_over[idx] }
    S.col_over[idx] = to_f4(a, b, c, d)
end
function im.PopStyleColor(n)
    for _ = 1, (n or 1) do
        local e = S.col_stack[#S.col_stack]
        if not e then return end
        S.col_over[e[1]] = e[2]
        S.col_stack[#S.col_stack] = nil
    end
end
function im.PushStyleVar(idx, a, b)
    local name = VAR_NAME[idx]
    if not name then return end
    local old = S.style[name]
    S.var_stack[#S.var_stack + 1] = { name, old }
    if type(old) == "table" then
        if type(a) == "table" then a, b = a.x or a[1], a.y or a[2] end
        S.style[name] = v2(a or old.x, b or a or old.y)
    else
        S.style[name] = a or old
    end
end
function im.PopStyleVar(n)
    for _ = 1, (n or 1) do
        local e = S.var_stack[#S.var_stack]
        if not e then return end
        S.style[e[1]] = e[2]
        S.var_stack[#S.var_stack] = nil
    end
end
function im.GetStyle() S.style.Colors = S.style.Colors or {}; return S.style end
function im.GetStyleColorVec4(idx) local c = col(idx); return c[1], c[2], c[3], c[4] end
function im.GetColorU32(a, b, c, d)
    if type(a) == "number" and b == nil and a < ImGuiCol.COUNT and a >= 0 and floor(a) == a then
        local cc = col(a); return f4_to_u32(cc[1], cc[2], cc[3], cc[4])
    end
    local f = to_f4(a, b, c, d)
    return f4_to_u32(f[1], f[2], f[3], f[4])
end
function im.ColorConvertFloat4ToU32(a, b, c, d) local f = to_f4(a, b, c, d); return f4_to_u32(f[1], f[2], f[3], f[4]) end
function im.ColorConvertU32ToFloat4(u) local f = u32_to_f4(u); return f[1], f[2], f[3], f[4] end
function im.ColorConvertRGBtoHSV(r, g, b)
    local mx, mn = max(r, g, b), min(r, g, b)
    local d = mx - mn
    local h = 0
    if d > 0 then
        if mx == r then h = ((g - b) / d) % 6 elseif mx == g then h = (b - r) / d + 2 else h = (r - g) / d + 4 end
        h = h / 6
    end
    return h, mx > 0 and d / mx or 0, mx
end
function im.ColorConvertHSVtoRGB(h, s, v)
    if s <= 0 then return v, v, v end
    h = (h % 1) * 6
    local i = floor(h)
    local f = h - i
    local p, q, t = v * (1 - s), v * (1 - s * f), v * (1 - s * (1 - f))
    if i == 0 then return v, t, p elseif i == 1 then return q, v, p elseif i == 2 then return p, v, t
    elseif i == 3 then return p, q, v elseif i == 4 then return t, p, v end
    return v, p, q
end
function im.BeginDisabled(disabled)
    local on = disabled == nil or disabled == true
    S.dis_stack = S.dis_stack or {}
    S.dis_stack[#S.dis_stack + 1] = on
    if on then S.disabled = S.disabled + 1 end
end
function im.EndDisabled()
    local st = S.dis_stack or {}
    local on = st[#st]
    st[#st] = nil
    if on then S.disabled = max(0, S.disabled - 1) end
end
function im.PushTextWrapPos(x) S.wrap_stack[#S.wrap_stack + 1] = x or 0 end
function im.PopTextWrapPos() S.wrap_stack[#S.wrap_stack] = nil end
-- PushFont(font_id | font_object | nil[, size]). Font objects come from GetIO().Fonts:AddFont*(); a size
-- scales the font (0.5x..2x of its native height).
function im.PushFont(f, size)
    local id = S.default_font or font.item
    if type(f) == "number" then id = f
    elseif type(f) == "table" then id = f.id or id; if not size or size <= 0 then size = f.size end end
    local scale = 1
    if size and size > 0 then
        local base = text.height(id)
        if base > 0 then scale = size / base end
    end
    S.font_stack[#S.font_stack + 1] = { id = id, scale = scale }
end
function im.PopFont() S.font_stack[#S.font_stack] = nil end
function im.GetFont() return { id = font_body(), size = font_h(), FontSize = font_h() } end
function im.PushItemFlag(flag, enabled)
    S.iflag_stack[#S.iflag_stack + 1] = S.iflags
    if enabled then S.iflags = S.iflags | (flag or 0) else S.iflags = S.iflags & ~(flag or 0) end
end
function im.PopItemFlag()
    local n = #S.iflag_stack
    if n > 0 then S.iflags = S.iflag_stack[n]; S.iflag_stack[n] = nil end
end
function im.PushButtonRepeat(r) im.PushItemFlag(ImGuiItemFlags.ButtonRepeat, r ~= false) end
function im.PopButtonRepeat() im.PopItemFlag() end
function im.PushTabStop(b) im.PushItemFlag(ImGuiItemFlags.NoTabStop, b == false) end
function im.PopTabStop() im.PopItemFlag() end
function im.SetItemDefaultFocus()
    local w = S.cur
    if not w or w.root ~= S.nav_win or not S.last.id or S.last.id == 0 then return end
    if S.nav_id == nil or w.root.first == S.frame then S.nav_id = S.last.id end
end
-- SetKeyboardFocusHere(0) focuses the next item, 1 the one after, -1 the previous one
function im.SetKeyboardFocusHere(offset)
    offset = offset or 0
    if not S.cur then return end
    if offset < 0 then
        if S.last.id and S.last.id ~= 0 then S.focus_take, S.nav_id = S.last.id, S.last.id end
    else
        S.kbd_focus = { win = S.cur.root, n = offset, frame = S.frame }
    end
end
function im.SetItemAllowOverlap() if S.hovered_id and S.hovered_id == S.last.id then S.hovered_allow = true end end
function im.SetNextItemAllowOverlap() S.next_allow_overlap = true end
function im.SetNextItemOpen(open, cond) S.next_open = { open and true or false, cond } end

-- ── text ─────────────────────────────────────────────────────────────────────

local function wrap_lines(s, width)
    local out = {}
    for para in (s .. "\n"):gmatch("(.-)\n") do
        if width <= 0 or text_w(para) <= width then
            out[#out + 1] = para
        else
            local line = ""
            for word in para:gmatch("%S+%s*") do
                local try = line .. word
                if line ~= "" and text_w((try:gsub("%s+$", ""))) > width then
                    out[#out + 1] = (line:gsub("%s+$", ""))
                    line = word
                else
                    line = try
                end
            end
            out[#out + 1] = (line:gsub("%s+$", ""))
        end
    end
    return out
end

local function log_append(s)
    local lg = S.log
    if lg then lg.buf[#lg.buf + 1] = s end
end

local function text_item(s, c, wrap)
    local w = S.cur
    if not w then return end
    s = tostring(s == nil and "" or s)
    if S.log then log_append(s) end
    local x, y = item_pos()
    local dc = w.dc
    local oy = 0
    if (dc.same and dc.line_frame) or dc.align_text then oy = S.style.FramePadding.y end
    dc.align_text = false
    local wrap_x = S.wrap_stack[#S.wrap_stack]
    local width = 0
    if wrap then width = dc.right - x
    elseif wrap_x then width = (wrap_x > 0) and (w.x + wrap_x - x) or (wrap_x == 0 and dc.right - x or 0) end
    local lines = (width > 0 or s:find("\n", 1, true)) and wrap_lines(s, width) or { s }
    local fh = font_h()
    local L = w.root.cmds
    local tw = 0
    local cy = y + oy
    for i = 1, #lines do
        local ln = lines[i]
        if cy + fh >= w.clip[2] and cy <= w.clip[4] then r_text(L, x, cy, ln, c) end
        local lw = text_w(ln)
        if lw > tw then tw = lw end
        cy = cy + fh
    end
    item_add(x, y, tw, #lines * fh + oy)
    S.last.hovered = hover_rect(x, y, x + tw, y + #lines * fh + oy)
end

function im.Text(...)
    local n = select("#", ...)
    local s = ...
    if n > 1 and type(s) == "string" and s:find("%", 1, true) then
        local ok, r = pcall(string.format, ...)
        if ok then s = r end
    end
    text_item(s, col(ImGuiCol.Text))
end
function im.TextUnformatted(s) text_item(s, col(ImGuiCol.Text)) end
function im.TextColored(r, g, b, a, s)
    if type(r) == "table" then text_item(g, to_f4(r)) return end
    text_item(s, { r or 1, g or 1, b or 1, a or 1 })
end
function im.TextDisabled(s) text_item(s, col(ImGuiCol.TextDisabled)) end
function im.TextWrapped(s) text_item(s, col(ImGuiCol.Text), true) end
function im.TextLink(s)
    local w = S.cur
    if not w then return false end
    local disp, idl = parse_label(s)
    local x, y = item_pos()
    local tw, fh = text_w(disp), font_h()
    local id = get_id(idl)
    local pressed, hov = button_behavior(id, x, y, x + tw, y + fh)
    local c = col(ImGuiCol.TextLink)
    r_text(w.root.cmds, x, y, disp, c)
    if hov then r_line(w.root.cmds, x, y + fh, x + tw, y + fh, c, 1) end
    local keep = S.last.hovered
    item_add(x, y, tw, fh)
    S.last.hovered, S.last.clicked, S.last.id = keep, pressed, id
    return pressed
end
function im.TextLinkOpenURL(label) return im.TextLink(label) end
function im.LabelText(label, s)
    local w = S.cur
    if not w then return end
    local disp = parse_label(label)
    local x, y = item_pos()
    local iw = calc_item_w()
    local fh = font_h()
    local L = w.root.cmds
    r_text(L, x, y + S.style.FramePadding.y, tostring(s or ""), col(ImGuiCol.Text))
    r_text(L, x + iw + S.style.ItemInnerSpacing.x, y + S.style.FramePadding.y, disp, col(ImGuiCol.Text))
    item_add(x, y, iw + S.style.ItemInnerSpacing.x + text_w(disp), fh + S.style.FramePadding.y * 2)
end
function im.Bullet()
    local w = S.cur
    if not w then return end
    local x, y = item_pos()
    local fh = font_h()
    r_circle(w.root.cmds, x + fh * 0.5, y + fh * 0.5, fh * 0.18, col(ImGuiCol.Text), true)
    item_add(x, y, fh, fh)
    im.SameLine(0, S.style.ItemInnerSpacing.x)
end
function im.BulletText(s)
    local w = S.cur
    if not w then return end
    local x, y = item_pos()
    local fh = font_h()
    r_circle(w.root.cmds, x + fh * 0.5, y + fh * 0.5, fh * 0.18, col(ImGuiCol.Text), true)
    local tx = x + fh + S.style.ItemInnerSpacing.x
    r_text(w.root.cmds, tx, y, tostring(s or ""), col(ImGuiCol.Text))
    item_add(x, y, tx - x + text_w(tostring(s or "")), fh)
end

-- ── buttons ──────────────────────────────────────────────────────────────────

local function frame_colors(held, hov, base, hovered, active)
    if held then return col(active) elseif hov then return col(hovered) end
    return col(base)
end

function im.Button(label, sx, sy)
    local w = S.cur
    if not w then return false end
    if type(sx) == "table" then sx, sy = sx.x or sx[1], sx.y or sx[2] end
    local disp, idl = parse_label(label)
    local id = get_id(idl)
    local x, y = item_pos()
    local fp = S.style.FramePadding
    local tw = text_w(disp)
    local bw = (sx and sx ~= 0) and (sx > 0 and sx or max(4, avail_w() + sx)) or (tw + fp.x * 2)
    local bh = (sy and sy ~= 0) and (sy > 0 and sy or max(4, avail_w() + sy)) or frame_h()
    local pressed, hov, held = button_behavior(id, x, y, x + bw, y + bh)
    local L = w.root.cmds
    r_rect(L, x, y, x + bw, y + bh, frame_colors(held, hov, ImGuiCol.Button, ImGuiCol.ButtonHovered, ImGuiCol.ButtonActive), S.style.FrameRounding)
    local al = S.style.ButtonTextAlign
    r_text(L, x + max(fp.x, (bw - tw) * al.x), y + (bh - font_h()) * al.y, disp, col(ImGuiCol.Text))
    local keep_h, keep_a = S.last.hovered, S.last.active
    item_add(x, y, bw, bh)
    w.dc.line_frame = true
    local Lst = S.last
    Lst.id, Lst.hovered, Lst.active, Lst.clicked = id, keep_h, keep_a, pressed
    return pressed
end

function im.SmallButton(label)
    local fp = S.style.FramePadding
    S.style.FramePadding = v2(fp.x, 0)
    local r = im.Button(label)
    S.style.FramePadding = fp
    return r
end

function im.InvisibleButton(label, sx, sy)
    local w = S.cur
    if not w then return false end
    if type(sx) == "table" then sx, sy = sx.x or sx[1], sx.y or sx[2] end
    local id = get_id(label)
    local x, y = item_pos()
    sx = (sx and sx > 0) and sx or max(1, avail_w() + (sx or 0))
    sy = (sy and sy > 0) and sy or frame_h()
    local pressed, hov, held = button_behavior(id, x, y, x + sx, y + sy)
    item_add(x, y, sx, sy)
    local L = S.last
    L.id, L.hovered, L.active, L.clicked = id, hov, held, pressed
    return pressed
end

local function arrow(L, cx, cy, s, dir, c)
    if dir == ImGuiDir.Right then
        r_line(L, cx - s * 0.4, cy - s, cx + s * 0.6, cy, c, 1.6); r_line(L, cx + s * 0.6, cy, cx - s * 0.4, cy + s, c, 1.6)
    elseif dir == ImGuiDir.Left then
        r_line(L, cx + s * 0.4, cy - s, cx - s * 0.6, cy, c, 1.6); r_line(L, cx - s * 0.6, cy, cx + s * 0.4, cy + s, c, 1.6)
    elseif dir == ImGuiDir.Up then
        r_line(L, cx - s, cy + s * 0.4, cx, cy - s * 0.6, c, 1.6); r_line(L, cx, cy - s * 0.6, cx + s, cy + s * 0.4, c, 1.6)
    else
        r_line(L, cx - s, cy - s * 0.4, cx, cy + s * 0.6, c, 1.6); r_line(L, cx, cy + s * 0.6, cx + s, cy - s * 0.4, c, 1.6)
    end
end

function im.ArrowButton(label, dir)
    local w = S.cur
    if not w then return false end
    local id = get_id(label)
    local x, y = item_pos()
    local s = frame_h()
    local pressed, hov, held = button_behavior(id, x, y, x + s, y + s)
    local L = w.root.cmds
    r_rect(L, x, y, x + s, y + s, frame_colors(held, hov, ImGuiCol.Button, ImGuiCol.ButtonHovered, ImGuiCol.ButtonActive), S.style.FrameRounding)
    arrow(L, x + s * 0.5, y + s * 0.5, s * 0.18, dir, col(ImGuiCol.Text))
    item_add(x, y, s, s)
    S.last.id, S.last.hovered, S.last.clicked = id, hov, pressed
    return pressed
end

-- Checkbox(label, v) -> v, pressed
function im.Checkbox(label, v)
    local w = S.cur
    if not w then return v, false end
    local disp, idl = parse_label(label)
    local id = get_id(idl)
    local x, y = item_pos()
    local s = frame_h()
    local tw = text_w(disp)
    local tot = s + (tw > 0 and (S.style.ItemInnerSpacing.x + tw) or 0)
    local pressed, hov, held = button_behavior(id, x, y, x + tot, y + s)
    if pressed then v = not v end
    local L = w.root.cmds
    r_rect(L, x, y, x + s, y + s, frame_colors(held, hov, ImGuiCol.FrameBg, ImGuiCol.FrameBgHovered, ImGuiCol.FrameBgActive), S.style.FrameRounding)
    if v then
        local pad = max(1, floor(s / 5))
        r_rect(L, x + pad, y + pad, x + s - pad, y + s - pad, col(ImGuiCol.CheckMark), max(0, S.style.FrameRounding - 1))
        local c = { 1, 1, 1, 0.95 }
        r_line(L, x + s * 0.28, y + s * 0.52, x + s * 0.44, y + s * 0.68, c, 2)
        r_line(L, x + s * 0.44, y + s * 0.68, x + s * 0.74, y + s * 0.34, c, 2)
    end
    if tw > 0 then r_text(L, x + s + S.style.ItemInnerSpacing.x, y + S.style.FramePadding.y, disp, col(ImGuiCol.Text)) end
    item_add(x, y, tot, s)
    w.dc.line_frame = true
    local Lst = S.last
    Lst.id, Lst.hovered, Lst.active, Lst.clicked, Lst.edited = id, hov, held, pressed, pressed
    return v, pressed
end

function im.CheckboxFlags(label, flags, value)
    local on = (flags & value) == value
    local nv, pressed = im.Checkbox(label, on)
    if pressed then flags = nv and (flags | value) or (flags & ~value) end
    return flags, pressed
end

-- RadioButton(label, active) -> pressed | RadioButton(label, v, v_button) -> v, pressed
function im.RadioButton(label, a, b)
    local w = S.cur
    if not w then return b ~= nil and a or false, false end
    local active = a
    if b ~= nil then active = (a == b) end
    local disp, idl = parse_label(label)
    local id = get_id(idl)
    local x, y = item_pos()
    local s = frame_h()
    local tw = text_w(disp)
    local tot = s + (tw > 0 and (S.style.ItemInnerSpacing.x + tw) or 0)
    local pressed, hov, held = button_behavior(id, x, y, x + tot, y + s)
    local L = w.root.cmds
    local r = s * 0.5
    r_circle(L, x + r, y + r, r, frame_colors(held, hov, ImGuiCol.FrameBg, ImGuiCol.FrameBgHovered, ImGuiCol.FrameBgActive), true)
    if active then r_circle(L, x + r, y + r, r * 0.5, col(ImGuiCol.CheckMark), true) end
    if tw > 0 then r_text(L, x + s + S.style.ItemInnerSpacing.x, y + S.style.FramePadding.y, disp, col(ImGuiCol.Text)) end
    item_add(x, y, tot, s)
    w.dc.line_frame = true
    S.last.id, S.last.hovered, S.last.clicked, S.last.edited = id, hov, pressed, pressed
    if b ~= nil then
        if pressed then a = b end
        return a, pressed
    end
    return pressed
end

function im.ProgressBar(frac, sx, sy, overlay)
    local w = S.cur
    if not w then return end
    if type(sx) == "string" then overlay, sx, sy = sx, nil, nil end
    if type(sx) == "table" then overlay, sx, sy = sy, sx.x or sx[1], sx.y or sx[2] end
    frac = clamp(frac or 0, 0, 1)
    local x, y = item_pos()
    local bw = (sx and sx > 0) and sx or max(4, avail_w() + (sx or 0))
    if sx == nil then bw = calc_item_w() end
    local bh = (sy and sy > 0) and sy or frame_h()
    local L = w.root.cmds
    r_rect(L, x, y, x + bw, y + bh, col(ImGuiCol.FrameBg), S.style.FrameRounding)
    if frac > 0 then r_rect(L, x, y, x + max(bh * 0.5, bw * frac), y + bh, col(ImGuiCol.PlotHistogram), S.style.FrameRounding) end
    local s = overlay or string.format("%.0f%%", frac * 100)
    local tw = text_w(s)
    r_text(L, x + (bw - tw) * 0.5, y + (bh - font_h()) * 0.5, s, col(ImGuiCol.Text))
    item_add(x, y, bw, bh)
    w.dc.line_frame = true
end

function im.Image(handle, sx, sy, u0, v0, u1, v1, tint)
    local w = S.cur
    if not w then return end
    if type(sx) == "table" then sx, sy = sx.x or sx[1], sx.y or sx[2] end
    local x, y = item_pos()
    if not sx or sx <= 0 then
        local iw, ih = draw.image_size(handle)
        sx, sy = iw, ih
    end
    if handle then r_image(w.root.cmds, handle, x, y, x + sx, y + (sy or sx), type(tint) == "table" and to_f4(tint) or nil) end
    item_add(x, y, sx or 0, sy or sx or 0)
    S.last.hovered = hover_rect(x, y, x + (sx or 0), y + (sy or 0))
end
function im.ImageButton(label, handle, sx, sy)
    local w = S.cur
    if not w then return false end
    if type(sx) == "table" then sx, sy = sx.x or sx[1], sx.y or sx[2] end
    local id = get_id(label)
    local x, y = item_pos()
    local fp = S.style.FramePadding
    local bw, bh = (sx or 16) + fp.x * 2, (sy or sx or 16) + fp.y * 2
    local pressed, hov, held = button_behavior(id, x, y, x + bw, y + bh)
    local L = w.root.cmds
    r_rect(L, x, y, x + bw, y + bh, frame_colors(held, hov, ImGuiCol.Button, ImGuiCol.ButtonHovered, ImGuiCol.ButtonActive), S.style.FrameRounding)
    if handle then r_image(L, handle, x + fp.x, y + fp.y, x + bw - fp.x, y + bh - fp.y) end
    item_add(x, y, bw, bh)
    S.last.id, S.last.hovered, S.last.clicked = id, hov, pressed
    return pressed
end

-- ── sliders / drags ──────────────────────────────────────────────────────────

local function fmt_value(fmt, v, is_int)
    if is_int then v = floor(v + 0.5) end
    fmt = fmt or (is_int and "%d" or "%.3f")
    local ok, s = pcall(string.format, fmt, v)
    if ok then return s end
    ok, s = pcall(string.format, fmt, floor(v))
    return ok and s or tostring(v)
end

local function round_to_format(v, fmt)
    local dec = fmt and fmt:match("%%[%-+ #0]*%d*%.(%d+)[fFeEgG]")
    if dec then
        local m = 10 ^ tonumber(dec)
        return floor(v * m + 0.5) / m
    end
    return v
end

-- Shared frame + label for slider/drag/input rows. Returns x, y, frame_w, frame_h, total_w
local function labelled_frame(disp)
    local x, y = item_pos()
    local iw = calc_item_w()
    return x, y, iw, frame_h()
end

local function finish_labelled(w, x, y, iw, fh, disp)
    if disp ~= "" then
        r_text(w.root.cmds, x + iw + S.style.ItemInnerSpacing.x, y + S.style.FramePadding.y, disp, col(ImGuiCol.Text))
    end
    local tot = iw + (disp ~= "" and (S.style.ItemInnerSpacing.x + text_w(disp)) or 0)
    item_add(x, y, tot, fh)
    w.dc.line_frame = true
end

-- inline text editing of a numeric frame (Ctrl+click / double-click on sliders, always for InputInt/Float)
local function begin_text_edit(id, initial, flags)
    ui.focus(id, initial, flags or 0)
    S.text_id = id
    S.text_seen = true
    S.text_edited = false
    S.text_tf = flags or 0
    S.text_caret_prev = nil
    S.activated_id, S.activated_frame = id, S.frame
    menu.set_text_editing(true)
end

local function text_done(id)
    S.text_id = nil
    menu.set_text_editing(false)
    S.deactivated_id, S.deactivated_frame, S.deactivated_edited = id, S.frame, S.text_edited or false
end

local function slider_scalar(label, v, vmin, vmax, fmt, flags, is_int)
    local w = S.cur
    if not w then return v, false end
    local disp, idl = parse_label(label)
    local id = get_id(idl)
    local x, y, iw, fh = labelled_frame(disp)
    local L = w.root.cmds
    local changed = false
    v = v or 0
    if S.focus_take == id and not has(flags, ImGuiSliderFlags.NoInput) then
        S.focus_take = nil
        begin_text_edit(id, fmt_value(is_int and "%d" or "%g", v, is_int), is_int and text_flag.numeric or text_flag.decimal)
    end
    local editing = S.text_id == id and ui.focused() == id
    if editing then
        S.text_seen = true
        local s, _, status = ui.text_edit(id)
        r_rect(L, x, y, x + iw, y + fh, col(ImGuiCol.FrameBgActive), S.style.FrameRounding)
        r_text(L, x + S.style.FramePadding.x, y + S.style.FramePadding.y, s .. ((floor(now() * 2) % 2 == 0) and "|" or ""), col(ImGuiCol.Text))
        if status == 1 then
            local n = tonumber(s)
            if n then
                n = clamp(n, min(vmin, vmax), max(vmin, vmax))
                v = is_int and floor(n + 0.5) or n
                changed = true
            end
        end
        if changed then S.text_edited = true end
        if status == 1 or status == 2 then text_done(id)
        elseif S.clicked[0] and not mouse_in(x, y, x + iw, y + fh) then ui.blur(); text_done(id) end
        nav_item(id, x, y, x + iw, y + fh, "text")
        finish_labelled(w, x, y, iw, fh, disp)
        S.last.id, S.last.edited = id, changed
        return v, changed
    end
    local hov = item_hoverable(id, x, y, x + iw, y + fh)
    if hov and S.clicked[0] and S.active_id == nil then
        if (input.key_down(0x11) or S.dbl) and not has(flags, ImGuiSliderFlags.NoInput) then
            begin_text_edit(id, fmt_value(is_int and "%d" or "%g", v, is_int), is_int and text_flag.numeric or text_flag.decimal)
            ui.consume_click(0)
        else
            set_active(id)
        end
    end
    local held = S.active_id == id
    local grab = max(S.style.GrabMinSize, is_int and (iw - 4) / max(1, abs(vmax - vmin) + 1) or 0)
    grab = min(grab, iw - 4)
    local lo, hi = min(vmin, vmax), max(vmin, vmax)
    local log = has(flags, ImGuiSliderFlags.Logarithmic) and lo > 0
    if nav_item(id, x, y, x + iw, y + fh, "slider") then
        if S.nav_adjust ~= 0 then
            local step = is_int and 1 or (hi - lo) / 100
            if input.key_down(0x10) then step = step * 10 end
            local nv = clamp(v + step * S.nav_adjust * ((vmin > vmax) and -1 or 1), lo, hi)
            if not is_int then nv = round_to_format(nv, fmt) end
            if nv ~= v then v = nv; changed = true end
        end
        if S.nav_activate == id then S.nav_activate = nil; S.focus_take = id end
    end
    if held then
        if S.down[0] then
            local t = clamp((S.mx - x - 2 - grab * 0.5) / max(1, iw - 4 - grab), 0, 1)
            if vmin > vmax then t = 1 - t end
            local nv
            if log then nv = lo * (hi / lo) ^ t else nv = lo + (hi - lo) * t end
            if is_int then nv = floor(nv + 0.5) else nv = round_to_format(nv, fmt) end
            if nv ~= v then v = nv; changed = true end
        else
            clear_active()
        end
    end
    if changed and S.active_id == id then S.active_edited = true end
    local t = (hi > lo) and ((log and (math.log(clamp(v, lo, hi) / lo) / math.log(hi / lo))) or ((clamp(v, lo, hi) - lo) / (hi - lo))) or 0
    if vmin > vmax then t = 1 - t end
    r_rect(L, x, y, x + iw, y + fh, frame_colors(held, hov, ImGuiCol.FrameBg, ImGuiCol.FrameBgHovered, ImGuiCol.FrameBgActive), S.style.FrameRounding)
    local gx = x + 2 + (iw - 4 - grab) * t
    r_rect(L, gx, y + 2, gx + grab, y + fh - 2, col(held and ImGuiCol.SliderGrabActive or ImGuiCol.SliderGrab), S.style.GrabRounding)
    local s = fmt_value(fmt, v, is_int)
    r_text(L, x + (iw - text_w(s)) * 0.5, y + S.style.FramePadding.y, s, col(ImGuiCol.Text))
    finish_labelled(w, x, y, iw, fh, disp)
    local Lst = S.last
    Lst.id, Lst.hovered, Lst.active, Lst.edited = id, hov, held, changed
    return v, changed
end

function im.SliderFloat(label, v, vmin, vmax, fmt, flags)
    if type(fmt) == "number" then flags, fmt = nil, nil end
    return slider_scalar(label, v, vmin or 0, vmax or 1, fmt, flags, false)
end
function im.SliderInt(label, v, vmin, vmax, fmt, flags)
    return slider_scalar(label, v, vmin or 0, vmax or 100, fmt, flags, true)
end
function im.SliderAngle(label, rad, dmin, dmax, fmt)
    local deg, changed = slider_scalar(label, (rad or 0) * 180 / math.pi, dmin or -360, dmax or 360, fmt or "%.0f deg", 0, false)
    return deg * math.pi / 180, changed
end

local function multi_scalar(fn, label, vals, n, ...)
    local w = S.cur
    if not w then return vals, false end
    local disp, idl = parse_label(label)
    local total = calc_item_w()
    local sp = S.style.ItemInnerSpacing.x
    local each = max(1, (total - sp * (n - 1)) / n)
    local out, any = {}, false
    im.BeginGroup()
    im.PushID(idl)
    for i = 1, n do
        S.next_item_w = each
        local nv, ch = fn("##v" .. i, vals[i] or 0, ...)
        out[i] = nv
        any = any or ch
        if i < n then im.SameLine(0, sp) end
    end
    im.PopID()
    if disp ~= "" then im.SameLine(0, sp); im.TextUnformatted(disp) end
    im.EndGroup()
    return out, any
end
function im.SliderFloat2(l, v, a, b, f, fl) return multi_scalar(im.SliderFloat, l, v, 2, a, b, f, fl) end
function im.SliderFloat3(l, v, a, b, f, fl) return multi_scalar(im.SliderFloat, l, v, 3, a, b, f, fl) end
function im.SliderFloat4(l, v, a, b, f, fl) return multi_scalar(im.SliderFloat, l, v, 4, a, b, f, fl) end
function im.SliderInt2(l, v, a, b, f, fl) return multi_scalar(im.SliderInt, l, v, 2, a, b, f, fl) end
function im.SliderInt3(l, v, a, b, f, fl) return multi_scalar(im.SliderInt, l, v, 3, a, b, f, fl) end
function im.SliderInt4(l, v, a, b, f, fl) return multi_scalar(im.SliderInt, l, v, 4, a, b, f, fl) end

local function drag_scalar(label, v, speed, vmin, vmax, fmt, flags, is_int)
    local w = S.cur
    if not w then return v, false end
    local disp, idl = parse_label(label)
    local id = get_id(idl)
    local x, y, iw, fh = labelled_frame(disp)
    local L = w.root.cmds
    v = v or 0
    speed = (speed and speed ~= 0) and speed or 1
    local changed = false
    if S.focus_take == id and not has(flags, ImGuiSliderFlags.NoInput) then
        S.focus_take = nil
        begin_text_edit(id, fmt_value(is_int and "%d" or "%g", v, is_int), is_int and text_flag.numeric or text_flag.decimal)
    end
    local editing = S.text_id == id and ui.focused() == id
    if editing then
        S.text_seen = true
        local s, _, status = ui.text_edit(id)
        r_rect(L, x, y, x + iw, y + fh, col(ImGuiCol.FrameBgActive), S.style.FrameRounding)
        r_text(L, x + S.style.FramePadding.x, y + S.style.FramePadding.y, s .. ((floor(now() * 2) % 2 == 0) and "|" or ""), col(ImGuiCol.Text))
        if status == 1 then
            local n = tonumber(s)
            if n then
                if vmin and vmax and vmin < vmax then n = clamp(n, vmin, vmax) end
                v = is_int and floor(n + 0.5) or n
                changed = true
            end
        end
        if changed then S.text_edited = true end
        if status == 1 or status == 2 then text_done(id)
        elseif S.clicked[0] and not mouse_in(x, y, x + iw, y + fh) then ui.blur(); text_done(id) end
        nav_item(id, x, y, x + iw, y + fh, "text")
        finish_labelled(w, x, y, iw, fh, disp)
        S.last.id, S.last.edited = id, changed
        return v, changed
    end
    local hov = item_hoverable(id, x, y, x + iw, y + fh)
    if hov and S.clicked[0] and S.active_id == nil then
        if (input.key_down(0x11) or S.dbl) and not has(flags, ImGuiSliderFlags.NoInput) then
            begin_text_edit(id, fmt_value(is_int and "%d" or "%g", v, is_int), is_int and text_flag.numeric or text_flag.decimal)
            ui.consume_click(0)
        else
            set_active(id)
            S.drag_acc = v
            S.drag_last_x = S.mx
        end
    end
    local held = S.active_id == id
    if held then
        if S.down[0] then
            local dx = S.mx - S.drag_last_x
            S.drag_last_x = S.mx
            if dx ~= 0 then
                local mul = input.key_down(0x10) and 10 or (input.key_down(0x12) and 0.1 or 1)
                S.drag_acc = S.drag_acc + dx * speed * mul
                if vmin and vmax and vmin < vmax then S.drag_acc = clamp(S.drag_acc, vmin, vmax) end
                local nv = is_int and floor(S.drag_acc + 0.5) or round_to_format(S.drag_acc, fmt)
                if nv ~= v then v = nv; changed = true end
            end
        else
            clear_active()
        end
    end
    if changed and S.active_id == id then S.active_edited = true end
    if nav_item(id, x, y, x + iw, y + fh, "drag") then
        if S.nav_adjust ~= 0 then
            local step = abs(speed) * (input.key_down(0x10) and 10 or 1)
            if is_int then step = max(1, floor(step + 0.5)) end
            local nv = v + step * S.nav_adjust
            if vmin and vmax and vmin < vmax then nv = clamp(nv, vmin, vmax) end
            if not is_int then nv = round_to_format(nv, fmt) end
            if nv ~= v then v = nv; changed = true end
        end
        if S.nav_activate == id then S.nav_activate = nil; S.focus_take = id end
    end
    r_rect(L, x, y, x + iw, y + fh, frame_colors(held, hov, ImGuiCol.FrameBg, ImGuiCol.FrameBgHovered, ImGuiCol.FrameBgActive), S.style.FrameRounding)
    local s = fmt_value(fmt, v, is_int)
    r_text(L, x + (iw - text_w(s)) * 0.5, y + S.style.FramePadding.y, s, col(ImGuiCol.Text))
    finish_labelled(w, x, y, iw, fh, disp)
    local Lst = S.last
    Lst.id, Lst.hovered, Lst.active, Lst.edited = id, hov, held, changed
    return v, changed
end

function im.DragFloat(label, v, speed, vmin, vmax, fmt, flags) return drag_scalar(label, v, speed or 1, vmin, vmax, fmt, flags, false) end
function im.DragInt(label, v, speed, vmin, vmax, fmt, flags) return drag_scalar(label, v, speed or 1, vmin, vmax, fmt, flags, true) end
function im.DragFloat2(l, v, s, a, b, f, fl) return multi_scalar(im.DragFloat, l, v, 2, s, a, b, f, fl) end
function im.DragFloat3(l, v, s, a, b, f, fl) return multi_scalar(im.DragFloat, l, v, 3, s, a, b, f, fl) end
function im.DragFloat4(l, v, s, a, b, f, fl) return multi_scalar(im.DragFloat, l, v, 4, s, a, b, f, fl) end
function im.DragInt2(l, v, s, a, b, f, fl) return multi_scalar(im.DragInt, l, v, 2, s, a, b, f, fl) end
function im.DragInt3(l, v, s, a, b, f, fl) return multi_scalar(im.DragInt, l, v, 3, s, a, b, f, fl) end
function im.DragInt4(l, v, s, a, b, f, fl) return multi_scalar(im.DragInt, l, v, 4, s, a, b, f, fl) end

-- ── text input ───────────────────────────────────────────────────────────────

-- core text field. Returns text, changed, committed(enter), hovered, focused
local function text_field(id, x, y, fw, fh, value, flags, hint, multi)
    local w = S.cur
    local L = w.root.cmds
    local focused = S.text_id == id and ui.focused() == id
    local ro = has(flags, ImGuiInputTextFlags.ReadOnly)
    local hov = item_hoverable(id, x, y, x + fw, y + fh)
    if hov then S.cursor = ImGuiMouseCursor.TextInput end
    local changed, committed = false, false
    local want = not focused and hov and S.clicked[0] and S.active_id == nil
    if S.focus_take == id then S.focus_take = nil; want = true end
    -- keyboard activation starts editing next frame, so the Enter that activated it is not also a commit
    if nav_item(id, x, y, x + fw, y + fh, "text") and S.nav_activate == id then S.nav_activate = nil; S.focus_take = id end
    if want and not focused and not ro then
        local tf = 0
        if has(flags, ImGuiInputTextFlags.Password) then tf = text_flag.password
        elseif has(flags, ImGuiInputTextFlags.CharsDecimal) or has(flags, ImGuiInputTextFlags.CharsScientific) then tf = text_flag.decimal end
        if multi then tf = tf | (text_flag.multiline or 0) end
        if has(flags, ImGuiInputTextFlags.AllowTabInput) then tf = tf | (text_flag.tab or 0) end
        if has(flags, ImGuiInputTextFlags.CtrlEnterForNewLine) then tf = tf | (text_flag.ctrl_enter_newline or 0) end
        if has(flags, ImGuiInputTextFlags.AutoSelectAll) then tf = tf | (text_flag.select_all or 0) end
        begin_text_edit(id, value, tf)
        if S.clicked[0] then ui.consume_click(0) end
        focused = true
    end
    local shown = value
    if focused then
        S.text_seen = true
        local s, ch, status = ui.text_edit(id)
        local fs = s
        if has(flags, ImGuiInputTextFlags.CharsUppercase) then fs = fs:upper() end
        if has(flags, ImGuiInputTextFlags.CharsNoBlank) then fs = (fs:gsub("%s", "")) end
        if has(flags, ImGuiInputTextFlags.CharsHexadecimal) then fs = (fs:gsub("[^%x]", "")) end
        if has(flags, ImGuiInputTextFlags.CharsScientific) then fs = (fs:gsub("[^%d%.%+%-eE]", "")) end
        if fs ~= s and status == 0 then ui.focus(id, fs, (S.text_tf or 0) & ~(text_flag.select_all or 0)) end
        s = fs
        shown = s
        if ch then S.text_edited = true end
        if ch and not has(flags, ImGuiInputTextFlags.EnterReturnsTrue) then value = s; changed = true end
        if status == 1 then
            value = s
            committed = true
            if has(flags, ImGuiInputTextFlags.EnterReturnsTrue) then changed = true end
            text_done(id)
        elseif status == 2 then
            if has(flags, ImGuiInputTextFlags.EscapeClearsAll) then value = ""; changed = true end
            text_done(id)
        elseif status == 3 then
            text_done(id)
        elseif S.clicked[0] and not mouse_in(x, y, x + fw, y + fh) then
            ui.blur(); text_done(id)
            if not has(flags, ImGuiInputTextFlags.EnterReturnsTrue) then value = s end
        end
    end
    r_rect(L, x, y, x + fw, y + fh, frame_colors(focused, hov, ImGuiCol.FrameBg, ImGuiCol.FrameBgHovered, ImGuiCol.FrameBgActive), S.style.FrameRounding)
    if focused then r_outline(L, x, y, x + fw, y + fh, col(ImGuiCol.CheckMark), S.style.FrameRounding, 1) end
    local fp = S.style.FramePadding
    local disp = shown or ""
    if has(flags, ImGuiInputTextFlags.Password) then disp = string.rep("*", #disp) end
    local lh = font_h()
    L[#L + 1] = { OP_CLIP, x + 2, y + 1, x + fw - 2, y + fh - 1 }
    if disp == "" and not focused and hint then
        r_text(L, x + fp.x, multi and (y + fp.y) or (y + (fh - lh) * 0.5), hint, col(ImGuiCol.TextDisabled))
    elseif not multi then
        local tx, ty = x + fp.x, y + (fh - lh) * 0.5
        if focused then
            local caret = ui.caret()
            local cw = text_w(disp:sub(1, caret))
            local ox = min(0, (fw - fp.x * 2) - cw - 2)
            local s1, s2 = ui.selection()
            if s1 and s2 and s1 ~= s2 then
                local a, b = min(s1, s2), max(s1, s2)
                r_rect(L, tx + text_w(disp:sub(1, a)) + ox, ty, tx + text_w(disp:sub(1, b)) + ox, ty + lh, col(ImGuiCol.TextSelectedBg))
            end
            r_text(L, tx + ox, ty, disp, col(ImGuiCol.Text))
            if floor(now() * 2) % 2 == 0 then
                r_line(L, tx + ox + cw + 1, ty, tx + ox + cw + 1, ty + lh, col(ImGuiCol.InputTextCursor), 1)
            end
        else
            r_text(L, tx, ty, disp, col(ImGuiCol.Text))
        end
    else
        -- multiline: per-line layout, a scroll offset that follows the caret, and the wheel while hovered
        local st = S.storage["ml:" .. id]
        if type(st) ~= "table" then st = { sy = 0, sx = 0 }; S.storage["ml:" .. id] = st end
        local lines, starts = {}, {}
        local pos = 0
        for ln in (disp .. "\n"):gmatch("(.-)\n") do
            lines[#lines + 1] = ln
            starts[#starts + 1] = pos
            pos = pos + #ln + 1
        end
        local inner_h, inner_w = fh - fp.y * 2, fw - fp.x * 2
        local total_h = #lines * lh
        if hov then
            local wh = input.mouse_wheel()
            if wh ~= 0 and total_h > inner_h then st.sy = st.sy - wh * lh * 3; S.wheel_claim = S.frame end
        end
        local cl, cc = 1, 0
        local a, b
        if focused then
            local caret = ui.caret()
            for i = #lines, 1, -1 do if caret >= starts[i] then cl, cc = i, caret - starts[i] break end end
            if S.text_caret_prev ~= caret then
                local cy = (cl - 1) * lh
                if cy < st.sy then st.sy = cy elseif cy + lh > st.sy + inner_h then st.sy = cy + lh - inner_h end
                local cx = text_w(lines[cl]:sub(1, cc))
                if cx < st.sx then st.sx = cx elseif cx > st.sx + inner_w - 4 then st.sx = cx - inner_w + 4 end
                S.text_caret_prev = caret
            end
            local s1, s2 = ui.selection()
            if s1 and s2 and s1 ~= s2 then a, b = min(s1, s2), max(s1, s2) end
        end
        st.sy = clamp(st.sy, 0, max(0, total_h - inner_h))
        st.sx = max(0, st.sx)
        local tx, ty = x + fp.x - st.sx, y + fp.y - st.sy
        for i = 1, #lines do
            local ly = ty + (i - 1) * lh
            if ly + lh >= y and ly <= y + fh then
                local ln = lines[i]
                if a then
                    local ls, le = starts[i], starts[i] + #ln
                    if b > ls and a <= le then
                        local p1, p2 = max(a, ls) - ls, min(b, le) - ls
                        local x1 = tx + text_w(ln:sub(1, p1))
                        local x2 = tx + text_w(ln:sub(1, p2)) + ((b > le) and lh * 0.3 or 0)
                        r_rect(L, x1, ly, x2, ly + lh, col(ImGuiCol.TextSelectedBg))
                    end
                end
                r_text(L, tx, ly, ln, col(ImGuiCol.Text))
            end
        end
        if focused and floor(now() * 2) % 2 == 0 then
            local cx = tx + text_w(lines[cl]:sub(1, cc))
            local cy = ty + (cl - 1) * lh
            r_line(L, cx + 1, cy, cx + 1, cy + lh, col(ImGuiCol.InputTextCursor), 1)
        end
        -- thin scroll indicator when the text is taller than the box
        if total_h > inner_h then
            local len = fh - 4
            local gl = max(8, len * inner_h / total_h)
            local gy = y + 2 + (len - gl) * (st.sy / max(1, total_h - inner_h))
            r_rect(L, x + fw - 5, gy, x + fw - 2, gy + gl, col(ImGuiCol.ScrollbarGrab), 2)
        end
    end
    L[#L + 1] = { OP_UNCLIP }
    if S.last then S.last.hovered = hov end
    return value, changed, committed, hov, focused
end

-- InputText(label, text, buf_size[, flags]) -> text, changed
function im.InputText(label, value, buf_size, flags)
    local w = S.cur
    if not w then return value, false end
    if type(buf_size) ~= "number" then flags, buf_size = buf_size, nil end
    flags = flags or 0
    local disp, idl = parse_label(label)
    local id = get_id(idl)
    local x, y, iw, fh = labelled_frame(disp)
    value = tostring(value == nil and "" or value)
    local nv, changed, _, hov, foc = text_field(id, x, y, iw, fh, value, flags)
    if buf_size and buf_size > 0 and #nv >= buf_size then nv = nv:sub(1, buf_size - 1) end
    finish_labelled(w, x, y, iw, fh, disp)
    local Lst = S.last
    Lst.id, Lst.hovered, Lst.active, Lst.edited = id, hov, foc, changed
    return nv, changed
end
function im.InputTextWithHint(label, hint, value, buf_size, flags)
    local w = S.cur
    if not w then return value, false end
    if type(buf_size) ~= "number" then flags, buf_size = buf_size, nil end
    flags = flags or 0
    local disp, idl = parse_label(label)
    local id = get_id(idl)
    local x, y, iw, fh = labelled_frame(disp)
    value = tostring(value == nil and "" or value)
    local nv, changed, _, hov, foc = text_field(id, x, y, iw, fh, value, flags, tostring(hint or ""))
    if buf_size and buf_size > 0 and #nv >= buf_size then nv = nv:sub(1, buf_size - 1) end
    finish_labelled(w, x, y, iw, fh, disp)
    S.last.id, S.last.hovered, S.last.active, S.last.edited = id, hov, foc, changed
    return nv, changed
end
-- InputTextMultiline(label, text, buf_size[, w, h, flags]) -> text, changed. Enter inserts a newline;
-- Ctrl+Enter (or clicking away) finishes, unless CtrlEnterForNewLine swaps the two.
function im.InputTextMultiline(label, value, buf_size, sx, sy, flags)
    local w = S.cur
    if not w then return value, false end
    if type(sx) == "table" then flags, sx, sy = sy, sx.x or sx[1], sx.y or sx[2] end
    local disp, idl = parse_label(label)
    local id = get_id(idl)
    local x, y = item_pos()
    local fp = S.style.FramePadding
    local fw
    if sx and sx > 0 then fw = sx elseif sx and sx < 0 then fw = max(20, avail_w() + sx) else fw = calc_item_w() end
    local fh = (sy and sy > 0) and sy or (font_h() * 8 + fp.y * 2)
    if sy and sy < 0 then fh = max(font_h() + fp.y * 2, w.clip[4] - y + sy) end
    value = tostring(value == nil and "" or value)
    local nv, changed, _, hov, foc = text_field(id, x, y, fw, fh, value, flags or 0, nil, true)
    if buf_size and buf_size > 0 and #nv >= buf_size then nv = nv:sub(1, buf_size - 1) end
    local tw = 0
    if disp ~= "" then
        r_text(w.root.cmds, x + fw + S.style.ItemInnerSpacing.x, y + fp.y, disp, col(ImGuiCol.Text))
        tw = S.style.ItemInnerSpacing.x + text_w(disp)
    end
    item_add(x, y, fw + tw, fh)
    S.last.id, S.last.hovered, S.last.active, S.last.edited = id, hov, foc, changed
    return nv, changed
end

local function input_number(label, v, step, step_fast, fmt, flags, is_int)
    local w = S.cur
    if not w then return v, false end
    flags = flags or 0
    local disp, idl = parse_label(label)
    local id = get_id(idl)
    local x, y, iw, fh = labelled_frame(disp)
    v = v or 0
    local bs = (step and step ~= 0) and fh or 0
    local fw = max(10, iw - (bs > 0 and (bs * 2 + S.style.ItemInnerSpacing.x * 2) or 0))
    local shown = fmt_value(fmt, v, is_int)
    local focused = S.text_id == id and ui.focused() == id
    local ns, _, committed, hov, foc = text_field(id, x, y, fw, fh, focused and shown or shown,
        flags | (is_int and 0 or ImGuiInputTextFlags.CharsDecimal) | ImGuiInputTextFlags.EnterReturnsTrue)
    local changed = false
    if committed or (focused and S.text_id ~= id) then
        local n = tonumber(ns)
        if n then
            n = is_int and floor(n + 0.5) or n
            if n ~= v then v = n; changed = true end
        end
    end
    if bs > 0 then
        local L = w.root.cmds
        local bx = x + fw + S.style.ItemInnerSpacing.x
        seed_push(tostring(id))
        for i = 1, 2 do
            local bid = get_id(i == 1 and "-" or "+")
            local pressed, bh, held = button_behavior(bid, bx, y, bx + bs, y + fh)
            r_rect(L, bx, y, bx + bs, y + fh, frame_colors(held, bh, ImGuiCol.Button, ImGuiCol.ButtonHovered, ImGuiCol.ButtonActive), S.style.FrameRounding)
            local c = col(ImGuiCol.Text)
            local cx, cy = bx + bs * 0.5, y + fh * 0.5
            r_line(L, cx - bs * 0.2, cy, cx + bs * 0.2, cy, c, 1.5)
            if i == 2 then r_line(L, cx, cy - bs * 0.2, cx, cy + bs * 0.2, c, 1.5) end
            if pressed then
                local st = (input.key_down(0x11) and step_fast) or step
                v = v + (i == 1 and -st or st)
                if not is_int then v = round_to_format(v, fmt or "%.3f") end
                changed = true
            end
            bx = bx + bs + S.style.ItemInnerSpacing.x
        end
        seed_pop()
    end
    finish_labelled(w, x, y, iw, fh, disp)
    S.last.id, S.last.hovered, S.last.active, S.last.edited = id, hov, foc, changed
    return v, changed
end
function im.InputInt(label, v, step, step_fast, flags) return input_number(label, v, step == nil and 1 or step, step_fast or 100, "%d", flags, true) end
function im.InputFloat(label, v, step, step_fast, fmt, flags)
    if type(fmt) == "number" then flags, fmt = fmt, nil end
    return input_number(label, v, step or 0, step_fast or 0, fmt or "%.3f", flags, false)
end
function im.InputDouble(label, v, step, step_fast, fmt, flags) return im.InputFloat(label, v, step, step_fast, fmt or "%.6f", flags) end
function im.InputInt2(l, v, f) return multi_scalar(function(lb, x) return im.InputInt(lb, x, 0) end, l, v, 2) end
function im.InputInt3(l, v, f) return multi_scalar(function(lb, x) return im.InputInt(lb, x, 0) end, l, v, 3) end
function im.InputInt4(l, v, f) return multi_scalar(function(lb, x) return im.InputInt(lb, x, 0) end, l, v, 4) end
function im.InputFloat2(l, v, fmt) return multi_scalar(function(lb, x) return im.InputFloat(lb, x, 0, 0, fmt) end, l, v, 2) end
function im.InputFloat3(l, v, fmt) return multi_scalar(function(lb, x) return im.InputFloat(lb, x, 0, 0, fmt) end, l, v, 3) end
function im.InputFloat4(l, v, fmt) return multi_scalar(function(lb, x) return im.InputFloat(lb, x, 0, 0, fmt) end, l, v, 4) end

-- ── popups ───────────────────────────────────────────────────────────────────

local function popup_id(str) return get_id(str) end

function im.OpenPopup(str, flags)
    local id = type(str) == "number" and str or popup_id(str)
    local lvl = S.popup_depth + 1
    local cur = S.popups[lvl]
    if cur and cur.id == id and has(flags, ImGuiPopupFlags.NoReopen) then return end
    for i = #S.popups, lvl, -1 do S.popups[i] = nil end
    S.popups[lvl] = { id = id, x = S.mx, y = S.my, opened_frame = S.frame, fresh = true, parent_win = S.cur and S.cur.root }
end
function im.OpenPopupOnItemClick(str, flags)
    local btn = (flags or 1) & 0x1F
    if S.last.hovered and S.clicked[btn] then im.OpenPopup(str or "") end
end
function im.IsPopupOpen(str, flags)
    if has(flags, ImGuiPopupFlags.AnyPopupId) then return #S.popups > 0 end
    local id = popup_id(str)
    for i = 1, #S.popups do if S.popups[i].id == id then return true end end
    return false
end
function im.CloseCurrentPopup()
    local lvl = S.popup_depth
    if lvl > 0 then for i = #S.popups, lvl, -1 do S.popups[i] = nil end end
end

local function begin_popup_ex(id, flags, modal, name, p_open)
    local lvl = S.popup_depth + 1
    local p = S.popups[lvl]
    if not p or p.id ~= id then return false end
    p.modal = modal
    local w = get_window("popup:" .. tostring(id), "popup")
    w.modal = modal
    p.win = w
    if modal then
        if not w.user_moved and not S.next_win.pos then
            S.next_win.pos = { ctx.screen_w() * 0.5, ctx.screen_h() * 0.5 }
            S.next_win.pivot_x, S.next_win.pivot_y = 0.5, 0.5
        end
    elseif not S.next_win.pos then
        if p.anchor then S.next_win.pos = { p.anchor[1], p.anchor[2] }
        elseif p.fresh then S.next_win.pos = { p.x, p.y } end
    end
    if p.fresh then
        p.fresh = false
        w.user_moved = nil
    end
    if p.min_w then w.min_w = p.min_w end
    S.popup_depth = lvl
    local win = begin_window(name or "##popup", (flags or 0) | (modal and 0 or ImGuiWindowFlags.NoTitleBar), "popup", p_open, tostring(id))
    if win.close_req then
        end_window()
        S.popup_depth = lvl - 1
        for i = #S.popups, lvl, -1 do S.popups[i] = nil end
        return false
    end
    return true
end

local function end_popup()
    local w = S.cur
    if not w or not w.is_popup then return end
    end_window()
    S.popup_depth = max(0, S.popup_depth - 1)
end

function im.BeginPopup(str, flags) return begin_popup_ex(popup_id(str), flags, false) end
-- BeginPopupModal(name[, open, flags]) -> draw | open, draw
function im.BeginPopupModal(name, a, b)
    local p_open, flags = nil, 0
    if type(a) == "boolean" then p_open, flags = a, b or 0 elseif a == nil then flags = b or 0 else flags = a end
    local id = popup_id(name)
    local was_open = im.IsPopupOpen(name)
    local ok = begin_popup_ex(id, flags | ImGuiWindowFlags.NoCollapse, true, tostring(name), p_open)
    if p_open ~= nil then
        if was_open and not ok then return false, false end   -- closed with the title-bar X
        return p_open, ok
    end
    return ok
end
function im.EndPopup() end_popup() end
function im.BeginPopupContextItem(str, flags)
    str = str or ("##ctx" .. tostring(S.last.id))
    local btn = (flags == nil) and 1 or (flags & 0x1F)
    if S.last.hovered and S.clicked[btn] then im.OpenPopup(str) end
    return im.BeginPopup(str)
end
function im.BeginPopupContextWindow(str, flags)
    str = str or "##ctxwin"
    local btn = (flags == nil) and 1 or (flags & 0x1F)
    if S.cur and S.hover_root == S.cur.root and S.clicked[btn] then im.OpenPopup(str) end
    return im.BeginPopup(str)
end
function im.BeginPopupContextVoid(str, flags)
    str = str or "##ctxvoid"
    local btn = (flags == nil) and 1 or (flags & 0x1F)
    if not S.hover_root and S.input_ok and S.clicked[btn] then im.OpenPopup(str) end
    return im.BeginPopup(str)
end

-- ── tooltips ─────────────────────────────────────────────────────────────────

function im.BeginTooltip()
    S.next_win.pos, S.next_win.pivot_x, S.next_win.pivot_y = { S.mx + 16, S.my + 14 }, 0, 0
    local w = begin_window("##tooltip", ImGuiWindowFlags.NoTitleBar | ImGuiWindowFlags.AlwaysAutoResize, "tooltip")
    S.tooltip = w
    return true
end
function im.EndTooltip() if S.cur and S.cur.kind == "tooltip" then end_window() end end
function im.SetTooltip(...)
    local n = select("#", ...)
    local s = ...
    if n > 1 then local ok, r = pcall(string.format, ...); if ok then s = r end end
    im.BeginTooltip(); im.TextUnformatted(s); im.EndTooltip()
end
function im.BeginItemTooltip() if im.IsItemHovered() then return im.BeginTooltip() end return false end
function im.SetItemTooltip(...) if im.IsItemHovered() then im.SetTooltip(...) end end

-- ── combo / selectable / listbox ─────────────────────────────────────────────

function im.Selectable(label, selected, flags, sx, sy)
    local w = S.cur
    if not w then return false end
    if type(selected) == "number" then flags, sx, sy, selected = selected, flags, sx, nil end
    if type(sx) == "table" then sx, sy = sx.x or sx[1], sx.y or sx[2] end
    flags = flags or 0
    local disp, idl = parse_label(label)
    local id = get_id(idl)
    local x, y = item_pos()
    local fh = font_h()
    local hw = (sx and sx > 0) and sx or (w.dc.right - x)
    if w.dc.col_x2 then hw = (sx and sx > 0) and sx or (w.dc.col_x2 - x) end
    local hh = (sy and sy > 0) and sy or fh
    local sp = S.style.ItemSpacing.y * 0.5
    local dis = has(flags, ImGuiSelectableFlags.Disabled)
    if dis then S.disabled = S.disabled + 1 end
    local t = S.table
    local span = t and t.in_cell and has(flags, ImGuiSelectableFlags.SpanAllColumns)
    local bx1, bx2, row_clip, cell_clip = x - 2, x + hw, nil, nil
    if span then
        local B = t.base_clip
        row_clip = { B[1], (t.row < t.fr) and B[2] or max(B[2], t.body_top), B[3], B[4] }
        cell_clip = w.clip
        bx1, bx2 = t.x, t.x + max(t.w, t.total_w or 0)
        w.clip = row_clip
    end
    local pressed, hov, held = button_behavior(id, bx1, y - sp, bx2, y + hh + sp, nil, has(flags, ImGuiSelectableFlags.AllowOverlap))
    if span then w.clip = cell_clip end
    if has(flags, ImGuiSelectableFlags.AllowDoubleClick) and hov and S.dbl then pressed = true end
    local L = w.root.cmds
    if selected or hov or held or has(flags, ImGuiSelectableFlags.Highlight) then
        local c = held and ImGuiCol.HeaderActive or (hov and ImGuiCol.HeaderHovered or ImGuiCol.Header)
        if span then
            L[#L + 1] = { OP_UNCLIP }
            r_clip(L, row_clip[1], row_clip[2], row_clip[3], row_clip[4])
            r_rect(L, bx1, y - sp, bx2, y + hh + sp, col(c))
            L[#L + 1] = { OP_UNCLIP }
            r_clip(L, cell_clip[1], cell_clip[2], cell_clip[3], cell_clip[4])
        else
            r_rect(L, bx1, y - sp, bx2, y + hh + sp, col(c), S.style.FrameRounding * 0.5)
        end
    end
    local al = S.style.SelectableTextAlign
    r_text(L, x + (hw - text_w(disp)) * al.x, y + (hh - fh) * max(al.y, 0), disp, col(ImGuiCol.Text))
    item_add(x, y, (sx and sx > 0) and sx or text_w(disp), hh)
    if dis then S.disabled = S.disabled - 1 end
    S.last.id, S.last.hovered, S.last.clicked, S.last.active = id, hov, pressed, held
    if pressed and S.popup_depth > 0 and has(S.iflags, ImGuiItemFlags.AutoClosePopups)
       and not has(flags, ImGuiSelectableFlags.NoAutoClosePopups) and S.cur.is_popup then
        im.CloseCurrentPopup()
    end
    return pressed
end

function im.BeginCombo(label, preview, flags)
    local w = S.cur
    if not w then return false end
    flags = flags or 0
    local disp, idl = parse_label(label)
    local id = get_id(idl)
    local x, y, iw, fh = labelled_frame(disp)
    preview = preview ~= nil and tostring(preview) or ""
    if has(flags, ImGuiComboFlags.WidthFitPreview) then iw = text_w(preview) + S.style.FramePadding.x * 2 + fh end
    local pid = ui.hash(seed() .. "\31##combo_" .. idl)
    local open = false
    for i = 1, #S.popups do if S.popups[i].id == pid then open = true end end
    local pressed, hov, held = button_behavior(id, x, y, x + iw, y + fh, true)
    local L = w.root.cmds
    r_rect(L, x, y, x + iw, y + fh, frame_colors(held or open, hov, ImGuiCol.FrameBg, ImGuiCol.FrameBgHovered, ImGuiCol.FrameBgActive), S.style.FrameRounding)
    if not has(flags, ImGuiComboFlags.NoArrowButton) then
        r_rect(L, x + iw - fh, y, x + iw, y + fh, col((hov or open) and ImGuiCol.ButtonHovered or ImGuiCol.Button), S.style.FrameRounding)
        arrow(L, x + iw - fh * 0.5, y + fh * 0.5, fh * 0.16, ImGuiDir.Down, col(ImGuiCol.Text))
    end
    if not has(flags, ImGuiComboFlags.NoPreview) then
        L[#L + 1] = { OP_CLIP, x, y, x + iw - fh, y + fh }
        r_text(L, x + S.style.FramePadding.x, y + S.style.FramePadding.y, preview, col(ImGuiCol.Text))
        L[#L + 1] = { OP_UNCLIP }
    end
    finish_labelled(w, x, y, iw, fh, disp)
    S.last.id, S.last.hovered, S.last.clicked = id, hov, pressed
    if pressed then
        if open then
            for i = #S.popups, 1, -1 do if S.popups[i].id == pid then for j = #S.popups, i, -1 do S.popups[j] = nil end break end end
            open = false
        elseif not S.just_closed[pid] then
            im.OpenPopup(pid)
            open = true
        end
    end
    if not open then return false end
    local lvl = S.popup_depth + 1
    local p = S.popups[lvl]
    if not p or p.id ~= pid then return false end
    p.anchor = { x, y + fh + 2 }
    p.min_w = iw
    local items = 8
    if has(flags, ImGuiComboFlags.HeightSmall) then items = 4
    elseif has(flags, ImGuiComboFlags.HeightLarge) then items = 20
    elseif has(flags, ImGuiComboFlags.HeightLargest) then items = 1000 end
    local pw = get_window("popup:" .. pid, "popup")
    pw.max_h = items * (font_h() + S.style.ItemSpacing.y) + S.style.WindowPadding.y * 2
    return begin_popup_ex(pid, ImGuiWindowFlags.NoTitleBar, false)
end
function im.EndCombo() end_popup() end

local function items_of(items, count)
    if type(items) == "string" then
        local t = {}
        for s in (items .. "\0"):gmatch("([^\0]*)\0") do if s ~= "" then t[#t + 1] = s end end
        return t, #t
    end
    items = items or {}
    return items, count or #items
end

-- Combo(label, current, items, count[, popup_max_height]) -> current, clicked   (0-based index)
function im.Combo(label, current, items, count, max_h)
    local list_, n = items_of(items, count)
    current = current or 0
    local preview = list_[current + 1] or ""
    local changed = false
    if im.BeginCombo(label, preview, 0) then
        for i = 1, n do
            local sel = (i - 1) == current
            if im.Selectable(tostring(list_[i]) .. "##" .. i, sel) then
                if current ~= i - 1 then changed = true end
                current = i - 1
            end
            if sel then im.SetItemDefaultFocus() end
        end
        im.EndCombo()
    end
    return current, changed
end

-- ListBox(label, current, items, count[, height_in_items]) -> current, clicked
function im.BeginListBox(label, sx, sy)
    local w = S.cur
    if not w then return false end
    if type(sx) == "table" then sx, sy = sx.x or sx[1], sx.y or sx[2] end
    local disp, idl = parse_label(label)
    local iw = (sx and sx > 0) and sx or calc_item_w()
    local ih = (sy and sy > 0) and sy or (font_h() + S.style.ItemSpacing.y) * 7.25 + S.style.FramePadding.y * 2
    im.BeginGroup()
    S.lb_label = S.lb_label or {}
    S.lb_label[#S.lb_label + 1] = disp
    im.BeginChild(idl, iw, ih, ImGuiChildFlags.FrameStyle)
    return true
end
function im.EndListBox()
    im.EndChild()
    local disp = S.lb_label and S.lb_label[#S.lb_label]
    if S.lb_label then S.lb_label[#S.lb_label] = nil end
    if disp and disp ~= "" then im.SameLine(0, S.style.ItemInnerSpacing.x); im.TextUnformatted(disp) end
    im.EndGroup()
end
function im.ListBox(label, current, items, count, height_items)
    local list_, n = items_of(items, count)
    current = current or 0
    local changed = false
    local h = height_items and height_items > 0 and ((font_h() + S.style.ItemSpacing.y) * height_items + S.style.FramePadding.y * 2) or nil
    if im.BeginListBox(label, 0, h) then
        for i = 1, n do
            if im.Selectable(tostring(list_[i]) .. "##" .. i, (i - 1) == current) then
                if current ~= i - 1 then changed = true end
                current = i - 1
            end
        end
        im.EndListBox()
    end
    return current, changed
end

-- ── trees / headers / tabs ───────────────────────────────────────────────────

local function tree_open_state(id, flags)
    local st = S.storage[id]
    if S.next_open then
        local o, cond = S.next_open[1], S.next_open[2]
        S.next_open = nil
        if st == nil or not cond or has(cond, ImGuiCond.Always) then st = o end
    end
    if st == nil then st = has(flags, ImGuiTreeNodeFlags.DefaultOpen) end
    S.storage[id] = st
    return st
end

local function tree_node_behavior(label, flags)
    local w = S.cur
    if not w then return false end
    flags = flags or 0
    local disp, idl = parse_label(label)
    local id = get_id(idl)
    local open = tree_open_state(id, flags)
    local leaf = has(flags, ImGuiTreeNodeFlags.Leaf)
    local framed = has(flags, ImGuiTreeNodeFlags.Framed)
    local x, y = item_pos()
    local fh = font_h()
    local h = framed and frame_h() or ((has(flags, ImGuiTreeNodeFlags.FramePadding)) and frame_h() or fh)
    local x1 = framed and (w.dc.start_x + w.dc.indent) or x
    local hw = (framed or has(flags, ImGuiTreeNodeFlags.SpanAvailWidth) or has(flags, ImGuiTreeNodeFlags.SpanFullWidth))
        and (w.dc.right - x1) or (fh + S.style.FramePadding.x * 2 + text_w(disp))
    local pressed, hov, held = button_behavior(id, x1, y, x1 + hw, y + h, nil, has(flags, ImGuiTreeNodeFlags.AllowOverlap))
    if pressed and not leaf then
        local toggle = true
        if has(flags, ImGuiTreeNodeFlags.OpenOnArrow) then toggle = S.mx < x1 + fh + S.style.FramePadding.x end
        if has(flags, ImGuiTreeNodeFlags.OpenOnDoubleClick) then toggle = toggle and S.dbl end
        if toggle then open = not open; S.storage[id] = open end
    end
    local L = w.root.cmds
    if framed then
        r_rect(L, x1, y, x1 + hw, y + h, frame_colors(held, hov, ImGuiCol.Header, ImGuiCol.HeaderHovered, ImGuiCol.HeaderActive), S.style.FrameRounding)
    elseif hov or held or has(flags, ImGuiTreeNodeFlags.Selected) then
        local c = held and ImGuiCol.HeaderActive or (hov and ImGuiCol.HeaderHovered or ImGuiCol.Header)
        r_rect(L, x1, y, x1 + hw, y + h, col(c), S.style.FrameRounding * 0.5)
    end
    local ax = x1 + (framed and S.style.FramePadding.x or 0) + fh * 0.5
    local ay = y + h * 0.5
    if has(flags, ImGuiTreeNodeFlags.Bullet) then
        r_circle(L, ax, ay, fh * 0.16, col(ImGuiCol.Text), true)
    elseif not leaf then
        arrow(L, ax, ay, fh * 0.18, open and ImGuiDir.Down or ImGuiDir.Right, col(ImGuiCol.Text))
    end
    r_text(L, ax + fh * 0.5 + S.style.ItemInnerSpacing.x, y + (h - fh) * 0.5, disp, col(ImGuiCol.Text))
    item_add(x1, y, (ax - x1) + fh * 0.5 + S.style.ItemInnerSpacing.x + text_w(disp) + S.style.FramePadding.x, h)
    S.last.id, S.last.hovered, S.last.clicked, S.last.active, S.last.toggled = id, hov, pressed, held, pressed and not leaf
    if (open or leaf) and not has(flags, ImGuiTreeNodeFlags.NoTreePushOnOpen) then
        im.Indent()
        seed_push(tostring(id))
        w.dc.tree_depth = (w.dc.tree_depth or 0) + 1
    end
    return open or leaf
end

function im.TreeNode(label, ...) return tree_node_behavior(label, 0) end
function im.TreeNodeEx(label, flags) return tree_node_behavior(label, flags or 0) end
function im.TreePush(str)
    if not S.cur then return end
    im.Indent()
    seed_push(seed() .. "/" .. tostring(str or "#TreePush"))
    S.cur.dc.tree_depth = (S.cur.dc.tree_depth or 0) + 1
end
function im.TreePop()
    local w = S.cur
    if not w or (w.dc.tree_depth or 0) <= 0 then return end
    w.dc.tree_depth = w.dc.tree_depth - 1
    im.Unindent()
    seed_pop()
end
function im.GetTreeNodeToLabelSpacing() return font_h() + S.style.FramePadding.x * 2 end
-- CollapsingHeader(label[, flags]) -> open | CollapsingHeader(label, visible, flags) -> visible, open
function im.CollapsingHeader(label, a, b)
    if type(a) == "boolean" then
        if not a then return false, false end
        local open = tree_node_behavior(label, (b or 0) | ImGuiTreeNodeFlags.CollapsingHeader)
        return true, open
    end
    return tree_node_behavior(label, (a or 0) | ImGuiTreeNodeFlags.CollapsingHeader)
end

function im.BeginTabBar(str, flags)
    local w = S.cur
    if not w then return false end
    local id = get_id(str)
    local x, y = item_pos()
    local fh = frame_h()
    local bar = { id = id, x = x, y = y, cx = x, h = fh, flags = flags or 0, parent = S.tab_bar, seen = {} }
    bar.sel = S.storage[id]
    local L = w.root.cmds
    r_line(L, w.dc.start_x + w.dc.indent, y + fh, w.dc.right, y + fh, col(ImGuiCol.TabSelected), S.style.TabBarBorderSize)
    item_add(x, y, 0, fh + S.style.TabBarBorderSize)
    S.tab_bar = bar
    seed_push(tostring(id))
    return true
end
function im.EndTabBar()
    local bar = S.tab_bar
    if not bar then return end
    -- selected tab vanished: fall back to the first tab next frame
    if bar.sel and not bar.seen[bar.sel] then S.storage[bar.id] = bar.first end
    if not bar.sel then S.storage[bar.id] = bar.first end
    seed_pop()
    S.tab_bar = bar.parent
end

-- BeginTabItem(label[, open, flags]) -> selected | open, selected
function im.BeginTabItem(label, a, b)
    local w, bar = S.cur, S.tab_bar
    local p_open, flags = nil, 0
    if type(a) == "boolean" then p_open, flags = a, b or 0 else flags = a or 0 end
    if not w or not bar then if p_open ~= nil then return p_open, false end return false end
    if p_open == false then return false, false end
    local disp, idl = parse_label(label)
    local id = get_id(idl)
    if bar.closed and bar.closed[id] then
        if p_open ~= nil then return false, false end
        return false
    end
    bar.seen[id] = true
    bar.first = bar.first or id
    if has(flags, ImGuiTabItemFlags.SetSelected) then bar.sel = id; S.storage[bar.id] = id end
    if not bar.sel then bar.sel = id; S.storage[bar.id] = id end
    local fp = S.style.FramePadding
    local close_w = p_open ~= nil and font_h() or 0
    local tw = text_w(disp) + fp.x * 2 + close_w
    local x, y, h = bar.cx, bar.y, bar.h
    local pressed, hov, held = button_behavior(id, x, y, x + tw, y + h)
    local closed = false
    if p_open ~= nil and hov and S.clicked[2] then closed = true end
    if pressed then
        if p_open ~= nil and S.mx >= x + tw - close_w - fp.x * 0.5 then closed = true
        else bar.sel = id; S.storage[bar.id] = id end
    end
    local sel = bar.sel == id
    local L = w.root.cmds
    local c = sel and ImGuiCol.TabSelected or (hov and ImGuiCol.TabHovered or ImGuiCol.Tab)
    r_rect(L, x, y, x + tw, y + h, col(c), S.style.TabRounding)
    if sel then
        r_rect(L, x, y + h - S.style.TabRounding, x + tw, y + h, col(c))
        r_line(L, x + 2, y + 1, x + tw - 2, y + 1, col(ImGuiCol.TabSelectedOverline), S.style.TabBarOverlineSize)
    end
    r_text(L, x + fp.x, y + fp.y, disp, col(ImGuiCol.Text))
    if close_w > 0 and (hov or sel) then
        local cx, cy, s = x + tw - fp.x - close_w * 0.5, y + h * 0.5, close_w * 0.22
        r_line(L, cx - s, cy - s, cx + s, cy + s, col(ImGuiCol.Text), 1.4)
        r_line(L, cx + s, cy - s, cx - s, cy + s, col(ImGuiCol.Text), 1.4)
    end
    bar.cx = x + tw + S.style.ItemInnerSpacing.x
    if bar.cx > w.dc.max_x then w.dc.max_x = bar.cx end
    S.last.id, S.last.hovered, S.last.clicked = id, hov, pressed
    S.last.x1, S.last.y1, S.last.x2, S.last.y2 = x, y, x + tw, y + h
    if sel then seed_push(tostring(id)); bar.pushed = (bar.pushed or 0) + 1 end
    if p_open ~= nil then return not closed, sel and not closed end
    return sel
end
function im.EndTabItem()
    local bar = S.tab_bar
    if bar and (bar.pushed or 0) > 0 then bar.pushed = bar.pushed - 1; seed_pop() end
end
function im.TabItemButton(label, flags)
    local bar = S.tab_bar
    if not bar or not S.cur then return false end
    local disp, idl = parse_label(label)
    local id = get_id(idl)
    local fp = S.style.FramePadding
    local tw = text_w(disp) + fp.x * 2
    local x, y, h = bar.cx, bar.y, bar.h
    local pressed, hov = button_behavior(id, x, y, x + tw, y + h)
    local L = S.cur.root.cmds
    r_rect(L, x, y, x + tw, y + h, col(hov and ImGuiCol.TabHovered or ImGuiCol.Tab), S.style.TabRounding)
    r_text(L, x + fp.x, y + fp.y, disp, col(ImGuiCol.Text))
    bar.cx = x + tw + S.style.ItemInnerSpacing.x
    return pressed
end
-- SetTabItemClosed(label): call between BeginTabBar and the tab submissions to drop a tab this frame
function im.SetTabItemClosed(label)
    local bar = S.tab_bar
    if not bar or not S.cur then return end
    local _, idl = parse_label(label or "")
    bar.closed = bar.closed or {}
    bar.closed[get_id(idl)] = true
end

-- ── menus ────────────────────────────────────────────────────────────────────

function im.BeginMenuBar()
    local w = S.cur
    if not w or not w.menubar or w.collapsed then return false end
    local th = w.has_title and title_h() or 0
    local dc = w.dc
    S.menubar_saved = { cx = dc.cx, cy = dc.cy, line_top = dc.line_top, line_h = dc.line_h, same = dc.same, max_y = dc.max_y, clip = w.clip }
    w.clip = { w.x, w.y + th, w.x + w.w, w.y + th + w.menubar_h }
    w.root.cmds[#w.root.cmds + 1] = { OP_UNCLIP }
    w.root.cmds[#w.root.cmds + 1] = { OP_CLIP, w.clip[1], w.clip[2], w.clip[3], w.clip[4] }
    S.menubar = { x = w.x + S.style.WindowPadding.x, y = w.y + th, h = w.menubar_h }
    seed_push(seed() .. "/##menubar")
    return true
end
function im.EndMenuBar()
    local w = S.cur
    local s = S.menubar_saved
    if not w or not s then return end
    local dc = w.dc
    dc.cx, dc.cy, dc.line_top, dc.line_h, dc.same, dc.max_y = s.cx, s.cy, s.line_top, s.line_h, s.same, s.max_y
    w.clip = s.clip
    w.root.cmds[#w.root.cmds + 1] = { OP_UNCLIP }
    w.root.cmds[#w.root.cmds + 1] = { OP_CLIP, w.clip[1], w.clip[2], w.clip[3], w.clip[4] }
    S.menubar, S.menubar_saved = nil, nil
    seed_pop()
end
-- Full-width menu bar pinned to the top of the screen, drawn above every other window.
function im.BeginMainMenuBar()
    local sw, fh = ctx.screen_w(), frame_h()
    im.SetNextWindowPos(0, 0, ImGuiCond.Always)
    im.SetNextWindowSize(sw, fh, ImGuiCond.Always)
    S.next_win.cons = { sw, fh, sw, fh }
    im.PushStyleVar(ImGuiStyleVar.WindowRounding, 0)
    im.PushStyleVar(ImGuiStyleVar.WindowBorderSize, 0)
    local F = ImGuiWindowFlags
    local vis = im.Begin("##MainMenuBar", F.NoTitleBar | F.NoResize | F.NoMove | F.NoScrollbar | F.NoCollapse
        | F.NoSavedSettings | F.MenuBar | F.NoScrollWithMouse)
    im.PopStyleVar(2)
    local w = S.windows["root:##MainMenuBar"]
    if w then w.topmost = true end
    if not vis then im.End(); return false end
    if not im.BeginMenuBar() then im.End(); return false end
    return true
end
function im.EndMainMenuBar()
    im.EndMenuBar()
    im.End()
end

function im.BeginMenu(label, enabled)
    local w = S.cur
    if not w then return false end
    if enabled == nil then enabled = true end
    local disp, idl = parse_label(label)
    local id = get_id(idl)
    local pid = ui.hash(seed() .. "\31##menu_" .. idl)
    local fp = S.style.FramePadding
    local fh = font_h()
    local x, y, bw, bh, in_bar
    if S.menubar and not w.is_popup then
        in_bar = true
        x, y, bh = S.menubar.x, S.menubar.y, S.menubar.h
        bw = text_w(disp) + fp.x * 2
        S.menubar.x = x + bw
    else
        x, y = item_pos()
        bw, bh = w.dc.right - x, fh
    end
    if not enabled then S.disabled = S.disabled + 1 end
    local pressed, hov = button_behavior(id, x, y, x + bw, y + bh, true)
    if not enabled then S.disabled = S.disabled - 1 end
    local lvl = S.popup_depth + 1
    local open = S.popups[lvl] and S.popups[lvl].id == pid
    if enabled then
        if in_bar then
            if pressed then
                if open then S.popups[lvl] = nil; open = false
                elseif not S.just_closed[pid] then im.OpenPopup(pid); open = true end
            elseif hov and #S.popups >= lvl and not open then
                im.OpenPopup(pid); open = true     -- slide across an open menu bar
            end
        elseif hov and not open then
            im.OpenPopup(pid); open = true
        end
    end
    local L = w.root.cmds
    if open or hov then
        r_rect(L, x, y, x + bw, y + bh, col(open and ImGuiCol.HeaderActive or ImGuiCol.HeaderHovered), S.style.FrameRounding * 0.5)
    end
    if not enabled then S.disabled = S.disabled + 1 end
    r_text(L, x + (in_bar and fp.x or 0), y + (bh - fh) * 0.5, disp, col(ImGuiCol.Text))
    if not in_bar then arrow(L, x + bw - fh * 0.5, y + fh * 0.5, fh * 0.16, ImGuiDir.Right, col(ImGuiCol.Text)) end
    if not enabled then S.disabled = S.disabled - 1 end
    if not in_bar then item_add(x, y, text_w(disp) + fh * 2, bh) end
    S.last.id, S.last.hovered = id, hov
    if not open then return false end
    local p = S.popups[lvl]
    if in_bar then p.anchor = { x, y + bh } else p.anchor = { w.x + w.w - 2, y - S.style.WindowPadding.y } end
    return begin_popup_ex(pid, ImGuiWindowFlags.NoTitleBar, false)
end
function im.EndMenu() end_popup() end

-- MenuItem(label[, shortcut, selected, enabled]) -> clicked | selected, clicked (when `selected` given)
function im.MenuItem(label, shortcut, selected, enabled)
    local w = S.cur
    if not w then return selected ~= nil and selected or false, false end
    if type(shortcut) == "boolean" then shortcut, selected, enabled = nil, shortcut, selected end
    if enabled == nil then enabled = true end
    local disp, idl = parse_label(label)
    local id = get_id(idl)
    local fh = font_h()
    local x, y, bw, in_bar, natural
    if S.menubar and not w.is_popup then
        in_bar = true
        x, y = S.menubar.x, S.menubar.y
        bw = text_w(disp) + S.style.FramePadding.x * 2
        S.menubar.x = x + bw
    else
        x, y = item_pos()
        natural = text_w(disp) + (shortcut and text_w(shortcut) + 30 or 0) + fh * 1.5
        bw = max(w.dc.right - x, natural)
    end
    local bh = in_bar and S.menubar.h or fh
    if not enabled then S.disabled = S.disabled + 1 end
    local pressed, hov, held = button_behavior(id, x, y, x + bw, y + bh)
    local L = w.root.cmds
    if hov or held then r_rect(L, x - 2, y, x + bw, y + bh, col(held and ImGuiCol.HeaderActive or ImGuiCol.HeaderHovered), S.style.FrameRounding * 0.5) end
    local tx = in_bar and (x + S.style.FramePadding.x) or (x + fh * 1.2)
    if selected and not in_bar then
        local c = col(ImGuiCol.CheckMark)
        r_line(L, x + fh * 0.2, y + fh * 0.52, x + fh * 0.42, y + fh * 0.72, c, 2)
        r_line(L, x + fh * 0.42, y + fh * 0.72, x + fh * 0.82, y + fh * 0.3, c, 2)
    end
    r_text(L, tx, y + (bh - fh) * 0.5, disp, col(ImGuiCol.Text))
    if shortcut and not in_bar then
        r_text(L, x + bw - text_w(shortcut) - 4, y, shortcut, col(ImGuiCol.TextDisabled))
    end
    if not in_bar then item_add(x, y, natural, bh) end
    if not enabled then S.disabled = S.disabled - 1 end
    S.last.id, S.last.hovered, S.last.clicked = id, hov, pressed
    if pressed and S.popup_depth > 0 and has(S.iflags, ImGuiItemFlags.AutoClosePopups) then
        for i = #S.popups, 1, -1 do S.popups[i] = nil end    -- a chosen item closes the whole menu chain
    end
    if selected ~= nil then
        if pressed then selected = not selected end
        return selected, pressed
    end
    return pressed
end

-- ── tables ───────────────────────────────────────────────────────────────────
-- Per-table state that must survive frames (user widths, column order, hidden columns, sort specs,
-- measured auto widths) lives in S.storage["tbl:"..id]. Every cell is clipped on its own. ScrollX /
-- ScrollY tables live inside an internal child window; TableSetupScrollFreeze pins the leading rows /
-- columns by laying them out in unscrolled coordinates and clipping the scrolling body to the space
-- they leave free, so the two regions never overlap and need no draw reordering.

local TF, TCF = ImGuiTableFlags, ImGuiTableColumnFlags

local function table_state(id, n)
    local key = "tbl:" .. id
    local ts = S.storage[key]
    if type(ts) ~= "table" or ts.n ~= n then
        ts = { n = n, w = {}, auto_w = {}, order = {}, hidden = {}, seen = {}, sort = nil, h = 0, hover_row = -1 }
        for i = 1, n do ts.order[i] = i end
        S.storage[key] = ts
    end
    return ts
end

function im.BeginTable(str, columns, flags, ox, oy)
    local w = S.cur
    if not w or not columns or columns < 1 then return false end
    if type(ox) == "table" then ox, oy = ox.x or ox[1], ox.y or ox[2] end
    flags = flags or 0
    local id = get_id(str)
    local scroll = has(flags, TF.ScrollX) or has(flags, TF.ScrollY)
    if scroll then
        im.BeginChild("##tbl" .. tostring(str), ox or 0, oy or 0, 0,
            has(flags, TF.ScrollX) and ImGuiWindowFlags.HorizontalScrollbar or 0)
        w = S.cur
    end
    local x, y = item_pos()
    local tw
    if scroll then tw = max(10, w.dc.right - x)
    else tw = (ox and ox > 0) and ox or max(10, w.dc.right - x + (ox or 0)) end
    local t = {
        id = id, n = columns, flags = flags, x = x, y = y, w = tw, total_w = tw,
        cols = {}, setup = 0, col = -1, row = -1, row_top = y, row_bottom = y,
        parent = S.table, win = w, child = scroll,
        saved = { start_x = w.dc.start_x, indent = w.dc.indent, right = w.dc.right, max_x = w.dc.max_x },
        base_clip = { w.clip[1], w.clip[2], w.clip[3], w.clip[4] },
        ts = table_state(id, columns), fr = 0, fc = 0, meas = {}, cell_bg = {}, cell_cmd = {},
        sx = scroll and (w.scroll_x or 0) or 0, sy = scroll and w.scroll or 0, hover_row = -1,
    }
    t.body_top, t.body_left = t.base_clip[2], t.base_clip[1]
    t.acc_max_x = w.dc.max_x
    S.table = t
    seed_push(tostring(id))
    return true
end

local function sort_default_dir(c)
    if has(c.flags, TCF.PreferSortDescending) or has(c.flags, TCF.NoSortAscending) then return ImGuiSortDirection.Descending end
    return ImGuiSortDirection.Ascending
end

local function sort_rebuild(t)
    local ts = t.ts
    local sp = ts.specs or {}
    ts.specs = sp
    sp.Specs = {}
    for k, e in ipairs(ts.sort) do
        local c = t.cols[e.col] or {}
        sp.Specs[k] = { ColumnIndex = e.col - 1, ColumnUserID = c.user_id or 0, SortOrder = k - 1, SortDirection = e.dir }
    end
    sp.SpecsCount = #ts.sort
    sp.SpecsDirty = true
end

local function col_fixed(t, c, i)
    if t.ts.w[i] or has(t.flags, TF.ScrollX) or has(c.flags, TCF.WidthFixed) then return true end
    if has(c.flags, TCF.WidthStretch) then return false end
    local sz = t.flags & (7 << 13)
    return sz == TF.SizingFixedFit or sz == TF.SizingFixedSame
end

local function table_resize_handles(t)
    if not has(t.flags, TF.Resizable) then return end
    local ts = t.ts
    local top = (t.fr > 0) and (t.y + t.sy) or t.y
    local bot = min(top + max(ts.h or 0, frame_h()), t.base_clip[4])
    local saved = S.iflags
    S.iflags = saved | ImGuiItemFlags.NoNav
    for k = 1, #t.vis do
        local i = t.vis[k]
        local c = t.cols[i]
        if not has(c.flags, TCF.NoResize) and not (k == #t.vis and not c.fixed) then
            local hid = get_id("##resize" .. i)
            local x = c.x2
            local _, hov, held = button_behavior(hid, x - 4, top, x + 4, bot, true)
            if hov or held then
                S.cursor = ImGuiMouseCursor.ResizeEW
                t.resize_hl = { x, held }
            end
            if held then
                if S.dbl and S.activated_id == hid and S.activated_frame == S.frame then
                    ts.w[i] = nil                                   -- double-click: back to auto width
                elseif S.mx ~= S.drag_x then
                    ts.w[i] = max(font_h(), S.mx - c.x1)
                end
            end
        end
    end
    S.iflags = saved
end

local function table_layout(t)
    if t.laid then return end
    t.laid = true
    local ts, n = t.ts, t.n
    for i = 1, n do
        local c = t.cols[i]
        if not c then c = { label = "", flags = 0, user_id = 0 }; t.cols[i] = c end
        if not ts.seen[i] then
            ts.seen[i] = true
            if has(c.flags, TCF.DefaultHide) then ts.hidden[i] = true end
        end
    end
    if has(t.flags, TF.Sortable) and not ts.sort then
        ts.sort = {}
        for i = 1, n do
            local c = t.cols[i]
            if has(c.flags, TCF.DefaultSort) and not has(c.flags, TCF.NoSort) then
                ts.sort[#ts.sort + 1] = { col = i, dir = sort_default_dir(c) }
                if not has(t.flags, TF.SortMulti) then break end
            end
        end
        if #ts.sort == 0 and not has(t.flags, TF.SortTristate) then
            for i = 1, n do
                local c = t.cols[i]
                if not has(c.flags, TCF.NoSort) then ts.sort[1] = { col = i, dir = sort_default_dir(c) } break end
            end
        end
        sort_rebuild(t)
    end
    local fh = font_h()
    local cp = S.style.CellPadding.x
    local fixed_total, weight_total = 0, 0
    local vis = {}
    for pos = 1, n do
        local i = ts.order[pos]
        local c = t.cols[i]
        c.pos = pos
        c.hidden = ts.hidden[i] == true or has(c.flags, TCF.Disabled)
        if not c.hidden then
            vis[#vis + 1] = i
            c.fixed = col_fixed(t, c, i)
            if c.fixed then
                c.cw = max(fh, ts.w[i] or c.init or ts.auto_w[i] or max(fh * 4, text_w(c.label) + cp * 2))
                fixed_total = fixed_total + c.cw
            else
                c.wt = c.init or 1
                weight_total = weight_total + c.wt
            end
        end
    end
    local rest = max(0, t.w - fixed_total)
    local x = t.x
    for k = 1, #vis do
        local c = t.cols[vis[k]]
        if not c.fixed then c.cw = max(fh, weight_total > 0 and rest * c.wt / weight_total or 0) end
        c.x1, c.x2 = x, x + c.cw
        c.frozen = k <= t.fc
        x = c.x2
    end
    t.total_w = max(x - t.x, has(t.flags, TF.ScrollX) and 0 or t.w)
    for i = 1, n do
        local c = t.cols[i]
        if c.hidden then c.x1, c.x2, c.cw, c.frozen = t.x, t.x, 0, false end
    end
    if t.fc > 0 then
        local right = t.base_clip[1]
        for k = 1, min(t.fc, #vis) do
            local c = t.cols[vis[k]]
            c.x1, c.x2 = c.x1 + t.sx, c.x2 + t.sx
            right = c.x2
        end
        t.body_left = max(t.base_clip[1], right)
    end
    for i = 1, n do local c = t.cols[i]; c.cx1, c.cx2 = c.x1 + cp, max(c.x1 + cp, c.x2 - cp) end
    t.vis = vis
    table_resize_handles(t)
end

local function table_leave_cell(t)
    if not t.in_cell then return end
    t.in_cell = false
    local w = S.cur
    local i = t.col + 1
    local c = t.cols[i]
    if c and not c.hidden then
        local m = w.dc.max_x - c.cx1
        if m > (t.meas[i] or 0) then t.meas[i] = m end
    end
    if w.dc.max_x > t.acc_max_x then t.acc_max_x = w.dc.max_x end
    r_unclip(w.root.cmds)
    w.clip = t.base_clip
end

local function table_set_column(t, i)
    local w = S.cur
    table_layout(t)
    local c = t.cols[i + 1]
    if not c then return false end
    table_leave_cell(t)
    t.col = i
    local dc = w.dc
    dc.start_x = c.cx1
    dc.indent = 0
    dc.right = c.cx2
    dc.col_w = max(1, c.cx2 - c.cx1)
    dc.col_x2 = c.cx2
    dc.cx, dc.cy = c.cx1, t.row_top + S.style.CellPadding.y
    dc.line_top, dc.line_h, dc.same = dc.cy, 0, false
    dc.max_x = c.cx1
    local B = t.base_clip
    local clip
    if c.hidden then
        clip = { B[1], B[2], B[1], B[2] }
    else
        local top = (t.row < t.fr) and B[2] or max(B[2], t.body_top)
        local left = c.frozen and B[1] or t.body_left
        local x2 = has(c.flags, TCF.NoClip) and B[3] or min(B[3], c.x2)
        clip = { max(left, c.x1), top, x2, B[4] }
    end
    w.clip = clip
    local L = w.root.cmds
    r_clip(L, clip[1], clip[2], clip[3], clip[4])
    local ph = { 0 }                    -- CellBg placeholder, filled at row end
    L[#L + 1] = ph
    t.cell_cmd[i + 1] = ph
    t.in_cell = true
    return not c.hidden
end

local function row_clip_top(t) return (t.row < t.fr) and t.base_clip[2] or max(t.base_clip[2], t.body_top) end

local function table_end_row(t)
    local w = S.cur
    if t.row < 0 then return end
    table_leave_cell(t)
    local bottom = max(t.row_bottom, w.dc.max_y)
    local rb = bottom + S.style.CellPadding.y
    local x2 = t.x + max(t.w, t.total_w)
    local cmd = t.row_bg_cmd
    if cmd then
        local alt = (t.row % 2) == 1
        local c = t.row_is_header and col(ImGuiCol.TableHeaderBg) or col(alt and ImGuiCol.TableRowBgAlt or ImGuiCol.TableRowBg)
        if t.row_custom_bg then c = t.row_custom_bg end
        local r, g, b, a = rgba(c)
        cmd[1], cmd[2], cmd[3], cmd[4], cmd[5], cmd[6], cmd[7], cmd[8], cmd[9], cmd[10] =
            OP_RECT, t.x, t.row_top, x2, rb, r, g, b, a, 0
    end
    for ci, cc in pairs(t.cell_bg) do
        local ph, c = t.cell_cmd[ci], t.cols[ci]
        if ph and c and not c.hidden then
            local r, g, b, a = rgba(cc)
            ph[1], ph[2], ph[3], ph[4], ph[5], ph[6], ph[7], ph[8], ph[9], ph[10] = OP_RECT, c.x1, t.row_top, c.x2, rb, r, g, b, a, 0
        end
    end
    t.cell_bg, t.cell_cmd = {}, {}
    if S.cur and S.hover_root == w.root and S.my >= t.row_top and S.my < rb and S.my >= row_clip_top(t)
       and S.mx >= t.base_clip[1] and S.mx < t.base_clip[3] then
        t.hover_row = t.row
    end
    t.row_bottom = rb
    if has(t.flags, TF.BordersInnerH) or (t.row_is_header and has(t.flags, TF.BordersOuterH)) then
        local L, B = w.root.cmds, t.base_clip
        r_clip(L, B[1], row_clip_top(t), B[3], B[4])
        r_line(L, t.x, rb, x2, rb, col(t.row_is_header and ImGuiCol.TableBorderStrong or ImGuiCol.TableBorderLight), 1)
        r_unclip(L)
    end
end

-- TableSetupColumn(label[, flags, init_width_or_weight, user_id])
function im.TableSetupColumn(label, flags, width, user_id)
    local t = S.table
    if not t or t.setup >= t.n then return end
    t.setup = t.setup + 1
    t.cols[t.setup] = { label = parse_label(label or ""), flags = flags or 0, user_id = user_id or 0,
                        init = (width and width > 0) and width or nil }
end
-- TableSetupScrollFreeze(cols, rows): keep the first cols / rows visible while scrolling (ScrollX/ScrollY tables)
function im.TableSetupScrollFreeze(cols, rows)
    local t = S.table
    if not t or not t.child or t.row >= 0 then return end
    t.fc = has(t.flags, TF.ScrollX) and max(0, cols or 0) or 0
    t.fr = has(t.flags, TF.ScrollY) and max(0, rows or 0) or 0
    if t.fr > 0 then t.row_bottom = t.y + t.sy end
end
function im.TableNextRow(row_flags, min_h)
    local t = S.table
    if not t then return end
    table_layout(t)
    table_end_row(t)
    t.row = t.row + 1
    if t.fr > 0 and t.row == t.fr then
        t.body_top = t.row_bottom                 -- visible bottom of the frozen rows
        t.row_bottom = t.row_bottom - t.sy        -- body continues in scrolled coordinates
    end
    t.row_top = t.row_bottom
    t.row_is_header = has(row_flags, ImGuiTableRowFlags.Headers)
    t.row_custom_bg = nil
    local w = S.cur
    local L = w.root.cmds
    if has(t.flags, TF.RowBg) or t.row_is_header then
        local B = t.base_clip
        r_clip(L, B[1], row_clip_top(t), B[3], B[4])
        local cmd = { 0 }                          -- filled in at row end (op 0 draws nothing)
        L[#L + 1] = cmd
        r_unclip(L)
        t.row_bg_cmd = cmd
    else
        t.row_bg_cmd = nil
    end
    w.dc.max_y = t.row_top + (min_h or 0)
    t.col = -1
    t.row_bottom = t.row_top + (min_h or 0)
end
function im.TableNextColumn()
    local t = S.table
    if not t then return false end
    if t.row < 0 or t.col + 1 >= t.n then im.TableNextRow() end
    return table_set_column(t, t.col + 1)
end
function im.TableSetColumnIndex(i)
    local t = S.table
    if not t then return false end
    if t.row < 0 then im.TableNextRow() end
    return table_set_column(t, i)
end

-- Header cell: click sorts (Sortable), drag across a neighbour reorders (Reorderable), right-click opens
-- the column menu (Hideable / Resizable / Reorderable).
function im.TableHeader(label)
    local t, w = S.table, S.cur
    if not t or not w or t.col < 0 then return end
    local i = t.col + 1
    local c = t.cols[i]
    local ts = t.ts
    local disp = parse_label(label or "")
    local fh = font_h()
    local cp = S.style.CellPadding
    local y1, y2 = t.row_top, t.row_top + fh + cp.y * 2
    local hid = get_id("##hdr" .. i)
    local L = w.root.cmds
    local pressed, hov, held = button_behavior(hid, c.x1, y1, c.x2, y2)
    if hov or held then r_rect(L, c.x1, y1, c.x2, y2, col(held and ImGuiCol.HeaderActive or ImGuiCol.HeaderHovered)) end
    if S.activated_id == hid and S.activated_frame == S.frame then ts.reorder_drag = nil end
    if held and has(t.flags, TF.Reorderable) and not has(c.flags, TCF.NoReorder) then
        local pos, dst = c.pos, nil
        if S.mx < c.x1 and pos > 1 then dst = pos - 1 elseif S.mx > c.x2 and pos < t.n then dst = pos + 1 end
        if dst then
            local j = ts.order[dst]
            if not has(t.cols[j].flags, TCF.NoReorder) then
                ts.order[pos], ts.order[dst] = j, i
                ts.reorder_drag = hid
            end
        end
    end
    local sortable = has(t.flags, TF.Sortable) and not has(c.flags, TCF.NoSort)
    if pressed and sortable and ts.reorder_drag ~= hid then
        local cur_k
        for k, e in ipairs(ts.sort) do if e.col == i then cur_k = k end end
        local e = cur_k and ts.sort[cur_k]
        local dir
        if e then
            dir = (e.dir == ImGuiSortDirection.Ascending) and ImGuiSortDirection.Descending or ImGuiSortDirection.Ascending
            if has(c.flags, TCF.NoSortAscending) then dir = ImGuiSortDirection.Descending end
            if has(c.flags, TCF.NoSortDescending) then dir = ImGuiSortDirection.Ascending end
            if has(t.flags, TF.SortTristate) and e.dir ~= sort_default_dir(c) then dir = nil end
        else
            dir = sort_default_dir(c)
        end
        if not (has(t.flags, TF.SortMulti) and input.key_down(0x10)) then
            ts.sort = dir and { { col = i, dir = dir } } or {}
        elseif e then
            if dir then e.dir = dir else table.remove(ts.sort, cur_k) end
        elseif dir then
            ts.sort[#ts.sort + 1] = { col = i, dir = dir }
        end
        sort_rebuild(t)
    end
    if hov and S.clicked[1] and (has(t.flags, TF.Hideable) or has(t.flags, TF.Reorderable) or has(t.flags, TF.Resizable)) then
        im.OpenPopup("##TableContextMenu")
    end
    local x, y = item_pos()
    if not has(c.flags, TCF.NoHeaderLabel) then r_text(L, x, y, disp, col(ImGuiCol.Text)) end
    local sorted
    if has(t.flags, TF.Sortable) then for _, e in ipairs(ts.sort) do if e.col == i then sorted = e.dir end end end
    if sorted then
        arrow(L, c.cx2 - fh * 0.3, y + fh * 0.5, fh * 0.18, sorted == ImGuiSortDirection.Ascending and ImGuiDir.Up or ImGuiDir.Down, col(ImGuiCol.Text))
    end
    item_add(x, y, text_w(disp) + (sortable and fh or 0), fh)
    S.last.id, S.last.hovered, S.last.clicked, S.last.active = hid, hov, pressed, held
end
function im.TableHeadersRow()
    local t = S.table
    if not t then return end
    table_layout(t)
    im.TableNextRow(ImGuiTableRowFlags.Headers)
    for i = 1, t.n do
        if table_set_column(t, i - 1) then im.TableHeader(t.cols[i].label) end
    end
end
function im.TableAngledHeadersRow()
    local t = S.table
    if not t then return end
    table_layout(t)
    im.TableNextRow(ImGuiTableRowFlags.Headers)
    for i = 1, t.n do
        local c = t.cols[i]
        if has(c.flags, TCF.AngledHeader) and table_set_column(t, i - 1) then im.TableHeader(c.label) end
    end
end
-- TableSetBgColor(target, color[, column]): RowBg0/RowBg1 tint the row, CellBg one cell
function im.TableSetBgColor(target, color, column)
    local t = S.table
    if not t then return end
    local c = type(color) == "table" and to_f4(color) or u32_to_f4(color)
    if target == ImGuiTableBgTarget.CellBg then
        t.cell_bg[((column and column >= 0) and column or t.col) + 1] = c
    else
        t.row_custom_bg = c
    end
end
function im.TableGetColumnCount() return S.table and S.table.n or 0 end
function im.TableGetColumnIndex() return S.table and S.table.col or 0 end
function im.TableGetRowIndex() return S.table and S.table.row or 0 end
function im.TableGetColumnName(i)
    local t = S.table
    local c = t and t.cols[((i and i >= 0) and i or t.col) + 1]
    return c and c.label or ""
end
-- -> { SpecsDirty, SpecsCount, Specs = { { ColumnIndex, ColumnUserID, SortOrder, SortDirection }, ... } } or nil.
-- Set SpecsDirty = false once the data is sorted; it turns true again when the user changes the sort.
function im.TableGetSortSpecs()
    local t = S.table
    if not t or not has(t.flags, TF.Sortable) then return nil end
    table_layout(t)
    return t.ts.specs
end
function im.TableSetColumnEnabled(i, v)
    local t = S.table
    if not t then return end
    i = (i and i >= 0) and i or t.col
    local c = t.cols[i + 1]
    if c and has(c.flags, TCF.NoHide) and not v then return end
    t.ts.hidden[i + 1] = not v
end
function im.TableGetHoveredColumn()
    local t = S.table
    if not t or not S.cur or S.hover_root ~= S.cur.root then return -1 end
    table_layout(t)
    local top = (t.fr > 0) and (t.y + t.sy) or t.y
    if S.my < top or S.my > top + max(t.ts.h or 0, frame_h()) then return -1 end
    for _, i in ipairs(t.vis) do
        local c = t.cols[i]
        if S.mx >= (c.frozen and c.x1 or max(c.x1, t.body_left)) and S.mx < c.x2 then return i - 1 end
    end
    return -1
end
function im.TableGetHoveredRow() return S.table and S.table.ts.hover_row or -1 end
function im.TableGetColumnFlags(i)
    local t = S.table
    if not t then return 0 end
    table_layout(t)
    i = (i and i >= 0) and i or t.col
    local c = t.cols[i + 1]
    if not c then return 0 end
    local f = c.flags
    if not c.hidden then f = f | TCF.IsEnabled | TCF.IsVisible end
    for _, e in ipairs(t.ts.sort or {}) do if e.col == i + 1 then f = f | TCF.IsSorted end end
    if im.TableGetHoveredColumn() == i then f = f | TCF.IsHovered end
    return f
end
function im.EndTable()
    local t = S.table
    local w = S.cur
    if not t or not w then return end
    table_layout(t)
    table_end_row(t)
    local ts = t.ts
    local L = w.root.cmds
    local B = t.base_clip
    local y2 = max(t.row_bottom, t.y)
    local top = (t.fr > 0) and (t.y + t.sy) or t.y
    local vis_bot = min(y2, B[4])
    if t.fr > 0 and t.row < t.fr then vis_bot = min(t.row_bottom, B[4]) end
    local x2 = t.x + max(t.w, t.total_w)
    r_clip(L, B[1], B[2], B[3], B[4])
    if has(t.flags, TF.BordersInnerV) then
        for k = 1, #t.vis - 1 do
            local c = t.cols[t.vis[k]]
            if c.frozen or c.x2 >= t.body_left then r_line(L, c.x2, top, c.x2, vis_bot, col(ImGuiCol.TableBorderLight), 1) end
        end
    end
    if not t.child and (has(t.flags, TF.BordersOuterV) or has(t.flags, TF.BordersOuterH)) then
        r_outline(L, t.x, t.y, x2, y2, col(ImGuiCol.TableBorderStrong), 0, 1)
    end
    if t.resize_hl then
        r_line(L, t.resize_hl[1], top, t.resize_hl[1], vis_bot, col(t.resize_hl[2] and ImGuiCol.SeparatorActive or ImGuiCol.SeparatorHovered), 2)
    end
    r_unclip(L)
    for i = 1, t.n do
        if t.meas[i] then ts.auto_w[i] = t.meas[i] + S.style.CellPadding.x * 2 end
    end
    ts.h = max(0, vis_bot - top)
    ts.hover_row = t.hover_row
    -- column context menu
    S.table = nil
    if im.BeginPopup("##TableContextMenu") then
        if has(t.flags, TF.Resizable) and im.MenuItem("Size all columns to default") then
            for i = 1, t.n do ts.w[i] = nil end
        end
        if has(t.flags, TF.Reorderable) and im.MenuItem("Reset order") then
            for i = 1, t.n do ts.order[i] = i end
        end
        if has(t.flags, TF.Hideable) then
            im.Separator()
            local shown = 0
            for i = 1, t.n do if not ts.hidden[i] then shown = shown + 1 end end
            for i = 1, t.n do
                local c = t.cols[i]
                if not has(c.flags, TCF.Disabled) then
                    local on = not ts.hidden[i]
                    local can = not has(c.flags, TCF.NoHide) and not (on and shown <= 1)
                    local name = (c.label ~= "" and c.label or ("Column " .. i)) .. "##tblcol" .. i
                    local _, clicked = im.MenuItem(name, nil, on, can)
                    if clicked then ts.hidden[i] = on end
                end
            end
        end
        im.EndPopup()
    end
    S.table = t
    local dc = w.dc
    dc.start_x, dc.indent, dc.right = t.saved.start_x, t.saved.indent, t.saved.right
    dc.col_w, dc.col_x2 = nil, nil
    dc.same = false
    dc.max_x = max(t.saved.max_x, t.acc_max_x)
    dc.cx = dc.start_x + dc.indent
    dc.line_top, dc.line_h = t.y, 0
    w.clip = t.base_clip
    item_add(t.x, t.y, has(t.flags, TF.ScrollX) and t.total_w or t.w, y2 - t.y)
    seed_pop()
    S.table = t.parent
    if t.child then
        local cw = t.win
        im.EndChild()
        if has(t.flags, TF.BordersOuterV) or has(t.flags, TF.BordersOuterH) then
            r_outline(S.cur.root.cmds, cw.x, cw.y, cw.x + cw.w, cw.y + cw.h, col(ImGuiCol.TableBorderStrong), 0, 1)
        end
    end
    if S.table and S.cur then
        local pt = S.table
        local c = pt.cols[pt.col + 1]
        local pdc = S.cur.dc
        if c then pdc.start_x, pdc.right, pdc.col_w, pdc.col_x2 = c.cx1, c.cx2, c.cx2 - c.cx1, c.cx2 end
    end
end
-- legacy Columns API maps onto a borderless table
function im.Columns(n, id, border)
    if S.table and S.table.legacy then im.EndTable() end
    if (n or 1) > 1 then
        im.BeginTable(id or "##columns", n, border == false and 0 or ImGuiTableFlags.BordersInnerV)
        S.table.legacy = true
        im.TableNextColumn()
    end
end
function im.NextColumn() if S.table and S.table.legacy then im.TableNextColumn() end end
function im.GetColumnIndex() return S.table and S.table.col or 0 end
function im.GetColumnsCount() return S.table and S.table.n or 1 end
function im.GetColumnWidth(i)
    local t = S.table
    local c = t and t.cols[((i and i >= 0) and i or t.col) + 1]
    return c and c.x2 and (c.x2 - c.x1) or 0
end
function im.SetColumnWidth(i, w) local t = S.table; if t then t.ts.w[i + 1] = w end end

-- ── colours ──────────────────────────────────────────────────────────────────

local function hsv_state(id, r, g, b)
    local st = S.storage[id]
    local h, s, v = im.ColorConvertRGBtoHSV(r, g, b)
    if type(st) ~= "table" then st = { h, s, v }; S.storage[id] = st end
    local cr, cg, cb = im.ColorConvertHSVtoRGB(st[1], st[2], st[3])
    if abs(cr - r) > 0.004 or abs(cg - g) > 0.004 or abs(cb - b) > 0.004 then
        if s > 0 and v > 0 then st[1] = h end
        st[2], st[3] = s, v
    end
    return st
end

-- Inline SV square + hue bar (+ alpha bar). Mutates c (float4) and returns changed.
local function picker(id, c, with_alpha, size)
    local w = S.cur
    local L = w.root.cmds
    local x, y = item_pos()
    local sq = size or max(120, min(200, calc_item_w()))
    local bar = max(12, floor(frame_h() * 0.8))
    local gap = S.style.ItemInnerSpacing.x
    local st = hsv_state(id, c[1], c[2], c[3])
    local changed = false
    local hr, hg, hb = im.ColorConvertHSVtoRGB(st[1], 1, 1)
    local sv_id, h_id, a_id = id + 1, id + 2, id + 3
    -- SV square
    local _, hov_sv = button_behavior(sv_id, x, y, x + sq, y + sq)
    if S.active_id == sv_id and S.down[0] then
        st[2] = clamp((S.mx - x) / sq, 0, 1)
        st[3] = 1 - clamp((S.my - y) / sq, 0, 1)
        changed = true
    end
    local white, black0, black1 = { 255, 255, 255, 255 }, { 0, 0, 0, 0 }, { 0, 0, 0, 255 }
    local hue = { floor(hr * 255), floor(hg * 255), floor(hb * 255), 255 }
    r_grad(L, x, y, x + sq, y + sq, white, hue, hue, white)
    r_grad(L, x, y, x + sq, y + sq, black0, black0, black1, black1)
    local px, py = x + st[2] * sq, y + (1 - st[3]) * sq
    r_circle(L, px, py, 5, { 1, 1, 1, 1 }, false, 1.5)
    r_circle(L, px, py, 6, { 0, 0, 0, 0.6 }, false, 1)
    -- hue bar
    local hx = x + sq + gap
    button_behavior(h_id, hx, y, hx + bar, y + sq)
    if S.active_id == h_id and S.down[0] then st[1] = clamp((S.my - y) / sq, 0, 0.9999); changed = true end
    for i = 0, 5 do
        local r1, g1, b1 = im.ColorConvertHSVtoRGB(i / 6, 1, 1)
        local r2, g2, b2 = im.ColorConvertHSVtoRGB((i + 1) / 6, 1, 1)
        local c1 = { floor(r1 * 255), floor(g1 * 255), floor(b1 * 255), 255 }
        local c2 = { floor(r2 * 255), floor(g2 * 255), floor(b2 * 255), 255 }
        r_grad(L, hx, y + sq * i / 6, hx + bar, y + sq * (i + 1) / 6, c1, c1, c2, c2)
    end
    local hy = y + st[1] * sq
    r_rect(L, hx - 2, hy - 2, hx + bar + 2, hy + 2, { 1, 1, 1, 1 })
    local total_w = sq + gap + bar
    -- alpha bar
    if with_alpha then
        local ax = hx + bar + gap
        button_behavior(a_id, ax, y, ax + bar, y + sq)
        if S.active_id == a_id and S.down[0] then c[4] = 1 - clamp((S.my - y) / sq, 0, 1); changed = true end
        local top = { floor(c[1] * 255), floor(c[2] * 255), floor(c[3] * 255), 255 }
        local bot = { top[1], top[2], top[3], 0 }
        r_rect(L, ax, y, ax + bar, y + sq, { 0.5, 0.5, 0.5, 1 })
        r_grad(L, ax, y, ax + bar, y + sq, top, top, bot, bot)
        local ay = y + (1 - (c[4] or 1)) * sq
        r_rect(L, ax - 2, ay - 2, ax + bar + 2, ay + 2, { 1, 1, 1, 1 })
        total_w = total_w + gap + bar
    end
    if changed then c[1], c[2], c[3] = im.ColorConvertHSVtoRGB(st[1], st[2], st[3]) end
    item_add(x, y, total_w, sq)
    return changed
end

local function color_edit(label, c, flags, with_alpha)
    local w = S.cur
    if type(c) ~= "table" then c = { 1, 1, 1, 1 } end
    local out = { c[1] or c.x or 0, c[2] or c.y or 0, c[3] or c.z or 0, c[4] or c.w or 1 }
    if not w then return out, false end
    flags = flags or 0
    local disp, idl = parse_label(label)
    local id = get_id(idl)
    local fh = frame_h()
    local sp = S.style.ItemInnerSpacing.x
    local changed = false
    local alpha = with_alpha and not has(flags, ImGuiColorEditFlags.NoAlpha)
    local iw = calc_item_w()
    im.BeginGroup()
    im.PushID(idl)
    if not has(flags, ImGuiColorEditFlags.NoInputs) then
        -- R G B (A) drag fields in 0..255
        local n = alpha and 4 or 3
        local each = max(20, (iw - fh - sp * n) / n)
        local names = { "R:%d", "G:%d", "B:%d", "A:%d" }
        for i = 1, n do
            S.next_item_w = each
            local nv, ch = drag_scalar("##c" .. i, floor(out[i] * 255 + 0.5), 1, 0, 255, names[i], 0, true)
            if ch then out[i] = nv / 255; changed = true end
            im.SameLine(0, sp)
        end
    end
    -- swatch: opens the picker popup
    local L = w.root.cmds
    local x, y = item_pos()
    local sid = get_id("##swatch")
    local pressed, hov = button_behavior(sid, x, y, x + fh, y + fh)
    r_rect(L, x, y, x + fh, y + fh, { 0.5, 0.5, 0.5, 1 }, S.style.FrameRounding)
    r_rect(L, x, y, x + fh, y + fh, { out[1], out[2], out[3], alpha and out[4] or 1 }, S.style.FrameRounding)
    if hov then r_outline(L, x, y, x + fh, y + fh, col(ImGuiCol.Text), S.style.FrameRounding, 1) end
    item_add(x, y, fh, fh)
    w.dc.line_frame = true
    local pid = get_id("##picker")
    if pressed and not has(flags, ImGuiColorEditFlags.NoPicker) and not S.just_closed[pid] then
        im.OpenPopup(pid)
        S.popups[S.popup_depth + 1].anchor = { x, y + fh + 2 }
    end
    if begin_popup_ex(pid, ImGuiWindowFlags.NoTitleBar, false) then
        if picker(get_id("##sv"), out, alpha) then changed = true end
        end_popup()
    end
    im.PopID()
    if disp ~= "" and not has(flags, ImGuiColorEditFlags.NoLabel) then
        im.SameLine(0, sp)
        text_item(disp, col(ImGuiCol.Text))
    end
    im.EndGroup()
    S.last.id, S.last.edited = id, changed
    return out, changed
end

-- ColorEdit3(label, {r,g,b}[, flags]) -> col, used   (floats 0..1)
function im.ColorEdit3(label, c, flags) local o, ch = color_edit(label, c, flags, false); return { o[1], o[2], o[3] }, ch end
function im.ColorEdit4(label, c, flags) return color_edit(label, c, flags, true) end
function im.ColorPicker3(label, c, flags)
    if type(c) ~= "table" then c = { 1, 1, 1 } end
    local o = { c[1] or 0, c[2] or 0, c[3] or 0, 1 }
    if not S.cur then return o, false end
    local disp, idl = parse_label(label)
    local ch = picker(get_id(idl), o, false)
    return { o[1], o[2], o[3] }, ch
end
function im.ColorPicker4(label, c, flags)
    if type(c) ~= "table" then c = { 1, 1, 1, 1 } end
    local o = { c[1] or 0, c[2] or 0, c[3] or 0, c[4] or 1 }
    if not S.cur then return o, false end
    local disp, idl = parse_label(label)
    local ch = picker(get_id(idl), o, not has(flags, ImGuiColorEditFlags.NoAlpha))
    return o, ch
end
function im.ColorButton(label, c, flags, sx, sy)
    local w = S.cur
    if not w then return false end
    local f = to_f4(c)
    local id = get_id(label)
    local x, y = item_pos()
    local s = frame_h()
    local bw, bh = (sx and sx > 0) and sx or s, (sy and sy > 0) and sy or s
    local pressed, hov = button_behavior(id, x, y, x + bw, y + bh)
    r_rect(w.root.cmds, x, y, x + bw, y + bh, f, S.style.FrameRounding)
    if hov then r_outline(w.root.cmds, x, y, x + bw, y + bh, col(ImGuiCol.Text), S.style.FrameRounding, 1) end
    item_add(x, y, bw, bh)
    S.last.id, S.last.hovered, S.last.clicked = id, hov, pressed
    return pressed
end

-- ── plots ────────────────────────────────────────────────────────────────────

local function plot(label, values, count, offset, overlay, smin, smax, sx, sy, histogram)
    local w = S.cur
    if not w then return end
    values = values or {}
    count = count or #values
    offset = offset or 0
    local disp = parse_label(label)
    local x, y = item_pos()
    local pw = (sx and sx > 0) and sx or calc_item_w()
    local ph = (sy and sy > 0) and sy or frame_h() * 3
    if not smin or not smax or smin == smax or smin ~= smin then
        local lo, hi = math.huge, -math.huge
        for i = 1, count do local v = values[i] or 0; if v < lo then lo = v end; if v > hi then hi = v end end
        smin = (smin and smin == smin and smin ~= math.huge) and smin or lo
        smax = (smax and smax == smax and smax ~= math.huge) and smax or hi
    end
    if smax <= smin then smax = smin + 1 end
    local L = w.root.cmds
    r_rect(L, x, y, x + pw, y + ph, col(ImGuiCol.FrameBg), S.style.FrameRounding)
    local ix1, iy1, ix2, iy2 = x + 2, y + 2, x + pw - 2, y + ph - 2
    local c = col(histogram and ImGuiCol.PlotHistogram or ImGuiCol.PlotLines)
    if count > 0 then
        local function vy(v) return iy2 - (clamp((v - smin) / (smax - smin), 0, 1)) * (iy2 - iy1) end
        if histogram then
            local bw = (ix2 - ix1) / count
            for i = 0, count - 1 do
                local v = values[((i + offset) % count) + 1] or 0
                r_rect(L, ix1 + i * bw + 1, vy(v), ix1 + (i + 1) * bw - 1, iy2, c)
            end
        elseif count > 1 then
            local step = (ix2 - ix1) / (count - 1)
            local px, py
            for i = 0, count - 1 do
                local v = values[((i + offset) % count) + 1] or 0
                local cx, cy = ix1 + i * step, vy(v)
                if px then r_line(L, px, py, cx, cy, c, 1.5) end
                px, py = cx, cy
            end
        end
    end
    if overlay then r_text(L, x + (pw - text_w(overlay)) * 0.5, y + 2, overlay, col(ImGuiCol.Text)) end
    finish_labelled(w, x, y, pw, ph, disp)
end
function im.PlotLines(label, values, count, offset, overlay, smin, smax, sx, sy) plot(label, values, count, offset, overlay, smin, smax, sx, sy, false) end
function im.PlotHistogram(label, values, count, offset, overlay, smin, smax, sx, sy) plot(label, values, count, offset, overlay, smin, smax, sx, sy, true) end

-- ── item / window queries ────────────────────────────────────────────────────

function im.IsItemHovered(flags)
    local L = S.last
    if not S.cur or L.win ~= S.cur then return false end
    if has(flags, ImGuiHoveredFlags.AllowWhenBlockedByActiveItem) or has(flags, ImGuiHoveredFlags.RectOnly) then
        return S.input_ok and S.hover_root == S.cur.root and mouse_in(L.x1, L.y1, L.x2, L.y2)
    end
    if L.hovered then
        if has(flags, ImGuiHoveredFlags.DelayNormal) or has(flags, ImGuiHoveredFlags.ForTooltip) or has(flags, ImGuiHoveredFlags.Stationary) then
            local key = L.id ~= 0 and L.id or (floor(L.x1) * 7919 + floor(L.y1))
            if S.hov_key ~= key then S.hov_key, S.hov_t = key, now() end
            return now() - S.hov_t > 0.35
        end
        return true
    end
    return false
end
function im.IsItemActive() return S.last.active and S.active_id ~= nil and S.active_id == S.last.id or (S.text_id ~= nil and S.text_id == S.last.id) end
function im.IsItemClicked(btn)
    btn = btn or 0
    if btn == 0 then return S.last.hovered and S.clicked[0] or false end
    return S.last.hovered and S.clicked[btn] or false
end
function im.IsItemEdited() return S.last.edited or false end
function im.IsItemActivated() return (S.last.id or 0) ~= 0 and S.activated_id == S.last.id and S.activated_frame == S.frame end
function im.IsItemDeactivated() return (S.last.id or 0) ~= 0 and S.deactivated_id == S.last.id and S.deactivated_frame == S.frame end
function im.IsItemDeactivatedAfterEdit() return im.IsItemDeactivated() and S.deactivated_edited == true end
function im.IsItemFocused()
    local id = S.last.id
    return (S.text_id ~= nil and S.text_id == id) or (S.nav_active and id ~= nil and S.nav_id == id)
end
function im.IsItemVisible() local L = S.last; return S.cur ~= nil and L.y2 >= S.cur.clip[2] and L.y1 <= S.cur.clip[4] end
function im.IsItemToggledOpen() return S.last.toggled or false end
function im.IsAnyItemHovered() return S.hover_root ~= nil end
function im.IsAnyItemActive() return S.active_id ~= nil or S.text_id ~= nil end
function im.IsAnyItemFocused() return S.text_id ~= nil or (S.nav_active and S.nav_id ~= nil) end
function im.GetItemRectMin() return S.last.x1, S.last.y1 end
function im.GetItemRectMax() return S.last.x2, S.last.y2 end
function im.GetItemRectSize() return S.last.x2 - S.last.x1, S.last.y2 - S.last.y1 end
function im.GetItemID() return S.last.id end
function im.IsRectVisible(a, b, c, d)
    if not S.cur then return false end
    local cl = S.cur.clip
    if c == nil then local x, y = item_pos(); return y + (b or 0) >= cl[2] and y <= cl[4] end
    return d >= cl[2] and b <= cl[4] and c >= cl[1] and a <= cl[3]
end

-- ── mouse / keyboard / io ────────────────────────────────────────────────────

function im.GetMousePos() return S.mx or input.mouse_x(), S.my or input.mouse_y() end
function im.GetMousePosOnOpeningCurrentPopup()
    local p = S.popups[S.popup_depth]
    if p then return p.x, p.y end
    return im.GetMousePos()
end
function im.IsMouseClicked(b) return input.mouse_clicked(b or 0) end
function im.IsMouseDown(b) return input.mouse_down(b or 0) end
function im.IsMouseReleased(b) return input.mouse_released(b or 0) end
function im.IsMouseDoubleClicked(b) return (b or 0) == 0 and S.dbl or false end
function im.IsMouseHoveringRect(x1, y1, x2, y2)
    if type(x1) == "table" then x1, y1, x2, y2 = x1.x or x1[1], x1.y or x1[2], y1.x or y1[1], y1.y or y1[2] end
    local mx, my = im.GetMousePos()
    return mx >= x1 and mx < x2 and my >= y1 and my < y2
end
function im.IsMousePosValid() return true end
function im.IsMouseDragging(b, thresh)
    b = b or 0
    if not input.mouse_down(b) then return false end
    local dx, dy = S.mx - (S.last_click_x or S.mx), S.my - (S.last_click_y or S.my)
    local t = thresh or 6
    return dx * dx + dy * dy >= t * t
end
function im.GetMouseDragDelta(b, thresh)
    b = b or 0
    if not input.mouse_down(b) then return 0, 0 end
    return S.mx - (S.last_click_x or S.mx), S.my - (S.last_click_y or S.my)
end
function im.ResetMouseDragDelta() S.last_click_x, S.last_click_y = S.mx, S.my end
function im.GetMouseCursor() return S.cursor or ImGuiMouseCursor.Arrow end
function im.SetMouseCursor(c) S.cursor = c or ImGuiMouseCursor.Arrow end
function im.SetNextFrameWantCaptureMouse(b) if b ~= false then S.want_mouse_frame = S.frame + 1 end end
function im.SetNextFrameWantCaptureKeyboard(b) if b ~= false then S.want_kbd_frame = S.frame + 1 end end

local function vk_of(key)
    if not key then return nil end
    if key >= 512 then return KEY_VK[key & 0xFFF] or KEY_VK[key] end
    return key     -- legacy: raw virtual-key codes (YimMenu scripts often pass VK values)
end
function im.IsKeyDown(key) local vk = vk_of(key); return vk and input.key_down(vk) or false end
-- IsKeyPressed(key[, repeat=true]): repeats while held (0.275 s delay, 0.05 s rate)
function im.IsKeyPressed(key, rep) local vk = vk_of(key); return vk and key_rep(vk, rep ~= false) or false end
function im.IsKeyReleased(key) local vk = vk_of(key); return vk and input.key_released(vk) or false end
function im.IsKeyChordPressed(chord)
    local key = chord & 0xFFF
    if has(chord, ImGuiMod.Ctrl) and not input.key_down(0x11) then return false end
    if has(chord, ImGuiMod.Shift) and not input.key_down(0x10) then return false end
    if has(chord, ImGuiMod.Alt) and not input.key_down(0x12) then return false end
    return im.IsKeyPressed(key)
end
function im.GetKeyName(key)
    for name, v in pairs(ImGuiKey) do if v == key then return name end end
    return "Unknown"
end
function im.GetKeyIndex(key) return key end

local function font_atlas()
    if S.atlas then return S.atlas end
    local A = { Fonts = {} }
    -- Fonts can't be loaded from TTF at runtime: each call returns a handle on the overlay font at the
    -- requested pixel size, which PushFont honours by scaling.
    local function add(self, path, size)
        if self ~= A then path, size = self, path end
        local f = { id = font.item, size = size or 0, FontSize = size or 0, path = path }
        A.Fonts[#A.Fonts + 1] = f
        return f
    end
    A.AddFontFromFileTTF = add
    A.AddFontFromMemoryTTF = function(self, data, size) if self ~= A then size = data end return add(A, nil, size) end
    A.AddFontFromMemoryCompressedTTF = A.AddFontFromMemoryTTF
    A.AddFontFromMemoryCompressedBase85TTF = A.AddFontFromMemoryTTF
    A.AddFontDefault = function() return add(A, nil, 0) end
    A.Build = function() return true end
    A.Clear = function() A.Fonts = {} end
    A.GetGlyphRangesDefault = function() return nil end
    A.GetGlyphRangesCyrillic = A.GetGlyphRangesDefault
    A.GetGlyphRangesChineseFull = A.GetGlyphRangesDefault
    A.GetGlyphRangesJapanese = A.GetGlyphRangesDefault
    A.GetGlyphRangesKorean = A.GetGlyphRangesDefault
    S.atlas = A
    return A
end

function im.GetIO()
    local io = S.io
    if not io then
        io = { FontGlobalScale = 1.0, ConfigFlags = 0, BackendFlags = 0, IniFilename = nil, LogFilename = nil,
               MouseDrawCursor = false, ConfigInputTextCursorBlink = true, MouseDoubleClickTime = 0.30,
               KeyRepeatDelay = 0.275, KeyRepeatRate = 0.05 }
        S.io = io
    end
    local sw, sh = ctx.screen_w(), ctx.screen_h()
    local dt = ctx.delta()
    io.DisplaySize = { x = sw, y = sh }
    io.DeltaTime = dt
    io.Framerate = ctx.fps and ctx.fps() or (dt > 0 and 1 / dt or 60)
    io.MousePos = { x = S.mx or input.mouse_x(), y = S.my or input.mouse_y() }
    io.MouseDown = { input.mouse_down(0), input.mouse_down(1), input.mouse_down(2) }
    io.MouseWheel = input.mouse_wheel()
    io.KeyCtrl, io.KeyShift, io.KeyAlt = input.key_down(0x11), input.key_down(0x10), input.key_down(0x12)
    io.WantCaptureMouse = S.hover_root ~= nil or S.active_id ~= nil or S.want_mouse_frame == S.frame
    io.WantCaptureKeyboard = S.text_id ~= nil or (S.nav_active and S.nav_win ~= nil) or S.want_kbd_frame == S.frame
    io.WantTextInput = S.text_id ~= nil
    io.NavActive = S.nav_active and S.nav_win ~= nil
    io.Fonts = font_atlas()
    return io
end
function im.GetTime() return now() end
function im.GetFrameCount() return S.frame end
function im.GetMainViewport()
    local sw, sh = ctx.screen_w(), ctx.screen_h()
    return { Pos = { x = 0, y = 0 }, Size = { x = sw, y = sh }, WorkPos = { x = 0, y = 0 }, WorkSize = { x = sw, y = sh },
             GetCenter = function() return sw * 0.5, sh * 0.5 end, GetWorkCenter = function() return sw * 0.5, sh * 0.5 end }
end
function im.GetDisplaySize() return ctx.screen_w(), ctx.screen_h() end
function im.GetClipboardText() return ui.get_clipboard and ui.get_clipboard() or "" end
function im.SetClipboardText(s) if ui.set_clipboard then ui.set_clipboard(tostring(s == nil and "" or s)) end end
function im.GetVersion() return "1.92.1 (Nenyoo shim)" end
function im.StyleColorsDark() S.preset, S.preset_name = build_preset("dark"), "dark" end
function im.StyleColorsLight() S.preset, S.preset_name = build_preset("light"), "light" end
function im.StyleColorsClassic() S.preset, S.preset_name = build_preset("classic"), "classic" end
-- back to colours derived from the active Nenyoo theme (the default)
function im.StyleColorsTheme() S.preset, S.preset_name = nil, nil end

-- ── logging ──────────────────────────────────────────────────────────────────
-- Between LogTo*() and LogFinish(), every Text-family item is captured and written out at LogFinish.

function im.LogToTTY() S.log = { kind = "tty", buf = {} } end
function im.LogToFile(_, file) S.log = { kind = "file", buf = {}, file = file or "imgui_log.txt" } end
function im.LogToClipboard() S.log = { kind = "clip", buf = {} } end
function im.LogText(...)
    if not S.log then return end
    local n, s = select("#", ...), ...
    if n > 1 and type(s) == "string" then
        local ok, r = pcall(string.format, ...)
        if ok then s = r end
    end
    log_append(tostring(s == nil and "" or s))
end
function im.LogFinish()
    local lg = S.log
    if not lg then return end
    S.log = nil
    local out = table.concat(lg.buf, "\n")
    if lg.kind == "clip" then
        im.SetClipboardText(out)
    elseif lg.kind == "file" then
        if fs and fs.write then pcall(fs.write, lg.file, out) end
    else
        print(out)
    end
end
function im.LogButtons()
    im.PushID("LogButtons")
    local tty = im.Button("Log To TTY"); im.SameLine()
    local file = im.Button("Log To File"); im.SameLine()
    local clip = im.Button("Log To Clipboard")
    im.PopID()
    if tty then im.LogToTTY() elseif file then im.LogToFile() elseif clip then im.LogToClipboard() end
end

-- ── drag and drop ────────────────────────────────────────────────────────────
-- Payload data is any Lua value. AcceptDragDropPayload returns a payload table
-- { Data, DataType, Delivery, Preview, IsDataType(t), IsDelivery(), IsPreview() } or nil.

local function dd_payload(dd, delivery)
    return {
        Data = dd.data, DataType = dd.type, Delivery = delivery, Preview = true,
        IsDataType = function(a, b) local t = (b == nil) and a or b; return dd.type == tostring(t) end,
        IsDelivery = function() return delivery end,
        IsPreview = function() return true end,
    }
end

function im.BeginDragDropSource(flags)
    flags = flags or 0
    if not S.cur then return false end
    local L = S.last
    local dd = S.dd
    if has(flags, ImGuiDragDropFlags.SourceExtern) then
        if not (dd and dd.src == "extern") then S.dd = { src = "extern" }; dd = S.dd end
    else
        local id = L.id
        local null_id = not id or id == 0
        if null_id then
            if not has(flags, ImGuiDragDropFlags.SourceAllowNullID) then return false end
            id = ui.hash(seed() .. string.format("\31##dd_%d_%d", floor(L.x1), floor(L.y1)))
        end
        if not S.down[0] then return false end
        if not (dd and dd.src == id) then
            if null_id then
                if not (S.last_click_x >= L.x1 and S.last_click_x < L.x2 and S.last_click_y >= L.y1 and S.last_click_y < L.y2) then return false end
                if abs(S.mx - S.last_click_x) + abs(S.my - S.last_click_y) < 6 then return false end
            else
                if S.active_id ~= id then return false end
                if abs(S.mx - S.drag_x) + abs(S.my - S.drag_y) < 6 then return false end
            end
            S.dd = { src = id }
            dd = S.dd
        end
    end
    dd.frame = S.frame
    dd.tooltip = not has(flags, ImGuiDragDropFlags.SourceNoPreviewTooltip)
    if dd.tooltip then im.BeginTooltip() end
    return true
end
-- SetDragDropPayload(type, data[, cond]) -> true when a target accepted the payload last frame
function im.SetDragDropPayload(dtype, data, cond)
    local dd = S.dd
    if not dd then return false end
    if not (cond == ImGuiCond.Once and dd.type ~= nil) then dd.type, dd.data = tostring(dtype or ""), data end
    return dd.accepted_frame ~= nil and dd.accepted_frame >= S.frame - 1
end
function im.EndDragDropSource()
    local dd = S.dd
    if dd and dd.tooltip then dd.tooltip = false; im.EndTooltip() end
end
function im.BeginDragDropTarget()
    local dd = S.dd
    if not dd or not S.cur then return false end
    local L = S.last
    if (L.id or 0) ~= 0 and L.id == dd.src then return false end
    if not hover_rect(L.x1, L.y1, L.x2, L.y2) then return false end
    S.dd_target = { x1 = L.x1, y1 = L.y1, x2 = L.x2, y2 = L.y2, win = S.cur }
    return true
end
function im.AcceptDragDropPayload(dtype, flags)
    local dd, tg = S.dd, S.dd_target
    if not dd or not tg or dd.type == nil then return nil end
    flags = flags or 0
    if dtype ~= nil and dd.type ~= tostring(dtype) then return nil end
    dd.accepted_frame = S.frame
    local delivery = S.released[0] and true or false
    if not has(flags, ImGuiDragDropFlags.AcceptNoDrawDefaultRect) then
        r_outline(tg.win.root.cmds, tg.x1 - 3, tg.y1 - 3, tg.x2 + 3, tg.y2 + 3, col(ImGuiCol.DragDropTarget), 0, 2)
    end
    if not delivery and not has(flags, ImGuiDragDropFlags.AcceptBeforeDelivery) then return nil end
    return dd_payload(dd, delivery)
end
function im.EndDragDropTarget() S.dd_target = nil end
function im.GetDragDropPayload()
    local dd = S.dd
    if not dd or dd.type == nil then return nil end
    return dd_payload(dd, false)
end
function im.IsDragDropActive() return S.dd ~= nil end

-- ── built-in tool windows ────────────────────────────────────────────────────

local function tool_begin(title, p_open, w, h)
    if w then im.SetNextWindowSize(w, h, ImGuiCond.FirstUseEver) end
    if p_open ~= nil then
        local open, vis = im.Begin(title, p_open)
        return open, vis
    end
    return true, im.Begin(title)
end

function im.ShowUserGuide()
    im.BulletText("Double-click a title bar to collapse the window.")
    im.BulletText("Drag the bottom-right corner to resize a window.")
    im.BulletText("Drag a title bar to move a window.")
    im.BulletText("Ctrl+click or double-click a slider or drag box to type a value.")
    im.BulletText("Shift / Alt while dragging a value: faster / slower.")
    im.BulletText("Tab to start keyboard navigation, arrows to move, Enter to activate, Esc to leave.")
    im.BulletText("While typing: Ctrl+A select all, Ctrl+C / Ctrl+X / Ctrl+V clipboard.")
    im.BulletText("In multi-line fields Enter adds a line; Ctrl+Enter or clicking away finishes.")
end

function im.ShowStyleSelector(label)
    local names = { "Theme", "Dark", "Light", "Classic" }
    local cur = ({ dark = 1, light = 2, classic = 3 })[S.preset_name or ""] or 0
    local idx, ch = im.Combo(label or "Colors##Selector", cur, names, 4)
    if ch then
        if idx == 0 then im.StyleColorsTheme() elseif idx == 1 then im.StyleColorsDark()
        elseif idx == 2 then im.StyleColorsLight() else im.StyleColorsClassic() end
    end
    return ch
end

function im.ShowFontSelector(label)
    local names = {}
    local ok = pcall(function() for k, v in pairs(font) do if type(v) == "number" then names[#names + 1] = k end end end)
    if not ok or #names == 0 then return end
    table.sort(names)
    local cur = 0
    for i, n in ipairs(names) do if font[n] == font_body() then cur = i - 1 end end
    local idx, ch = im.Combo(label or "Font", cur, names, #names)
    if ch then S.default_font = font[names[idx + 1]] end
end

function im.ShowStyleEditor()
    local st = S.style
    im.ShowStyleSelector("Colors##Selector")
    im.ShowFontSelector("Font##Selector")
    local io = im.GetIO()
    io.FontGlobalScale = im.SliderFloat("Global font scale", io.FontGlobalScale or 1, 0.5, 2, "%.2f")
    if im.BeginTabBar("##StyleEditor") then
        if im.BeginTabItem("Sizes") then
            for _, k in ipairs({ "WindowPadding", "FramePadding", "CellPadding", "ItemSpacing", "ItemInnerSpacing" }) do
                local v = st[k]
                if type(v) == "table" then
                    local o = im.SliderFloat2(k, { v.x, v.y }, 0, 20, "%.0f")
                    v.x, v.y = o[1], o[2]
                end
            end
            for _, k in ipairs({ "IndentSpacing", "ScrollbarSize", "GrabMinSize" }) do
                if st[k] then st[k] = im.SliderFloat(k, st[k], 1, 30, "%.0f") end
            end
            im.SeparatorText("Borders")
            for _, k in ipairs({ "WindowBorderSize", "ChildBorderSize", "PopupBorderSize", "FrameBorderSize" }) do
                if st[k] then st[k] = im.SliderFloat(k, st[k], 0, 1, "%.0f") end
            end
            im.SeparatorText("Rounding")
            for _, k in ipairs({ "WindowRounding", "ChildRounding", "FrameRounding", "PopupRounding", "ScrollbarRounding", "GrabRounding", "TabRounding" }) do
                if st[k] then st[k] = im.SliderFloat(k, st[k], 0, 12, "%.0f") end
            end
            im.EndTabItem()
        end
        if im.BeginTabItem("Colors") then
            if im.Button("Clear overrides") then S.col_user = {} end
            im.BeginChild("##colors", 0, 0, ImGuiChildFlags.Borders)
            for i = 0, ImGuiCol.COUNT - 1 do
                local c = col(i)
                local nc, ch = im.ColorEdit4(COL_NAMES[i + 1] .. "##col" .. i, { c[1], c[2], c[3], c[4] }, ImGuiColorEditFlags.AlphaBar)
                if ch then S.col_user[i] = nc end
            end
            im.EndChild()
            im.EndTabItem()
        end
        im.EndTabBar()
    end
end

function im.ShowAboutWindow(p_open)
    if p_open == false then return false end
    local open, vis = tool_begin("About Dear ImGui", p_open)
    if vis then
        im.Text("Dear ImGui " .. im.GetVersion())
        im.Separator()
        im.TextWrapped("A Lua re-implementation of the Dear ImGui API that draws with the Nenyoo overlay. "
            .. "Windows follow the active theme; StyleColorsDark / Light / Classic switch to the stock palettes.")
    end
    im.End()
    return open
end

function im.ShowMetricsWindow(p_open)
    if p_open == false then return false end
    local open, vis = tool_begin("Dear ImGui Metrics/Debugger", p_open, 420, 380)
    if vis then
        local io = im.GetIO()
        im.Text("%.1f FPS (%.2f ms/frame)", io.Framerate, (io.DeltaTime or 0) * 1000)
        local nwin, ncmd = 0, 0
        for _, w in ipairs(S.order) do
            if w.last_frame >= S.frame - 1 then nwin = nwin + 1; ncmd = ncmd + #(w.cmds or {}) end
        end
        im.Text("%d active windows, %d draw commands", nwin, ncmd)
        im.Text("Hovered window: %s", S.hover_root and S.hover_root.name or "none")
        im.Text("Active id: %s   Text field: %s", tostring(S.active_id or 0), tostring(S.text_id or 0))
        im.Text("Nav: %s (item %s)", S.nav_active and "active" or "idle", tostring(S.nav_id or 0))
        im.Text("Open popups: %d", #S.popups)
        if im.TreeNode("Windows") then
            for _, w in ipairs(S.order) do
                im.BulletText(string.format("%s  pos %.0f,%.0f  size %.0fx%.0f  %d cmds", tostring(w.name), w.x, w.y, w.w, w.h, #(w.cmds or {})))
            end
            im.TreePop()
        end
    end
    im.End()
    return open
end

function im.ShowDebugLogWindow(p_open)
    if p_open == false then return false end
    local open, vis = tool_begin("Dear ImGui Debug Log", p_open, 360, 200)
    if vis then im.TextDisabled("Script errors are reported as notifications and in the Nenyoo log.") end
    im.End()
    return open
end

function im.ShowIDStackToolWindow(p_open)
    if p_open == false then return false end
    local open, vis = tool_begin("Dear ImGui ID Stack Tool", p_open, 360, 200)
    if vis then
        im.Text("Hovered item: %s", tostring(S.hovered_prev or 0))
        im.Text("Active item: %s", tostring(S.active_id or 0))
    end
    im.End()
    return open
end

local function demo_state()
    local D = S.demo
    if not D then
        D = { check = true, radio = 0, si = 50, sf = 0.5, drag = 10, text = "Hello, world!", multi = "Line one\nLine two\nLine three",
              combo = 0, col = { 0.40, 0.70, 1.00, 1.00 }, prog = 0, clicks = 0, rep = 0,
              rows = {}, dd = { "Apple", "Banana", "Cherry", "Grape" }, tabs = { true, true, true } }
        for i = 1, 30 do D.rows[i] = { id = i, name = "Item " .. i, qty = (i * 37) % 23 } end
        S.demo = D
    end
    return D
end

function im.ShowDemoWindow(p_open)
    if p_open == false then return false end
    local D = demo_state()
    local open, vis = tool_begin("Dear ImGui Demo", p_open, 540, 620)
    if vis then
        im.Text("Dear ImGui %s", im.GetVersion())
        im.Spacing()
        if im.CollapsingHeader("Help") then im.ShowUserGuide() end
        if im.CollapsingHeader("Widgets", ImGuiTreeNodeFlags.DefaultOpen) then
            if im.Button("Button") then D.clicks = D.clicks + 1 end
            im.SameLine(); im.Text("clicked %d times", D.clicks)
            im.PushButtonRepeat(true)
            if im.ArrowButton("##left", ImGuiDir.Left) then D.rep = D.rep - 1 end
            im.SameLine()
            if im.ArrowButton("##right", ImGuiDir.Right) then D.rep = D.rep + 1 end
            im.PopButtonRepeat()
            im.SameLine(); im.Text("hold to repeat: %d", D.rep)
            D.check = im.Checkbox("Checkbox", D.check)
            for i = 0, 2 do
                if i > 0 then im.SameLine() end
                if im.RadioButton("Radio " .. i, D.radio == i) then D.radio = i end
            end
            D.combo = im.Combo("Combo", D.combo, { "Alpha", "Bravo", "Charlie", "Delta" }, 4)
            D.si = im.SliderInt("SliderInt", D.si, 0, 100)
            D.sf = im.SliderFloat("SliderFloat", D.sf, 0, 1, "%.3f")
            D.drag = im.DragInt("DragInt", D.drag, 1, 0, 1000)
            D.text = im.InputText("InputText", D.text, 128)
            if im.IsItemDeactivatedAfterEdit() then im.SameLine(); im.TextDisabled("(committed)") end
            D.multi = im.InputTextMultiline("##multi", D.multi, 4096, -1, im.GetTextLineHeight() * 5)
            D.col = im.ColorEdit4("Color", D.col)
            D.prog = (D.prog + (im.GetIO().DeltaTime or 0) * 0.2) % 1
            im.ProgressBar(D.prog, -1, 0)
        end
        if im.CollapsingHeader("Tables") then
            local F = ImGuiTableFlags
            local flags = F.Resizable | F.Reorderable | F.Hideable | F.Sortable | F.RowBg | F.Borders | F.ScrollY
            if im.BeginTable("demo_table", 3, flags, 0, im.GetTextLineHeightWithSpacing() * 9) then
                im.TableSetupScrollFreeze(0, 1)
                im.TableSetupColumn("ID", ImGuiTableColumnFlags.DefaultSort | ImGuiTableColumnFlags.WidthFixed, 0, 0)
                im.TableSetupColumn("Name", ImGuiTableColumnFlags.WidthStretch, 0, 1)
                im.TableSetupColumn("Quantity", ImGuiTableColumnFlags.WidthFixed, 0, 2)
                im.TableHeadersRow()
                local specs = im.TableGetSortSpecs()
                if specs and specs.SpecsDirty and specs.SpecsCount > 0 then
                    local sp = specs.Specs[1]
                    local key = ({ "id", "name", "qty" })[sp.ColumnIndex + 1]
                    local desc = sp.SortDirection == ImGuiSortDirection.Descending
                    table.sort(D.rows, function(a, b) if desc then return a[key] > b[key] end return a[key] < b[key] end)
                    specs.SpecsDirty = false
                end
                for _, r in ipairs(D.rows) do
                    im.TableNextRow()
                    im.TableNextColumn(); im.Text("%d", r.id)
                    im.TableNextColumn(); im.Selectable(r.name, false, ImGuiSelectableFlags.SpanAllColumns)
                    im.TableNextColumn(); im.Text("%d", r.qty)
                end
                im.EndTable()
            end
        end
        if im.CollapsingHeader("Drag and drop") then
            im.TextDisabled("Drag the buttons to reorder them.")
            for i, name in ipairs(D.dd) do
                if i > 1 then im.SameLine() end
                im.Button(name .. "##dd" .. i, 70, 0)
                if im.BeginDragDropSource() then
                    im.SetDragDropPayload("DEMO_ITEM", i)
                    im.Text("Move %s", name)
                    im.EndDragDropSource()
                end
                if im.BeginDragDropTarget() then
                    local pl = im.AcceptDragDropPayload("DEMO_ITEM")
                    if pl then D.dd[i], D.dd[pl.Data] = D.dd[pl.Data], D.dd[i] end
                    im.EndDragDropTarget()
                end
            end
        end
        if im.CollapsingHeader("Tabs") then
            if im.BeginTabBar("##demo_tabs") then
                for i = 1, 3 do
                    if D.tabs[i] then
                        local o, sel = im.BeginTabItem("Tab " .. i, true)
                        D.tabs[i] = o
                        if sel then im.Text("Contents of tab %d", i); im.EndTabItem() end
                    end
                end
                im.EndTabBar()
            end
            if im.Button("Reopen tabs") then D.tabs = { true, true, true } end
        end
        if im.CollapsingHeader("Popups") then
            if im.Button("Open popup") then im.OpenPopup("demo_popup") end
            if im.BeginPopup("demo_popup") then
                im.Text("A popup")
                if im.Selectable("Close") then end
                im.EndPopup()
            end
            im.SameLine()
            if im.Button("Open modal") then im.OpenPopup("Demo modal") end
            if im.BeginPopupModal("Demo modal", nil, ImGuiWindowFlags.AlwaysAutoResize) then
                im.Text("Modal windows block everything behind them.")
                if im.Button("OK", 120, 0) then im.CloseCurrentPopup() end
                im.SetItemDefaultFocus()
                im.EndPopup()
            end
        end
        if im.CollapsingHeader("Style") then im.ShowStyleEditor() end
    end
    im.End()
    return open
end

-- ── draw lists ───────────────────────────────────────────────────────────────
-- Coordinates are absolute screen pixels. Colours: u32 (ImGui.GetColorU32 / IM_COL32) or {r,g,b,a} floats.

local function dl_col(c)
    if type(c) == "table" then return to_f4(c) end
    return u32_to_f4(c or 0xFFFFFFFF)
end

local DrawList = {}
DrawList.__index = DrawList
local function make_dl(kind) return setmetatable({ kind = kind }, DrawList) end
local function dl_target(self)
    if self.kind == "bg" then return S.bg_cmds end
    if self.kind == "fg" then return S.fg_cmds end
    return (S.cur and S.cur.root.cmds) or S.fg_cmds
end
local function dl_draw(self, fn)
    -- draw-list primitives ignore the disabled fade and style alpha
    local d, a = S.disabled, S.style.Alpha
    S.disabled, S.style.Alpha = 0, 1
    fn(dl_target(self))
    S.disabled, S.style.Alpha = d, a
end
function DrawList:AddLine(...)
    local a = { ... }
    local x1, y1, i = vec_args(a, 1)
    local x2, y2, j = vec_args(a, i)
    local c, th = a[j], a[j + 1]
    dl_draw(self, function(L) r_line(L, x1, y1, x2, y2, dl_col(c), th or 1) end)
end
function DrawList:AddRect(...)
    local a = { ... }
    local x1, y1, i = vec_args(a, 1)
    local x2, y2, j = vec_args(a, i)
    local c, rnd, _, th = a[j], a[j + 1], a[j + 2], a[j + 3]
    dl_draw(self, function(L) r_outline(L, x1, y1, x2, y2, dl_col(c), rnd or 0, th or 1) end)
end
function DrawList:AddRectFilled(...)
    local a = { ... }
    local x1, y1, i = vec_args(a, 1)
    local x2, y2, j = vec_args(a, i)
    local c, rnd = a[j], a[j + 1]
    dl_draw(self, function(L) r_rect(L, x1, y1, x2, y2, dl_col(c), rnd or 0) end)
end
function DrawList:AddRectFilledMultiColor(...)
    local a = { ... }
    local x1, y1, i = vec_args(a, 1)
    local x2, y2, j = vec_args(a, i)
    local function c8(c) local f = dl_col(c); return { floor(f[1] * 255), floor(f[2] * 255), floor(f[3] * 255), floor(f[4] * 255) } end
    local tl, tr, br, bl = c8(a[j]), c8(a[j + 1]), c8(a[j + 2]), c8(a[j + 3])
    local L = dl_target(self)
    r_grad(L, x1, y1, x2, y2, tl, tr, br, bl)
end
function DrawList:AddCircle(...)
    local a = { ... }
    local x, y, i = vec_args(a, 1)
    local rad, c, _, th = a[i], a[i + 1], a[i + 2], a[i + 3]
    dl_draw(self, function(L) r_circle(L, x, y, rad or 1, dl_col(c), false, th or 1) end)
end
function DrawList:AddCircleFilled(...)
    local a = { ... }
    local x, y, i = vec_args(a, 1)
    local rad, c = a[i], a[i + 1]
    dl_draw(self, function(L) r_circle(L, x, y, rad or 1, dl_col(c), true) end)
end
DrawList.AddNgon, DrawList.AddNgonFilled = DrawList.AddCircle, DrawList.AddCircleFilled
-- AddText(pos, col, text) | AddText(x, y, col, text)
function DrawList:AddText(...)
    local a = { ... }
    local x, y, j = vec_args(a, 1)
    local c, str = a[j], a[j + 1]
    if type(c) == "string" then c, str = str, c end
    dl_draw(self, function(L) r_text(L, x, y, tostring(str or ""), dl_col(c)) end)
end
function DrawList:AddTriangle(...)
    local a = { ... }
    local x1, y1, i = vec_args(a, 1)
    local x2, y2, j = vec_args(a, i)
    local x3, y3, k = vec_args(a, j)
    local c, th = dl_col(a[k]), a[k + 1] or 1
    dl_draw(self, function(L) r_line(L, x1, y1, x2, y2, c, th); r_line(L, x2, y2, x3, y3, c, th); r_line(L, x3, y3, x1, y1, c, th) end)
end
function DrawList:AddTriangleFilled(...)
    local a = { ... }
    local x1, y1, i = vec_args(a, 1)
    local x2, y2, j = vec_args(a, i)
    local x3, y3, k = vec_args(a, j)
    local c = dl_col(a[k])
    -- no filled-polygon primitive: scanline fill with horizontal lines
    dl_draw(self, function(L)
        local pts = { { x1, y1 }, { x2, y2 }, { x3, y3 } }
        table.sort(pts, function(p, q) return p[2] < q[2] end)
        local ya, yb = pts[1][2], pts[3][2]
        local function edge(p, q, yy) if q[2] == p[2] then return p[1] end return p[1] + (q[1] - p[1]) * (yy - p[2]) / (q[2] - p[2]) end
        for yy = floor(ya), floor(yb) do
            local xa = edge(pts[1], pts[3], yy)
            local xb = (yy < pts[2][2]) and edge(pts[1], pts[2], yy) or edge(pts[2], pts[3], yy)
            r_line(L, min(xa, xb), yy + 0.5, max(xa, xb), yy + 0.5, c, 1)
        end
    end)
end
function DrawList:AddQuad(...)
    local a = { ... }
    local x1, y1, i = vec_args(a, 1)
    local x2, y2, j = vec_args(a, i)
    local x3, y3, k = vec_args(a, j)
    local x4, y4, l = vec_args(a, k)
    local c, th = dl_col(a[l]), a[l + 1] or 1
    dl_draw(self, function(L) r_line(L, x1, y1, x2, y2, c, th); r_line(L, x2, y2, x3, y3, c, th); r_line(L, x3, y3, x4, y4, c, th); r_line(L, x4, y4, x1, y1, c, th) end)
end
function DrawList:AddQuadFilled(...)
    local a = { ... }
    local x1, y1, i = vec_args(a, 1)
    local x2, y2, j = vec_args(a, i)
    local x3, y3, k = vec_args(a, j)
    local x4, y4, l = vec_args(a, k)
    self:AddTriangleFilled(x1, y1, x2, y2, x3, y3, a[l])
    self:AddTriangleFilled(x1, y1, x3, y3, x4, y4, a[l])
end
function DrawList:AddPolyline(points, c, flags, th)
    local cc = dl_col(c)
    dl_draw(self, function(L)
        for i = 2, #points do
            local p, q = points[i - 1], points[i]
            r_line(L, p.x or p[1], p.y or p[2], q.x or q[1], q.y or q[2], cc, th or 1)
        end
        if has(flags, 1) and #points > 2 then
            local p, q = points[#points], points[1]
            r_line(L, p.x or p[1], p.y or p[2], q.x or q[1], q.y or q[2], cc, th or 1)
        end
    end)
end
function DrawList:AddBezierCubic(...)
    local a = { ... }
    local x1, y1, i = vec_args(a, 1)
    local x2, y2, j = vec_args(a, i)
    local x3, y3, k = vec_args(a, j)
    local x4, y4, l = vec_args(a, k)
    local c, th, seg = dl_col(a[l]), a[l + 1] or 1, a[l + 2] or 20
    if seg <= 0 then seg = 20 end
    dl_draw(self, function(L)
        local px, py = x1, y1
        for s = 1, seg do
            local t = s / seg
            local u = 1 - t
            local qx = u * u * u * x1 + 3 * u * u * t * x2 + 3 * u * t * t * x3 + t * t * t * x4
            local qy = u * u * u * y1 + 3 * u * u * t * y2 + 3 * u * t * t * y3 + t * t * t * y4
            r_line(L, px, py, qx, qy, c, th)
            px, py = qx, qy
        end
    end)
end
function DrawList:AddImage(handle, ...)
    local a = { ... }
    local x1, y1, i = vec_args(a, 1)
    local x2, y2, j = vec_args(a, i)
    local tint = a[j + 4] or a[j]
    local L = dl_target(self)
    r_image(L, handle, x1, y1, x2, y2, (type(tint) == "number" and tint ~= 0xFFFFFFFF) and u32_to_f4(tint) or nil)
end
function DrawList:AddImageRounded(handle, ...) self:AddImage(handle, ...) end
function DrawList:PushClipRect(...)
    local a = { ... }
    local x1, y1, i = vec_args(a, 1)
    local x2, y2 = vec_args(a, i)
    r_clip(dl_target(self), x1, y1, x2, y2)
end
function DrawList:PopClipRect() r_unclip(dl_target(self)) end

local DL_WINDOW, DL_BG, DL_FG = make_dl("window"), make_dl("bg"), make_dl("fg")

-- sol_ImGui free-function forms: ImGui.ImDrawListAddLine(drawList, ...) == drawList:AddLine(...)
for name, fn in pairs(DrawList) do
    if type(fn) == "function" and name:sub(1, 2) ~= "__" then
        im["ImDrawList" .. name] = function(dl, ...) return fn(dl, ...) end
    end
end
-- PushClipRect(min, max[, intersect]) / PopClipRect() on the current window's draw list
function im.PushClipRect(...) DL_WINDOW:PushClipRect(...) end
function im.PopClipRect() DL_WINDOW:PopClipRect() end

function im.GetWindowDrawList() return DL_WINDOW end
function im.GetBackgroundDrawList() return DL_BG end
function im.GetForegroundDrawList() return DL_FG end

-- IM_COL32(r, g, b, a) with 0..255 ints, as in C++
function IM_COL32(r, g, b, a)
    return (floor(a == nil and 255 or a) << 24) | (floor(b or 0) << 16) | (floor(g or 0) << 8) | floor(r or 0)
end
function ImVec2(x, y) return { x = x or 0, y = y or 0 } end
function ImVec4(x, y, z, w) return { x = x or 0, y = y or 0, z = z or 0, w = w or 0, x, y, z, w } end

-- ── fallback: unknown ImGui.* calls degrade to a no-op instead of erroring ───

setmetatable(im, {
    __index = function(_, k)
        if type(k) == "string" and k:match("^%u") then
            return function() return false end
        end
        return nil
    end,
})
