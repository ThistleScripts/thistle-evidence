local config <const> = require "config"
local framework <const> = require "server.framework"
local evidenceTypes <const> = require "common.evidence_types"
local api <const> = require "server.evidences.api"
local logger <const> = require "server.logger"

local actions = {}

local reach <const> = 10.0
local removalMethods <const> = {
    removeFromPlayer = true,
    removeFromEntity = true,
    removeFromRelativeEntityCoords = true,
    removeFromVehicleSeats = true,
    removeFromVehicleDoors = true,
    removeFromVehicleDoorAndSeat = true,
    removeFromCoords = true
}

-- Confirms the evidence the client wants to collect or destroy really is where it says, and within reach.
local function isEvidenceInReach(source, evidenceType, owner, remove)
    if type(owner) ~= "string" or type(remove) ~= "table" or type(remove.arguments) ~= "table" or not removalMethods[remove.fun] then
        return false
    end

    local target <const> = remove.arguments[1]
    local stateKey <const> = ("evidences:%s"):format(evidenceType)

    if remove.fun == "removeFromCoords" then
        local evidence <const> = EvidencesAtCoords[target]
        return evidence ~= nil and evidence.__name == evidenceType and evidence.owner == owner and api.isNear(source, target, reach)
    end

    if remove.fun == "removeFromPlayer" then
        local playerId <const> = tonumber(target)
        if not playerId or not DoesPlayerExist(playerId) then
            return false
        end

        local evidences <const> = Player(playerId).state[stateKey]
        return evidences ~= nil and evidences[owner] ~= nil and api.isNear(source, GetEntityCoords(GetPlayerPed(playerId)), reach)
    end

    local entity <const> = api.entityFromNetId(target)
    local evidences <const> = entity and Entity(entity).state[stateKey]
    return evidences ~= nil and evidences[owner] ~= nil and api.isNear(source, GetEntityCoords(entity), reach)
end

-- The client builds the item's metadata (it knows the street name and local time), so only keep the expected fields
local function sanitizeMetadata(metadata)
    metadata = type(metadata) == "table" and metadata or {}

    local function text(value)
        return type(value) == "string" and value:sub(1, 250) or nil
    end

    local information <const> = type(metadata.information) == "table" and metadata.information or {}
    local ballistics <const> = type(metadata.ballistics) == "table" and metadata.ballistics or {}

    return {
        createdAt = tonumber(metadata.createdAt),
        information = {
            collectionTime = text(information.collectionTime),
            crimeScene = text(information.crimeScene),
            additionalData = text(information.additionalData)
        },
        ballistics = {
            weaponType = text(ballistics.weaponType),
            weaponImage = text(ballistics.weaponImage),
            serial = text(ballistics.serial),
            imperfections = text(ballistics.imperfections),
            type = text(ballistics.type)
        }
    }
end

Thistle.Callback.Register("evidences:destroy", function(source, evidenceType, owner, remove)
    if not evidenceTypes[evidenceType] or not isEvidenceInReach(source, evidenceType, owner, remove) then
        return false
    end

    local requiredItem <const> = evidenceTypes[evidenceType].target.destroy.requiredItem or nil

    if requiredItem then
        local success <const> = exports.ox_inventory:RemoveItem(source, requiredItem, 1)
        if not success then
            return false
        end
    end

    local object <const> = api.get(api.evidenceTypes[evidenceType], owner)
    object[remove.fun](object, table.unpack(remove.arguments))

    logger.log(source, "Evidence destroyed", {
        evidenceType = evidenceType,
        biometricData = owner,
        [remove.fun] = json.encode(remove.arguments)
    })
    return true
end)

local vehicleMethods <const> = {
    removeFromVehicleSeats = true,
    removeFromVehicleDoors = true,
    removeFromVehicleDoorAndSeat = true,
    removeFromEntity = true,
    removeFromRelativeEntityCoords = true
}

local function capitalise(text)
    return (text:gsub("^%l", string.upper))
end

-- Where in a vehicle evidence was collected (the steering wheel, a seat, a door or the bodywork) and the vehicle's
-- plate, worked out from where it's being removed, so the lab can tell the driver's prints from a passenger's.
---@return string? location, string? plate
local function getSeatLabel(evidenceType, seatId)
    local key <const> = ("evidences.information.seats.%d"):format(seatId)
    local seat = locale(key)
    if not seat or seat == key then
        seat = locale("evidences.information.seat_number", seatId + 2)
    end

    -- the driver's prints are on the wheel
    return (seatId == -1 and evidenceType == "fingerprint") and locale("evidences.information.steering_wheel", seat) or seat
end

local function getDoorLabel(doorId)
    local key <const> = ("evidences.information.doors.%d"):format(doorId)
    local door <const> = locale(key)
    return (door and door ~= key) and door or locale("evidences.information.door_number", doorId + 1)
end

---@param owner string Whose evidence it is, to tell which of a door and its seat they left it on
local function getVehicleLocation(evidenceType, remove, owner)
    if type(remove) ~= "table" or type(remove.arguments) ~= "table" or not vehicleMethods[remove.fun] then
        return nil
    end

    local entity <const> = api.entityFromNetId(remove.arguments[1])
    if not entity or GetEntityType(entity) ~= 2 then
        return nil
    end

    local plate <const> = (GetVehicleNumberPlateText(entity) or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local place = tonumber(remove.arguments[2])
    local location

    if remove.fun == "removeFromVehicleSeats" and place then
        location = getSeatLabel(evidenceType, place)
    elseif remove.fun == "removeFromVehicleDoors" and place then
        location = getDoorLabel(place)
    elseif remove.fun == "removeFromVehicleDoorAndSeat" and place then
        -- collected from outside: the door, the seat next to it, or both
        local seatId <const> = tonumber(remove.arguments[3])
        local evidences <const> = Entity(entity).state[("evidences:%s"):format(evidenceType)] or {}
        local record <const> = evidences[owner] or {}
        local places = {}

        if record.doorIds and record.doorIds[place] then
            places[#places + 1] = getDoorLabel(place)
        end
        if seatId and record.seatIds and record.seatIds[seatId] then
            places[#places + 1] = getSeatLabel(evidenceType, seatId)
        end

        location = #places > 0 and table.concat(places, ", ") or getDoorLabel(place)
    else
        location = locale("evidences.information.vehicle_body")
    end

    return capitalise(location), plate ~= "" and plate or nil
end

-- Which way a heading points, as a compass direction (GTA headings turn anticlockwise from north)
local function compass(heading)
    local directions <const> = { "north", "north_east", "east", "south_east", "south", "south_west", "west", "north_west" }
    local index <const> = math.floor(((360.0 - (tonumber(heading) or 0.0)) % 360.0 + 22.5) / 45.0) % 8
    return locale(("evidences.directions.%s"):format(directions[index + 1]))
end

-- What a footprint or tyre mark tells: the shoes and which way they went, or the vehicle model
local function describeTrace(evidenceType, owner, coordsMetadata)
    if evidenceType == "footprint" then
        local sex <const>, size <const>, tread <const> = tostring(owner):match("^([MF])%-(%d+)%-(%d+)$")
        if sex then
            return locale("evidences.footprint.description", locale(sex == "M" and "evidences.footprint.mens" or "evidences.footprint.womens"),
                size, tread, compass(coordsMetadata.heading))
        end
    elseif evidenceType == "tyre_mark" then
        return locale("evidences.tyre_mark.description", coordsMetadata.model or locale("laptop.desktop_screen.common.statuses.unknown"),
            compass(coordsMetadata.heading))
    end
end

---@param source number The collecting player
---@param evidenceType string
---@param owner number|string The evidence owner, or a player's server id when taking their biometrics directly
---@param remove? { fun: string, arguments: table } Where to remove the evidence from once collected
---@param metadata? table
---@param amount? number How many pieces this item holds (a pile of casings from one gun), 1 by default
function actions.collect(source, evidenceType, owner, remove, metadata, amount)
    if not framework.hasPermission(config.permissions.collect, source) then
        return false
    end

    local options <const> = evidenceTypes[evidenceType]
    local collectedItem <const> = options.target.collect.collectedItem

    -- why collecting failed, rather than only the generic error
    local function fail(key, ...)
        TriggerClientEvent("evidences:notify", source, { key = ("evidences.notifications.common.errors.%s"):format(key), arguments = { ... } }, "error")
        return false
    end

    if not exports.ox_inventory:Items(collectedItem) then
        lib.print.error(("Setup step missing: the %s item isn't in ox_inventory/data/items.lua (see setup/), so %s evidence can't be collected"):format(collectedItem, evidenceType))
        return fail("missing_item", collectedItem)
    end

    if not exports.ox_inventory:CanCarryItem(source, collectedItem, 1, nil) then
        return fail("cannot_carry")
    end

    -- the first kit in the list the player has (saliva and gunshot residue take a swab kit or a forensic kit)
    local kits <const> = options.target.collect.requiredItem or "forensic_kit"
    local slots
    for _, kit in ipairs(type(kits) == "table" and kits or { kits }) do
        slots = exports.ox_inventory:GetSlotsWithItem(source, kit)
        if slots and #slots > 0 then
            break
        end
    end

    if not slots or #slots < 1 then
        return fail("no_kit")
    end

    local object <const> = api.get(api.evidenceTypes[evidenceType], owner)
    if not object then
        return false
    end

    local lowestDurability = lib.array.reduce(lib.array:from(slots), function(accumulator, element)
        local accDurability = (accumulator.metadata and accumulator.metadata.durability) or 100
        local elemDurability = (element.metadata and element.metadata.durability) or 100

        return elemDurability < accDurability and element or accumulator
    end, slots[1])

    exports.ox_inventory:SetDurability(source, lowestDurability.slot, ((lowestDurability.metadata and lowestDurability.metadata.durability) or 100) - 10)

    local success <const>, response <const> = exports.ox_inventory:AddItem(source, collectedItem, 1)
    if not success then
        return false
    end

    -- before the evidence is removed, while the vehicle's state still holds it
    local vehicleLocation, plate = getVehicleLocation(evidenceType, remove, object.owner)

    -- ground evidence: what it was left on (exports.leaveFingerprint), and what a footprint or tyre mark shows
    local trace
    if not vehicleLocation and type(remove) == "table" and remove.fun == "removeFromCoords" then
        local coordsMetadata <const> = object.coordsMetadata and object.coordsMetadata[remove.arguments[1]] or {}
        vehicleLocation = coordsMetadata.surface
        trace = describeTrace(evidenceType, object.owner, coordsMetadata)
    end

    if remove then
        object[remove.fun](object, table.unpack(remove.arguments))
    end

    metadata = sanitizeMetadata(metadata)
    metadata.collectedAt = os.time() -- with createdAt, how old the trace was when it was bagged (config.evidenceAging)
    metadata.information.vehicleLocation = vehicleLocation
    metadata.information.trace = trace
    metadata.information.plate = plate
    metadata.description = require "server.evidences.evidence_information"(metadata.information)

    if amount and amount > 1 then
        local item <const> = exports.ox_inventory:Items(collectedItem)
        metadata.label = ("%s ×%d"):format(item and item.label or collectedItem, amount)
    end

    object:atItem(source, response[1].slot, metadata)


    local data = {
        evidenceType = evidenceType,
        biometricData = object.owner,
        information = metadata.description:gsub("  \n ", "\n")
    }

    if remove then
        data[remove.fun] = json.encode(remove.arguments)
    end

    logger.log(source, "Evidence collected", data)
    return true
end

Thistle.Callback.Register("evidences:collect", function(source, evidenceType, owner, remove, metadata)
    if not evidenceTypes[evidenceType] or not isEvidenceInReach(source, evidenceType, owner, remove) then
        return false
    end

    return actions.collect(source, evidenceType, owner, remove, metadata)
end)


-- A pile of ground evidence (e.g. casings from automatic fire) is collected or destroyed in one go.
-- Every piece is checked like a single one; pieces sharing an owner (the same gun or DNA) become one item.
local maxPileSize <const> = 50

---@param entries { owner: string, coords: vector3, metadata?: table }[]
---@return table<string, { coords: vector3[], metadata?: table }>, string[] owners in the order they were found
local function groupPile(source, evidenceType, entries)
    local groups, owners, seen = {}, {}, {}

    if type(entries) ~= "table" or #entries > maxPileSize then
        return groups, owners
    end

    for _, entry in ipairs(entries) do
        local remove <const> = type(entry) == "table" and { fun = "removeFromCoords", arguments = { entry.coords } }
        if remove and not seen[entry.coords] and isEvidenceInReach(source, evidenceType, entry.owner, remove) then
            seen[entry.coords] = true

            if not groups[entry.owner] then
                groups[entry.owner] = { coords = {}, metadata = entry.metadata }
                owners[#owners + 1] = entry.owner
            end

            table.insert(groups[entry.owner].coords, entry.coords)
        end
    end

    return groups, owners
end

---@return number collected How many pieces were collected
Thistle.Callback.Register("evidences:collectPile", function(source, evidenceType, entries)
    if not evidenceTypes[evidenceType] then
        return 0
    end

    local groups <const>, owners <const> = groupPile(source, evidenceType, entries)
    local collected = 0

    for _, owner in ipairs(owners) do
        local group <const> = groups[owner]
        local first <const> = { fun = "removeFromCoords", arguments = { group.coords[1] } }

        -- stops at the first failure (no kit, inventory full...), leaving the rest on the ground
        if not actions.collect(source, evidenceType, owner, first, group.metadata, #group.coords) then
            break
        end

        local object <const> = api.get(api.evidenceTypes[evidenceType], owner)
        for i = 2, #group.coords do
            object:removeFromCoords(group.coords[i])
        end

        collected += #group.coords
    end

    return collected
end)

---@return number destroyed How many pieces were destroyed
Thistle.Callback.Register("evidences:destroyPile", function(source, evidenceType, entries)
    if not evidenceTypes[evidenceType] then
        return 0
    end

    local groups <const>, owners <const> = groupPile(source, evidenceType, entries)
    if #owners == 0 then
        return 0
    end

    -- one bottle of hydrogen peroxide cleans the whole pile
    local requiredItem <const> = evidenceTypes[evidenceType].target.destroy.requiredItem
    if requiredItem and not exports.ox_inventory:RemoveItem(source, requiredItem, 1) then
        return 0
    end

    local destroyed = 0

    for _, owner in ipairs(owners) do
        local object <const> = api.get(api.evidenceTypes[evidenceType], owner)
        for _, coords in ipairs(groups[owner].coords) do
            object:removeFromCoords(coords)
            destroyed += 1
        end
    end

    logger.log(source, "Evidence destroyed", { evidenceType = evidenceType, amount = destroyed, owners = #owners })
    return destroyed
end)

return actions
