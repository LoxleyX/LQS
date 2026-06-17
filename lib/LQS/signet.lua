-----------------------------------
-- LQS Extension: Signet Effect
-----------------------------------
require("modules/module_utils")
-----------------------------------
local m = Module:new("LQS_signet")

-- Library-only module (defines LQS.signetEffect): register a no-op override
-- so the module loader does not flag it with "No overrides found in module".
m:addOverride("xi.dummyFunc", function()
end)

LQS = LQS or {}

LQS.signetEffect = function()
    return {
        effect            = xi.effect.SIGNET,
        removeConflicting = true,
        duration          = function(player)
            local pNation = player:getNation()
            local pRank   = player:getRank(pNation)
            return (pRank + GetNationRank(pNation) + 3) * 3600
        end
    }
end

return m
