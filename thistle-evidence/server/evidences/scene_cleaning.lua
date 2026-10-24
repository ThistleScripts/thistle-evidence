-- The scene cleaning kit (config.sceneCleaning): bleach that wipes the ground evidence around the player, though each
-- piece has a chance of being missed. It's used up once the cleaning finishes.
local config <const> = require "config"
local logger <const> = require "server.logger"

local settings <const> = config.sceneCleaning
local item <const> = "scene_cleaning_kit"
local cleaningSince = {} -- source -> os.time() the progress bar started

-- The client starts the progress bar here, so finishing early (or without starting) is refused
Thistle.Callback.Register("evidences:startSceneCleaning", function(source)
    if (exports.ox_inventory:Search(source, "count", item) or 0) < 1 then
        return false
    end

    cleaningSince[source] = os.time()
    return true
end)

Thistle.Callback.Register("evidences:finishSceneCleaning", function(source)
    local startedAt <const> = cleaningSince[source]
    cleaningSince[source] = nil

    if not startedAt or os.time() - startedAt < math.floor(settings.duration / 1000) - 1 then
        return false
    end

    if not exports.ox_inventory:RemoveItem(source, item, 1) then
        return false
    end

    local playerCoords <const> = GetEntityCoords(GetPlayerPed(source))
    local cleaned, missed = 0, 0
    local toRemove = {}

    for coords, evidence in pairs(EvidencesAtCoords) do
        if #(playerCoords - coords) <= settings.radius then
            if math.random() < settings.missChance then
                missed += 1
            else
                toRemove[#toRemove + 1] = { evidence = evidence, coords = coords }
            end
        end
    end

    for _, entry in ipairs(toRemove) do
        entry.evidence:removeFromCoords(entry.coords)
        cleaned += 1
    end

    logger.log(source, "Scene cleaned", { cleaned = cleaned, missed = missed, coords = tostring(playerCoords) })
    return cleaned
end)

AddEventHandler("playerDropped", function()
    cleaningSince[source] = nil
end)

