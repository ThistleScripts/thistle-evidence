-- Numbered evidence markers officers put down at a crime scene (evidence_marker item). They're kept in memory only:
-- a restart clears them, and each removes itself after config.evidenceMarkers.lifetime minutes.
local config <const> = require "config"
local framework <const> = require "server.framework"

local item <const> = "evidence_marker"
local settings <const> = config.evidenceMarkers

local markers = {} -- id -> { id, coords: vector4, number, expiresAt }
local nextId = 0

-- The lowest number not yet used by a marker at the same scene, so a scene reads 1, 2, 3...
local function getNextNumber(coords)
    local used = {}
    for _, marker in pairs(markers) do
        if #(marker.coords.xyz - coords.xyz) <= settings.sceneRadius then
            used[marker.number] = true
        end
    end

    local number = 1
    while used[number] do
        number += 1
    end

    return number
end

local function removeMarker(id)
    if markers[id] then
        markers[id] = nil
        TriggerClientEvent("evidences:removeEvidenceMarker", -1, id)
    end
end

Thistle.Callback.Register("evidences:getEvidenceMarkers", function()
    local list = {}
    for _, marker in pairs(markers) do
        list[#list + 1] = marker
    end
    return list
end)

Thistle.Callback.Register("evidences:placeEvidenceMarker", function(source, coords)
    if not framework.hasPermission(settings.permissions, source) then
        TriggerClientEvent("evidences:notify", source, { key = "laptop.notifications.no_permission" }, "error")
        return false
    end

    if type(coords) ~= "vector4" or #(GetEntityCoords(GetPlayerPed(source)) - coords.xyz) > 15.0 then
        return false
    end

    if not exports.ox_inventory:RemoveItem(source, item, 1) then
        return false
    end

    nextId += 1
    local marker <const> = {
        id = nextId,
        coords = coords,
        number = getNextNumber(coords),
        expiresAt = os.time() + settings.lifetime * 60
    }

    markers[marker.id] = marker
    TriggerClientEvent("evidences:addEvidenceMarker", -1, marker)
    return marker.number
end)

Thistle.Callback.Register("evidences:pickupEvidenceMarker", function(source, id)
    if not framework.hasPermission(settings.permissions, source) then
        return false
    end

    local marker <const> = markers[tonumber(id)]
    if not marker or #(GetEntityCoords(GetPlayerPed(source)) - marker.coords.xyz) > 5.0 then
        return false
    end

    if not exports.ox_inventory:CanCarryItem(source, item, 1) then
        return false
    end

    removeMarker(marker.id)
    exports.ox_inventory:AddItem(source, item, 1)
    return true
end)

-- Old markers clear themselves
lib.cron.new("* * * * *", function()
    local now <const> = os.time()
    for id, marker in pairs(markers) do
        if marker.expiresAt <= now then
            removeMarker(id)
        end
    end
end)
