features.on_draw("Minigames", function(f)
    if not f.active then return end

    local sw, sh = ctx.screen_w(), ctx.screen_h()
    local ar, ag, ab = theme.accent()

    if (f.countdown or 0) > 0 then
        local value = tostring(math.floor(f.countdown))
        text.draw(font.title, sw * 0.5 - 18, sh * 0.30, ar, ag, ab, 255, value)
        return
    end

    if f.results then
        local title = f.dance and f.dance_draw and "DRAW" or (f.won and "VICTORY" or "GAME OVER")
        local neutral = f.dance and f.dance_draw
        local r, g, b = neutral and ar or (f.won and 70 or 240), neutral and ag or (f.won and 220 or 65), neutral and ab or (f.won and 110 or 65)
        draw.rect(sw * 0.5 - 170, sh * 0.34, sw * 0.5 + 170, sh * 0.34 + 112, 10, 10, 16, 225, 8)
        draw.rect(sw * 0.5 - 170, sh * 0.34, sw * 0.5 + 170, sh * 0.34 + 4, r, g, b, 255, 4)
        text.draw(font.title, sw * 0.5 - 72, sh * 0.34 + 20, r, g, b, 255, title)
        local score = f.dance and ("You " .. math.floor(f.dance_player_score or 0) .. "  -  " .. math.floor(f.dance_opponent_score or 0) .. " Rival") or ("Score: " .. math.floor(f.score or 0))
        text.draw(font.item, sw * 0.5 - 80, sh * 0.34 + 58, 235, 235, 240, 255, score)
        text.draw(font.item, sw * 0.5 - 80, sh * 0.34 + 80, 175, 175, 185, 255, "Best: " .. math.floor(f.best or 0))
        return
    end

    if f.dance then
        local x, y, w, h = sw * 0.5 - 250, sh * 0.12, 500, 176
        local phase = math.floor(f.dance_phase or 0)
        local phase_text = phase == 1 and "WATCH" or (phase == 2 and "GET READY" or (phase == 3 and "YOUR TURN" or "ROUND COMPLETE"))
        draw.rect(x, y, x + w, y + h, 10, 10, 16, 225, 8)
        draw.rect(x, y, x + w, y + 4, ar, ag, ab, 255, 3)
        text.draw(font.title, x + 18, y + 14, ar, ag, ab, 255, "DANCE BATTLE")
        text.draw(font.item, x + w - 125, y + 18, 225, 225, 232, 255, "ROUND " .. math.floor(f.dance_round or 1) .. " / 3")
        text.draw(font.item, x + 18, y + 47, 245, 245, 250, 255, phase_text)
        text.draw(font.item, x + w - 205, y + 47, 205, 205, 214, 255,
            "YOU " .. math.floor(f.dance_player_score or 0) .. "  -  " .. math.floor(f.dance_opponent_score or 0) .. " RIVAL")

        local moves = { "W", "D", "S", "A" }
        local sequence = { f.d0, f.d1, f.d2, f.d3, f.d4, f.d5, f.d6, f.d7 }
        local count = math.floor(f.dance_sequence_length or 0)
        local revealed = math.floor(f.dance_sequence_revealed or 0)
        local slot_w = 44
        local total_w = count * slot_w
        local sx = x + (w - total_w) * 0.5
        for i = 1, count do
            local shown = phase >= 3 or i <= revealed
            local value = shown and moves[(math.floor(sequence[i] or -1) + 1)] or "?"
            local active = phase == 3 and i == math.floor(f.dance_response_index or 0) + 1
            local sr, sg, sb = active and ar or 38, active and ag or 38, active and ab or 48
            draw.rect(sx + (i - 1) * slot_w, y + 78, sx + (i - 1) * slot_w + 36, y + 114, sr, sg, sb, 245, 5)
            text.draw(font.item, sx + (i - 1) * slot_w + 12, y + 87, 245, 245, 250, 255, value or "?")
        end

        local feedback = math.floor(f.dance_feedback or 0)
        local feedback_text = feedback == 1 and "PERFECT" or (feedback == 2 and "GOOD" or (feedback == 3 and "WRONG" or (feedback == 4 and "MISS" or "")))
        local fr, fg, fb = feedback >= 3 and 240 or ar, feedback >= 3 and 70 or ag, feedback >= 3 and 70 or ab
        if feedback_text ~= "" then
            text.draw(font.item, x + 18, y + 130, fr, fg, fb, 255, feedback_text)
        elseif phase == 3 then
            local expected = moves[(math.floor(f.dance_expected or -1) + 1)] or "?"
            text.draw(font.item, x + 18, y + 130, 225, 225, 232, 255, "PRESS " .. expected)
        end
        text.draw(font.item, x + w - 122, y + 130, 205, 205, 214, 255, "COMBO x" .. math.floor(f.dance_combo or 0))
        local p = math.max(0, math.min(1, f.dance_timing or 0))
        draw.rect(x + 18, y + 157, x + w - 18, y + 164, 42, 42, 50, 230, 3)
        if phase == 3 then
            draw.rect(x + 18, y + 157, x + 18 + (w - 36) * p, y + 164, ar, ag, ab, 245, 3)
        end
        return
    end

    local x, y, w, h = 24, sh * 0.17, 330, 142
    draw.rect(x, y, x + w, y + h, 10, 10, 16, 218, 7)
    draw.rect(x, y, x + 4, y + h, ar, ag, ab, 255, 4)
    draw.rect(x + 4, y, x + w, y + 3, ar, ag, ab, 210, 2)

    text.draw(font.title, x + 18, y + 14, ar, ag, ab, 255, f.title or "Minigame")
    text.draw(font.item, x + 18, y + 45, 215, 215, 222, 255, f.objective or "")
    text.draw(font.item, x + 18, y + 70, 240, 240, 245, 255, f.status or "")

    local seconds = math.floor((f.time_ms or 0) / 1000)
    local timer = string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
    text.draw(font.item, x + 18, y + 95, 175, 175, 185, 255, timer)
    text.draw(font.item, x + w - 105, y + 95, 235, 235, 240, 255, "Score " .. math.floor(f.score or 0))

    local p = math.max(0, math.min(1, f.progress or 0))
    draw.rect(x + 18, y + 121, x + w - 18, y + 128, 42, 42, 50, 230, 3)
    draw.rect(x + 18, y + 121, x + 18 + (w - 36) * p, y + 128, ar, ag, ab, 245, 3)
end)
