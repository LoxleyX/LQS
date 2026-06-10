-----------------------------------
-- LQS Util: reqPenalty
-----------------------------------
-- Mob gains TP when hit by Requiescat.
-----------------------------------
require("modules/module_utils")
-----------------------------------
local m = Module:new("LQS_util_reqPenalty")

LQS      = LQS or {}
LQS.util = LQS.util or {}

LQS.util.reqPenalty = {
    onMobSpawn = function(mob)
        mob:addListener("WEAPONSKILL_TAKE", "LQS_REQ_PENALTY", function(mobArg, user, wsid)
            if wsid == 226 then -- Requiescat
                mobArg:setTP(math.max(mobArg:getTP(), 1000))
            end
        end)
    end,
}

return m
