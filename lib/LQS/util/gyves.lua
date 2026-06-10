-----------------------------------
-- LQS Util: gyves (Spread Mechanic)
-----------------------------------
-- Players must stand on separate gyve positions around the mob.
-- Unoccupied gyves heal the boss. All empty = wipe after timeout.
-- Each gyve applies a debuff to its occupant.
-- Auto-creates hidden gyve NPC entities alongside the mob.
--
-- config:
--   look         (number)  NPC model ID (default 2141 = dark/purple circle)
--   count        (number)  number of gyves
--   positions    (table)   array of { x, y, z, rot } per gyve
--   healPerTick  (number)  HP healed per empty gyve per tick
--   wipeTimer    (number)  ticks with ALL empty before wipe
--   wipeDamage   (number)  damage on wipe (default 9999)
--   tickDamage   (number)  damage per tick to occupants
--   tickInterval (number)  seconds between checks (default 5)
--   occupyRadius (number)  distance to count as occupied (default 4)
--   auras        (table)   { [1] = xi.effect.X, [2] = xi.effect.Y, ... }
--   activateAt   (number)  HP% to show gyves (e.g. 50)
--   deactivateAt (number)  HP% to hide gyves (e.g. 25)
--   onActivate   (function) callback(mob) when gyves activate
--   onDeactivate (function) callback(mob) when gyves deactivate
-----------------------------------
require("modules/module_utils")
-----------------------------------
local m = Module:new("LQS_util_gyves")

LQS      = LQS or {}
LQS.util = LQS.util or {}

local function getGyveNpcs(mob, count)
    local zone     = mob:getZone()
    local gyveNpcs = {}
    for i = 1, count do
        local result = zone:queryEntitiesByName("DE_" .. mob:getPacketName() .. "_Gyve_" .. i)
        if result and result[1] then
            gyveNpcs[i] = result[1]
        end
    end
    return gyveNpcs
end

local function setGyveVisibility(mob, count, visible)
    local npcs = getGyveNpcs(mob, count)
    for _, npc in pairs(npcs) do
        npc:setStatus(visible and xi.status.NORMAL or xi.status.DISAPPEAR)
    end
end

LQS.util.gyves = function(config)
    local occupyRadius = config.occupyRadius or 4

    return {
        entities = function(mobEntity)
            local gyves = {}
            for i = 1, config.count do
                local pos = config.positions and config.positions[i] or { 1, 1, 1, 0 }
                table.insert(gyves, {
                    name          = mobEntity.name .. "_Gyve_" .. i,
                    type          = xi.objType.NPC,
                    look          = config.look or 2141,
                    pos           = pos,
                    hidden        = true,
                    _isUtilEntity = true,
                    _parentMob    = mobEntity.name,
                })
            end
            return gyves
        end,

        onMobFight = function(mob, target)
            local hpP = mob:getHPP()

            if config.activateAt and hpP > config.activateAt then
                return
            end

            if config.deactivateAt and hpP <= config.deactivateAt then
                if mob:getLocalVar("[GYVE]active") == 1 then
                    mob:setLocalVar("[GYVE]active", 0)
                    setGyveVisibility(mob, config.count, false)
                    if config.onDeactivate then
                        config.onDeactivate(mob)
                    end
                end
                return
            end

            -- First time entering activation range — show gyves
            if mob:getLocalVar("[GYVE]active") == 0 then
                mob:setLocalVar("[GYVE]active", 1)
                setGyveVisibility(mob, config.count, true)
                if config.onActivate then
                    config.onActivate(mob)
                end
            end

            -- Tick interval gating
            local now     = os.time()
            local lastAt  = mob:getLocalVar("[GYVE]lastTick")
            local interval = config.tickInterval or 5
            if now - lastAt < interval then return end
            mob:setLocalVar("[GYVE]lastTick", now)

            -- Per-gyve occupation check
            local gyveNpcs   = getGyveNpcs(mob, config.count)
            local emptyCount = 0

            for i, gyve in ipairs(gyveNpcs) do
                if gyve == nil or gyve:getStatus() == xi.status.DISAPPEAR then
                    goto continue
                end

                local occupied = false

                LQS.util.forEachEngaged(mob, function(player)
                    if LQS.util.distance(player, gyve) <= occupyRadius then
                        occupied = true

                        if config.auras and config.auras[i] then
                            if not player:hasStatusEffect(config.auras[i]) then
                                player:addStatusEffect(config.auras[i], 1, 0, 8)
                            end
                        end

                        if config.tickDamage and config.tickDamage > 0 then
                            player:takeDamage(config.tickDamage, mob)
                        end
                    end
                end)

                if not occupied then
                    emptyCount = emptyCount + 1
                end

                ::continue::
            end

            -- Boss heals per empty gyve
            if emptyCount > 0 and config.healPerTick then
                mob:addHP(config.healPerTick * emptyCount)
            end

            -- Wipe timer: track consecutive all-empty ticks
            if emptyCount >= config.count then
                local emptyTime = mob:getLocalVar("[GYVE]emptyTime") + 1
                mob:setLocalVar("[GYVE]emptyTime", emptyTime)

                if emptyTime >= (config.wipeTimer or 10) then
                    LQS.util.forEachEngaged(mob, function(player)
                        player:takeDamage(config.wipeDamage or 9999, mob)
                    end)
                    mob:setLocalVar("[GYVE]emptyTime", 0)
                end
            else
                mob:setLocalVar("[GYVE]emptyTime", 0)
            end
        end,

        onMobDeath = function(mob)
            setGyveVisibility(mob, config.count, false)
            mob:setLocalVar("[GYVE]active", 0)
        end,
    }
end

return m
