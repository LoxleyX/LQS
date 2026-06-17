-----------------------------------
-- LQS Extension: Teleporter
-----------------------------------
require("modules/module_utils")
-----------------------------------
local m = Module:new("LQS_teleporter")

-- Library-only module (defines LQS.teleporter / LQS.outpostTeleporter): register
-- a no-op override so the module loader does not flag it with
-- "No overrides found in module".
m:addOverride("xi.dummyFunc", function()
end)

LQS = LQS or {}

-- Returns an onTrigger handler for use with LQS.npc.
--
-- Usage:
--   LQS.npc(m, {
--       name = "Dimensional_Guide",
--       area = "Port_Jeuno",
--       pos  = { 10, 0, -20, 128 },
--       look = 1415,
--       onTrigger = LQS.teleporter({
--           destinations = {
--               { name = "Sanctuary", pos = { -37, 0, -141, 69, 121 }, costs = { gil = 500 } },
--               { name = "Crag of Dem", teleport = xi.teleport.id.DEM, costs = { cp = 100 } },
--           },
--           preTeleportEffects = { LQS.signetEffect() },
--           animation = { actionID = 6, animID = 600 },
--       }),
--   })
-----------------------------------

LQS.teleporter = function(config)
    -- Default configuration
    local defaults = {
        itemsPerPage    = 5,
        teleportDelay   = 1250,
        greeting        = "Where would you like to go?",
        noDestinations  = "You haven't unlocked any destinations.",
        insufficientGil = "You don't have enough Gil.",
        insufficientCP  = "You don't have enough conquest points.",
        cancelled       = "Safe travels!",
    }

    for k, v in pairs(defaults) do
        if config[k] == nil then
            config[k] = v
        end
    end

    -- Helper: Apply pre-teleport effects
    local function applyPreEffects(player)
        if config.preTeleportEffects then
            for _, effectInfo in ipairs(config.preTeleportEffects) do
                local duration = effectInfo.duration
                if type(duration) == "function" then
                    duration = duration(player)
                end
                duration = duration or 3600

                if effectInfo.removeConflicting then
                    player:delStatusEffectsByFlag(xi.effectFlag.INFLUENCE, true)
                end

                local power = effectInfo.power or 0
                player:addStatusEffect(effectInfo.effect, power, 0, duration)
            end
        end
    end

    -- Helper: Play teleport animation
    local function playAnimation(player)
        if config.animation then
            player:injectActionPacket(
                player:getID(),
                config.animation.actionID or 6,
                config.animation.animID or 600,
                0, 0, 0, 0, 0
            )
        end
    end

    -- Helper: Execute teleport
    local function executeTeleport(player, destination)
        applyPreEffects(player)
        playAnimation(player)

        player:timer(config.teleportDelay, function(playerArg)
            if destination.teleport then
                if type(destination.teleport) == "number" then
                    playerArg:addStatusEffectEx(
                        xi.effect.TELEPORT, 0,
                        destination.teleport, 0, 1, 0,
                        destination.region or 0
                    )
                elseif type(destination.teleport) == "table" then
                    playerArg:setPos(unpack(destination.teleport))
                end
            elseif destination.pos then
                if destination.pos[5] ~= nil then
                    playerArg:setPos(destination.pos[1], destination.pos[2], destination.pos[3], destination.pos[4], destination.pos[5])
                else
                    playerArg:setPos(destination.pos[1], destination.pos[2], destination.pos[3], destination.pos[4])
                end
            end
        end)
    end

    -- Helper: Show payment menu
    local function showPaymentMenu(player, npc, destination)
        local gilCost = destination.costs and destination.costs.gil or 0
        local cpCost  = destination.costs and destination.costs.cp or 0

        local options = {}

        if gilCost > 0 then
            table.insert(options, {
                string.format("Pay %d Gil", gilCost),
                function(playerArg)
                    if playerArg:getGil() >= gilCost then
                        playerArg:delGil(gilCost)
                        executeTeleport(playerArg, destination)
                    else
                        playerArg:printToPlayer(config.insufficientGil, 0, npc:getPacketName())
                    end
                end
            })
        end

        if cpCost > 0 then
            table.insert(options, {
                string.format("Pay %d CP", cpCost),
                function(playerArg)
                    if playerArg:getCP() >= cpCost then
                        playerArg:delCP(cpCost)
                        executeTeleport(playerArg, destination)
                    else
                        playerArg:printToPlayer(config.insufficientCP, 0, npc:getPacketName())
                    end
                end
            })
        end

        -- Free teleport
        if gilCost == 0 and cpCost == 0 then
            executeTeleport(player, destination)
            return
        end

        table.insert(options, {
            "Cancel",
            function(playerArg)
                playerArg:printToPlayer(config.cancelled, 0, npc:getPacketName())
            end
        })

        player:timer(100, function(playerArg)
            playerArg:customMenu({
                title   = string.format("Teleport to %s", destination.name),
                options = options,
            })
        end)
    end

    -- Filter destinations
    local function filterDestination(player, dest)
        if dest.level and player:getMainLvl() < dest.level then
            return false
        end

        if dest.check and not dest.check(player) then
            return false
        end

        return true
    end

    -- Return the onTrigger handler
    return function(player, npc)
        npc:lookAt(player:getPos())

        if config.greeting then
            player:printToPlayer(config.greeting, xi.msg.channel.SYSTEM_3)
        end

        LQS.paginatedMenu(player, {
            title        = config.menuTitle or "Select Destination",
            items        = config.destinations,
            itemsPerPage = config.itemsPerPage,
            filter       = filterDestination,
            npc          = npc,
            onSelect     = function(playerArg, destination, npcArg)
                showPaymentMenu(playerArg, npcArg, destination)
            end,
            onCancel     = function(playerArg, reason)
                if reason == "no_items" then
                    playerArg:printToPlayer(config.noDestinations, 0, npc:getPacketName())
                else
                    playerArg:printToPlayer(config.cancelled, 0, npc:getPacketName())
                end
            end,
        })
    end
end

-----------------------------------
-- LQS.outpostTeleporter
-- Pre-configured outpost warper (returns onTrigger handler)
--
-- Usage:
--   LQS.npc(m, {
--       name = "Outpost_Warper",
--       area = "Lower_Jeuno",
--       pos  = { 24.155, -1.0, 45.905, 149 },
--       look = 1415,
--       onTrigger = LQS.outpostTeleporter({
--           preTeleportEffects = { LQS.signetEffect() },
--       }),
--   })
-----------------------------------
LQS.outpostTeleporter = function(config)
    config = config or {}

    local outpostTable = {
        [xi.region.RONFAURE]         = { gil = 100, cp = 10,  level = 10, name = "Ronfaure" },
        [xi.region.ZULKHEIM]         = { gil = 100, cp = 30,  level = 10, name = "Zulkheim" },
        [xi.region.NORVALLEN]        = { gil = 150, cp = 40,  level = 15, name = "Norvallen" },
        [xi.region.GUSTABERG]        = { gil = 100, cp = 10,  level = 10, name = "Gustaberg" },
        [xi.region.DERFLAND]         = { gil = 150, cp = 40,  level = 15, name = "Derfland" },
        [xi.region.SARUTABARUTA]     = { gil = 100, cp = 10,  level = 10, name = "Sarutabaruta" },
        [xi.region.KOLSHUSHU]        = { gil = 100, cp = 40,  level = 10, name = "Kolshushu" },
        [xi.region.ARAGONEU]         = { gil = 150, cp = 40,  level = 15, name = "Aragoneu" },
        [xi.region.FAUREGANDI]       = { gil = 350, cp = 70,  level = 35, name = "Fauregandi" },
        [xi.region.VALDEAUNIA]       = { gil = 400, cp = 50,  level = 40, name = "Valdeaunia" },
        [xi.region.QUFIMISLAND]      = { gil = 150, cp = 60,  level = 15, name = "Qufim" },
        [xi.region.LITELOR]          = { gil = 250, cp = 40,  level = 25, name = "Li'Telor" },
        [xi.region.KUZOTZ]           = { gil = 300, cp = 70,  level = 30, name = "Kuzotz" },
        [xi.region.VOLLBOW]          = { gil = 500, cp = 70,  level = 50, name = "Vollbow" },
        [xi.region.ELSHIMO_LOWLANDS] = { gil = 250, cp = 70,  level = 25, name = "Elshimo Lowlands" },
        [xi.region.ELSHIMO_UPLANDS]  = { gil = 350, cp = 70,  level = 35, name = "Elshimo Uplands" },
        [xi.region.TAVNAZIANARCH]    = { gil = 300, cp = 70,  level = 30, name = "Tavnazia" },
    }

    if config.outpostOverrides then
        for region, overrides in pairs(config.outpostOverrides) do
            if outpostTable[region] then
                for k, v in pairs(overrides) do
                    outpostTable[region][k] = v
                end
            end
        end
    end

    local destinations = {}
    for region, data in pairs(outpostTable) do
        table.insert(destinations, {
            name     = data.name,
            teleport = xi.teleport.id.OUTPOST,
            region   = region,
            costs    = { gil = data.gil, cp = data.cp },
            level    = data.level,
            check    = function(player)
                if region == xi.region.TAVNAZIANARCH then
                    return player:getRank(player:getNation()) >= 6
                else
                    return player:hasTeleport(player:getNation(), region + 5)
                end
            end,
        })
    end

    table.sort(destinations, function(a, b)
        return a.region < b.region
    end)

    config.destinations = destinations

    if config.animation == nil then
        config.animation = { actionID = 6, animID = 600 }
    end

    if config.greeting == nil then
        config.greeting = "Welcome to the Outpost Warp Service!"
    end

    return LQS.teleporter(config)
end

return m
