-----------------------------------
-- LQS Util: doomRoulette
-----------------------------------
-- Random player gets Doom. Must run to a cleanse marker (DE) to remove it.
-- Mob heals if fought near the cleanse marker (prevents camping on it).
-- Auto-creates cleanse marker NPC entities.
--
-- config:
--   doomDuration    (number)  seconds before doom kills (default 30)
--   cleanseRadius   (number)  distance to marker to cleanse (default 5)
--   cleanseLook     (number)  NPC model for cleanse marker (default 2175)
--   cleansePositions(table)   array of { x, y, z, rot } for markers
--   cooldown        (number)  seconds between doom applications (default 45)
--   healPerTick     (number)  mob heals per tick when near marker (default 3000)
--   healRadius      (number)  how close mob must be to marker (default 12)
--   tickInterval    (number)  seconds between checks (default 2)
--   telegraph       (string)  message when doom applied (use %s for player name)
--   cleanseMessage  (string)  message when doom cleansed (use %s for player name)
-----------------------------------
require("modules/module_utils")
-----------------------------------
local m = Module:new("LQS_util_doomRoulette")

LQS      = LQS or {}
LQS.util = LQS.util or {}

local function getCleanseMarkers(mob, count)
    local zone    = mob:getZone()
    local markers = {}
    for i = 1, count do
        local result = zone:queryEntitiesByName("DE_" .. mob:getPacketName() .. "_Cleanse_" .. i)
        if result and result[1] then
            table.insert(markers, result[1])
        end
    end
    return markers
end

LQS.util.doomRoulette = function(config)
    local markerCount = config.cleansePositions and #config.cleansePositions or 1

    return {
        entities = function(mobEntity)
            local markers = {}
            for i = 1, markerCount do
                local pos = config.cleansePositions[i] or { 1, 1, 1, 0 }
                table.insert(markers, {
                    name          = mobEntity.name .. "_Cleanse_" .. i,
                    type          = xi.objType.NPC,
                    look          = config.cleanseLook or 2175,
                    pos           = pos,
                    hidden        = true,
                    _isUtilEntity = true,
                    _parentMob    = mobEntity.name,
                })
            end
            return markers
        end,

        onMobSpawn = function(mob)
            local markers = getCleanseMarkers(mob, markerCount)
            for _, marker in ipairs(markers) do
                marker:setStatus(xi.status.NORMAL)
            end
        end,

        onMobFight = function(mob, target)
            local now = os.time()
            if now - mob:getLocalVar("[DOOM]lastTick") < (config.tickInterval or 2) then return end
            mob:setLocalVar("[DOOM]lastTick", now)

            local markers = getCleanseMarkers(mob, markerCount)

            -- Mob healing near cleanse markers
            for _, marker in ipairs(markers) do
                if LQS.util.distance(mob, marker) <= (config.healRadius or 12) then
                    mob:addHP(config.healPerTick or 3000)
                    break
                end
            end

            -- Cleanse doomed players near markers
            LQS.util.forEachEngaged(mob, function(player)
                if player:hasStatusEffect(xi.effect.DOOM) then
                    for _, marker in ipairs(markers) do
                        if LQS.util.distance(player, marker) <= (config.cleanseRadius or 5) then
                            player:delStatusEffect(xi.effect.DOOM)
                            if config.cleanseMessage then
                                LQS.util.shout(mob, string.format(config.cleanseMessage, player:getName()))
                            end
                            return
                        end
                    end
                end
            end)

            -- Apply doom if nobody currently doomed and off cooldown
            if now < mob:getLocalVar("[DOOM]nextAt") then return end

            local anyDoomed = false
            LQS.util.forEachEngaged(mob, function(player)
                if player:hasStatusEffect(xi.effect.DOOM) then
                    anyDoomed = true
                end
            end)
            if anyDoomed then return end

            local victim = LQS.util.randomEngaged(mob)
            if victim == nil then return end

            victim:addStatusEffect(xi.effect.DOOM, 1, 0, config.doomDuration or 30)
            mob:setLocalVar("[DOOM]nextAt", now + (config.cooldown or 45))

            if config.telegraph then
                LQS.util.shout(mob, string.format(config.telegraph, victim:getName()))
            end
        end,

        onMobDeath = function(mob)
            local markers = getCleanseMarkers(mob, markerCount)
            for _, marker in ipairs(markers) do
                marker:setStatus(xi.status.DISAPPEAR)
            end

            LQS.util.forEachEngaged(mob, function(player)
                if player:hasStatusEffect(xi.effect.DOOM) then
                    player:delStatusEffect(xi.effect.DOOM)
                end
            end)
        end,
    }
end

return m
