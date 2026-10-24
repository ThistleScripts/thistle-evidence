-- Player lookups and job permissions go through thistle-lib's framework bridge (qb-core, qbx_core, es_extended).
-- Only the citizen search stays here, since it reads each framework's own character table.
local config <const> = require "config"
local database <const> = require "server.database"

local framework = {}

function framework.getIdentifier(playerId)
    return Thistle.GetIdentifier(Thistle.GetPlayerObject(playerId))
end

function framework.getPlayerName(playerId)
    return Thistle.GetCharacterName(Thistle.GetPlayerObject(playerId)) or "undefined"
end

-- Checks whether a player has permission to perform a specific action.
---@param requiredPermissions table<string, number> Jobs and their minimum grades
---@param playerId number
---@return boolean
function framework.hasPermission(requiredPermissions, playerId)
    local player <const> = Thistle.GetPlayerObject(playerId)
    if not player then
        return false
    end

    for job, minGrade in pairs(requiredPermissions or {}) do
        -- Only the active job counts. Qbox keeps every job a player has held in PlayerData.jobs,
        -- so counting those let someone switched to mechanic keep their police access.
        if Thistle.HasJob(player, job, minGrade) then
            return true
        end
    end

    return false
end

-- https://github.com/qbcore-framework/qb-core/blob/36d8986b4298b3e762c9e799b23241b56eaf78b5/qbcore.sql (qbx_core uses the same table)
local qbCitizenColumns <const> = [[
    citizenid AS identifier,
    CONCAT_WS(' ', JSON_VALUE(charinfo, '$.firstname'), JSON_VALUE(charinfo, '$.lastname')) AS fullName,
    JSON_VALUE(charinfo, '$.birthdate') AS birthdate,
    CASE
        WHEN JSON_VALUE(charinfo, '$.gender') = '0' THEN 'male'
        WHEN JSON_VALUE(charinfo, '$.gender') = '1' THEN 'female'
        ELSE 'non_binary'
    END AS gender
]]

-- https://github.com/esx-framework/esx_core/blob/main/%5Bcore%5D/esx_identity/esx_identity.sql
local esxCitizenColumns <const> = [[
    identifier,
    CONCAT_WS(' ', firstname, lastname) AS fullName,
    dateofbirth AS birthdate,
    CASE
        WHEN LOWER(sex) = 'm' THEN 'male'
        WHEN LOWER(sex) = 'f' THEN 'female'
        ELSE 'non_binary'
    END AS gender
]]

local function isEsx()
    return Thistle.GetFramework() == "esx"
end

function framework.getCitizens(searchText, offset)
    local pattern <const> = "%" .. searchText:sub(1, 25):gsub("\\", "\\\\"):gsub("%%", "\\%%"):gsub("_", "\\_") .. "%"

    if isEsx() then
        return database.query(
            ("SELECT %s FROM users WHERE disabled = 0 HAVING fullName LIKE ? LIMIT 10 OFFSET ?"):format(esxCitizenColumns),
            pattern, offset
        )
    end

    return database.query(
        ("SELECT %s FROM players HAVING fullName LIKE ? LIMIT 10 OFFSET ?"):format(qbCitizenColumns),
        pattern, offset
    )
end

function framework.getCitizen(identifier)
    if isEsx() then
        return database.selectFirstRow(
            ("SELECT %s FROM users WHERE disabled = 0 AND identifier = ?"):format(esxCitizenColumns),
            identifier
        )
    end

    return database.selectFirstRow(
        ("SELECT %s FROM players WHERE citizenid = ?"):format(qbCitizenColumns),
        identifier
    )
end

-- The client has no framework bridge of its own, so it asks for the player's name and laptop permissions here.
Thistle.Callback.Register("evidences:getPlayerInfo", function(source)
    return {
        name = framework.getPlayerName(source),
        permissions = {
            place = framework.hasPermission(config.permissions.place, source),
            placeMicroscope = framework.hasPermission(config.forensicsLab.permissions.place, source),
            placeMarkers = framework.hasPermission(config.evidenceMarkers.permissions, source),
            placeUvFloodlight = framework.hasPermission(config.uvFloodlight.permissions, source),
            access = framework.hasPermission(config.permissions.access, source),
            interceptCalls = framework.hasPermission(config.wiretap.calls.permissions, source),
            interceptRadio = framework.hasPermission(config.wiretap.radio.permissions, source),
            listenToSpyMicrophones = framework.hasPermission(config.wiretap.spyMicrophones.permissions, source)
        },
        -- what the evidence admin panel lets this officer do (server/permissions.lua, which requires this file)
        capabilities = require("server.permissions").resolve(source)
    }
end)

return framework
