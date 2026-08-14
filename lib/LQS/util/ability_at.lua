-----------------------------------
-- LQS Util: abilityAt
-----------------------------------
-- Uses a job ability (2hr etc.) when the mob reaches specific HP thresholds.
-- Each threshold fires once per spawn.
--
-- config: array of { hp = N, ability = abilityID }
--   hp       (number)  HP percentage to trigger at
--   ability  (number)  ability ID to use (688 = Mighty Strikes, etc.)
--
-- Usage:
--   util = { LQS.util.abilityAt({
--       { hp = 50, ability = 688 }, -- Mighty Strikes at 50%
--       { hp = 25, ability = 690 }, -- Hundred Fists at 25%
--   }) }
-----------------------------------
require("modules/module_utils")
-----------------------------------
local m = Module:new("LQS_util_abilityAt")

LQS      = LQS or {}
LQS.util = LQS.util or {}

LQS.util.abilityAt = function(list)
    return {
        onMobFight = function(mob, target)
            for index, entry in ipairs(list) do
                if
                    mob:getHPP() <= entry.hp and
                    mob:getLocalVar(string.format("[AA]%d", index)) == 0
                then
                    mob:setLocalVar(string.format("[AA]%d", index), 1)
                    mob:useMobAbility(entry.ability)
                end
            end
        end,
    }
end

return m
