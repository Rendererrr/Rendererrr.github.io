-- Drone Swarm Control HUD. Runtime data is published by world_drone_swarm::draw.

local MODE = { [0] = "PILOT", [1] = "COMMANDER" }
local FORMATION = { [0] = "V", [1] = "LINE", [2] = "RING", [3] = "DOUBLE RING" }
local WEAPON = { [0] = "STUN", [1] = "MG", [2] = "MINIGUN", [3] = "HEAVY SNIPER", [4] = "RAY PISTOL" }
local COMMAND = { [0] = "FOLLOW", [1] = "MOVE", [2] = "ATTACK" }

features.on_draw("Drone Swarm", function(f)
    if not f.active then return end

    local sw, sh = ctx.screen_w(), ctx.screen_h()
    local scale = math.max(0.75, math.min(1.6, sh / 1080))
    local orange_r, orange_g, orange_b = 226, 97, 42
    local x, y = 28 * scale, 35 * scale
    local width, height = 245 * scale, 105 * scale

    draw.rect(x, y, x + width, y + height, 5, 8, 12, 185, 4)
    draw.rect(x, y, x + 3 * scale, y + height, orange_r, orange_g, orange_b, 255, 1)
    text.draw_spaced(font.small, x + 13 * scale, y + 10 * scale,
                     orange_r, orange_g, orange_b, 245, "DRONE SWARM", 2 * scale)

    local mode = math.floor(f.mode or 0)
    local formation = math.floor(f.formation or 0)
    local weapon = math.floor(f.weapon or 0)
    local command = math.floor(f.command or 0)
    local live = math.floor(f.live or 0)
    local desired = math.floor(f.desired or 0)
    local status = string.format("%s   %d/%d ONLINE", MODE[mode] or "PILOT", live, desired)
    text.draw(font.tiny, x + 13 * scale, y + 37 * scale, 235, 240, 245, 235, status)
    text.draw(font.tiny, x + 13 * scale, y + 57 * scale, 185, 195, 205, 225,
              string.format("%s   |   %s", FORMATION[formation] or "V", WEAPON[weapon] or "STUN"))

    local order = COMMAND[command] or "FOLLOW"
    local ordr, ordg, ordb = 120, 205, 255
    if command == 2 and f.target_valid then ordr, ordg, ordb = 255, 90, 75 end
    text.draw_spaced(font.tiny, x + 13 * scale, y + 79 * scale,
                     ordr, ordg, ordb, 240, "ORDER  " .. order, 1.5 * scale)

    local telemetry = string.format("SPD %.1f   ALT %.1f   HOME %.0fM",
                                    f.speed or 0, f.altitude or 0, f.distance or 0)
    local tw = text.width(font.tiny, telemetry)
    text.draw(font.tiny, sw - tw - 28 * scale, sh - 32 * scale,
              220, 225, 230, 220, telemetry)

    if mode ~= 0 then
        local hint = "AIM + ATTACK: MOVE / TARGET"
        text.draw(font.tiny, sw * 0.5 - text.width(font.tiny, hint) * 0.5,
                  sh - 32 * scale, 180, 195, 210, 215, hint)
        return
    end

    local cx, cy = sw * 0.5, sh * 0.5
    local size = 13 * scale * (f.reticle_size or 1)
    local gap = 5 * scale
    draw.line(cx - size, cy, cx - gap, cy, orange_r, orange_g, orange_b, 235, 1.5)
    draw.line(cx + gap, cy, cx + size, cy, orange_r, orange_g, orange_b, 235, 1.5)
    draw.line(cx, cy - size, cx, cy - gap, orange_r, orange_g, orange_b, 235, 1.5)
    draw.line(cx, cy + gap, cx, cy + size, orange_r, orange_g, orange_b, 235, 1.5)
    draw.circle(cx, cy, 2 * scale, orange_r, orange_g, orange_b, 235)

    local hint = "MOVE: WASD   RISE: JUMP   DESCEND: SPRINT   FIRE: ATTACK"
    text.draw(font.tiny, sw * 0.5 - text.width(font.tiny, hint) * 0.5,
              sh - 32 * scale, 180, 195, 210, 215, hint)
end)
