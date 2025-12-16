-----------------------------------
-- LQS Example: Custom Teleporter
-----------------------------------
-- This example demonstrates the LQS.teleporter() function
-- for creating custom teleporter NPCs with full control over:
-- - Custom destinations with coordinates or teleport IDs
-- - Custom costs (gil, cp, or free)
-- - Custom requirements (level, key items, etc.)
-- - Pre-teleport effects (buffs, reraise, etc.)
-----------------------------------

return LQS.teleporter({
    name = "Dimensional Guide",
    zone = "Port_Jeuno",
    pos  = { -10.0, 0.0, -20.0, 128 },
    look = LQS.look({
        race = xi.race.HUME_M,
        face = LQS.face.A1,
        body = 15,
        legs = 15,
        feet = 15,
    }),

    -- Greeting shown when NPC is triggered
    greeting = "I can guide you between dimensions. Where would you like to go?",

    -- Menu customization
    menuTitle    = "Choose Your Destination",
    itemsPerPage = 5,

    -- Teleport settings
    teleportDelay = 1500,

    -- Pre-teleport effects (optional)
    -- Can use LQS.signetEffect() for standard Signet, or custom effects:
    preTeleportEffects = {
        LQS.signetEffect(), -- Standard Signet with rank-based duration
        {
            effect   = xi.effect.RERAISE,
            power    = 1,
            duration = 7200, -- 2 hours
        },
    },

    -- Teleport animation (optional)
    animation = { actionID = 6, animID = 600 },

    -- Custom destinations
    destinations = {
        -- Using direct coordinates (cross-zone)
        {
            name  = "Sanctuary of Zi'Tah",
            pos   = { -37.669, 0.419, -141.216, 69, 121 }, -- x, y, z, rot, zoneID
            costs = { gil = 500 },
            level = 25,
        },

        -- Using xi.teleport.id constants
        {
            name     = "Crag of Dem",
            teleport = xi.teleport.id.DEM,
            costs    = { gil = 200 },
            level    = 10,
        },

        -- Free teleport with custom check
        {
            name  = "Batallia Downs",
            pos   = { -480.0, -24.0, 355.0, 0, 105 },
            costs = {}, -- Free
            check = function(player)
                -- Only allow if player has completed a certain quest
                -- return player:hasCompletedQuest(xi.questLog.SANDORIA, xi.quest.id.sandoria.SOME_QUEST)
                return true -- Always allow for this example
            end,
        },

        -- High-level destination with CP cost only
        {
            name  = "Cape Teriggan",
            pos   = { 68.0, -8.0, -70.0, 0, 113 },
            costs = { cp = 100 },
            level = 50,
        },

        -- Destination with both Gil and CP options
        {
            name  = "Eastern Altepa Desert",
            pos   = { -180.0, -8.0, 40.0, 0, 114 },
            costs = { gil = 750, cp = 50 },
            level = 30,
        },

        -- Dynamic label example
        {
            name  = "Valkurm Dunes",
            label = function(player, dest)
                local level = player:getMainLvl()
                if level < 20 then
                    return "Valkurm Dunes (Perfect for you!)"
                else
                    return "Valkurm Dunes"
                end
            end,
            pos   = { 100.0, -8.0, 100.0, 0, 103 },
            costs = { gil = 100 },
            level = 10,
        },
    },

    -- Messages
    noDestinations  = "You haven't met the requirements for any destinations yet.",
    insufficientGil = "You don't have enough Gil for this journey.",
    insufficientCP  = "You don't have enough conquest points for this journey.",
    cancelled       = "Perhaps another time. Safe travels!",
})
