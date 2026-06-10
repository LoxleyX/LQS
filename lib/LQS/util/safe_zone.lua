-----------------------------------
-- LQS Util: safeZone (Stack Mechanic)
-----------------------------------
-- A safe zone NPC appears at an HP threshold. After a countdown,
-- players outside the radius take massive damage.
-- Auto-creates a hidden safe zone NPC entity.
--
-- config:
--   look      (number)  NPC model ID (default 2175 = light/safe circle)
--   radius    (number)  safe radius (default 8)
--   damage    (number)  damage outside zone (default 9999)
--   countdown (number)  seconds before blast (default 8)
--   killRange (number)  max range to deal damage (default 100)
--   telegraph (string)  message broadcast when zone appears
--   triggers  (table)   array of { hp = number, pos = { x, y, z } }
-----------------------------------
require("modules/module_utils")
-----------------------------------
local m = Module:new("LQS_util_safeZone")

LQS      = LQS or {}
LQS.util = LQS.util or {}

local function getSafeZoneNpc(mob)
    local zone   = mob:getZone()
    local result = zone:queryEntitiesByName("DE_" .. mob:getPacketName() .. "_SafeZone")
    return result and result[1] or nil
end

local function startBlast(mob, npc, config)
    local safeRadius  = config.radius    or 8
    local countdownMs = (config.countdown or 8) * 1000
    local tickMs      = 1000
    local elapsed     = 0

    local function tick(mobArg)
        if mobArg == nil or not mobArg:isAlive() then
            npc:setStatus(xi.status.DISAPPEAR)
            return
        end

        elapsed = elapsed + tickMs

        -- Phalanx indicator for players inside the zone
        local nearbyAll = npc:getPlayersInRange(safeRadius)
        for _, player in pairs(nearbyAll) do
            if not player:hasStatusEffect(xi.effect.PHALANX) then
                player:addStatusEffect(xi.effect.PHALANX, 50, 0, 10)
            end
        end

        if elapsed < countdownMs then
            mobArg:timer(tickMs, tick)
            return
        end

        -- BLAST
        local safePos = npc:getPos()
        LQS.util.forEachEngaged(mobArg, function(player)
            local pPos = player:getPos()
            local dx   = pPos.x - safePos.x
            local dz   = pPos.z - safePos.z
            if math.sqrt(dx * dx + dz * dz) > safeRadius then
                player:takeDamage(config.damage or 9999, mobArg)
            end
        end)

        npc:setStatus(xi.status.DISAPPEAR)
    end

    mob:timer(tickMs, tick)
end

LQS.util.safeZone = function(config)
    return {
        entities = function(mobEntity)
            return {
                {
                    name          = mobEntity.name .. "_SafeZone",
                    type          = xi.objType.NPC,
                    look          = config.look or 2175,
                    pos           = { 1, 1, 1, 0 },
                    hidden        = true,
                    _isUtilEntity = true,
                    _parentMob    = mobEntity.name,
                },
            }
        end,

        onMobFight = function(mob, target)
            if not config.triggers then return end

            local hpP = mob:getHPP()

            for idx, trigger in ipairs(config.triggers) do
                local key = string.format("[SZ]%d", idx)

                if hpP <= trigger.hp and mob:getLocalVar(key) == 0 then
                    mob:setLocalVar(key, 1)

                    local npc = getSafeZoneNpc(mob)
                    if npc then
                        npc:setPos(trigger.pos[1], trigger.pos[2], trigger.pos[3], 0)
                        npc:setStatus(xi.status.NORMAL)

                        if config.telegraph then
                            LQS.util.shout(mob, config.telegraph)
                        end

                        startBlast(mob, npc, config)
                    end
                end
            end
        end,

        onMobDeath = function(mob)
            local npc = getSafeZoneNpc(mob)
            if npc then
                npc:setStatus(xi.status.DISAPPEAR)
            end
        end,
    }
end

return m
