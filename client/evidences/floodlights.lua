-- UV floodlights at crime scenes (server/evidences/floodlights.lua). Each one lights the ground around it in UV
-- and shows every piece of evidence within config.uvFloodlight.radius, without anyone holding a flashlight.
local config <const> = require "config"
local eventHandler <const> = require "common.events.handler"
local placement <const> = require "client.utils.placement"
local player <const> = require "client.player"
local uv <const> = require "client.evidences.uv"

local settings <const> = config.uvFloodlight
local colour <const> = config.uvLight.colour or { r = 60, g = 90, b = 255 }
local areaKey <const> = "floodlight:%s"

local floodlights = {} -- id -> { point, entity }

local function addFloodlight(data)
    if floodlights[data.id] then
        return
    end

    local coords <const> = vector4(data.coords.x, data.coords.y, data.coords.z, data.coords.w)
    local lampCoords <const> = coords.xyz + vector3(0.0, 0.0, settings.lampHeight)
    local floodlight = {}

    floodlight.point = lib.points.new({
        coords = coords.xyz,
        distance = settings.radius + 40.0,
        onEnter = function()
            if not floodlight.entity then
                lib.requestModel(settings.model)
                floodlight.entity = CreateObject(settings.model, coords.x, coords.y, coords.z, false, true, false)
                SetEntityHeading(floodlight.entity, coords.w)
                PlaceObjectOnGroundProperly(floodlight.entity)
                FreezeEntityPosition(floodlight.entity, true)
                SetModelAsNoLongerNeeded(settings.model)
            end

            uv.setArea(areaKey:format(data.id), coords.xyz, settings.radius)
        end,
        onExit = function()
            uv.removeArea(areaKey:format(data.id))

            if floodlight.entity and DoesEntityExist(floodlight.entity) then
                DeleteObject(floodlight.entity)
            end
            floodlight.entity = nil
        end,
        nearby = function()
            -- a soft blue glow over the whole area, and the lamp's beam angled down onto it
            DrawLightWithRange(lampCoords.x, lampCoords.y, lampCoords.z, colour.r, colour.g, colour.b, settings.radius + 2.0, settings.intensity)
            DrawSpotLight(lampCoords.x, lampCoords.y, lampCoords.z, 0.0, 0.0, -1.0, colour.r, colour.g, colour.b, settings.radius + 4.0, settings.intensity * 3.0, 0.0, 65.0, 1.0)
        end
    })

    floodlights[data.id] = floodlight
end

local function removeFloodlight(id)
    local floodlight <const> = floodlights[id]
    if not floodlight then
        return
    end

    floodlight.point:onExit()
    floodlight.point:remove()
    floodlights[id] = nil
end

local function getFloodlightId(entity)
    for id, floodlight in pairs(floodlights) do
        if floodlight.entity == entity then
            return id
        end
    end
end

CreateThread(function()
    for _, data in ipairs(Thistle.Callback.Await("evidences:getUvFloodlights") or {}) do
        addFloodlight(data)
    end
end)

RegisterNetEvent("evidences:addUvFloodlight", addFloodlight)
RegisterNetEvent("evidences:removeUvFloodlight", removeFloodlight)

exports.ox_target:addModel(settings.model, {
    {
        name = "evidences:uv_floodlight_pickup",
        label = locale("uv_floodlight.pickup"),
        icon = "fa-solid fa-arrow-up-from-bracket",
        distance = 2,
        groups = settings.permissions or false,
        canInteract = function(entity)
            return getFloodlightId(entity) ~= nil
        end,
        onSelect = function(data)
            local id <const> = getFloodlightId(data.entity)
            if id and Thistle.Callback.Await("evidences:pickupUvFloodlight", id) then
                lib.playAnim(cache.ped, "random@domestic", "pickup_low")
            end
        end
    }
})

local isPlacing = false

local function placeFloodlight()
    local info <const> = player.getInfo()
    if info.setupIncomplete then
        return
    end

    if not info.permissions.placeUvFloodlight then
        config.notify({ key = "laptop.notifications.no_permission" }, "error")
        return
    end

    local coords <const> = placement.place(settings.model, locale("uv_floodlight.input_help"))

    -- The server takes the item, so a floodlight can't be placed without one
    if coords and Thistle.Callback.Await("evidences:placeUvFloodlight", coords) then
        lib.playAnim(cache.ped, "random@domestic", "pickup_low")
    end
end

exports("uv_floodlight", function(data, slot)
    if isPlacing then
        return
    end

    -- ox_inventory calls this export from its own resource, so the waiting runs in a thread
    isPlacing = true
    CreateThread(function()
        local success <const>, err <const> = pcall(placeFloodlight)
        isPlacing = false

        if not success then
            error(err)
        end
    end)
end)

eventHandler.onLocal("onResourceStop", function(event)
    if event.arguments[1] == cache.resource then
        exports.ox_target:removeModel(settings.model, "evidences:uv_floodlight_pickup")

        for id in pairs(floodlights) do
            removeFloodlight(id)
        end
    end
end)
