-----------------------------------
-- LQS Util: spawnWave
-----------------------------------
-- Spawns groups of adds at HP thresholds. Each wave fires once per spawn.
-- Add mobs must be defined as entities in the same quest.
--
-- config: array of { hp = N, mobs = { { name = "Mob Name", level = N, hp = N }, ... } }
--   hp    (number)  HP percentage to trigger at
--   mobs  (table)   array of mob definitions to spawn
--
-- Usage:
--   util = { LQS.util.spawnWave({
--       { hp = 50, mobs = { { name = "Add 1", level = 88, hp = 10000 } } },
--       { hp = 25, mobs = { { name = "Add 2", level = 88, hp = 10000 } } },
--   }) }
-----------------------------------
require("modules/module_utils")
-----------------------------------
local m = Module:new("LQS_util_spawnWave")

LQS      = LQS or {}
LQS.util = LQS.util or {}

LQS.util.spawnWave = function(config)
    return {
        onMobFight = function(mob, target)
            for index, wave in ipairs(config) do
                if
                    mob:getHPP() <= wave.hp and
                    mob:getLocalVar(string.format("[SW]%d", index)) == 0
                then
                    mob:setLocalVar(string.format("[SW]%d", index), 1)

                    local zone = mob:getZone()
                    for _, addInfo in ipairs(wave.mobs) do
                        local result = zone:queryEntitiesByName("DE_" .. addInfo.name)
                        for _, add in pairs(result) do
                            if add ~= nil and not add:isAlive() then
                                local pos = mob:getPos()
                                add:setSpawn(pos.x, pos.y, pos.z, pos.rot)
                                add:spawn()
                                if addInfo.level then add:setMobLevel(addInfo.level) end
                                if addInfo.hp then add:setMaxHP(addInfo.hp); add:setHP(addInfo.hp) end
                                add:updateClaim(target)
                                add:setLocalVar("NO_CASKET", 1)
                            end
                        end
                    end

                    if target:isPC() then
                        target:printToArea(
                            "summons reinforcements!",
                            xi.msg.channel.EMOTION,
                            xi.msg.area.SAY,
                            mob:getPacketName()
                        )
                    end
                end
            end
        end,
    }
end

return m
