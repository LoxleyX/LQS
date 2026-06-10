-----------------------------------
-- LQS Util: phaseCheck
-----------------------------------
-- HP% phase transition tracker. Calls a callback when the mob
-- crosses an HP threshold. Only fires once per phase per spawn.
--
-- phases: array of { hp = number, callback = function(mob, target) }
-----------------------------------
require("modules/module_utils")
-----------------------------------
local m = Module:new("LQS_util_phaseCheck")

LQS      = LQS or {}
LQS.util = LQS.util or {}

LQS.util.phaseCheck = function(phases)
    return {
        onMobFight = function(mob, target)
            local hpPercent = mob:getHPP()

            for _, phase in pairs(phases) do
                local key = string.format("[PHASE]%d", phase.hp)

                if hpPercent <= phase.hp and mob:getLocalVar(key) == 0 then
                    mob:setLocalVar(key, 1)

                    if phase.callback then
                        phase.callback(mob, target)
                    end
                end
            end
        end,
    }
end

return m
