-- Numbered evidence markers at crime scenes (server/evidences/markers.lua). Marker N uses the Nth numbered prop
-- (config.evidenceMarkers.models); past those, the fallback prop with the number floating above it.
local config <const> = require "config"
local eventHandler <const> = require "common.events.handler"
local placement <const> = require "client.utils.placement"
local player <const> = require "client.player"

local settings <const> = config.evidenceMarkers

local function toHash(model)
    return type(model) == "string" and joaat(model) or model
end

local numberedModels = {}
for index, model in ipairs(settings.models or {}) do
    numberedModels[index] = toHash(model)
end

local fallbackModel <const> = toHash(settings.model)

-- The prop for marker number n, and whether the number has to be drawn above it
local function getModel(number)
    local numbered <const> = numberedModels[number]
    return numbered or fallbackModel, numbered == nil
end

local allModels = { fallbackModel }
for _, model in ipairs(numberedModels) do
    allModels[#allModels + 1] = model
end

local markers = {} -- id -> { number, point, entity }

local function drawNumber(coords, number)
    SetDrawOrigin(coords.x, coords.y, coords.z + (settings.numberHeight or 0.55), 0)
    SetTextScale(0.0, 0.45)
    SetTextFont(4)
    SetTextCentre(true)
    SetTextOutline()
    SetTextColour(255, 214, 10, 255)
    BeginTextCommandDisplayText("STRING")
    AddTextComponentSubstringPlayerName(tostring(number))
    EndTextCommandDisplayText(0.0, 0.0)
    ClearDrawOrigin()
end

local function addMarker(data)
    if markers[data.id] then
        return
    end

    local coords <const> = vector4(data.coords.x, data.coords.y, data.coords.z, data.coords.w)
    local model <const>, showNumber <const> = getModel(data.number)
    local marker = { number = data.number }

    marker.point = lib.points.new({
        coords = coords.xyz,
        distance = 60,
        onEnter = function()
            if marker.entity then
                return
            end

            lib.requestModel(model)
            marker.entity = CreateObject(model, coords.x, coords.y, coords.z, false, true, false)
            SetEntityHeading(marker.entity, coords.w)
            PlaceObjectOnGroundProperly(marker.entity)
            FreezeEntityPosition(marker.entity, true)
            SetModelAsNoLongerNeeded(model)
        end,
        onExit = function()
            if marker.entity and DoesEntityExist(marker.entity) then
                DeleteObject(marker.entity)
            end
            marker.entity = nil
        end,
        nearby = function(point)
            if showNumber and point.currentDistance < 20.0 then
                drawNumber(coords.xyz, marker.number)
            end
        end
    })

    markers[data.id] = marker
end

local function removeMarker(id)
    local marker <const> = markers[id]
    if not marker then
        return
    end

    marker.point:onExit()
    marker.point:remove()
    markers[id] = nil
end

local function getMarkerId(entity)
    for id, marker in pairs(markers) do
        if marker.entity == entity then
            return id
        end
    end
end

CreateThread(function()
    for _, data in ipairs(Thistle.Callback.Await("evidences:getEvidenceMarkers") or {}) do
        addMarker(data)
    end
end)

RegisterNetEvent("evidences:addEvidenceMarker", addMarker)
RegisterNetEvent("evidences:removeEvidenceMarker", removeMarker)

exports.ox_target:addModel(allModels, {
    {
        name = "evidences:evidence_marker_pickup",
        label = locale("markers.pickup"),
        icon = "fa-solid fa-arrow-up-from-bracket",
        distance = 2,
        groups = settings.permissions or false,
        canInteract = function(entity)
            return getMarkerId(entity) ~= nil
        end,
        onSelect = function(data)
            local id <const> = getMarkerId(data.entity)
            if id and Thistle.Callback.Await("evidences:pickupEvidenceMarker", id) then
                lib.playAnim(cache.ped, "random@domestic", "pickup_low")
            end
        end
    }
})

local isPlacing = false

exports("evidence_marker", function(data, slot)
    if isPlacing then
        return
    end

    -- ox_inventory calls this export from its own resource, so the placement runs in a thread
    isPlacing = true
    CreateThread(function()
        local success <const>, err <const> = pcall(function()
            local info <const> = player.getInfo()
            if info.setupIncomplete then
                return
            end

            if not info.permissions.placeMarkers then
                config.notify({ key = "laptop.notifications.no_permission" }, "error")
                return
            end

            local coords <const> = placement.place(numberedModels[1] or fallbackModel, locale("markers.input_help"))
            if not coords then
                return
            end

            local number <const> = Thistle.Callback.Await("evidences:placeEvidenceMarker", coords)
            if number then
                lib.playAnim(cache.ped, "random@domestic", "pickup_low")
                config.notify({ key = "markers.placed", arguments = { number } }, "success")
            end
        end)

        isPlacing = false

        if not success then
            error(err)
        end
    end)
end)

eventHandler.onLocal("onResourceStop", function(event)
    if event.arguments[1] == cache.resource then
        exports.ox_target:removeModel(allModels, "evidences:evidence_marker_pickup")

        for id in pairs(markers) do
            removeMarker(id)
        end
    end
end)
