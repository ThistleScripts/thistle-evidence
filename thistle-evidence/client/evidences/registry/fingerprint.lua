local config <const> = require "config"

local lastEnteredVehicle = nil

lib.onCache("vehicle", function(value, oldValue)
    lastEnteredVehicle = value or lastEnteredVehicle
end)

-- vehicle(door) fingerprint
lib.onCache("seat", function(value, oldValue)
    if (not oldValue and value) or (oldValue and not value) then
        -- player is entering or exiting a vehicle
        if config.isPedWearingGloves() then
            return
        end

        local seatId <const> = value or oldValue
        local vehicle <const> = cache.vehicle or lastEnteredVehicle
        if not vehicle or not DoesEntityExist(vehicle) then
            return
        end

        local entityModel <const> = GetEntityModel(vehicle) -- cache.vehicle is already false when getting out

        -- our own vehicle door targeting logic only works with vehicles that have at least two doors
        -- checking whether the number of seats is less than or equal to 4 is necessary as our logic doesn't work for busses
        if GetNumberOfVehicleDoors(vehicle) >= 2 and GetVehicleModelNumberOfSeats(entityModel) <= 4 then
            -- vehicle door fingerprint
            TriggerServerEvent("evidences:syncEvidence", "fingerprint", cache.serverId,
                "atVehicleDoor", NetworkGetNetworkIdFromEntity(vehicle), seatId + 1 --[[doorId]], { plate = GetVehicleNumberPlateText(vehicle) })
        else
            -- vehicle fingerprint
            TriggerServerEvent("evidences:syncEvidence", "fingerprint", cache.serverId,
                "atEntity", NetworkGetNetworkIdFromEntity(vehicle), { plate = GetVehicleNumberPlateText(vehicle) })
        end
    end
end)

-- seat fingerprint: whoever sits in a seat leaves prints there, the driver's on the steering wheel. Collected by
-- sitting in that seat (client/evidences/evidences.lua), and the lab is told which seat (server/evidences/actions.lua).
lib.onCache("seat", function(value, oldValue)
    if value == nil or value == false or value == oldValue then
        return
    end

    if config.isPedWearingGloves() then
        return
    end

    -- the seat cache changes before the vehicle one when getting in, so read the ped's vehicle directly
    local vehicle <const> = GetVehiclePedIsIn(cache.ped, false)
    if vehicle == 0 or not DoesEntityExist(vehicle) or not NetworkGetEntityIsNetworked(vehicle) then
        return
    end

    TriggerServerEvent("evidences:syncEvidence", "fingerprint", cache.serverId,
        "atVehicleSeat", NetworkGetNetworkIdFromEntity(vehicle), value, { plate = GetVehicleNumberPlateText(vehicle) })
end)

-- weapon fingerprint
-- Only add fingerprints to weapons, as adding them to other items would prevent stacking them
-- This is because fingerprints are stored in the item's metadata and item's with different metadata cannot be stacked
AddEventHandler("ox_inventory:usedItem", function(name, slotId)
    if string.sub(string.lower(name), 1, #"weapon") == "weapon" then
        if not config.isPedWearingGloves() then
            TriggerServerEvent("evidences:syncEvidence", "fingerprint", cache.serverId, "atItem", cache.serverId, slotId)
        end
    end
end)

-- Prints on whatever a player touches in other scripts (ATM keypads, tills, safes, lockpicked doors):
--   exports["thistle-evidence"]:leaveFingerprint(coords?, surface?)                      -- client, the player touching it
--   exports["thistle-evidence"]:leaveFingerprint(playerId, coords?, surface?)            -- server
-- coords defaults to just in front of the player's hands; surface is a short label shown as "Found on" (e.g. "ATM keypad").
-- Nothing is left when they wear gloves, or when they left a print within half a metre of it in the last 15 minutes.
local recentPrints = {} -- { coords, at }

local function leaveFingerprint(coords, surface)
    if config.isPedWearingGloves() or config.isPedDead(cache.ped) then
        return false
    end

    coords = coords and vector3(coords.x, coords.y, coords.z) or GetOffsetFromEntityInWorldCoords(cache.ped, 0.0, 0.55, 0.15)
    if #(GetEntityCoords(cache.ped) - coords) > 5.0 then
        return false
    end

    local now <const> = GetGameTimer()
    for i = #recentPrints, 1, -1 do
        local recent <const> = recentPrints[i]
        if now - recent.at > 15 * 60000 then
            table.remove(recentPrints, i)
        elseif #(recent.coords - coords) < 0.5 then
            return false
        end
    end
    recentPrints[#recentPrints + 1] = { coords = coords, at = now }

    TriggerServerEvent("evidences:syncEvidence", "fingerprint", cache.serverId, "atCoords", coords, {
        surface = type(surface) == "string" and surface or nil
    })
    return true
end

exports("leaveFingerprint", leaveFingerprint)
RegisterNetEvent("evidences:leaveFingerprint", leaveFingerprint) -- from the server export
