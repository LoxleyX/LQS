-----------------------------------
-- LQS Example: Outpost Warper
-----------------------------------
-- This example demonstrates the LQS.outpostTeleporter() function
-- which creates a fully-featured outpost teleporter NPC with:
-- - Paginated destination menu
-- - Gil and CP payment options
-- - Optional pre-teleport effects (Signet, etc.)
-- - Level and outpost unlock requirements
-----------------------------------

return LQS.outpostTeleporter({
    name = "Outpost Warper",
    zone = "Lower_Jeuno",
    pos  = { 24.155, -1.0, 45.905, 149 },
    look = 1415, -- Hume Uncle model

    -- Apply Signet before teleport (optional)
    -- Uses rank-based duration calculation
    preTeleportEffects = { LQS.signetEffect() },

    -- Optional overrides (uncomment to customize)
    -- greeting       = "Welcome to the Outpost Warp Service!",
    -- itemsPerPage   = 5,
    -- teleportDelay  = 1250,

    -- Override specific outpost costs (optional)
    -- outpostOverrides = {
    --     [xi.region.RONFAURE] = { gil = 50, cp = 5 },
    -- },

    -- No pre-teleport effects (omit preTeleportEffects or set to {})
    -- preTeleportEffects = {},

    -- Custom animation (optional)
    -- animation = { actionID = 6, animID = 600 },
})
