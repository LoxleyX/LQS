-----------------------------------
-- LQS Util: enrageOnAddDeath
-----------------------------------
-- Boss gets permanent buffs when add mobs die. Checks add status
-- each fight tick by querying their alive state.
--
-- config:
--   adds       (table)   array of add entity names (as defined in LQS entities)
--   buffs      (table)   { [xi.mod.X] = value } — applied per dead add
--   maxStacks  (number)  cap on buff stacks (default: #adds)
--   telegraph  (string)  message per stack (use %s for mob name)
-----------------------------------
require("modules/module_utils")
-----------------------------------
local m = Module:new("LQS_util_enrageOnAddDeath")

LQS      = LQS or {}
LQS.util = LQS.util or {}

LQS.util.enrageOnAddDeath = function(config)
    return {
        onMobFight = function(mob, target)
            local zone       = mob:getZone()
            local totalAdds  = #config.adds
            local aliveCount = 0

            for _, addName in ipairs(config.adds) do
                local result = zone:queryEntitiesByName("DE_" .. addName)
                if result and result[1] and result[1]:isAlive() then
                    aliveCount = aliveCount + 1
                end
            end

            local deadCount     = totalAdds - aliveCount
            local currentStacks = mob:getLocalVar("[ENRAGE]stacks")
            local maxStacks     = config.maxStacks or totalAdds

            if deadCount > currentStacks and currentStacks < maxStacks then
                mob:setLocalVar("[ENRAGE]stacks", deadCount)

                if config.buffs then
                    for modId, value in pairs(config.buffs) do
                        mob:setMod(modId, value * deadCount)
                    end
                end

                if config.telegraph then
                    LQS.util.shout(mob, string.format(config.telegraph, mob:getPacketName()))
                end
            end
        end,
    }
end

return m
