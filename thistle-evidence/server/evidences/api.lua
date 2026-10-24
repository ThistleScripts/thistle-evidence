--local main = require "server.init"

local api = {}
local framework <const> = require "server.framework"

local biometricsProvider <const> = require "server.biometrics.biometrics_provider"

api.evidenceTypes = {
    fingerprint = require "server.evidences.classes.fingerprint",
    blood = require "server.evidences.classes.dna.blood",
    saliva = require "server.evidences.classes.dna.saliva",
    magazine = require "server.evidences.classes.ballistics.magazine",
    casing = require "server.evidences.classes.ballistics.casing",
    bullet = require "server.evidences.classes.ballistics.bullet",
    gunshot_residue = require "server.evidences.classes.ballistics.gunshot_residue",
    footprint = require "server.evidences.classes.trace.footprint",
    tyre_mark = require "server.evidences.classes.trace.tyre_mark"
}

local cache = {}

---@param evidenceClass Evidence|string The class of the evidence or the name of that class
---@param owner number|string The serverId of the related player or the owner of the evidence (dna key, fingerprint, weapon serial number)
function api.get(evidenceClass, owner)
    if not evidenceClass then
        return
    end

    if type(evidenceClass) == "string" then
        evidenceClass = api.evidenceTypes[evidenceClass]
    end

    if not owner then
        return
    end

    if type(owner) == "number" and DoesPlayerExist(owner) then
        owner = biometricsProvider.getBiometricData(owner, evidenceClass.superClassName)
        if not owner then return end
    end

    -- Gunshot residue owners are { serial, playerId } tables, which would be a new cache key on every shot
    local cacheKey <const> = type(owner) == "table" and table.concat(owner, ":") or owner

    cache[evidenceClass] = cache[evidenceClass] or {}
    cache[evidenceClass][cacheKey] = cache[evidenceClass][cacheKey] or evidenceClass:new(owner)

    return cache[evidenceClass][cacheKey]
end

-- Binds evidence or removes it
---@param evidenceClass Evidence|string The class of the evidence or the name of that class
---@param owner number|string The serverId of the related player or the owner of the evidence (dna key, fingerprint, weapon serial number)
---@param fun string The method from the evidence object to execute
---@param ... any The arguments passed to the method
local function syncEvidence(evidenceClass, owner, fun, ...)
    local evidenceHolder <const> = api.get(evidenceClass, owner)
    if evidenceHolder then
        evidenceHolder[fun](evidenceHolder, ...)
    end
end

api.syncEvidence = syncEvidence
exports("syncEvidence", syncEvidence)

-- Leaves a player's fingerprints on something they touched in another script (an ATM, till, safe or door).
-- The player's own client checks their gloves, so this asks it to. See client/evidences/registry/fingerprint.lua.
---@param playerId number
---@param coords vector3? where the print is, by default just in front of the player's hands
---@param surface string? a short label shown as "Found on", e.g. "ATM keypad"
exports("leaveFingerprint", function(playerId, coords, surface)
    local id <const> = tonumber(playerId)

    -- a calling script that lost `source` (it's gone after a Wait or inside a thread) passes nil; say which one
    if not id or not DoesPlayerExist(id) then
        lib.print.warn(("leaveFingerprint was called by %s without a valid player id (got %s). Pass the player's server id."):format(
            GetInvokingResource() or "an unknown resource", tostring(playerId)))
        return false
    end

    TriggerClientEvent("evidences:leaveFingerprint", id, coords, surface)
    return true
end)


---@param playerId number
---@param coords vector3|vector4|table
---@param maxDistance number
---@return boolean
function api.isNear(playerId, coords, maxDistance)
    local ped <const> = GetPlayerPed(playerId)
    if ped == 0 or type(coords) ~= "vector3" and type(coords) ~= "vector4" then
        return false
    end

    return #(GetEntityCoords(ped) - coords.xyz) <= maxDistance
end

---@param netId any
---@return number? entity
function api.entityFromNetId(netId)
    if type(netId) ~= "number" then
        return nil
    end

    local entity <const> = NetworkGetEntityFromNetworkId(netId)
    return (entity ~= 0 and DoesEntityExist(entity)) and entity or nil
end

local function currentWeaponSerial(playerId)
    local weapon <const> = exports.ox_inventory:GetCurrentWeapon(playerId)
    local metadata <const> = weapon and weapon.metadata
    return metadata and (metadata.serial or metadata.imperfections)
end

-- Clients report the traces they leave themselves (blood, fingerprints, shots), so anyone can send this event.
-- Only the methods the client scripts use are accepted, and only for the sender's own biometrics or current weapon,
-- their own inventory, and places near them.
local reportRange <const> = 150.0

local function isEntityInRange(source, netId)
    local entity <const> = api.entityFromNetId(netId)
    return entity ~= nil and api.isNear(source, GetEntityCoords(entity), reportRange)
end

local clientMethods <const> = {
    atCoords = function(source, coords) return api.isNear(source, coords, reportRange) end,
    atEntity = isEntityInRange,
    atRelativeEntityCoords = isEntityInRange,
    atVehicleSeat = isEntityInRange,
    atVehicleDoor = isEntityInRange,
    atPlayer = function(source, playerId) return playerId == source end,
    atItem = function(source, inventory) return inventory == source end,
    removeFromItem = function(source, inventory) return inventory == source end,
    atWeaponOf = function(source, attacker)
        attacker = tonumber(attacker)
        -- 0 is what the client gets for an attacker who isn't a player (a local, an animal)
        return attacker ~= nil and attacker > 0 and attacker ~= source and DoesPlayerExist(attacker)
            and api.isNear(source, GetEntityCoords(GetPlayerPed(attacker)), 10.0)
    end
}

local biometricTypes <const> = { fingerprint = true, blood = true, saliva = true }

-- A footprint's owner is the shoes: men's or women's, the shoe model, and a shoe size that belongs to the character
-- (from their identifier), so prints from one person in one pair of shoes match. The client only says which shoes.
local function footprintOwner(source, shoes)
    if type(shoes) ~= "string" then
        return nil
    end

    local sex <const>, model <const> = shoes:match("^([MF])%-(%d+)$")
    if not sex then
        return nil
    end

    local identifier <const> = framework.getIdentifier(source) or tostring(source)
    local seed <const> = GetHashKey(identifier) & 0x7FFFFFFF
    local size <const> = sex == "M" and 6 + seed % 7 or 3 + seed % 6 -- UK 6-12 for men's shoes, 3-8 for women's

    return ("%s-%d-%d"):format(sex, size, tonumber(model))
end

-- A tyre mark's owner is the model of the vehicle the player is driving
local function isDrivingModel(source, owner)
    local vehicle <const> = GetVehiclePedIsIn(GetPlayerPed(source), false)
    return vehicle ~= 0 and owner == ("model:%d"):format(GetEntityModel(vehicle) & 0xFFFFFFFF)
end

local function isOwnerAllowed(source, className, owner, fun)
    -- wiping someone's traces off a weapon in your own inventory (hydrogen peroxide)
    if fun == "removeFromItem" then
        return type(owner) == "string"
    end

    if biometricTypes[className] then
        return owner == source
    end

    if className == "footprint" then
        return type(owner) == "string" -- built by footprintOwner
    end

    if className == "tyre_mark" then
        return isDrivingModel(source, owner)
    end

    local serial <const> = currentWeaponSerial(source)
    if not serial then
        return false
    end

    if className == "gunshot_residue" then
        return type(owner) == "table" and owner[1] == serial and tonumber(owner[2]) == source
    end

    return owner == serial
end

RegisterNetEvent("evidences:syncEvidence", function(className, owner, fun, ...)
    local source <const> = source

    if type(className) ~= "string" or not api.evidenceTypes[className] then
        return
    end

    if className == "footprint" then
        owner = footprintOwner(source, owner)
    end

    local isAllowed <const> = type(fun) == "string" and clientMethods[fun]
    if not isAllowed or not isAllowed(source, ...) or not isOwnerAllowed(source, className, owner, fun) then
        return
    end

    syncEvidence(className, owner, fun, ...)
end)

return api