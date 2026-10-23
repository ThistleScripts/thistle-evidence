-- Evidence marker props officers put down at a crime scene (the evidence_marker item is a reusable kit). They're kept in
-- memory only: a restart clears them, and each removes itself after config.evidenceMarkers.lifetime minutes.
local config <const> = require "config"
local framework <const> = require "server.framework"

local item <const> = "evidence_marker"
local settings <const> = config.evidenceMarkers

local markers = {} -- id -> { id, coords: vector4, prop, owner, expiresAt }
local nextId = 0
local lastPlaced = {} -- source -> GetGameTimer() of their last placement

local function countOwned(owner)
    local count = 0
    for _, marker in pairs(markers) do
        if marker.owner == owner then
            count += 1
        end
    end
    return count
end

local function removeMarker(id)
    if markers[id] then
        markers[id] = nil
        TriggerClientEvent("evidences:removeEvidenceMarker", -1, id)
    end
end

-- The marker with this id if the player may pick it up from where they stand
local function getMarkerInReach(source, id)
    if not framework.hasPermission(settings.permissions, source) then
        return nil
    end

    local marker <const> = markers[tonumber(id)]
    if not marker or #(GetEntityCoords(GetPlayerPed(source)) - marker.coords.xyz) > 5.0 then
        return nil
    end

    return marker
end

Thistle.Callback.Register("evidences:getEvidenceMarkers", function()
    local list = {}
    for _, marker in pairs(markers) do
        list[#list + 1] = marker
    end
    return list
end)

Thistle.Callback.Register("evidences:placeEvidenceMarker", function(source, coords, prop)
    if not framework.hasPermission(settings.permissions, source) then
        TriggerClientEvent("evidences:notify", source, { key = "laptop.notifications.no_permission" }, "error")
        return false
    end

    if type(coords) ~= "vector4" or math.type(prop) ~= "integer" or not settings.props[prop] then
        return false
    end

    if #(GetEntityCoords(GetPlayerPed(source)) - coords.xyz) > 15.0 then
        return false
    end

    -- Clicking places one marker per click; anything faster than this isn't a person clicking
    local now <const> = GetGameTimer()
    if lastPlaced[source] and now - lastPlaced[source] < 150 then
        return false
    end

    -- The kit is reusable, so it only has to be carried
    if (exports.ox_inventory:GetItemCount(source, item) or 0) < 1 then
        return false
    end

    local owner <const> = framework.getIdentifier(source) or source
    if countOwned(owner) >= settings.maxPerPlayer then
        TriggerClientEvent("evidences:notify", source, { key = "markers.limit" }, "error")
        return false
    end

    lastPlaced[source] = now
    nextId += 1
    local marker <const> = {
        id = nextId,
        coords = coords,
        prop = prop,
        owner = owner,
        expiresAt = os.time() + settings.lifetime * 60
    }

    markers[marker.id] = marker
    TriggerClientEvent("evidences:addEvidenceMarker", -1, marker)
    return true
end)

Thistle.Callback.Register("evidences:pickupEvidenceMarker", function(source, id)
    local marker <const> = getMarkerInReach(source, id)
    if not marker then
        return false
    end

    removeMarker(marker.id)
    return true
end)

-- Picks up every marker at the scene of the targeted one
Thistle.Callback.Register("evidences:pickupAllEvidenceMarkers", function(source, id)
    local target <const> = getMarkerInReach(source, id)
    if not target then
        return 0
    end

    local count = 0
    for markerId, marker in pairs(markers) do
        if #(marker.coords.xyz - target.coords.xyz) <= settings.sceneRadius then
            removeMarker(markerId)
            count += 1
        end
    end

    return count
end)

AddEventHandler("playerDropped", function()
    lastPlaced[source] = nil
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
