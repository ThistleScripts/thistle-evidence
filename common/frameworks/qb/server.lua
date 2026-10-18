local database <const> = require "server.database"
local QBCore <const> = exports["qb-core"]:GetCoreObject()

local framework = {}

function framework.getIdentifier(playerId)
    local player <const> = QBCore.Functions.GetPlayer(playerId)

    if player then
        local playerData <const> = player.PlayerData
        return playerData and playerData.citizenid or nil
    end
    
    return nil
end

function framework.getPlayerName(playerId)
    local player <const> = QBCore.Functions.GetPlayer(playerId)

    if player then
        local playerData <const> = player.PlayerData
        
        if playerData then
            local charinfo <const> = playerData.charinfo
            return charinfo and (charinfo.firstname .. " " .. charinfo.lastname) or "undefined"
        end
    end

    return "undefined"
end

function framework.getGrade(job, playerId)
    local player <const> = QBCore.Functions.GetPlayer(playerId)

    if player then
        local playerData <const> = player.PlayerData

        if playerData then
            if playerData.job then
                return playerData.job.name == job and playerData.job.grade.level or false
            end
        end
    end

    return false
end

-- https://github.com/qbcore-framework/qb-core/blob/36d8986b4298b3e762c9e799b23241b56eaf78b5/qbcore.sql
function framework.getCitizens(searchText, offset)
    local pattern <const> = "%" .. searchText:sub(1, 25):gsub("\\", "\\\\"):gsub("%%", "\\%%"):gsub("_", "\\_") .. "%"

    return database.query(
        [[
            SELECT
                citizenid AS identifier,
                CONCAT_WS(' ', JSON_VALUE(charinfo, '$.firstname'), JSON_VALUE(charinfo, '$.lastname')) AS fullName,
                JSON_VALUE(charinfo, '$.birthdate') AS birthdate,
                CASE
                    WHEN JSON_VALUE(charinfo, '$.gender') = '0' THEN 'male'
                    WHEN JSON_VALUE(charinfo, '$.gender') = '1' THEN 'female'
                    ELSE 'non_binary'
                END AS gender
            FROM players
            HAVING fullName LIKE ?
            LIMIT 10 OFFSET ?
        ]],
        pattern, offset
    )
end

function framework.getCitizen(identifier)
    return database.selectFirstRow(
        [[
            SELECT
                citizenid AS identifier,
                CONCAT_WS(' ', JSON_VALUE(charinfo, '$.firstname'), JSON_VALUE(charinfo, '$.lastname')) AS fullName,
                JSON_VALUE(charinfo, '$.birthdate') AS birthdate,
                CASE
                    WHEN JSON_VALUE(charinfo, '$.gender') = '0' THEN 'male'
                    WHEN JSON_VALUE(charinfo, '$.gender') = '1' THEN 'female'
                    ELSE 'non_binary'
                END AS gender
            FROM players
            WHERE citizenid = ?
        ]],
        identifier
    )
end

return framework