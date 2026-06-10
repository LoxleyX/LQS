-----------------------------------
-- LQS Util: fixate
-----------------------------------
-- Mob ignores enmity and locks onto a random player.
-- That player must kite while others DPS.
--
-- config:
--   duration      (number)   how long fixate lasts (default 15)
--   cooldown      (number)   seconds between fixates (default 45)
--   telegraph     (string)   message when fixate starts (use %s for target name)
--   endMessage    (string)   message when fixate ends
--   targetFilter  (function) optional filter(player) → bool
-----------------------------------
require("modules/module_utils")
-----------------------------------
local m = Module:new("LQS_util_fixate")

LQS      = LQS or {}
LQS.util = LQS.util or {}

LQS.util.fixate = function(config)
    return {
        onMobFight = function(mob, target)
            local now   = os.time()
            local state = mob:getLocalVar("[FIX]state")

            if state == 0 then
                if now < mob:getLocalVar("[FIX]nextAt") then return end

                local chosen = LQS.util.randomEngaged(mob, config.targetFilter)
                if chosen == nil then return end

                mob:setLocalVar("[FIX]state", 1)
                mob:setLocalVar("[FIX]target", chosen:getID())
                mob:setLocalVar("[FIX]startedAt", now)

                LQS.util.resetEnmity(mob)
                mob:addEnmity(chosen, 10000, 10000)

                if config.telegraph then
                    LQS.util.shout(mob, string.format(config.telegraph, chosen:getName()))
                end
                return
            end

            if now - mob:getLocalVar("[FIX]startedAt") >= (config.duration or 15) then
                mob:setLocalVar("[FIX]state", 0)
                mob:setLocalVar("[FIX]nextAt", now + (config.cooldown or 45))
                mob:setLocalVar("[FIX]target", 0)
                if config.endMessage then
                    LQS.util.shout(mob, config.endMessage)
                end
                return
            end

            local fixTarget = GetPlayerByID(mob:getLocalVar("[FIX]target"))
            if fixTarget == nil or not fixTarget:isAlive() then
                mob:setLocalVar("[FIX]state", 0)
                mob:setLocalVar("[FIX]nextAt", now + (config.cooldown or 45))
                return
            end

            mob:addEnmity(fixTarget, 1000, 1000)
        end,
    }
end

return m
