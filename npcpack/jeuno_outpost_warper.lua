-----------------------------------
-- NPC: Jeuno Outpost Warper
-----------------------------------
-- Outpost teleporter NPC for Lower Jeuno using LQS framework.
-- Provides paginated outpost warp menu with Gil/CP payment options.
-- Features:
--   - Signet application before teleport (optional)
--   - Level and outpost unlock requirements
--   - Standard retail outpost costs
-----------------------------------

return LQS.outpostTeleporter({
    name = "Outpost Warper",
    zone = "Lower_Jeuno",
    pos  = { 24.1552, -1.0, 45.9046, 149 },
    look = 1415, -- Hume Uncle model

    -- Apply Signet before teleport (uses rank-based duration)
    preTeleportEffects = { LQS.signetEffect() },

    -- Other defaults:
    -- greeting       = "Welcome to the Outpost Warp Service!"
    -- itemsPerPage   = 5
    -- teleportDelay  = 1250
    -- animation      = { actionID = 6, animID = 600 }
})
