
-- Wardrobe live ped preview. Published by C++ (pedops::wardrobe_draw):
--   focus             : the cursor is on an editing row (zoom in on the slot being edited)
--   prop, slot        : which prop slot / component slot the cursor is editing
--   label             : category folder name ("tops", "hats", ...) or ""
--   drawable, texture : numbers
-- The ped is a live clone of the wardrobe ped (outfit + the highlighted prop row), drawn by the game
-- through wardrobe.draw_ped -- the same preview the Advanced Editor uses, so it works for every model.
-- Only dispatched while the Wardrobe page is open, so no page check is needed here.

-- Camera framing per body region: dist = how far back the ped sits (larger = smaller), raise = how
-- high it sits (larger = ped moves up, so a lower body part comes into view). Tune freely.
local FRAMING = {
    full   = { dist = 3.10, raise = -0.02 },
    head   = { dist = 2.05, raise = -0.99 },
    torso  = { dist = 2.36, raise = -0.55 },
    wrists = { dist = 2.29, raise = -0.27 },
    legs   = { dist = 2.47, raise =  0.23 },
    feet   = { dist = 2.05, raise =  0.53 },
}

-- Component id -> region (0 head, 1 mask, 2 hair, 3 arms, 4 legs, 5 bags, 6 shoes, 7 neck,
-- 8 undershirt, 9 armor, 10 decals, 11 top).
local COMPONENT_REGION = {
    [0] = "head", [1] = "head", [2] = "head", [3] = "torso", [4] = "legs", [5] = "torso",
    [6] = "feet", [7] = "torso", [8] = "torso", [9] = "torso", [10] = "torso", [11] = "torso",
}
-- Prop id -> region (0 hat, 1 glasses, 2 ears, 6 watch, 7 bracelet).
local PROP_REGION = { [0] = "head", [1] = "head", [2] = "head", [6] = "wrists", [7] = "wrists" }

local cam_dist, cam_raise = FRAMING.full.dist, FRAMING.full.raise
local heading = 0
local dragging, drag_x = false, 0

local function region_for(f)
    if not f.focus then return "full" end
    local slot = math.floor(f.slot or -1)
    local r = f.prop and PROP_REGION[slot] or (not f.prop and COMPONENT_REGION[slot])
    return r or "full"
end

features.on_draw("Wardrobe Preview", function(f)
    local pad   = 10
    local pw    = 230
    local vh    = 330                                   -- viewport height (portrait)
    local th    = text.height(font.item) + 6            -- title row
    local ch    = text.height(font.small) + 4           -- caption row
    local hh    = text.height(font.tiny) + 2            -- hint row
    local ph    = pad + th + vh + 6 + ch + hh + pad

    local sw, sh = ctx.screen_w(), ctx.screen_h()
    local bx, by, bw = menu.bounds()
    local gap = 12
    local x, y
    if bw and bw > 0 then
        -- Dock on whichever side of the menu has room.
        if (bx + bw * 0.5) < sw * 0.5 then x = bx + bw + gap else x = bx - gap - pw end
        y = by
    else
        x = sw - pw - 24; y = 120                       -- fallback: right edge
    end
    if x < 8 then x = 8 elseif x + pw > sw - 8 then x = sw - 8 - pw end
    if y < 8 then y = 8 elseif y + ph > sh - 8 then y = sh - 8 - ph end

    local vx0, vy0 = x + pad, y + pad + th
    local vx1, vy1 = x + pw - pad, vy0 + vh

    -- Ease the camera toward the region being edited instead of snapping.
    local target = FRAMING[region_for(f)] or FRAMING.full
    local dt = math.min(ctx.delta() or 0.016, 0.1)
    local k = 1 - math.exp(-dt * 8)
    cam_dist  = cam_dist  + (target.dist  - cam_dist)  * k
    cam_raise = cam_raise + (target.raise - cam_raise) * k

    -- Drag across the viewport to turn the ped; right-click it to face the camera again.
    local mx, my = input.mouse_x(), input.mouse_y()
    local inside = mx >= vx0 and mx <= vx1 and my >= vy0 and my <= vy1
    if inside and input.mouse_clicked(0) then dragging, drag_x = true, mx end
    if dragging then
        if input.mouse_down(0) then
            heading = (heading + (mx - drag_x) * 0.8) % 360
            drag_x = mx
        else
            dragging = false
        end
    end
    if inside and input.mouse_clicked(1) then heading = 0 end

    -- The ped and its backdrop are composited by the GAME underneath this overlay, so the viewport is
    -- left unfilled -- a draw.rect over it would paint straight over the ped. Only the chrome is ours.
    draw.rect(x, y, x + pw, vy0, 16, 16, 22, 235, 0)                 -- header strip
    draw.rect(x, vy1, x + pw, y + ph, 16, 16, 22, 235, 0)            -- caption strip
    draw.rect(x, vy0, vx0, vy1, 16, 16, 22, 235, 0)                  -- left margin
    draw.rect(vx1, vy0, x + pw, vy1, 16, 16, 22, 235, 0)             -- right margin

    local ar, ag, ab = theme.accent()
    draw.rect(x, y, x + pw, y + 2, ar, ag, ab, 255, 0)
    local L = str.preview_wardrobe()
    text.draw(font.item, x + pad, y + pad - 1, 235, 235, 240, 255, string.upper(L.title))

    local ok = wardrobe.draw_ped(vx0 / sw, vy0 / sh, (vx1 - vx0) / sw, (vy1 - vy0) / sh,
                                 cam_dist, cam_raise, heading)
    if not ok then
        draw.rect(vx0, vy0, vx1, vy1, 26, 26, 32, 255, 0)
        local msg = L.no_preview
        text.draw(font.small, vx0 + ((vx1 - vx0) - text.width(font.small, msg)) * 0.5,
                  vy0 + ((vy1 - vy0) - text.height(font.small)) * 0.5, 150, 150, 160, 255, msg)
    end
    local oa = (inside or dragging) and 255 or 150
    draw.rect_outline(vx0, vy0, vx1, vy1, dragging and ar or 60, dragging and ag or 60, dragging and ab or 70, oa, 4, 1)

    local cap = "-"
    if f.label and f.label ~= "" then
        cap = string.format("%s  #%d / %s %d", f.label, math.floor(f.drawable or 0), L.tex, math.floor(f.texture or 0))
    end
    text.draw(font.small, x + pad, vy1 + 6, ar, ag, ab, 255, cap)
    text.draw(font.tiny, x + pad, vy1 + 6 + ch, 140, 142, 156, 220, L.rotate_hint)
end)
