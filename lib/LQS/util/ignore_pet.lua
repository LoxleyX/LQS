-----------------------------------
-- LQS Util: ignorePet
-----------------------------------
-- Mob ignores pets and transfers enmity to master.
-----------------------------------
require("modules/module_utils")
-----------------------------------
local m = Module:new("LQS_util_ignorePet")

LQS      = LQS or {}
LQS.util = LQS.util or {}

LQS.util.ignorePet = {
    onMobFight = function(mob, target)
        if target ~= nil and target:getObjType() == xi.objType.PET then
            local master = target:getMaster()
            if master ~= nil then
                mob:addEnmity(master, mob:getCE(target), mob:getVE(target))
                mob:resetEnmity(target)
            end
        end
    end,
}

return m
