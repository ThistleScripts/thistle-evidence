-- Creating a citizen record for the player in front of the officer (booking and firearm terminals, citizens not
-- synced): the officer picks them from the players nearby, and the record gets their character's real name,
-- birthdate and gender, under their character's identifier so booking them again finds the same record. Their
-- fingerprint and DNA aren't added: the officer takes them and puts them on file as usual.
local config <const> = require "config"
local framework <const> = require "server.framework"
local database <const> = require "server.database"
local logger <const> = require "server.logger"

if config.citizens.synced then
    return
end

local reach <const> = 5.0

local function isNearby(source, target)
    local ped <const>, targetPed <const> = GetPlayerPed(source), GetPlayerPed(target)
    return ped ~= 0 and targetPed ~= 0 and #(GetEntityCoords(ped) - GetEntityCoords(targetPed)) <= reach
end

-- The player's character as the framework has it: name, birthdate, gender
local function getCharacter(playerId)
    local identifier <const> = framework.getIdentifier(playerId)
    if not identifier then
        return nil
    end

    local result <const> = framework.getCitizen(identifier)
    local character <const> = result and result.success and result.response
    if not character then
        return nil
    end

    return {
        identifier = identifier,
        fullName = character.fullName,
        birthdate = character.birthdate,
        gender = character.gender or "non_binary"
    }
end

-- The players near the officer, closest first. Only names: what the officer would see anyway, standing there.
Thistle.Callback.Register("evidences:getNearbyCharacters", function(source)
    if not framework.hasPermission(config.permissions.access, source) then
        return { success = false }
    end

    local ped <const> = GetPlayerPed(source)
    local coords <const> = GetEntityCoords(ped)
    local nearby = {}

    for _, id in ipairs(GetPlayers()) do
        local playerId <const> = tonumber(id)
        local otherPed <const> = GetPlayerPed(playerId)

        if playerId ~= source and otherPed ~= 0 then
            local distance <const> = #(coords - GetEntityCoords(otherPed))
            if distance <= reach then
                local character <const> = getCharacter(playerId)
                if character then
                    nearby[#nearby + 1] = { serverId = playerId, fullName = character.fullName, distance = distance }
                end
            end
        end
    end

    table.sort(nearby, function(a, b) return a.distance < b.distance end)
    return { success = true, response = nearby }
end)

-- Creates (or finds) the record for a nearby player
Thistle.Callback.Register("evidences:storeCitizenFromPlayer", function(source, arguments)
    local target <const> = tonumber(type(arguments) == "table" and arguments.serverId)
    if not framework.hasPermission(config.permissions.access, source) or not target or target == source
        or not DoesPlayerExist(target) or not isNearby(source, target) then
        return { success = false }
    end

    local character <const> = getCharacter(target)
    if not character then
        return { success = false }
    end

    -- already booked: their record is the one tied to their character
    local existing <const> = database.selectFirstRow("SELECT * FROM citizens WHERE identifier = ?", character.identifier)
    local record = existing.success and existing.response or nil

    if not record then
        local inserted <const> = database.update(
            "INSERT INTO citizens (identifier, fullName, birthdate, gender) VALUES (?, ?, ?, ?)",
            character.identifier, character.fullName, tostring(character.birthdate), character.gender
        )
        if not inserted.success then
            return { success = false }
        end

        record = { identifier = character.identifier, fullName = character.fullName, birthdate = tostring(character.birthdate), gender = character.gender }
        logger.log(source, "Citizen created", { identifier = record.identifier, fullName = record.fullName, fromPlayer = target })
    end

    return { success = true, response = record }
end)
