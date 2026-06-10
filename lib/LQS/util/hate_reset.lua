-----------------------------------
-- LQS Util: hateReset
-----------------------------------
-- Periodically wipes all enmity, forcing tanks to re-establish hate.
--
-- config:
--   interval   (number)  seconds between resets (default 60)
--   telegraph  (string)  message before reset (use %s for mob name)
-----------------------------------
require("modules/module_utils")
-----------------------------------
local m = Module:new("LQS_util_hateReset")

LQS      = LQS or {}
LQS.util = LQS.util or {}

LQS.util.hateReset = function(config)
    return {
        onMobFight = function(mob, target)
            local now    = os.time()
            local lastAt = mob:getLocalVar("[HR]lastAt")

            if lastAt == 0 then
                mob:setLocalVar("[HR]lastAt", now)
                return
            end

            if now - lastAt < (config.interval or 60) then return end
            mob:setLocalVar("[HR]lastAt", now)

            if config.telegraph then
                LQS.util.shout(mob, string.format(config.telegraph, mob:getPacketName()))
            end

            LQS.util.resetEnmity(mob)
        end,
    }
end

return m
