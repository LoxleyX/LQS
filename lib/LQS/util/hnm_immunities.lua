-----------------------------------
-- LQS Util: hnmImmunities
-----------------------------------
-- Standard HNM immunities (sleep, gravity, petrify, silence).
-----------------------------------
require("modules/module_utils")
-----------------------------------
local m = Module:new("LQS_util_hnmImmunities")

LQS      = LQS or {}
LQS.util = LQS.util or {}

LQS.util.hnmImmunities = {
    onMobInitialize = function(mob)
        mob:addImmunity(xi.immunity.DARK_SLEEP)
        mob:addImmunity(xi.immunity.LIGHT_SLEEP)
        mob:addImmunity(xi.immunity.GRAVITY)
        mob:addImmunity(xi.immunity.PETRIFY)
        mob:addImmunity(xi.immunity.SILENCE)
    end,
}

return m
