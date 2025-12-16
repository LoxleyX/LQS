-----------------------------------
-- Loxley Quest System (LQS)
-----------------------------------
-- Copyright (c) 2025 LoxleyXI
--
-- https://github.com/LoxleyXI/LQS
-----------------------------------
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.

-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.

-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see http://www.gnu.org/licenses/
-----------------------------------
local m = Module:new("LQS_Loxley_Quest_System")
-----------------------------------
-- Define globally for reloads and persistence between files
LQS          = LQS or {}
LQS.registry = LQS.registry or {}

LQS.settings =
{
    -- Respawn of spawners
    RESPAWN = 180000, -- 3 minutes
    DEBUG   = true,   -- Enable debugging mode
}

-- Pull optional setting overrides from LSB map settings
if xi.settings.main.LQS ~= nil then
    LQS.settings.RESPAWN = xi.settings.main.LQS.RESPAWN or LQS.settings.RESPAWN
    LQS.settings.DEBUG   = xi.settings.main.LQS.DEBUG   or LQS.settings.DEBUG
end

LQS.marker =
{
    SPARKLE  = 1382,
    BLUE     = 2424,
    FRAGMENT = 2357,
    SHIMMER  = 2326,
}

LQS.MAIN_QUEST   = "MAIN_QUEST"
LQS.SIDE_QUEST   = "SIDE_QUEST"
LQS.NOTHING      = { { object = true }, "You see nothing out of the ordinary." }
LQS.NOTHING_ELSE = { { object = true }, "There is nothing else to do here."    }
LQS.LOCKED       = { { object = true }, "It's locked." }

LQS.standardImmunities =
{
    xi.immunity.DARK_SLEEP,
    xi.immunity.GRAVITY,
    xi.immunity.LIGHT_SLEEP,
    xi.immunity.PETRIFY,
    xi.immunity.SILENCE,
    xi.immunity.TERROR,
}

-- Rates
LQS.GUARANTEED  = 1000 -- 100%
LQS.VERY_COMMON =  240 --  24%
LQS.COMMON      =  150 --  15%
LQS.UNCOMMON    =  100 --  10%
LQS.RARE        =   50 --   5%
LQS.VERY_RARE   =   10 --   1%
LQS.SUPER_RARE  =    5 -- 0.5%
LQS.ULTRA_RARE  =    1 -- 0.1%

-----------------------------------
-- Dynamic Entity Looks
-----------------------------------
local decToLE = function(num)
    local hex = string.format("%04x", num)
    return string.sub(hex, 3, 4) .. string.sub(hex, 1, 2)
end

local modelSlot = { "head", "body", "hand", "legs", "feet", "main", "offh" }

LQS.face =
{
    A1 = 0,
    B1 = 1,
    A2 = 2,
    B2 = 3,
    A3 = 4,
    B3 = 5,
    A4 = 6,
    B4 = 7,
    A5 = 8,
    B5 = 9,
    A6 = 10,
    B6 = 11,
    A7 = 12,
    B7 = 13,
    A8 = 14,
    B8 = 15,
}

LQS.look = function(tbl)
    local str = "00"  -- NPC or Mob

    if tbl.face then
        str = str .. string.format("%02x", tbl.face)
    else
        str = str .. "01"
    end

    if tbl.race then
        str = str .. string.format("%02x", tbl.race)
    else
        str = str .. "01"
    end

    for k, v in pairs(modelSlot) do
        if tbl[v] then
            str = str .. decToLE(tbl[v])
        else
            str = str .. "0000"
        end
    end

    str = str .. "0000" -- Ranged slot

    return "0x01" .. string.upper(str)
end

-----------------------------------
-- LQS.event
-----------------------------------
local processString = function(player, prefix, str, delay)
    if str:sub(1, 1) == " " then
        -- Paragraph continue
        player:timer(delay, function(playerArg)
            playerArg:fmt(str)
        end)
    else
        -- New paragraph
        player:timer(delay, function(playerArg)
            playerArg:fmt(prefix .. str)
        end)
    end
end

local applyEntities = function(player, entityList, func)
    local zone = player:getZone()

    for i = 1, #entityList do
        local entityName = entityList[i]
        local deEntity   = string.gsub(entityName, "_", " ")
        local result     = zone:queryEntitiesByName("DE_" .. deEntity)

        for j = 1, #result do
            func(result[j], player)
        end
    end
end

local getEntity = function(player, entityName)
    local zone     = player:getZone()
    local deEntity = string.gsub(entityName, "_", " ")
    local result   = zone:queryEntitiesByName("DE_" .. deEntity)

    return result[1]
end

local function eventSpawn(obj, player, npc, event)
    if obj.spawn == nil then
        return false
    end

    local spawned = getEntity(player, obj.spawn)

    npc:ceDespawn(player)
    spawned:ceSpawn(player)

    player:timer(750, function()
        spawned:ceFace(player)
        LQS.event(player, spawned, event)
    end)

    local delay = LQS.eventDelay(event)

    player:timer(delay + 1500, function()
        npc:ceSpawn(player)
        spawned:ceDespawn(player)
    end)

    return true
end

-- TODO: Should this be kept for LQS?
local scriptedEvent = function(player, entities, events)
    local ents = {}

    for i = 1, #entities do
        ents[i] = getEntity(player, entities[i])
        ents[i]:ceSpawn(player)
    end

    for i = 1, #events do
        local event = events[i]
        local delay = 5000 + i * 1000

        player:timer(delay, function()
            ents[event[1]]:entityAnimationPacket(event[2])
        end)
    end

    return 6000 + #events * 1000
end

local processTable = function(player, npc, prefix, row, delay)
    if row.fmt ~= nil then
        local result = player:getCharVar(row.var)
        player:fmt(row.fmt, result)

    -- Face
    -- Turn entity to face target
    elseif row.face ~= nil then
        if row.entity == nil then
            if npc then
                npc:ceFace(player)
            end
        else
            local entity = getEntity(player, row.entity)

            if entity == nil then
                return
            end

            if row.face == "player" then
                entity:ceFace(player)
            elseif type(row.face) == "number" then
                entity:ceTurn(player, row.face)
            else
                local otherEntity = getEntity(player, row.face)

                if otherEntity then
                    entity:ceFaceNpc(player, otherEntity)
                end
            end
        end

    elseif row.removeEffect ~= nil then
        if player:hasStatusEffect(row.removeEffect) then
            player:delStatusEffect(row.removeEffect)
        end

    -- Add Status Effect
    -- Add a status effect to the player
    elseif row.addEffect ~= nil then
        if type(row.addEffect) == "number" then
            -- Simple effect with defaults
            player:addStatusEffect(row.addEffect, 0, 0, 3600)
        elseif type(row.addEffect) == "table" then
            local effect   = row.addEffect.effect
            local power    = row.addEffect.power or 0
            local tick     = row.addEffect.tick or 0
            local duration = row.addEffect.duration or 3600
            local subId    = row.addEffect.subId or 0
            local subPower = row.addEffect.subPower or 0
            local tier     = row.addEffect.tier or 0
            local flags    = row.addEffect.flags or 0

            -- Remove conflicting effects if requested (e.g., for Signet)
            if row.addEffect.removeConflicting then
                player:delStatusEffectsByFlag(xi.effectFlag.INFLUENCE, true)
            end

            if flags ~= 0 then
                player:addStatusEffectEx(effect, effect, power, tick, duration, subId, subPower, tier, flags)
            else
                player:addStatusEffect(effect, power, tick, duration, subId, subPower, tier)
            end
        end

    elseif row.charvar ~= nil then
        player:setCharVar(row.charvar, row.value)

    elseif row.costume ~= nil then
        player:setCostume(row.costume)

    elseif row.message ~= nil then
        if type(row.message) == "table" then
            if row.after ~= nil then
                player:timer(row.after, function()
                    for _, message in pairs(row.message) do
                        player:sys(message)
                    end
                end)
            else
                for _, message in pairs(row.message) do
                    player:sys(message)
                end
            end
        else
            player:sys(row.message)
        end

    elseif row.say ~= nil then
        local result = row.say

        if row.var ~= nil then
            local value = player:getCharVar(row.var)
            result = fmt(result, value)
        end

        player:fmt(result)

    elseif row.emotion ~= nil then
        player:printToPlayer(row.emotion, 8, row.name)

    elseif row.special ~= nil then
        player:messageSpecial(row.special)

    elseif row.music ~= nil then
        player:changeMusic(0, row.music)
        player:changeMusic(1, row.music)

    elseif row.pos ~= nil then
        player:setPos(unpack(row.pos))

    elseif
        row.scripted_event ~= nil and
        row.scripted_event.events ~= nil and
        row.scripted_event.entities ~= nil
    then
        return scriptedEvent(player, row.scripted_event.entities, row.scripted_event.events)

    -- NPC Animation Packet
    -- Send an animation packet for the NPC
    elseif
        row.entity ~= nil and
        row.packet ~= nil
    then
        local entity = getEntity(player, row.entity)

        if row.target == nil then
            entity:ceAnimationPacket(player, row.packet, entity)
        else
            local target = getEntity(player, row.entity)
            entity:ceAnimationPacket(player, row.packet, target)
        end

    -- NPC Independent Animation Packet
    -- Send an independent animation packet for the NPC
    elseif
        row.animate ~= nil
    then
        if row.entity ~= nil then
            local entity = getEntity(player, row.entity)

            if row.target == "player" then
                entity:ceAnimate(player, player, row.animate, row.mode or 0)
            else
                entity:ceAnimate(player, entity, row.animate, row.mode or 0)
            end
        else
            player:ceAnimate(player, player, row.animate, row.mode or 0)
        end

    -- Send an action packet (visible to all players)
    -- row.action = { actionID, animationID }
    elseif
        row.action ~= nil and
        type(row.action) == "table"
    then
        if
            row.entity ~= nil
        then
            local entity = getEntity(player, row.entity)
            if row.target == "player" then
                entity:injectActionPacket(player:getID(), row.action[1], row.action[2], 0, 0, 0, 0, 0)
            else
                entity:injectActionPacket(entity:getID(), row.action[1], row.action[2], 0, 0, 0, 0, 0)
            end
        else
            player:injectActionPacket(player:getID(), row.action[1], row.action[2], 0, 0, 0, 0, 0)
        end

    -- Emote NPC
    -- Sends an emote from the source NPC onto the target NPC or player
    elseif row.emote  ~= nil then
        if row.entity == "player" then
            player:selfEmote(player, row.emote, xi.emoteMode.MOTION)

        elseif row.entity ~= nil then
            local entity = getEntity(player, row.entity)
            entity:ceEmote(player, row.emote, xi.emoteMode.MOTION)

        elseif npc ~= nil then
            npc:ceEmote(player, row.emote, xi.emoteMode.MOTION)
        end

    -- Animation
    -- Set an animation on the target
    elseif row.animation ~= nil then
        if row.target and row.target == "player" then
            local anim = player:getAnimation()

            player:setAnimation(row.animation)

            player:timer(row.duration, function(player)
                player:setAnimation(anim)
            end)

            return row.duration
        end

    -- Spawn Dynamic Entities
    elseif row.spawn ~= nil then
        applyEntities(player, row.spawn, function(entity, playerArg)
            entity:ceSpawn(playerArg)
        end)

    -- Despawn Dynamic Entities
    elseif row.despawn ~= nil then
        applyEntities(player, row.despawn, function(entity, playerArg)
            entity:ceDespawn(playerArg)
        end)

    -- Glimpse
    -- Temporarily spawn NPCs then despawn after a short interval
    elseif row.glimpse ~= nil then
        applyEntities(player, row.glimpse[2], function(entity, playerArg)
            entity:ceSpawn(playerArg)
            entity:timer(row.glimpse[1], function(npcArg)
                entity:ceDespawn(playerArg)
            end)
        end)

    -- Teleport
    -- Cross-zone or same-zone teleportation with optional delay
    elseif row.teleport ~= nil then
        local teleportDelay = row.teleportDelay or 0

        if type(row.teleport) == "number" then
            -- Using xi.teleport.id constant (e.g., xi.teleport.id.DEM, xi.teleport.id.OUTPOST)
            local teleportId = row.teleport
            local subPower   = row.region or 0

            player:timer(teleportDelay, function(playerArg)
                playerArg:addStatusEffectEx(xi.effect.TELEPORT, 0, teleportId, 0, 1, 0, subPower)
            end)

        elseif type(row.teleport) == "table" then
            -- Direct coordinates: { x, y, z, rotation, zoneID }
            player:timer(teleportDelay, function(playerArg)
                if row.teleport[5] ~= nil then
                    -- Cross-zone teleport
                    playerArg:setPos(row.teleport[1], row.teleport[2], row.teleport[3], row.teleport[4], row.teleport[5])
                else
                    -- Same-zone teleport
                    playerArg:setPos(row.teleport[1], row.teleport[2], row.teleport[3], row.teleport[4])
                end
            end)
        end
    end
end

-- Returns the total delay for event
LQS.eventDelay = function(tbl)
    if not tbl or type(tbl) ~= "table" or #tbl == 0 then
        print(string.format("[LQS] Event table for %s missing or empty.", npcName))
        return 0
    end

    local total = 0

    for i = 1, #tbl do
        local row = tbl[i]
        local nextDelay = 1500

        if row.delay ~= nil then
            if row.skipDelayInternally then
                nextDelay = 0
            else
                nextDelay = row.delay
            end

        elseif row.duration ~= nil then
            nextDelay = row.duration

        elseif row.move ~= nil then
            nextDelay = 200 * #row.move

        elseif row.scripted_event then
            nextDelay = 5000 + 1000 * #row.scripted_event.events

        elseif type(row) == "table" then
            nextDelay = 0
        end

        total = total + nextDelay
    end

    return total
end

LQS.event = function(player, npc, tbl)
    if
        type(tbl) ~= "table" and
        type(tbl) ~= "function"
    then
        print(fmt("[LQS] event must be a table or a function. {}, {}", npc, tbl))
        return
    end

    if player:getLocalVar("[LQS]BLOCKING") == 1 then
        return
    end

    -- Evaluate function instead of executing event
    if type(tbl) == "function" then
        tbl(player)
        return
    end

    local prefix = ""

    -- Objects should not have NPC names
    if
        npc ~= nil and
        tbl[1].object == nil
    then
        npc:ceFace(player)

        prefix = string.format("%s : ", npc:getPacketName())
        player:setLocalVar("[LQS]BLOCKING", 1)
    end

    if not tbl or #tbl == 0 then
        print(string.format("[LQS] Event table for (%s) missing or empty.", prefix))
        return
    end

    if #tbl == 1 then
        if type(tbl[1]) == "table" then
            processTable(player, npc, prefix, tbl[1], 0)
        else
            player:fmt(prefix .. tbl[1])
        end

        -- Reset NPC position after single line dialog
        if npc then
            player:timer(3000, function(playerArg)
                npc:ceReset(player)
                player:setLocalVar("[LQS]BLOCKING", 0)
            end)
        end

        return
    end

    local delay = 0

    for i = 1, #tbl do
        local row = tbl[i]
        local nextDelay = 1500

        if type(row) == "function" then
            -- Delayed function
            player:timer(delay, tbl[i])

        elseif type(row) == "string" then
            processString(player, prefix, row, delay)

        -- Process tables
        else
            player:timer(delay, function(playerArg)
                processTable(player, npc, prefix, row, delay)
            end)

            if row.delay ~= nil then
                nextDelay = row.delay

            elseif row.duration ~= nil then
                nextDelay = row.duration

            elseif row.scripted_event ~= nil then
                nextDelay = 5000 + 1000 * #row.scripted_event.events

            else
                nextDelay = 0
            end
        end

        delay = delay + nextDelay
    end

    if npc then
        player:timer(delay + 3000, function(playerArg)
            npc:ceReset(player)
            player:setLocalVar("[LQS]BLOCKING", 0)
        end)
    end
end

-----------------------------------
-- Quest tracker
-----------------------------------
LQS.newMission = function(player, missionName)
    player:sys("\129\158 New Mission: {}", missionName)
end

LQS.questAccepted = function(player, questName, isMission)
    local text = "\129\158 Quest Accepted: {}"

    if isMission then
        text = "\129\158 Mission Accepted: {}"
    end

    player:sys(text, questName)
end

LQS.questCompleted = function(player, questName, isMission)
    local text = "\129\159 Quest Completed: {}"

    if isMission then
        text = "\129\159 Mission Completed: {}"
    end

    player:sys(text, questName)
end

-----------------------------------
-- Core utils
-----------------------------------
local function delaySendMenu(player, menu)
    player:timer(300, function(playerArg)
        playerArg:customMenu(menu)
    end)
end

LQS.pickItem = function(items, mod)
    -- sum weights
    local sum = 0
    for i = 1, #items do
        if
            mod ~= nil and
            type(items[i][1]) == "table"
        then
            sum = sum + items[i][1][mod]
        else
            sum = sum + items[i][1]
        end
    end

    -- pick weighted result
    local item = items[1]
    local pick = math.random(1, sum)
    sum = 0

    for i = 1, #items do
        if
            mod ~= nil and
            type(items[i][1]) == "table"
        then
            sum = sum + items[i][1][mod]
        else
            sum = sum + items[i][1]
        end

        if sum >= pick then
            item = items[i]
            break
        end
    end

    return item
end

LQS.lootPool = function(player, pools)
    for _, pool in pairs(pools) do
        local result = LQS.pickItem(pool)
        local qty    = 1

        if result == nil then
            print(fmt("[LQS] pickItem returned a nil result in quest pool (Player: {}, Zone: {})", player:getName(), player:getZoneName()))
        else
            if result[4] ~= nil then
                qty = math.random(result[3], result[4])
            elseif result[3] ~= nil then
                qty = result[3]
            end

            if result[2] == nil then
                print(fmt("[LQS] pickItem returned a nil item ID in quest pool (Player: {}, Zone: {})", player:getName(), player:getZoneName()))
            elseif result[2] ~= 0 then
                npcUtil.giveItem(player, { { result[2], qty } })
            end
        end
    end
end

LQS.randomNoRepeat = function(size, exclude)
    local range = {}

    for i = 1, size do
        if i ~= exclude then
            table.insert(range, i)
        end
    end

    return range[math.random(1, #range)]
end

-----------------------------------
-- Entity utils
-----------------------------------
local function getEntity(player, entityName)
    local zone   = player:getZone()
    local result = zone:queryEntitiesByName("DE_" .. entityName)

    return result[1]
end

local function getEntityInfo(entities, entityName)
    local entityInfo = nil

    for _, entity in pairs(entities) do
        if entity.name == entityName then
            entityInfo = entity
        end
    end

    if entityInfo == nil then
        print(string.format("[LQS] Unable to match mob %s with quest entities", entityName))
    end

    return entityInfo
end

local function hideNPC(npc)
    npc:setStatus(xi.status.INVISIBLE)

    npc:timer(LQS.settings.RESPAWN, function(npcArg)
        npcArg:setStatus(xi.status.NORMAL)
    end)
end

-----------------------------------
-- Encounter utils
-----------------------------------
local function setEncounter(entity, params)
    local flags = xi.effectFlag.DEATH + xi.effectFlag.ON_ZONE

    if params.raiseAllowed ~= nil then
        flags = xi.effectFlag.ON_ZONE
    end

    entity:addStatusEffectEx(
        xi.effect.LEVEL_RESTRICTION,
        xi.effect.LEVEL_RESTRICTION,
        params.levelCap,
        0,
        0,
        0,
        0,
        0,
        flags + xi.effectFlag.CONFRONTATION
    )

    if params.subjob ~= nil and params.subjob == false then
        entity:addStatusEffectEx(
            xi.effect.SJ_RESTRICTION,
            xi.effect.SJ_RESTRICTION,
            0,
            0,
            0,
            0,
            0,
            0,
            flags
        )
    end
end

local levelCaps =
{
    16, -- Promyvion - Holla
    18, -- Promyvion - Dem
    20, -- Promyvion - Mea
    22, -- Promyvion-Vahzl
    28, -- Sacrarium
    29, -- Riverne Site B01
    30, -- Riverne Site A01
}

local function isLevelCappedZone(zoneID)
    for k, v in pairs(levelCaps) do
        if v == zoneID then
            return true
        end
    end

    return false
end

local function removeLevelCap(player)
    local zoneID   = player:getZoneID()

    -- Prevent removing level restriction inside intentionally capped areas
    if isLevelCappedZone(zoneID) then
        return
    end

    local alliance = player:getAlliance()

    for i = 1, #alliance do
        if alliance[i]:getZoneID() == zoneID then
            alliance[i]:delStatusEffect(xi.effect.LEVEL_RESTRICTION)

            local pet = alliance[i]:getPet()

            if pet ~= nil then
                pet:delStatusEffect(xi.effect.LEVEL_RESTRICTION)
            end
        end
    end
end

local function allPlayers(player, func)
    local zoneID   = player:getZoneID()
    local alliance = player:getAlliance()

    for i = 1, #alliance do
        if
            alliance[i]:isPC() and
            alliance[i]:getZoneID() == zoneID
        then
            func(alliance[i])
        end
    end
end

local function applyLevelCap(player, params)
    if
        params ~= nil and
        params.levelCap ~= nil
    then
        local zoneID   = player:getZoneID()
        local alliance = player:getAlliance()

        for i = 1, #alliance do
            if alliance[i]:getZoneID() == zoneID then
                setEncounter(alliance[i], params)

                local pet = alliance[i]:getPet()

                if pet ~= nil then
                    setEncounter(pet, params)
                end
            end
        end
    end
end

local function spawnMob(player, npc, entities, mobName, params)
    local zone     = player:getZone()
    local zoneName = player:getZoneName()
    local mobInfo  = getEntityInfo(entities[zoneName], mobName)
    local result   = zone:queryEntitiesByName("DE_" .. mobName)

    for _, mob in pairs(result) do
        if mob ~= nil and not mob:isSpawned() then
            if
                params ~= nil and
                params.setPos ~= nil
            then
                mob:setSpawn(params.setPos.x, params.setPos.y, params.setPos.z, params.setPos.rotation)
            else
                mob:setSpawn(mobInfo.pos[1], mobInfo.pos[2], mobInfo.pos[3], mobInfo.pos[4])
            end

            if mobInfo.dropID then
                mob:setDropID(mobInfo.dropID)
            else
                mob:setDropID(0)
            end

            local spawnLevel = mobInfo.level

            if
                params ~= nil and
                params.scaleVar ~= nil
            then
                local scaling = player:getCharVar(params.scaleVar)
                spawnLevel    = spawnLevel + scaling
            end

            mob:spawn()
            mob:setMobLevel(spawnLevel)
            mob:updateClaim(player)
            mob:setLocalVar("NO_CASKET", 1)
            mob:setCallForHelpBlocked(true)

            -- Quest mobs should not respawn
            mob:setRespawnTime(0)
            DisallowRespawn(mob:getID(), true)

            if mobInfo.mods ~= nil then
                for mod, value in pairs(mobInfo.mods) do
                    mob:setMod(mod, value)
                end
            end

            if mobInfo.effects ~= nil then
                for effectID, effectTable in pairs(mobInfo.effects) do
                    mob:addStatusEffect(effectID, unpack(effectTable))
                end
            end

            -- Correct HP value based on mob params
            mob:setHP(mob:getMaxHP())
            mob:updateHealth()

            if mobInfo.hp ~= nil then
                local mobHP = mob:getMaxHP()
                local hpp   = math.max(math.ceil((mobInfo.hp / mobHP) * 100) - 100, 0)
                mob:addMod(xi.mod.HPP, hpp)
                mob:updateHealth()
                mob:setHP(mob:getMaxHP())
            end

            if params ~= nil then
                if params.levelCap ~= nil then
                    -- Draw-In was moved to Lua mixin:
                    -- https://github.com/LandSandBoat/server/pull/6566
                    g_mixins.draw_in(mob)
                    setEncounter(mob, params)
                end

                if params.nextPos ~= nil then
                    local pos = params.nextPos[math.random(1, #params.nextPos)]
                    npc:setPos(unpack(pos))
                end
            end
        end
    end
end

local function mobsSpawned(player, mobName)
    local zone   = player:getZone()
    local result = zone:queryEntitiesByName("DE_" .. mobName)

    for _, mob in pairs(result) do
        if
            mob ~= nil and
            mob:isSpawned()
        then
            player:sys("An encounter is already in progress.")
            player:setLocalVar("[LQS]REWARD", 0)
            return true
        end
    end

    return false
end

local function delaySpawn(player, npc, delay, mobs, entities, hideSpawner, params)
    if type(mobs) == "table" then
        for _, mobName in pairs(mobs) do
            if mobsSpawned(player, mobName) then
                return false
            end
        end
    else
        if mobsSpawned(player, mobs) then
            return false
        end
    end

    -- TODO: Can these be moved to checks?
    if params ~= nil then
        if
            params.partySize ~= nil and
            player:getPartySize() > params.partySize
        then
            player:sys("Your party is too large to begin this encounter.")
            return false
        end

        if
            params.job ~= nil and
            player:getMainJob() ~= params.job
        then
            player:sys("Your job is incorrect for this encounter.")
            return false
        end
    end

    -- Only skip this if hideSpawner is false
    if
        ((params == nil or params.nextPos == nil) and
        hideSpawner == nil) or
        hideSpawner
    then
        hideNPC(npc)
    end

    applyLevelCap(player, params)

    npc:timer(delay, function(npcArg)
        if type(mobs) == "table" then
            for _, mobName in pairs(mobs) do
                spawnMob(player, npc, entities, mobName, params)
            end
        else
            spawnMob(player, npc, entities, mobs, params)
        end
    end)

    return true
end

-----------------------------------
-- Reward utils
-----------------------------------
local function giveReward(player, reward, questName)
    if
        type(reward) == "number" or
        type(reward[1]) == "table"
    then
        return npcUtil.giveItem(player, reward)
    end

    if reward.item ~= nil then
        if reward.augment ~= nil then
            local ID = zones[player:getZoneID()]

            if player:getFreeSlotsCount() > 0 then
                player:addItem(reward.item, 1, unpack(reward.augment))
                player:messageSpecial(ID.text.ITEM_OBTAINED, reward.item)
            else
                player:messageSpecial(ID.text.ITEM_CANNOT_BE_OBTAINED, reward.item)
                return false
            end
        elseif not npcUtil.giveItem(player, reward.item) then
            return false
        end
    end

    if reward.exp ~= nil then
        player:addExp(reward.exp)
    end

    if reward.currency ~= nil then
        npcUtil.giveCurrency(player, reward.currency[1], reward.currency[2])
    end

    if reward.gil ~= nil then
        npcUtil.giveCurrency(player, "gil", reward.gil)
    end

    if reward.keyitem ~= nil then
        if type(reward.keyitem) == "table" then
            for _, keyItem in pairs(reward.keyitem) do
                npcUtil.giveKeyItem(player, keyItem)
            end
        else
            npcUtil.giveKeyItem(player, reward.keyitem)
        end
    end

    -- Execute optional quest registry override
    if
        questName ~= nil and
        LQS.registry[questName] ~= nil and
        LQS.registry[questName].after ~= nil
    then
        LQS.registry[questName].after(player)
    end

    return true
end

-----------------------------------
-- LQS.checks
-----------------------------------
local checkList =
{
    eval = function(player, val)
        return val(player, val)
    end,

    gm = function(player, val)
        return (player:getGMLevel() > 0) == val
    end,

    level = function(player, val)
        return player:getMainLvl() >= val
    end,

    job  = function(player, val)
        return player:getMainJob() == val
    end,

    jobvar = function(player, var)
        return player:getMainJob() == player:getCharVar(var)
    end,

    vareq = function(player, val)
        return player:getCharVar(val[1]) == val[2]
    end,

    varin = function(player, tbl)
        local val = player:getCharVar(tbl[1])

        for _, varVal in pairs(tbl[2]) do
            if val == varVal then
                return true
            end
        end

        return false
    end,

    vargt = function(player, val)
        return player:getCharVar(val[1]) > val[2]
    end,

    varlt = function(player, val)
        return player:getCharVar(val[1]) < val[2]
    end,

    varlist = function(player, val)
        for _, varInfo in pairs(val) do
            if player:getCharVar(varInfo[1]) < varInfo[2] then
                return false
            end
        end

        return true
    end,

    zero = function(player, variable)
        return player:getCharVar(variable) == 0
    end,

    allzero = function(player, variable)
        local zoneID   = player:getZoneID()
        local alliance = player:getAlliance()

        for _, member in pairs(alliance) do
            if
                member ~= nil and
                member:isPC() and
                member:getZoneID() == zoneID
            then
                if member:getCharVar(variable) ~= 0 then
                    return false
                end
            end
        end

        return true
    end,

    timeout = function(player, variable)
        return GetSystemTime() < player:getCharVar(variable)
    end,

    cooldown = function(player, variable)
        return GetSystemTime() > player:getCharVar(variable)
    end,

    bool = function(player, val)
        return val
    end,

    item = function(player, item)
        return player:hasItem(item)
    end,

    ki = function(player, keyItem)
        return player:hasKeyItem(keyItem)
    end,

    skill = function(player, skillInfo)
        return player:getCharSkillLevel(skillInfo[1]) >= skillInfo[2]
    end,

    quest = function(player, questInfo)
        return player:hasCompletedQuest(questInfo[1], questInfo[2])
    end,

    -----------------------------------
    -- Teleporter-related checks
    -----------------------------------
    gil = function(player, val)
        return player:getGil() >= val
    end,

    cp = function(player, val)
        return player:getCP() >= val
    end,

    rank = function(player, val)
        if type(val) == "number" then
            return player:getRank(player:getNation()) >= val
        elseif type(val) == "table" then
            return player:getRank(val[1]) >= val[2]
        end
        return false
    end,

    hasTeleport = function(player, val)
        if type(val) == "number" then
            return player:hasTeleport(player:getNation(), val + 5)
        elseif type(val) == "table" then
            return player:hasTeleport(val[1], val[2] + 5)
        end
        return false
    end,

    currency = function(player, val)
        return player:getCurrency(val[1]) >= val[2]
    end,
}

LQS.checks = function(tbl)
    return function(player)
        local pass = true

        for k, v in pairs(tbl) do
            if not checkList[string.lower(k)](player, v) then
                pass = false
            end
        end

        return pass
    end
end

-----------------------------------
-- LQS.dialog
-----------------------------------
LQS.dialog = function(obj)
    return function(player, npc, tbl, var, step, questName)
        -----------------------------------
        -- Prevent players spamming dialog and duplicating rewards
        -----------------------------------
        if player:getLocalVar("[LQS]REWARD") > 0 then
            return
        end

        -----------------------------------
        -- Player does not meet requirements
        -- Show default dialog or "fail" dialog
        -----------------------------------
        if
            obj.check ~= nil and
            not LQS.checks(obj.check)(player)
        then
            if obj.fail ~= nil then
                LQS.event(player, npc, obj.fail)
            else
                LQS.event(player, npc, tbl.dialog.DEFAULT)
            end

            return
        end

        -----------------------------------
        -- Setup conditional dialog events
        -----------------------------------
        local event = obj.event

        if obj.conditionalDialog ~= nil then
            event = conditional[obj.conditionalDialog](player, obj.event)
        end

        -----------------------------------
        -- If spawned, despawn marker and spawn NPC
        -----------------------------------
        if not eventSpawn(obj, player, npc, event) then
            if obj.name == "" then
                LQS.event(player, nil, event)
            else
                LQS.event(player, npc, event)
            end
        end

        -- If not a step, stop here
        -- eg. Hint/Reminder dialog
        if
            obj.step ~= nil and
            not obj.step
        then
            return
        end

        -----------------------------------
        -- Prevent spamming events with local var
        -----------------------------------
        local delay = LQS.eventDelay(event)
        player:setLocalVar("[LQS]REWARD", 1)

        player:timer(delay, function(playerArg)
            -----------------------------------
            -- No reward, give Quest/Mission accepted message
            -----------------------------------
            if obj.reward == nil then
                player:setCharVar(var, step)

                if obj.quest ~= nil then
                    LQS.questAccepted(player, obj.quest, false)
                elseif obj.mission ~= nil then
                    LQS.newMission(player, obj.mission)
                end

                player:setLocalVar("[LQS]REWARD", 0)
                return
            end

            -----------------------------------
            -- Setup conditional rewards
            -----------------------------------
            local reward = obj.reward

            if obj.conditionalReward ~= nil then
                reward = conditional[obj.conditionalReward](player, obj.reward)
            end

            -----------------------------------
            -- Reward handling
            -----------------------------------
            if giveReward(player, reward, questName) then
                -- If the reward was succesfully given, advance the step
                player:setCharVar(var, step)

                -- If not explicitly beginQuest, assume Quest/Mission complete
                if obj.beginQuest ~= nil then
                    LQS.questAccepted(player, obj.beginQuest)
                elseif obj.quest ~= nil then
                    LQS.questCompleted(player, obj.quest, false)
                elseif obj.mission ~= nil then
                    LQS.newMission(player, obj.mission)
                end

                -- Call optional after function
                -- Older quest style
                if
                    type(reward) == "table" and
                    reward.after ~= nil
                then
                    reward.after(player)
                end

                -- Newer quest style
                if obj.after ~= nil then
                    obj.after(player)
                end

                -----------------------------------
                -- Clear locking var
                -----------------------------------
                player:setLocalVar("[LQS]REWARD", 0)
                return true
            else
                player:setLocalVar("[LQS]REWARD", 0)
                return false
            end
        end)
    end
end

-----------------------------------
-- LQS.trade
-----------------------------------
local function performTrade(obj, player, var, count, increment, items, multiple)
    if
        (obj.reward == nil and items == nil) or
        (type(obj.reward) == "table" and giveReward(player, obj.reward, obj)) or
        npcUtil.giveItem(player, items or obj.reward, { multiple = multiple })
    then
        player:tradeComplete()

        if
            obj.step == nil or
            obj.step
        then
            player:incrementCharVar(var, increment or 1)
        end

        if
            obj.reward ~= nil and
            type(obj.reward) == "table" and
            obj.reward.after ~= nil
        then
            local result = obj.reward.after(player)

            if type(result) ~= "boolean" then
                print("[LQS] Reward \"after\" function did not return a boolean value.")
            end
        end

        if obj.quest ~= nil then
            LQS.questCompleted(player, obj.quest, false)
        elseif obj.mission ~= nil then
            LQS.newMission(player, obj.mission)
        end

        player:setLocalVar("[LQS]REWARD", 0)
    else
        player:tradeRelease()
    end
end

LQS.trade = function(obj)
    return function(player, npc, trade, entity, var, step, tbl)
        if player:getLocalVar("[LQS]REWARD") == 1 then
            return
        end

        if obj.list ~= nil then
            for _, tradeInfo in pairs(obj.list) do
                if npcUtil.tradeHasExactly(trade, tradeInfo.required) then
                    player:setLocalVar("[LQS]REWARD", 1)
                    local delay = LQS.eventDelay(tradeInfo.accepted)

                    if not eventSpawn(obj, player, npc, tradeInfo.accepted) then
                        LQS.event(player, npc, tradeInfo.accepted)
                    end

                    player:timer(delay, function(playerArg)
                        performTrade(obj, player, var, nil, tradeInfo.increment)
                    end)

                    return
                end
            end

        -- TODO: Refactor and make this more sensible
        elseif obj.exchange ~= nil then
            local totalQtyTraded = 0

            for i = 0, trade:getSlotCount()-1 do
                local itemID = trade:getItemId(i)

                if
                    (obj.exchange[itemID] == nil and
                    obj.sellrate == nil) or
                    (obj.exclude ~= nil and obj.exclude[itemID])
                then
                    if not eventSpawn(obj, player, npc, obj.declined) then
                        LQS.event(player, npc, obj.declined)
                    end

                    return
                end

                totalQtyTraded = totalQtyTraded + trade:getSlotQty(i)
            end

            if obj.sellrate == nil then
                if player:getFreeSlotsCount() < totalQtyTraded then
                    player:sys("You don't have enough inventory space.")
                    return
                end
            end

            player:setLocalVar("[LQS]REWARD", 1)

            local delay = LQS.eventDelay(obj.accepted)

            if not eventSpawn(obj, player, npc, obj.accepted) then
                LQS.event(player, npc, obj.accepted)
            end

            player:timer(delay, function(playerArg)
                local givenGil = 0
                local results  = {}

                for i = 0, trade:getSlotCount()-1 do
                    local slotID   = trade:getItemId(i)
                    local slotQty  = trade:getSlotQty(i)

                    for j = 1, slotQty do
                        if
                            obj.exchange[slotID] == nil and
                            obj.sellrate ~= nil
                        then
                            local item  = GetItemByID(slotID)
                            local value = item:getBasePrice()

                            if value == 0 then
                                value = 1
                            end

                            local total = math.floor(value * obj.sellrate) + 1
                            local flags = item:getFlag()

                            -- Ex items are worth an extra 10g
                            if bit.band(item:getFlag(), xi.itemFlag.EX) ~= 0 then
                                total = total + 10
                            end

                            -- Rare items are worth an extra 50g
                            if bit.band(item:getFlag(), xi.itemFlag.RARE) ~= 0 then
                                total = total + 50
                            end

                            givenGil = givenGil + total
                        else
                            local exchangeList = obj.exchange[slotID]

                            -- Allow the item table to be filtered by a conditional function
                            if obj.conditional ~= nil then
                                exchangeList = obj.conditional(player, obj.exchange[slotID])
                            end

                            local result  = LQS.pickItem(exchangeList)
                            local givenID = result[2]

                            if type(givenID) == "table" then
                                if givenID.gil ~= nil then
                                    givenGil = givenGil + givenID.gil
                                end
                            else
                                local givenQty = 1

                                if
                                    result[4] ~= nil and
                                    type(result[4]) == "table"
                                then
                                    givenQty = math.random(result[4][1], result[4][2])
                                end

                                results[givenID] = (results[givenID] or 0) + givenQty
                            end
                        end
                    end
                end

                local items = {}

                for itemID, itemQty in pairs(results) do
                    -- This will preventing locking the trade container when it fails to give an item
                    if player:canObtainItem(itemID) then
                        table.insert(items, { itemID, itemQty })
                    elseif
                        -- if the exchange defines a replcement for this itemid if it's unobtainable (player already has)
                        obj.replacements ~= nil and
                        obj.replacements[itemID]
                    then
                        table.insert(items, obj.replacements[itemID])
                    else
                        -- otherwise just replace it with a cluster, everyone loves clusters
                        local clusters =
                        {
                            xi.item.FIRE_CLUSTER,
                            xi.item.ICE_CLUSTER,
                            xi.item.WIND_CLUSTER,
                            xi.item.EARTH_CLUSTER,
                            xi.item.LIGHTNING_CLUSTER,
                            xi.item.WATER_CLUSTER,
                            xi.item.LIGHT_CLUSTER,
                            xi.item.DARK_CLUSTER,
                        }
                        table.insert(items, clusters[math.random(#clusters)])
                    end
                end

                performTrade(obj, player, var, totalQtyTraded, nil, items, true)

                if givenGil > 0 then
                    npcUtil.giveCurrency(player, "gil", givenGil)

                    if obj.points ~= nil then
                        local givenPts = math.floor(givenGil / 10) + 1
                        player:incrementCharVar(obj.points.var, givenPts)
                        player:sys("{} gains {} {}.", player:getName(), givenPts, obj.points.name)
                    end
                end
            end)

            return
        else
            local count = trade:getItemCount()
            local total = count

            if npcUtil.tradeHasExactly(trade, obj.required) then
                player:setLocalVar("[LQS]REWARD", 1)

                if obj.tally ~= nil then
                    player:incrementCharVar(obj.tally, count)
                end

                local delay = LQS.eventDelay(obj.accepted)

                if
                    obj.spawn == nil or
                    type(obj.spawn) == "table" or
                    not eventSpawn(obj, player, npc, obj.accepted)
                then
                    LQS.event(player, npc, obj.accepted)
                end

                player:timer(delay, function(playerArg)
                    if
                        obj.spawn == nil or
                        type(obj.spawn) == "string"
                    then
                        performTrade(obj, player, var, count)
                    else
                        if obj.flag ~= nil then
                            player:setLocalVar(obj.flag, 1)
                        end

                        local mobs = obj.spawn

                        if obj.spawn.hq ~= nil then
                            mobs = { obj.spawn.nq }

                            if math.random(0, 100) < obj.spawn.rate then
                                mobs = { obj.spawn.hq }
                            end
                        end

                        for _, mobName in pairs(mobs) do
                            if delaySpawn(player, npc, 0, mobs, tbl, true, {
                                setPos       = npc:getPos(),
                                nextPos      = obj.nextPos,
                                levelCap     = obj.levelCap,
                                raiseAllowed = obj.raiseAllowed,
                                partySize    = obj.partySize,
                                scaleVar     = obj.scaleVar,
                            }) then
                                performTrade(obj, player, var, count)

                                if obj.setVar ~= nil then
                                    for _, varInfo in pairs(obj.setVar) do
                                        player:setCharVar(varInfo[1], varInfo[2])
                                    end
                                end
                            end

                            if obj.setVarAll ~= nil then
                                allPlayers(player, function(member)
                                    member:setCharVar(obj.setVarAll[1], obj.setVarAll[2])
                                end)
                            end
                        end
                    end
                end)

                return
            end
        end

        if not eventSpawn(obj, player, npc, obj.declined) then
            LQS.event(player, npc, obj.declined)
        end
    end
end

-----------------------------------
-- LQS.menu
-----------------------------------
LQS.menu = function(obj)
    return function(player, npc, tbl, var, step, entities)
        -- Prevent players opening menu while in dialog
        if player:getLocalVar("[LQS]BLOCKING") == 1 then
            return
        end

        if
            obj.check ~= nil and
            not obj.check(player)
        then
            if obj.declined ~= nil then
                LQS.event(player, npc, obj.declined)
            else
                if obj.default == nil then
                    printf("[LQS] Default event does not exist for (%s)", npc:getPacketName())
                    return
                end

                if
                    obj.default.condition ~= nil and
                    player:getCharVar(obj.default.condition[1]) == obj.default.condition[2]
                then
                    LQS.event(player, npc, obj.default.dialog)
                else
                    if type(obj.default) == "table" then
                        LQS.event(player, npc, obj.default)
                    else
                        LQS.event(player, npc, { obj.default })
                    end
                end
            end

            return
        end

        local options = {}
        local i = 1

        for i = 1, #obj.options do
            table.insert(options, {
                obj.options[i][1],
                function()
                    if obj.options[i][2] ~= nil then
                        if type(obj.options[i][2]) == "boolean" then
                            if obj.spawn ~= nil then
                                if obj.flag ~= nil then
                                    player:setLocalVar(obj.flag, 1)
                                end

                                local mobs = obj.spawn

                                if obj.spawn.hq ~= nil then
                                    mobs = { obj.spawn.nq }

                                    if math.random(0, 100) < obj.spawn.rate then
                                        mobs = { obj.spawn.hq }
                                    end
                                end

                                for _, mobName in pairs(mobs) do
                                    if delaySpawn(player, npc, 0, mobs, entities, true, {
                                        setPos       = npc:getPos(),
                                        nextPos      = obj.nextPos,
                                        levelCap     = obj.levelCap,
                                        raiseAllowed = obj.raiseAllowed,
                                        partySize    = obj.partySize,
                                        scaleVar     = obj.scaleVar,
                                    }) then
                                        if obj.setVar ~= nil then
                                            for _, varInfo in pairs(obj.setVar) do
                                                player:setCharVar(varInfo[1], varInfo[2])
                                            end
                                        end
                                    end

                                    if obj.setVarAll ~= nil then
                                        allPlayers(player, function(member)
                                            member:setCharVar(obj.setVarAll[1], obj.setVarAll[2])
                                        end)
                                    end
                                end
                            end

                            return
                        end

                        local delay = LQS.eventDelay(obj.options[i][2])
                        LQS.event(player, npc, obj.options[i][2])

                        if obj.options[3] ~= nil then
                            if player:getLocalVar("[LQS]REWARD") == 1 then
                                return
                            end

                            player:setLocalVar("[LQS]REWARD", 1)
                        end

                        npc:timer(delay, function(playerArg)
                            -- Optionally give item after dialog
                            if obj.options[i][3] ~= nil then
                                if npcUtil.giveItem(player, obj.options[3]) then

                                    if
                                        obj.step == nil or
                                        obj.step
                                    then
                                        player:setCharVar(var, step)
                                    end

                                    if obj.quest ~= nil then
                                        LQS.questAccepted(player, obj.quest, false)
                                    elseif obj.mission ~= nil then
                                        LQS.newMission(player, obj.mission)
                                    end
                                end
                            else
                                if
                                    obj.step == nil or
                                    obj.step
                                then
                                    player:setCharVar(var, step)
                                end

                                if obj.quest ~= nil then
                                    if obj.finish ~= nil then
                                        LQS.questCompleted(player, obj.quest, false)
                                    else
                                        LQS.questAccepted(player, obj.quest, false)
                                    end
                                elseif obj.mission ~= nil then
                                   LQS.newMission(player, obj.mission)
                                end
                            end

                            player:setLocalVar("[LQS]REWARD", 0)
                        end)
                    end
                end,
            })
        end

        local delay = 0

        if obj.before ~= nil then
            if type(obj.before) == "table" then
                LQS.event(player, npc, obj.before)
                delay = LQS.eventDelay(obj.before)
            else
                LQS.event(player, npc, { obj.before })
                delay = LQS.eventDelay({ obj.before })
            end
        end

        player:timer(delay, function()
            player:customMenu({
                title   = obj.title,
                options = options,
            })
        end)
    end
end

-----------------------------------
-- LQS.shop
-----------------------------------
LQS.simpleShop = function(player, npc, tbl, func, title, currentPage, param)
    local options  = {}
    local max      = 1
    local lastPage = math.floor((#tbl - 1) / 4)
    local page     = currentPage

    if currentPage == nil then
        page = 0
    end

    if page > 0 then
        table.insert(options, {
            "(Prev)",
            function(player)
                LQS.simpleShop(player, npc, tbl, func, title, page - 1, param)
            end,
        })
    end

    for i = 1, 4 do
        local item  = tbl[page * 4 + i]
        local block = false

        if
            param ~= nil and
            param.milestone ~= nil
        then
            local milestoneVal = player:getCharVar(param.milestone)

            if utils.mask.getBit(milestoneVal, page * 4 + i) then
                block = true
            end
        end

        if item ~= nil then
            local itemName = item[1]
            local itemCost = item[3]
            local label    = itemName

            if itemCost > 0 then
                if block then
                    label = string.format("-Claimed- (%u)", itemCost)
                else
                    label = string.format("%s (%u)", label, itemCost)
                end
            end

            table.insert(options, {
                label,
                function(playerArg)
                    if not block then
                        func(player, npc, item, param)
                    end
                end
            })

            max = page * 4 + i
        end
    end

    if max < #tbl then
        table.insert(options, {
            "(Next)",
            function(player)
                LQS.simpleShop(player, npc, tbl, func, title, page + 1, param)
            end,
        })
    end

    delaySendMenu(player, {
        title   = title,
        options = options,
    })
end

LQS.purchaseItem = function(player, npc, item, obj)
    local balance  = player:getCharVar(obj.var)

    if item[3] > balance then
        player:sys("You can't afford this purchase.")
        return
    end

    delaySendMenu(player, {
        title   = fmt("Buy {} ({})?", item[1], item[3]),
        options =
        {
            {
                "No",
                function()
                end,
            },
            {
                "Yes",
                function()
                    if type(item[2]) == "string" then
                        player:setCharVar(item[2], 1)
                        player:sys(item[4])
                        player:incrementCharVar(obj.var, -item[3])
                    else
                        if npcUtil.giveItem(player, item[2]) then
                            npc:facePlayer(player, true)
                            player:incrementCharVar(obj.var, -item[3])
                        end
                    end
                end,
            },
        },
    })
end

LQS.shop = function(obj)
    return function(player, npc, tbl, var, step)
        local balance  = player:getCharVar(obj.var)
        local purchase = function(player, npc, item)
            LQS.purchaseItem(player, npc, item, obj)
        end

        if obj.dialog ~= nil then
            LQS.event(player, nil, obj.dialog)
        end

        local list = {}

        for _, item in pairs(obj.list) do
            if type(item[2]) == "string" then
                if player:getCharVar(item[2]) == 0 then
                    table.insert(list, item)
                end
            else
                table.insert(list, item)
            end
        end

        LQS.simpleShop(player, npc, list, purchase, fmt(obj.title, balance))
    end
end

-----------------------------------
-- LQS.paginatedMenu
-- General-purpose paginated menu builder
-----------------------------------
LQS.paginatedMenu = function(player, config)
    local title        = config.title or "Select Option"
    local items        = config.items or {}
    local itemsPerPage = config.itemsPerPage or 5
    local filter       = config.filter
    local onSelect     = config.onSelect
    local showNav      = config.showNavigation ~= false
    local onCancel     = config.onCancel
    local npc          = config.npc

    -- Filter items if filter function provided
    local filteredItems = {}
    for _, item in ipairs(items) do
        if filter == nil or filter(player, item) then
            table.insert(filteredItems, item)
        end
    end

    -- Return early if no items available
    if #filteredItems == 0 then
        if onCancel then
            onCancel(player, "no_items")
        end
        return
    end

    local totalPages = math.ceil(#filteredItems / itemsPerPage)

    local function showPage(pageNum)
        local options  = {}
        local startIdx = (pageNum - 1) * itemsPerPage + 1
        local endIdx   = math.min(startIdx + itemsPerPage - 1, #filteredItems)

        -- Previous page navigation
        if showNav and pageNum > 1 then
            table.insert(options, {
                "(Prev)",
                function(playerArg)
                    showPage(pageNum - 1)
                end
            })
        end

        -- Add items for current page
        for i = startIdx, endIdx do
            local item  = filteredItems[i]
            local label = item.label or item.name or item[1]

            -- Allow label to be a function
            if type(label) == "function" then
                label = label(player, item)
            end

            table.insert(options, {
                label,
                function(playerArg)
                    if onSelect then
                        onSelect(playerArg, item, npc)
                    end
                end
            })
        end

        -- Next page navigation
        if showNav and pageNum < totalPages then
            table.insert(options, {
                "(Next)",
                function(playerArg)
                    showPage(pageNum + 1)
                end
            })
        end

        -- First page navigation (if more than 2 pages and not on first page)
        if showNav and totalPages > 2 and pageNum > 1 then
            table.insert(options, {
                "(First)",
                function(playerArg)
                    showPage(1)
                end
            })
        end

        -- Cancel option
        if onCancel then
            table.insert(options, {
                "Cancel",
                function(playerArg)
                    onCancel(playerArg, "cancelled")
                end
            })
        end

        -- Build title
        local menuTitle = title
        if type(title) == "function" then
            menuTitle = title(pageNum, totalPages)
        elseif totalPages > 1 then
            menuTitle = string.format("%s (%d/%d)", title, pageNum, totalPages)
        end

        -- Show menu with slight delay to prevent context issues
        player:timer(100, function(playerArg)
            playerArg:customMenu({
                title   = menuTitle,
                options = options,
            })
        end)
    end

    -- Start at page 1
    showPage(1)
end

-----------------------------------
-- LQS.signetEffect
-- Helper to create Signet effect config for teleporters
-- Usage: preTeleportEffects = { LQS.signetEffect() }
-----------------------------------
LQS.signetEffect = function()
    return {
        effect            = xi.effect.SIGNET,
        removeConflicting = true,
        duration          = function(player)
            local pNation = player:getNation()
            local pRank   = player:getRank(pNation)
            return (pRank + GetNationRank(pNation) + 3) * 3600
        end
    }
end

-----------------------------------
-- LQS.teleporter
-- Config-driven teleporter NPC creation
-----------------------------------
LQS.teleporter = function(config)
    local moduleName = string.format("lqs_teleporter_%s", string.lower(string.gsub(config.name or "unknown", " ", "_")))
    local m = Module:new(moduleName)

    -- Default configuration
    local defaults = {
        itemsPerPage      = 5,
        teleportDelay     = 1250,
        greeting          = "Where would you like to go?",
        noDestinations    = "You haven't unlocked any destinations.",
        insufficientGil   = "You don't have enough Gil.",
        insufficientCP    = "You don't have enough conquest points.",
        cancelled         = "Safe travels!",
    }

    -- Merge defaults with config
    for k, v in pairs(defaults) do
        if config[k] == nil then
            config[k] = v
        end
    end

    m:addOverride(string.format("xi.zones.%s.Zone.onInitialize", config.zone), function(zone)
        super(zone)

        -- Helper: Apply pre-teleport effects
        local function applyPreEffects(player)
            if config.preTeleportEffects then
                for _, effectInfo in ipairs(config.preTeleportEffects) do
                    local duration = effectInfo.duration
                    if type(duration) == "function" then
                        duration = duration(player)
                    end
                    duration = duration or 3600

                    -- Remove conflicting effects if needed (e.g., for Signet)
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

            -- Gil option
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

            -- CP option
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

            -- Free teleport (no costs defined)
            if gilCost == 0 and cpCost == 0 then
                executeTeleport(player, destination)
                return
            end

            -- Cancel option
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

        -- Filter function for destinations
        local function filterDestination(player, dest)
            -- Level check
            if dest.level and player:getMainLvl() < dest.level then
                return false
            end

            -- Custom check function
            if dest.check and not dest.check(player) then
                return false
            end

            return true
        end

        -- Insert the NPC
        zone:insertDynamicEntity({
            objtype    = xi.objType.NPC,
            name       = config.name,
            packetName = config.packetName or config.name,
            look       = config.look,
            x          = config.pos[1],
            y          = config.pos[2],
            z          = config.pos[3],
            rotation   = config.pos[4] or 0,
            widescan   = 1,

            onTrigger = function(player, npc)
                npc:lookAt(player:getPos())

                if config.greeting then
                    player:printToPlayer(config.greeting, xi.msg.channel.SYSTEM_3)
                end

                -- Use paginated menu
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
            end,
        })
    end)

    return m
end

-----------------------------------
-- LQS.outpostTeleporter
-- Pre-configured outpost warper template
-----------------------------------
LQS.outpostTeleporter = function(config)
    -- Standard outpost table with costs and requirements
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

    -- Allow config to override outpost costs
    if config.outpostOverrides then
        for region, overrides in pairs(config.outpostOverrides) do
            if outpostTable[region] then
                for k, v in pairs(overrides) do
                    outpostTable[region][k] = v
                end
            end
        end
    end

    -- Build destinations from outpost table
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
                    -- Tavnazia requires rank 6
                    return player:getRank(player:getNation()) >= 6
                elseif region == xi.region.QUFIMISLAND then
                    -- Qufim is accessible to everyone
                    return true
                else
                    return player:hasTeleport(player:getNation(), region + 5)
                end
            end,
        })
    end

    -- Sort by region ID for consistent ordering
    table.sort(destinations, function(a, b)
        return a.region < b.region
    end)

    -- Set destinations in config
    config.destinations = destinations

    -- preTeleportEffects is optional - use LQS.signetEffect() to add Signet
    -- Example: preTeleportEffects = { LQS.signetEffect() }

    -- Set default animation if not specified
    if config.animation == nil then
        config.animation = { actionID = 6, animID = 600 }
    end

    -- Set default greeting if not specified
    if config.greeting == nil then
        config.greeting = "Welcome to the Outpost Warp Service!"
    end

    return LQS.teleporter(config)
end

-----------------------------------
-- LQS.defeat
-----------------------------------
local function awardGive(player, var, reward)
    local var = string.format("[HELPER]%s", string.upper(var))

    -- Make sure player can't claim reward more than once every 24 hours
    if player:getCharVar(var) == 0 then
        print(string.format("[HELPER] %s has claimed a reward for helping with %s.", player:getName(), var))
        player:setCharVar(var, 1, JstMidnight())

        -- Increment var for helper points and leaderboards
        player:incrementCharVar("[HELPER]POINTS", 1)

        -- If player's inventory is full, increment var to receive later
        if not npcUtil.giveItem(player, reward) then
            player:incrementCharVar("[HELPER]EXP_SCROLL", 1)
        end
    end
end

LQS.defeat = function(params)
    return function(mob, player, entity, var, step, entities, check)
        if mob:getLocalVar("KILLED") == 1 then
            return
        end

        mob:setLocalVar("KILLED", 1)

        if params.mobs ~= nil then
            for _, mobName in pairs(params.mobs) do
                local ent = getEntity(player, mobName)

                if ent:isAlive() then
                    return false
                end
            end
        end

        local nextStep = step

        if resetStep ~= nil then
            nextStep = 0
        end

        -- Increment player quest step
        allPlayers(player, function(member)
            -- Apply update for players on the current quest step
            if
                (params.step == nil or params.step == true) and
                (member:getCharVar(var) == (step - 1) and
                (check == nil or check(alliance[i])))
            then
                -- Apply var changes only for flagged players
                if
                    params ~= nil and
                    params.flag ~= nil
                then
                    if member:getLocalVar(params.flag) == 1 then
                        member:setCharVar(var, nextStep)
                        member:setLocalVar(params.flag, 0)
                    end
                else
                    member:setCharVar(var, nextStep)
                end
            end

            -- Apply optional cooldown or clear local var for all players
            if params ~= nil then
                if params.cooldown ~= nil then
                    member:setCharVar(params.cooldown, 1, JstMidnight())
                end

                if params.setLocal ~= nil then
                    member:setLocalVar(params.setLocal.var, params.setLocal.val)
                end

                if params.helper ~= nil then
                    local cooldownVar = var .. "_HELPER"

                    if params.var ~= nil then
                        cooldownVar = params.var
                    end

                    awardGive(member, cooldownVar, params.helper)
                end

                if params.exp ~= nil then
                    member:addExp(params.exp)
                end

                if params.message ~= nil then
                    if params.points ~= nil then
                        local total = params.points

                        if params.multiplier ~= nil then
                            local multiply mob:getLocalVar(params.multiplier.var)
                            total = utils.clamp(params.points * multiply, params.multiplier.range[1], params.multiplier.range[2]) + math.random(1, params.points)
                        else
                            if type(params.points) == "table" then
                                total = math.random(params.points[1], params.points[2])
                            end
                        end

                        member:incrementCharVar(params.pointsVar, total)
                        member:sys(params.message, member:getName(), total)
                    else
                        member:sys(params.message)
                    end
                end

                if params.cooldown ~= nil then
                    member:setCharVar(params.cooldown, 1, JstMidnight())
                end

                if params.func ~= nil then
                    params.func(member, step - 1)
                end

                if params.raise ~= nil then
                    member:sendRaise(params.raise)
                end
            end

            -- Remove level cap
            removeLevelCap(member)
        end)

        -- Respawn spawner
        if params.spawner ~= nil then
            local spawner = getEntity(player, params.spawner)

            if spawner ~= nil then
                spawner:setStatus(xi.status.NORMAL)
            end
        end
    end
end

LQS.npcSpawner = function(tbl, npc, spawner, keepSpawner)
    local result = {}
    local before = {}
    local after  = {}

    local npcs = npc

    if type(npc) ~= "table" then
        npcs = { npc }
    end

    if keepSpawner then
        before =
        {
            { noturn  = true },
            { spawn   = npcs },
            { delay   = 500 },
            { entity  = npcs[1], face = "player" },
            { delay   = 500 },
        }

        after =
        {
            { delay   = 500 },
            { despawn = npcs },
        }
    else
        before =
        {
            { despawn = { spawner } },
            { spawn   = npcs },
            { delay   = 500 },
            { entity  = npcs[1], face = "player" },
            { delay   = 500 },
        }

        after =
        {
            { delay   = 500 },
            { despawn = npcs },
            { spawn   = { spawner } },
        }
    end

    for _, line in pairs(before) do
        table.insert(result, line)
    end

    for _, line in pairs(tbl) do
        table.insert(result, line)
    end

    for _, line in pairs(after) do
        table.insert(result, line)
    end

    return result
end

-----------------------------------
-- Extra helpers
-----------------------------------
LQS.nothingElse = function()
    return LQS.dialog({
        step  = false,
        name  = "",
        event =
        {
            "There is nothing else to do here.",
        },
    })
end

-----------------------------------
-- Step generators
-----------------------------------
local function getStepFunctions(steps, name)
    local func = {}

    for i = 1, #steps do
        if steps[i][name] ~= nil then
            func[i] = steps[i][name]
        end
    end

    return func
end

local getSteps = function(var, entity, steps, entities, questName)
    local func = getStepFunctions(steps, entity.name)

    return function(player, npc)
        -- Interactable NPCs must have a dialog table or default dialog
        if entity.dialog == nil and entity.default == nil then
            return
        end

        local defaultDialog = nil

        if entity.dialog ~= nil then
            defaultDialog = entity.dialog.DEFAULT
        elseif entity.default ~= nil then
            defaultDialog = entity.default
        else
            return
        end

        -- Check custom requirement overrides from quest registry
        if
            LQS.registry[questName] ~= nil and
            LQS.registry[questName].check ~= nil and
            not LQS.registry[questName].check(player)
        then
            LQS.event(player, npc, defaultDialog)
            return
        end

        local step    = player:getCharVar(var) + 1
        local npcName = entity.name

        if entity.marker ~= nil then
            npcName = ""
        elseif npcName == nil then
            npcName = npc:getPacketName()
        end

        if
            func[step] == nil or
            (
                steps[step].check and
                not steps[step].check(player)
            )
        then
            LQS.event(player, npc, defaultDialog)
        else
            if type(func[step]) == "table" then
                if func[step]["onTrigger"] ~= nil then
                    if
                        func[step].check and
                        not func[step].check(player)
                    then
                        LQS.event(player, npc, defaultDialog)
                        return
                    end

                    func[step]["onTrigger"](player, npc, entity, var, step, entities, questName)
                else
                    LQS.event(player, npc, defaultDialog)
                end
            else
                func[step](player, npc, entity, var, step, entities, questName)
            end
        end
    end
end

local getTradeSteps = function(var, entity, steps, tbl)
    local func = getStepFunctions(steps, entity.name)

    return function(player, npc, trade)
        local step = player:getCharVar(var) + 1

        -- Do not attempt to call trade functions on dialog only step
        if
            func[step] ~= nil and
            type(func[step]) == "table" and
            func[step]["onTrade"]
        then
            if
                func[step].check and
                not func[step].check(player)
            then
                return
            end

            func[step]["onTrade"](player, npc, trade, entity, var, step, tbl)
        end
    end
end

local getMobSteps = function(event, var, entity, steps, entities)
    local func = getStepFunctions(steps, entity.name)

    return function(mob, player, optParams)
        -- TODO:
        -- Can we respawn the marker if we don't know the step?
        if player == nil then
            return
        end

        if player:isPC() then
            if
                entity.restore ~= nil and
                optParams ~= nil and optParams.isKiller
            then
                player:setHP(player:getMaxHP())
                player:setMP(player:getMaxMP())
                player:setTP(3000)
            end

            if entity.title ~= nil then
                player:addTitle(entity.title)
            end
        end

        if mob:getLocalVar("LOOT_ROLLED") == 0 then
            if entity.loot ~= nil then
                mob:setLocalVar("LOOT_ROLLED", 1)

                for _, itemInfo in pairs(entity.loot) do
                    if itemInfo[2] == nil then
                        print(fmt("[LQS] Missing item ID! Rolled loot is nil for {} (Player: {})", mob:getName(), player:getName()))
                    elseif itemInfo[2] ~= 0 then
                        player:addTreasure(itemInfo[2], mob, itemInfo[1])
                    end
                end
            end

            -- TODO: Clean this up
            if entity.pool ~= nil then
                mob:setLocalVar("LOOT_ROLLED", 1)

                for _, pool in pairs(entity.pool) do
                    if pool.quantity ~= nil then
                        for _ = 1, pool.quantity do
                            local result = LQS.pickItem(pool)

                            if result[2] == nil then
                                print(fmt("[LQS] Missing item ID! Rolled loot is nil for {} (Player: {})", mob:getName(), player:getName()))
                            elseif result[2] ~= 0 then
                                player:addTreasure(result[2], mob)
                            end
                        end
                    else
                        local result = LQS.pickItem(pool)

                        if result[2] == nil then
                            print(fmt("[LQS] Missing item ID! Rolled loot is nil for {} (Player: {})", mob:getName(), player:getName()))
                        elseif result[2] ~= 0 then
                            player:addTreasure(result[2], mob)
                        end
                    end
                end
            end
        end

        if
            entity.points ~= nil and
            mob:getLocalVar("POINTS_ROLLED") == 0
        then
            mob:setLocalVar("POINTS_ROLLED", 1)

            allPlayers(player, function(member)
                if entity.points.exp ~= nil then
                    member:addExp(entity.points.exp)
                end

                if entity.points.amount ~= nil then
                    local amount = math.random(entity.points.amount[1], entity.points.amount[2])
                    member:incrementCharVar(entity.points.var, amount)
                    member:sys(entity.points.message, member:getName(), amount)
                end

                if entity.points.gil ~= nil then
                    npcUtil.giveCurrency(member, "gil", entity.points.gil)
                end

                if entity.points.item ~= nil then
                    if 
                        not npcUtil.giveItem(member, entity.points.item) and
                        entity.points.missed ~= nil
                    then
                        member:sys("Your missed item was stored at the relevant NPC.")
                        member:incrementCharVar(fmt(entity.points.missed, entity.points.item))
                    end
                end
            end)
        end

        if entity.after ~= nil then
            entity.after(mob, player)
        end

        if entity.delCap ~= nil then
            allPlayers(player, function(member)
                member:delStatusEffect(xi.effect.LEVEL_RESTRICTION)
            end)
        end

        if entity.tally ~= nil then
            allPlayers(player, function(member)
                member:incrementCharVar(entity.tally, 1)
            end)
        end

        local step = player:getCharVar(var) + 1

        if func[step] == nil then
            return
        end

        if type(func[step]) == "table" then
            if
                func[step].check ~= nil and
                not func[step].check(player)
            then
                return
            end

            if func[step][event] ~= nil then
                func[step][event](mob, player, entity, var, step, entities, func[step].check)
            end
        elseif event == "onMobDeath" then
            func[step](mob, player, entity, var, step, entities, nil)
        end
    end
end

-----------------------------------
-- Entity load and reload
-----------------------------------
local function entitySetup(dynamicEntity, tbl, entity)
    local questName = string.lower(tbl.info.name)

    if
        entity.type == xi.objType.NPC or
        entity.marker ~= nil
    then
        dynamicEntity.onTrigger = getSteps(tbl.info.var, entity, tbl.steps, tbl.entities, questName)
        dynamicEntity.onTrade   = getTradeSteps(tbl.info.var, entity, tbl.steps, tbl.entities)

    elseif entity.type == xi.objType.MOB then
        dynamicEntity.groupId     = entity.groupId
        dynamicEntity.groupZoneId = entity.groupZoneId

        if entity.base ~= nil then
            dynamicEntity.groupId     = entity.base[2]
            dynamicEntity.groupZoneId = entity.base[1]
        end

        if entity.mixins ~= nil then
            dynamicEntity.mixins = entity.mixins
        end

        dynamicEntity.onMobDeath     = getMobSteps("onMobDeath", tbl.info.var, entity, tbl.steps, tbl.entities)
        dynamicEntity.onMobDisengage = function(mob)
            DespawnMob(mob:getID())
        end

        dynamicEntity.onMobInitialize = function(mob)
            mob:setMobMod(xi.mobMod.DETECTION, 0x08)
            mob:setMobMod(xi.mobMod.CHECK_AS_NM,  1)
            mob:setMobMod(xi.mobMod.CHARMABLE,    0)
            mob:setMobMod(xi.mobMod.ALLI_HATE,   30)

            if entity.aeffect ~= nil then
                mob:setMobMod(xi.mobMod.ADD_EFFECT, 1)
            end

            if entity.jobSpecial then
                g_mixins.job_special(mob)
            end

            if entity.immunities ~= nil then
                for _, immunity in pairs(entity.immunities) do
                    mob:addImmunity(immunity)
                end
            end

            if entity.skillList ~= nil then
                mob:setMobMod(xi.mobMod.SKILL_LIST, entity.skillList)
            end

            if entity.spellList ~= nil then
                mob:setMobMod(xi.mobMod.SPELL_LIST, entity.spellList)
            end

            if entity.mobMods ~= nil then
                for mobModID, mobModValue in pairs(entity.mobMods) do
                    mob:setMobMod(mobModID, mobModValue)
                end
            end
        end

        if entity.onMobFight ~= nil then
            dynamicEntity.onMobFight = function(mob, target)
                entity.onMobFight(mob, target)
            end
        end

        if entity.onMobSpawn ~= nil then
            dynamicEntity.onMobSpawn = function(mob)
                entity.onMobSpawn(mob)
            end
        end

        if entity.onMobRoam ~= nil then
            dynamicEntity.onMobRoam = function(mob)
                entity.onMobRoam(mob)
            end
        end

        if entity.aeffect ~= nil then
            if type(entity.aeffect) == "table" then
                dynamicEntity.onAdditionalEffect = function(mob, target, damage)
                    return xi.mob.onAddEffect(mob, target, damage, entity.aeffect[1], { power = math.random(entity.aeffect[2], entity.aeffect[3]) })
                end
            else
                dynamicEntity.onAdditionalEffect = function(mob, target, damage)
                    return xi.mob.onAddEffect(mob, target, damage, entity.aeffect, { power = math.random(16, 26) })
                end
            end
        end
    end
end

local function entityAfter(de, entity)
    if entity.animation then
        de:setAnimation(entity.animation)
    end

    if entity.hidden then
        de:setStatus(xi.status.DISAPPEAR)
    end

    if entity.hidename ~= nil then
        de:hideName(entity.hidename)
    end

    -- Hide names and HP for side-quest/sparkle markers
    if entity.marker ~= nil then
        de:hideName(true)
        de:hideHP(true)
    end

    if entity.hidehp ~= nil then
        de:hideHP(entity.hidehp)
    end

    if entity.notarget ~= nil then
        de:setUntargetable(entity.notarget)
    end

    if
        entity.type == xi.objType.MOB and
        entity.dialog ~= nil
    then
        printf("[LQS] %s is a mob but has been assigned dialog.", entity.name)
    end

    -- entity.listener syntax:
    -- { 'ENGAGE', 'NameOfEngageListener', function }
    if
        entity.listeners == nil and
        entity.listener ~= nil
    then
        entity.listeners = { entity.listener }
    end

    if entity.listeners ~= nil then
        for _, listener in pairs(entity.listeners) do
            de:removeListener(listener[2])
            de:addListener(listener[1], listener[2], listener[3])
        end
    end
end

local function entityRefresh(dynamicEntity, zone, tbl, entity)
    local result = zone:queryEntitiesByName("DE_" .. entity.name)

    if result ~= nil then
        for _, de in pairs(result) do
            de:setPos(entity.pos[1], entity.pos[2], entity.pos[3], entity.pos[4])

            if type(entity.look) == "string" then
                de:setLookString(entity.look)

            -- TODO: Need extra packet to update without zoning
            elseif entity.marker == nil then
                de:setModelId(entity.look)
            end

            entityAfter(de, entity)
        end
        printf("[LQS] Entity DE_%s was updated.", entity.name)
    else
        printf("[LQS] Entity DE_%s not found.", entity.name)
    end
end

-----------------------------------
-- Prevents Treasure Caskets spawning for custom quest mobs
-----------------------------------
m:addOverride("xi.caskets.spawnCasket", function(player, mob, x, y, z, r)
    if mob:getLocalVar("NO_CASKET") == 1 then
        return
    else
        super(player, mob, x, y, z, r)
    end
end)

-----------------------------------
-- LQS.add - Initialise new quest
-----------------------------------
local function getStepHint(tbl, step, entityZone, entityType)
    local hint = "Unknown"

    for entityName, stepInfo in pairs(step) do
        if entityName ~= "check" then
            local detail = fmt("{} in {}", string.gsub(entityName, "_", " "), entityZone[entityName])

            if entityType[entityName] == xi.objType.MOB then
                return "Defeat " .. detail
            else
                if
                    type(step[entityName]) == "table" and
                    step[entityName].onTrade ~= nil
                then
                    return "Trade " .. detail
                else
                    hint = "Interact with " .. detail
                end
            end
        end
    end

    return hint
end

LQS.add = function(source, tbl)
    -----------------------------------
    -- Create quest registry for !quest command
    -----------------------------------
    if #tbl.steps > 1 then
        local registryName = string.lower(tbl.info.name)
        local entry =
        {
            name   = tbl.info.name,
            author = tbl.info.author,
            var    = tbl.info.var,
            finish = #tbl.steps - 1,
            hint   = {},
            reward = {},
        }

        -- Reuse existing overrides to prevent them being wiped on reload
        if LQS.registry[registryName] ~= nil then
            entry.check = LQS.registry[registryName].check
            entry.after = LQS.registry[registryName].after
        end

        LQS.registry[registryName] = entry

        local entityZone = {}
        local entityType = {}

        for zoneName, entityList in pairs(tbl.entities) do
            for _, entityInfo in pairs(entityList) do
                entityZone[entityInfo.name] = string.gsub(zoneName, "_", " ")
                entityType[entityInfo.name] = entityInfo.type or xi.objType.NPC
            end
        end

        for _, step in pairs(tbl.steps) do
            table.insert(LQS.registry[registryName].hint, getStepHint(tbl, step, entityZone, entityType))
        end

        if tbl.info.reward ~= nil then
            if
                type(tbl.info.reward) == "table" and
                tbl.info.reward[1] ~= nil
            then
                for _, rewardInfo in pairs(tbl.info.reward) do
                    table.insert(LQS.registry[registryName].reward, rewardInfo)
                end
            else
                table.insert(LQS.registry[registryName].reward, tbl.info.reward)
            end
        end
    end

    -----------------------------------
    -- Create quest entities
    -----------------------------------
    for zoneName, zoneEntities in pairs(tbl.entities) do
        -- Live reload of dynamic entities
        for _, entityInfo in pairs(zoneEntities) do
            if
                xi ~= nil and
                xi.zones ~= nil and
                xi.zones[zoneName] ~= nil and
                xi.zones[zoneName].npcs ~= nil
            then
                local dynamicEntity = xi.zones[zoneName].npcs["DE_" .. entityInfo.name]

                if dynamicEntity ~= nil then
                    entitySetup(dynamicEntity, tbl, entityInfo)
                    local underscoreZoneName = string.gsub(zoneName, "-", "_")
                    local zone = GetZone(xi.zone[string.upper(underscoreZoneName)])

                    if zone ~= nil then
                        entityRefresh(dynamicEntity, zone, tbl, entityInfo)
                    end
                end
            end
        end

        -- First time load of dynamic entities
        source:addOverride(string.format("xi.zones.%s.Zone.onInitialize", zoneName), function(zone)
            super(zone)

            for index, entity in pairs(zoneEntities) do
                if LQS.settings.DEBUG then
                    printf("[LQS] Added entity %s to %s (%s)", entity.name, zoneName, tbl.info.name)
                end

                local dynamicEntity =
                {
                    name        = entity.name,
                    packetName  = entity.packetName or entity.name,
                    objtype     = entity.type or xi.objType.NPC,
                    namevis     = entity.namevis or 0,
                    entityFlags = entity.flags or 0,
                    x           = entity.pos[1],
                    y           = entity.pos[2],
                    z           = entity.pos[3],
                    rotation    = entity.pos[4] or 0,
                    widescan    = 1,
                }

                if entity.marker ~= nil then
                    if entity.marker == LQS.MAIN_QUEST then
                        dynamicEntity.look = LQS.marker.SHIMMER
                    else
                        dynamicEntity.look = LQS.marker.SPARKLE
                    end
                end

                if entity.look ~= nil then 
                    dynamicEntity.look = entity.look
                end

                entitySetup(dynamicEntity, tbl, entity)

                tbl.entities[zoneName][index].entity = zone:insertDynamicEntity(dynamicEntity)

                entityAfter(tbl.entities[zoneName][index].entity, entity)
            end
        end)
    end
end

return m
