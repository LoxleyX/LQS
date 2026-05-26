# Loxley Quest System (LQS)
[![LQS](https://github.com/LoxleyXI/LQS/blob/main/lqs.png)](https://github.com/LoxleyXI/LQS)

## Overview
The Loxley Quest System (LQS) is a module for the [LandSandBoat](https://github.com/LandSandBoat/server) FFXI server emulator. It allows server operators to easily create their own custom quests and script custom events using a simple template system. The system provides an authentic experience and is actively in use by multiple prominent FFXI server projects.

If you found this module helpful, please consider kindly supporting my other work and/or starring the repository. Thank you.

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/loxleygames)

## Features
* **LQS now comes bundled with Questpack, providing 25+ new quests to experience**
* Fully scriptable dialog events with NPC animations and simulated cutscenes
* Flexible item trading system offers endless possibilities
* Mob encounters featuring spawn requirements, level caps and other restrictions
* NPC look/model utility functions allow easy creation of any appearance
* Each step can be gated by any number of requirements
* Custom quest tracker with a new `!quest` command providing quest info and hints
* LQS Quest modules are fully reloadable and will refresh simply by saving the file

(ie. You can update NPCs or implement new quest steps without any need for a server restart!)

## Setup
* `LQS.lua` must be located inside `modules/` and included to `init.txt` before any of your quests
* Also include `questpack` inside `init.txt` to load the provided additional quests
* Initialise your new quests using `LQS.add()`, following the examples provided in this repository
* Save time by using my [`pos` Ashita Addon](https://github.com/LoxleyXI/ashita-addons) to copy NPC/Mob positions straight to the clipboard
* Ensure `lqs_util.cpp` is included in your modules and [clear the CMake cache](https://github.com/LandSandBoat/server/wiki/Module-Guide#cpp-modules) before [rebuilding the C++](https://github.com/LandSandBoat/server/wiki/Quick-Start-Guide)

## Questpack
**LQS now comes bundled with Questpack, providing 25+ new quests to experience.** Each quest features tastefully written dialog, appropriate to the game's setting and a variety of new rewards, including augmented items and repeatable gil rewards. These quests are designed to better balance the starting areas and provide meaningful content for new players to complete at the start of their journey.

* San d'Oria **(7)**: Hatchet Job, Hungry Customer, In Sheep's Clothing, Rambling Around, Staying Afloat, Fleeing Daylight, Ring Around the Roses
* Bastok **(8)**: Bird Search, Bug Report, Chasing Tails, Mining My Business, That's All Folks, Earthen Echoes, Running Rings Around, Lode of Gil
* Windurst **(7)**: Down to Earth, Neck and Neck, Only the Dose, Reaping Rewards, Rustling Feathers, Slowing Down, Give Me a Ring
* Other Areas **(3)**: Head First, Here Be Dragons, Likely Tails
* Aht Urhgan **(2)**: Insult to Gingery, Pecking Battles

## Simple Example
The following is a minimal example to get started building quests in LQS.

(For a more complete example, see: [Here be Dragons](https://github.com/LoxleyXI/LQS/blob/main/questpack/other_areas/lqs_here_be_dragons.lua))
```lua
local m = Module:new("lqs_example")

local SimpleQuest = "Simple Quest"
local Example     = "Example"

LQS.add(m, {
    info     =
    {
        name   = SimpleQuest,
        author = "Loxley",
        var    = "[LQS]EXAMPLE",
    },
    entities =
    {
        ["Upper_Jeuno"] =
        {
            {
                name = Example,
                type = xi.objType.NPC,
                look = LQS.look({
                    race = xi.race.HUME_M,
                    face = LQS.face.A1,
                    body = 21,
                }),
                pos = { -3.276, -0.000, 25.295, 106 }, -- !pos -3.276 -0.000 25.295 244
            },
        },
    },
    steps =
    {
        {
            [Example] = LQS.dialog({
                quest  = SimpleQuest,
                reward = xi.item.CHUNK_OF_ROCK_SALT,
                step   = false, -- Prevent quest advancing
                event  =
                {
                    "Hello,",
                    { emote = xi.emote.WAVE },
                    " Welcome to the example quest.",
                },
            }),
        },
    },
})

return m
```

## Utilities
### LQS.event
Event tables are core to LQS and allow endless possibilities for scripting custom events for each quest step. Thanks to the LQS namespace, `LQS.event` can actually be utilised in other modules, offering enhanced interactions for all custom content. All events are handled per player and due to being sent packets directly, no other players will see the NPCs or their movements.

```lua
LQS.event(player, npc {
    "Hello there, messages are usually prefixed with the NPC's name, just like regular in-game dialog.", -- Eg. Name : Hello there...
    " Rows that start with indentation will also skip the NPC's name.", -- Eg.  Rows that start...
    { face         = "player", entity = "Name"                         }, -- Turn event trigger NPC to face player, specify entity name to turn a different NPC
    { removeEffect = xi.effect.LEVEL_RESTRICTION                       }, -- Remove a status effect from the player
    { charvar      = "[LQS]VAR_NAME", value = 10                       }, -- Set a character variable
    { setcostume   = 123                                               }, -- Set costume for the player
    { message      = "Test message"                                    }, -- Present a gold coloured system message
    { emotion      = "claps very loudly.", name = "Name"               }, -- Present a purple coloured emote message from "name"
    { special      = 123                                               }, -- Present a messageSpecial corresponding to the provided message ID
    { music        = 123                                               }, -- Update the player's current music ID, useful for creating impactful cutscenes
    { pos          = { 1, 1, 1, 0 }                                    }, -- Update the player's current position
    { packet       = "open", entity = "Treasure Chest"                 }, -- Send a named entity packet to the specified NPC
    { animate      = 251, mode = 4, entity = "Name", target = "player" }, -- Send an independent animation packet for the NPC (eg. Hearts animation), target optional
    { emote        = xi.emote.TOSS, entity = "Name/player"             }, -- Send an emote from the specified NPC, entity name optional
    { spawn        = { "One", "Two", "Three" }                         }, -- Spawn the specified entities for this player
    { despawn      = { "One", "Two", "Three" }                         }, -- Despawn the specified entities for this player
    { glimpse      = { 3000, { "One", "Two", "Three" } }               }, -- Briefly spawn then despawn the specified entities for this player after the given duration
})
```

### LQS.look
The look utility provides an easy interface to create unique NPC looks without needing to manually convert each model ID into a little endian byte string (eg. `"0x01000F020010032008300A400850006000700000"`). Model IDs can be found as an MId in [LSB's `item_equipment.sql`](https://github.com/LandSandBoat/server/blob/base/sql/item_equipment.sql)

```lua
LQS.look({
    race = xi.race.ELVAAN_F,
    face = LQS.face.B2,
    head = 0,
    body = 6,
    hand = 6,
    legs = 6,
    feet = 6,
    main = 0,
    offh = 0,
})
```

## Step Functions
### LQS.dialog
Dialog steps are the foundation of any quest, each dialog includes an event table and optional parameters, such as quest name to trigger the "Quest Accepted" message or reward to trigger the "Quest Completed" message and distribute rewards.
* Event tables consist of strings and tables containing many different functions
* Dialog is automatically assigned to the current NPC unless a spawn is specified
* The assigned NPC will turn to the player during dialog and reset position following
* Spawners will disappear during dialog and respawn after
* Events are sent directly to the target player, the only one who sees NPCs move, emote or spawners altering state
```lua
["Entity Name"] = LQS.dialog({
    -- (Optional)
    check  = { level = 5 },

    -- (Optional) Setting this will give players the "Quest Accepted" message after the dialog completes
    quest  = "Quest Name",

     -- (Optional) Setting this will complete the quest after the dialog completes
    reward = { item = xi.item.CHUNK_OF_ROCK_SALT, gil = 100, slots = { xi.inv.WARDROBE4, 1 }, feature = "Storage: Ephemeral Box" },

    -- (Optional) Set the NPC's name here if the entity is a spawner
    spawn  = "NPC Name",

    -- (Optional) Include if this should not increment the quest step, ie. reminder dialog
    step   = false,

    -- (Required)
    event  =
    {
        "Test message",
        { emote = xi.emote.THINK },
    },
}),
```

### LQS.trade
Trade steps advance the quest or provide rewards in exchange for requested items. By setting `step = false`, repeatable quests can be created and the `tally` parameter can be used to keep track of the total trades, eg. for dialog.
```lua
["Entity Name"] =
{
    -- When sharing a step with a trade handler, onTrigger events must be assigned to the table
    onTrigger = LQS.dialog({
        step  = false,
        event =
        {
            "Remember the thing I asked you to get for me?"
        },
    }),

    -- Trade handlers must be assigned to the onTrade parameter of a table in the entity's current step
    onTrade = LQS.trade({
        -- (Optional) Gate this step with optional requirements
        check = { level = 5 },

        -- (Optional) The required items
        required = { { xi.item.CHUNK_OF_ROCK_SALT, 12 } },

        -- (Optional) A table of rarity sorted results can be used instead of the `required` parameter, allowing multiple different types of items to be exchanged
        exchange =
        {
            [xi.item.CHUNK_OF_ROCK_SALT] =
            {
                { LQS.COMMON,   CHUNK_OF_COPPER_ORE, "a chunk of copper ore" }, --  (15%)
                { LQS.UNCOMMON, CHUNK_OF_ZINC_ORE,   "a chunk of zinc ore"   }, --  (10%)
                { LQS.RARE,     CHUNK_OF_GOLD_ORE,   "a chunk of gold ore"   }, --  ( 5%)
            },
        },

        -- (Optional) Setting this will give players the "Quest Accepted" message after the dialog completes
        quest = "Quest Name",

         -- (Optional) Setting this will complete the quest after the dialog completes
        reward = { gil = 250 },

        -- (Optional) Include if this should not increment the quest step, ie. reminder dialog
        step = false,

        -- (Optional) Character variable to store a tally for the total number of items accepted
        tally = "[LQS]VAR_NAME",

        -- (Required) This event table will be played if the player brings incorrect items
        declined  =
        {
            "This isn't what I wanted.",
        },

        -- (Required) This event table will be played if the player brings the correct items
        accepted  =
        {
            "Thanks for bringing me this item, here's your reward",
        },
    },
}),
```

### LQS.menu
The menu function must be assigned to an NPC.
```lua
["Entity Name"] = LQS.menu({
    -- (Optional) Setting this will give players the "Quest Accepted" message after the dialog completes
    quest = "Quest Name",

    -- (Optional) If specified, the affirmative menu option will spawn the provided mob list
    spawn = { "Mob Name" },

    -- (Optional) If mob spawns, the spawner can be moved along to another position
    nextPos = { 1, 1, 1, 0 },

    -- (Optional) If mob spawns, level cap the player for the encounter
    levelCap = 10,

    -- (Optional) If mob spawns, allow players with this level cap status to receive raise
    raiseAllowed = true,

    -- (Optional) Require a max party size before allowing the mob to spawn
    partySize = 6,

    -- (Optional) If mob spawns, set the player's variable, eg. to reset quest state and consume a pop
    setVar = "[LQS]VAR_NAME",

    -- (Optional) If mob spawns, set a variable for all players in the alliance
    setVarAll = "[LQS]VAR_NAME",

    -- (Required) Title displayed on the custom menu
    title = "Here's a question",

    -- (Required) Options displayed on the custom menu
    options =
    {
        {
            "Here's an answer",
        },
        {
            "Different answer",
            {
                "This event table plays if this answer is chosen"
                { emote = xi.emote.THINK },
            },
        },
    },
}),
```

### LQS.defeat
The defeat function must be assigned to a mob.
```lua
["Entity Name"] = LQS.defeat({
    -- (Required) A table containing all mobs required to trigger the win condition
    mobs = { "Mob Name" },

    -- (Required) The name of the spawner to reappear after all mobs are defeated
    spawner = "Spawner Name",

    -- (Optional) Players who aren't on the current quest step can receive an item for helping, once per JST midnight
    helper = { { xi.item.CHUNK_OF_ROCK_SALT, 3 } },

    -- (Optional) Applies a JST midnight cooldown to all players by setting the supplied variable to 1 with an expiry
    cooldown = "[LQS]VAR_NAME",

    -- (Optional) Roll a random amount of points within the specified range for all participants
    pointsVar = "[LQS]POINTS_NAME",
    points    = { 15, 20 },
    message   = "{} gains {} special points.",

    -- (Optional) Award all participants with an amount of EXP
    exp = 1000,

    -- (Optional) Send all defeated players a Raise of the specified value after combat ends
    raise = 3,

    -- (Optional) Execute an arbitrary function for all participants
    func = function(player, step)
    end,
}),
```

### LQS.shop
The shop utility presents players with an automatically paginated list and provides a confirmation dialog before purchasing each item. The amount of points is checked before each item is allowed to be purchased. The quest step will not advance and this function should be assigned to a secondary NPC or at the end of a quest.
```lua
["Entity Name"] = LQS.shop({
    var    = "[LQS]POINTS_NAME",
    title  = "Purchase an item ({} points)",
    dialog = { "Optional dialog here" },
    list   =
    {

        { "Copper Ore", CHUNK_OF_COPPER_ORE,  5 },
        { "Zinc Ore",   CHUNK_OF_ZINC_ORE,   10 },
        { "Gold Ore",   CHUNK_OF_GOLD_ORE,   25 },
    },
}),
```

## Standalone NPCs
### LQS.npc
For NPCs that don't need quest steps — shops, services, teleporters, etc. Supports hot-reloading of handlers on file save.

```lua
local m = Module:new("my_shop")

LQS.npc(m, {
    ["Port_Jeuno"] =
    {
        {
            name = "Shop Keeper",
            pos  = { -22, 0, -77, 128 },
            look = LQS.look({ race = xi.race.HUME_M, face = LQS.face.A3, body = 21 }),
            onTrigger = function(player, npc)
                LQS.event(player, npc, { "Welcome to my shop!" })
            end,
        },
    },
})

return m
```

Supports all entity properties: `hideName`, `hideHP`, `untargetable`, `size`, `hidden`, `listener(s)`, `animation`.

#### Size Constants
| Constant | Value | Effect |
|----------|-------|--------|
| `LQS.LARGE` | 2 | Large model (NPCs: entityFlags bit 2, Mobs: modelSize 2) |
| `LQS.EXTRA_LARGE` | 3 | Extra large model (Mobs only: modelSize 3) |

## Extensions
Extensions live in `lib/LQS/` and add functions to the `LQS` table. They are loaded automatically by the core.

### LQS.teleporter
Returns an `onTrigger` handler for config-driven teleporter NPCs with paginated menus and currency costs.

```lua
local m = Module:new("my_teleporter")

LQS.npc(m, {
    ["Port_Jeuno"] =
    {
        {
            name = "Dimensional Guide",
            pos  = { 10, 0, -20, 128 },
            look = 1415,
            onTrigger = LQS.teleporter({
                destinations = {
                    { name = "Sanctuary", pos = { -37, 0, -141, 69, 121 }, costs = { gil = 500 }, level = 25 },
                    { name = "Crag of Dem", teleport = xi.teleport.id.DEM, costs = { cp = 100 } },
                },
                preTeleportEffects = { LQS.signetEffect() },
                animation = { actionID = 6, animID = 600 },
            }),
        },
    },
})

return m
```

### LQS.outpostTeleporter
Pre-configured outpost warper with all 17 regions, unlock checks, and costs.

```lua
local m = Module:new("my_outpost_warper")

LQS.npc(m, {
    ["Lower_Jeuno"] =
    {
        {
            name = "Outpost Warper",
            pos  = { 24.155, -1.0, 45.905, 149 },
            look = 1415,
            onTrigger = LQS.outpostTeleporter({
                preTeleportEffects = { LQS.signetEffect() },
            }),
        },
    },
})

return m
```

### LQS.signetEffect
Helper for standard Signet effect with rank-based duration. Used with teleporter's `preTeleportEffects`.

```lua
preTeleportEffects = { LQS.signetEffect() }
```

### Writing Extensions
Create a file in `lib/LQS/` that adds functions to the `LQS` table. Extensions are loaded automatically by the module loader (alphabetically after `LQS.lua`).

```lua
-- lib/LQS/my_extension.lua
LQS = LQS or {}

LQS.myThing = function(config)
    return function(player, npc)
        -- Return an onTrigger handler
    end
end
```

## History
This system has been developed over a couple of years by myself and now supports over 130+ live custom quests and content systems.

* The [first version](https://www.bg-wiki.com/ffxi/CatsEyeXI_Systems/Quests) was initially developed by me for [Crystal Warrior](https://www.catseyexi.com/cw) on [CatsEyeXI](https://www.catseyexi.com/) in 2023
* This __definitive version__ was developed by me in 2025 to give the system a permanent home and make it more accessible to the community

## Final Note
If you found this module useful for your server, please provide a link back to it!

~ Loxley ~
