-----------------------------------
-- LQS Util: wsProc
-----------------------------------
-- Weaponskill proc system. Mob becomes susceptible to a random weapon
-- type. Using the correct WS triggers a proc (terror + damage bonus).
-- The weakness rotates on each proc so players must adapt.
--
-- config:
--   maxProcs       (number)   max procs before system exhausts (default 5)
--   dmgBonus       (number)   UDMG increase per proc in basis points (default 500 = 5%)
--   terrorDuration (number)   seconds of terror on proc (default 5)
--   rotateCooldown (number)   seconds before a new weakness can proc (default 15)
--   onProc         (function) callback(mob, player, totalProcs) after each proc
-----------------------------------
require("modules/module_utils")
-----------------------------------
local m = Module:new("LQS_util_wsProc")

LQS      = LQS or {}
LQS.util = LQS.util or {}

LQS.util.wsProc = function(config)
    config = config or {}

    local maxProcs       = config.maxProcs       or 5
    local dmgBonus       = config.dmgBonus       or 500
    local terrorDuration = config.terrorDuration or 5
    local rotateCooldown = config.rotateCooldown or 15
    local onProc         = config.onProc

    return {
        onMobSpawn = function(mob)
            -- Pick initial weakness
            local function pickWeakness(mobArg)
                local wsType = xi.weaponskillTypes[math.random(1, #xi.weaponskillTypes)]
                mobArg:setLocalVar("[WSP]TYPE", wsType)
                return wsType
            end

            local function announceWeakness(mobArg, wsType)
                LQS.util.forEachEngaged(mobArg, function(player)
                    player:fmt("{} appears susceptible to {} weaponskills.", mobArg:getPacketName(), xi.skillName[wsType])
                end)
            end

            local wsType = pickWeakness(mob)
            announceWeakness(mob, wsType)

            mob:addListener("WEAPONSKILL_TAKE", "LQS_WSP_CHECK", function(target, user, wsid)
                if not target:isAlive() then return end
                if user == nil or not user:isPC() then return end

                local totalProcs = target:getLocalVar("[WSP]TOTAL")
                if totalProcs >= maxProcs then return end

                local now    = GetSystemTime()
                local nextAt = target:getLocalVar("[WSP]NEXT")
                if now < nextAt then return end

                local triggerType = target:getLocalVar("[WSP]TYPE")
                if triggerType == 0 then
                    triggerType = pickWeakness(target)
                    announceWeakness(target, triggerType)
                    return
                end

                if xi.weaponskillType[wsid] == triggerType then
                    totalProcs = totalProcs + 1
                    target:setLocalVar("[WSP]TOTAL", totalProcs)
                    target:setLocalVar("[WSP]NEXT", now + rotateCooldown)

                    target:weaknessTrigger(2)
                    target:addStatusEffectEx(xi.effect.TERROR, xi.effect.TERROR, 0, 0, terrorDuration)

                    target:addMod(xi.mod.UDMGPHYS,   dmgBonus)
                    target:addMod(xi.mod.UDMGRANGE,  dmgBonus)
                    target:addMod(xi.mod.UDMGMAGIC,  dmgBonus)
                    target:addMod(xi.mod.UDMGBREATH, dmgBonus)

                    LQS.util.forEachEngaged(target, function(player)
                        player:fmt("{} triggers a weakness! ({}/{})", user:getName(), totalProcs, maxProcs)
                    end)

                    local newType = pickWeakness(target)
                    announceWeakness(target, newType)

                    if onProc then
                        onProc(target, user, totalProcs)
                    end

                    if totalProcs >= maxProcs then
                        target:removeListener("LQS_WSP_CHECK")
                    end
                end
            end)
        end,
    }
end

-- Returns the total WS procs triggered on a mob
LQS.util.getWsProcs = function(mob)
    return mob:getLocalVar("[WSP]TOTAL")
end

return m
