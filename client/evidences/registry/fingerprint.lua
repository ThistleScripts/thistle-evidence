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