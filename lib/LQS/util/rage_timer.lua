-----------------------------------
-- LQS Util: rageTimer
-----------------------------------
-- Mob gets increasingly dangerous over time. Stacks ATK/MATT
-- every interval seconds.
--
-- config:
--   interval   (number)  fight ticks between stacks (default 120)
--   att        (number)  ATK per stack (default 20)
--   matt       (number)  MATT per stack (default 0)
--   maxStacks  (number)  maximum stacks (default 10)
-----------------------------------
require("modules/module_utils")
-----------------------------------
local m = Module:new("LQS_util_rageTimer")

LQS      = LQS or {}
LQS.util = LQS.util or {}

LQS.util.rageTimer = function(config)
    config = config or {}
    return {
        onMobFight = function(mob, target)
            local elapsed = mob:getLocalVar("[RAGE]Elapsed") + 1
            mob:setLocalVar("[RAGE]Elapsed", elapsed)

            local stackInterval = config.interval   or 120
            local maxStacks     = config.maxStacks   or 10
            local currentStack  = mob:getLocalVar("[RAGE]Stack")

            if elapsed % stackInterval == 0 and currentStack < maxStacks then
                currentStack = currentStack + 1
                mob:setLocalVar("[RAGE]Stack", currentStack)
                mob:setMod(xi.mod.ATT,  (config.att  or 20) * currentStack)
                mob:setMod(xi.mod.MATT, (config.matt or 0)  * currentStack)
            end
        end,
    }
end

return m
