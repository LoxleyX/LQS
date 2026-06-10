-----------------------------------
-- LQS Util: tether (Chain Lightning)
-----------------------------------
-- Two random players get tethered. While close together, chain lightning
-- hits them and anyone nearby. They must spread apart to break the tether.
--
-- config:
--   breakDistance  (number)  distance to break the tether (default 15)
--   chainRadius   (number)  chain lightning AoE radius around each target (default 8)
--   tickDamage    (number)  damage per tick to tethered players (default 100)
--   chainDamage   (number)  damage to others caught in chain (default 200)
--   tickInterval  (number)  seconds between ticks (default 3)
--   cooldown      (number)  seconds before next tether after break (default 30)
--   maxDuration   (number)  max seconds before tether auto-breaks (default 30)
--   effect        (number)  status effect applied to tethered players as indicator
--   telegraph     (string)  message when tether forms (use %s for player names)
--   breakMessage  (string)  message when tether breaks
-----------------------------------
require("modules/module_utils")
-----------------------------------
local m = Module:new("LQS_util_tether")

LQS      = LQS or {}
LQS.util = LQS.util or {}

local function breakTether(mob, config)
    mob:setLocalVar("[TETHER]state", 0)
    mob:setLocalVar("[TETHER]nextAt", os.time() + (config.cooldown or 30))

    local effect = config.effect or xi.effect.SHOCK
    local p1 = GetPlayerByID(mob:getLocalVar("[TETHER]p1"))
    local p2 = GetPlayerByID(mob:getLocalVar("[TETHER]p2"))
    if p1 and p1:hasStatusEffect(effect) then p1:delStatusEffect(effect) end
    if p2 and p2:hasStatusEffect(effect) then p2:delStatusEffect(effect) end

    if config.breakMessage then
        LQS.util.shout(mob, config.breakMessage)
    end
end

LQS.util.tether = function(config)
    return {
        onMobFight = function(mob, target)
            local now   = os.time()
            local state = mob:getLocalVar("[TETHER]state")

            if state == 0 then
                local nextAt = mob:getLocalVar("[TETHER]nextAt")
                if now < nextAt then return end

                local candidates = {}
                LQS.util.forEachEngaged(mob, function(player)
                    table.insert(candidates, player)
                end)
                if #candidates < 2 then return end

                local i = math.random(1, #candidates)
                local j = i
                while j == i do j = math.random(1, #candidates) end

                local p1 = candidates[i]
                local p2 = candidates[j]

                mob:setLocalVar("[TETHER]state", 1)
                mob:setLocalVar("[TETHER]p1", p1:getID())
                mob:setLocalVar("[TETHER]p2", p2:getID())
                mob:setLocalVar("[TETHER]startedAt", now)
                mob:setLocalVar("[TETHER]lastTick", now)

                local effect = config.effect or xi.effect.SHOCK
                if not p1:hasStatusEffect(effect) then
                    p1:addStatusEffect(effect, 1, 0, config.maxDuration or 30)
                end
                if not p2:hasStatusEffect(effect) then
                    p2:addStatusEffect(effect, 1, 0, config.maxDuration or 30)
                end

                if config.telegraph then
                    LQS.util.shout(mob, string.format(config.telegraph, p1:getName(), p2:getName()))
                end
                return
            end

            -- Active: tick the tether
            local lastTick = mob:getLocalVar("[TETHER]lastTick")
            local interval = config.tickInterval or 3
            if now - lastTick < interval then return end
            mob:setLocalVar("[TETHER]lastTick", now)

            local p1 = GetPlayerByID(mob:getLocalVar("[TETHER]p1"))
            local p2 = GetPlayerByID(mob:getLocalVar("[TETHER]p2"))

            local startedAt   = mob:getLocalVar("[TETHER]startedAt")
            local maxDuration = config.maxDuration or 30

            if p1 == nil or p2 == nil or not p1:isAlive() or not p2:isAlive() or (now - startedAt >= maxDuration) then
                breakTether(mob, config)
                return
            end

            if LQS.util.distance(p1, p2) >= (config.breakDistance or 15) then
                breakTether(mob, config)
                return
            end

            -- Chain lightning
            p1:takeDamage(config.tickDamage or 100, mob)
            p2:takeDamage(config.tickDamage or 100, mob)

            local chainRadius = config.chainRadius or 8
            local chainDmg    = config.chainDamage or 200
            local p1Id = p1:getID()
            local p2Id = p2:getID()

            LQS.util.forEachEngaged(mob, function(player)
                if player:getID() == p1Id or player:getID() == p2Id then return end
                if LQS.util.distance(player, p1) <= chainRadius or LQS.util.distance(player, p2) <= chainRadius then
                    player:takeDamage(chainDmg, mob)
                end
            end)
        end,

        onMobDeath = function(mob)
            breakTether(mob, config)
        end,
    }
end

return m
