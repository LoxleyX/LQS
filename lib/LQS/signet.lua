-----------------------------------
-- LQS Extension: Signet Effect
-----------------------------------
require("modules/module_utils")
-----------------------------------
local m = Module:new("LQS_signet")

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
