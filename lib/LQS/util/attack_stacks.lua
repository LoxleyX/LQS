-----------------------------------
-- LQS Util: attackStacks
-----------------------------------
-- Mob's ATK/STR/DEX escalate when hitting the same target.
-- Switching targets resets the stacks.
-----------------------------------
require("modules/module_utils")
-----------------------------------
local m = Module:new("LQS_util_attackStacks")

LQS      = LQS or {}
LQS.util = LQS.util or {}

LQS.util.attackStacks = {
    onMobSpawn = function(mob)
        mob:addListener("ATTACK", "LQS_ATTACK_STACKS", function(mobArg, player, action)
            local target   = mobArg:getLocalVar("[STACK]Target")
            local playerID = player:getID()

            if target == playerID then
                local stacks = player:getLocalVar("[STACK]Qty") + 1
                player:setLocalVar("[STACK]Qty", stacks)
                mobArg:setMod(xi.mod.ATT, 100 * stacks)
                mobArg:setMod(xi.mod.STR, 10 * stacks)
                mobArg:setMod(xi.mod.DEX, 10 * stacks)
            else
                mobArg:setLocalVar("[STACK]Target", playerID)
                player:setLocalVar("[STACK]Qty", 0)
                mobArg:setMod(xi.mod.ATT, 0)
                mobArg:setMod(xi.mod.STR, 0)
                mobArg:setMod(xi.mod.DEX, 0)
            end
        end)
    end,
}

return m
