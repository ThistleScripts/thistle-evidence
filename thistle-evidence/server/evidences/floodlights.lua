-- UV lamps officers stand at a crime scene, one item per style in config.uvFloodlight.styles (uv_floodlight,
-- uv_spotlight). Evidence they light shows up as if under the UV flashlight's beam. They're kept in memory only:
-- a restart clears them, and each switches itself off after config.uvFloodlight.lifetime minutes. Either way the item
-- is gone, so officers should pick them up when the scene is done.
local config <const> = require "config"
local framework <const> = require "server.framework"
local officerPermissions <const> = require "server.permissions"

local settings <const> = config.uvFloodlight

local floodlights = {} -- id -> { id, style, coords: vector4, owner, expiresAt }
local nextId = 0

local function countOwned(owner)
    local count = 0
    for _, floodlight in pairs(floodlights) do
        if floodlight.owner == owner then
            count += 1
        end
    end
    return count
end

local function removeFloodlight(id)
    if floodlights[id] then
        floodlights[id] = nil
        TriggerClientEvent("evidences:removeUvFloodlight", -1, id)
    end
end

Thistle.Callback.Register("evidences:getUvFloodlights", function()
    local list = {}
    for _, floodlight in pairs(floodlights) do
        list[#list + 1] = floodlight
    end
    return list
end)

Thistle.Callback.Register("evidences:placeUvFloodlight", function(source, coords, style)
    if not framework.hasPermission(settings.permissions, source) or not officerPermissions.has(source, "uv_lamps") then
        TriggerClientEvent("evidences:notify", source, { key = "laptop.notifications.no_permission" }, "error")
        return false
    end

    if type(coords) ~= "vector4" or #(GetEntityCoords(GetPlayerPed(source)) - coords.xyz) > 15.0 then
        return false
    end

    -- the style is also the item's name
    if type(style) ~= "string" or not settings.styles[style] then
        return false
    end

    local owner <const> = framework.getIdentifier(source) or source
    if countOwned(owner) >= settings.maxPerPlayer then
        TriggerClientEvent("evidences:notify", source, { key = "uv_floodlight.limit" }, "error")
        return false
    end

    if not exports.ox_inventory:RemoveItem(source, style, 1) then
        return false
    end

    nextId += 1
    local floodlight <const> = {
        id = nextId,
        style = style,
        coords = coords,
        owner = owner,
        expiresAt = os.time() + settings.lifetime * 60
    }

    floodlights[floodlight.id] = floodlight
    TriggerClientEvent("evidences:addUvFloodlight", -1, floodlight)
    return true
end)

Thistle.Callback.Register("evidences:pickupUvFloodlight", function(source, id)
    if not framework.hasPermission(settings.permissions, source) or not officerPermissions.has(source, "uv_lamps") then
        return false
    end

    local floodlight <const> = floodlights[tonumber(id)]
    if not floodlight or #(GetEntityCoords(GetPlayerPed(source)) - floodlight.coords.xyz) > 5.0 then
        return false
    end

    if not exports.ox_inventory:CanCarryItem(source, floodlight.style, 1) then
        TriggerClientEvent("evidences:notify", source, { key = "uv_floodlight.cannot_carry" }, "error")
        return false
    end

    -- removed first, so two players picking it up at once can't both get one
    removeFloodlight(floodlight.id)
    exports.ox_inventory:AddItem(source, floodlight.style, 1)
    return true
end)

-- Floodlights left behind switch themselves off
lib.cron.new("* * * * *", function()
    local now <const> = os.time()
    for id, floodlight in pairs(floodlights) do
        if floodlight.expiresAt <= now then
            removeFloodlight(id)
        end
    end
end)
