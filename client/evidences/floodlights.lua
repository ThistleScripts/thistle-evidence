-- UV lamps at crime scenes (server/evidences/floodlights.lua), in the styles of config.uvFloodlight.styles. They light
-- all round them, or a cone in front if the style has a direction. Evidence they light shows up without anyone holding a flashlight.
local config <const> = require "config"
local eventHandler <const> = require "common.events.handler"
local placement <const> = require "client.utils.placement"
local player <const> = require "client.player"
local uv <const> = require "client.evidences.uv"

local settings <const> = config.uvFloodlight
local colour <const> = config.uvLight.colour or { r = 60, g = 90, b = 255 }
local areaKey <const> = "uvlamp:%s"

local lamps = {} -- id -> { point, entity, zone }

-- The lamp's beam in the world: its direction on the model turned by the lamp's heading
local function getWorldDirection(style, heading)
    local direction <const> = style.direction
    local radians <const> = math.rad(heading)
    local cos <const>, sin <const> = math.cos(radians), math.sin(radians)
    local world <const> = vector3(direction.x * cos - direction.y * sin, direction.x * sin + direction.y * cos, direction.z)
    return world / #world
end

-- How far to turn the lamp from facing away from the officer, so its head (not its back) faces away
local function getHeadingOffset(style)
    if not style.direction then
        return 0.0
    end

    return -math.deg(math.atan(-style.direction.x, style.direction.y))
end

local function addLamp(data)
    local style <const> = settings.styles[data.style]
    if lamps[data.id] or not style then
        return
    end

    local coords <const> = vector4(data.coords.x, data.coords.y, data.coords.z, data.coords.w)
    local lampCoords <const> = GetOffsetFromCoordAndHeadingInWorldCoords(coords.x, coords.y, coords.z, coords.w, style.lamp.x, style.lamp.y, style.lamp.z)
    local direction <const> = style.direction and getWorldDirection(style, coords.w) or nil
    local lamp = {}

    lamp.point = lib.points.new({
        coords = coords.xyz,
        distance = style.radius + 40.0,
        onEnter = function()
            if not lamp.entity then
                lib.requestModel(style.model)
                lamp.entity = CreateObject(style.model, coords.x, coords.y, coords.z, false, true, false)
                SetEntityHeading(lamp.entity, coords.w)
                PlaceObjectOnGroundProperly(lamp.entity)
                FreezeEntityPosition(lamp.entity, true)
                SetModelAsNoLongerNeeded(style.model)
            end

            uv.setArea(areaKey:format(data.id), lampCoords, style.radius, direction, style.angle)
        end,
        onExit = function()
            uv.removeArea(areaKey:format(data.id))

            if lamp.entity and DoesEntityExist(lamp.entity) then
                DeleteObject(lamp.entity)
            end
            lamp.entity = nil
        end,
        nearby = function()
            if direction then
                DrawSpotLight(lampCoords.x, lampCoords.y, lampCoords.z, direction.x, direction.y, direction.z, colour.r, colour.g, colour.b, style.radius + 4.0, settings.intensity * 3.0, 0.0, style.angle * 1.2, 1.0)
                DrawLightWithRange(lampCoords.x, lampCoords.y, lampCoords.z, colour.r, colour.g, colour.b, 2.0, settings.intensity) -- the glowing head
            else
                DrawLightWithRange(lampCoords.x, lampCoords.y, lampCoords.z, colour.r, colour.g, colour.b, style.radius + 2.0, settings.intensity)
            end
        end
    })

    -- A target zone instead of the model, so picking it up doesn't depend on the prop having collision
    lamp.zone = exports.ox_target:addSphereZone({
        coords = coords.xyz + vector3(0.0, 0.0, 0.9),
        radius = 0.8,
        drawSprite = false,
        options = {
            {
                name = "evidences:uv_lamp_pickup",
                label = locale("uv_floodlight.pickup"),
                icon = "fa-solid fa-arrow-up-from-bracket",
                distance = 2.5,
                groups = settings.permissions or false,
                onSelect = function()
                    if Thistle.Callback.Await("evidences:pickupUvFloodlight", data.id) then
                        lib.playAnim(cache.ped, "random@domestic", "pickup_low")
                    end
                end
            }
        }
    })

    lamps[data.id] = lamp
end

local function removeLamp(id)
    local lamp <const> = lamps[id]
    if not lamp then
        return
    end

    lamp.point:onExit()
    lamp.point:remove()
    exports.ox_target:removeZone(lamp.zone, true)
    lamps[id] = nil
end

CreateThread(function()
    for _, data in ipairs(Thistle.Callback.Await("evidences:getUvFloodlights") or {}) do
        addLamp(data)
    end
end)

RegisterNetEvent("evidences:addUvFloodlight", addLamp)
RegisterNetEvent("evidences:removeUvFloodlight", removeLamp)

local isPlacing = false

local function placeLamp(styleName)
    local style <const> = settings.styles[styleName]

    local info <const> = player.getInfo()
    if info.setupIncomplete then
        return
    end

    if not info.permissions.placeUvFloodlight then
        config.notify({ key = "laptop.notifications.no_permission" }, "error")
        return
    end

    local coords <const> = placement.place(style.model, locale("uv_floodlight.input_help"), getHeadingOffset(style))

    -- The server takes the item, so a lamp can't be placed without one
    if coords and Thistle.Callback.Await("evidences:placeUvFloodlight", coords, styleName) then
        lib.playAnim(cache.ped, "random@domestic", "pickup_low")
    end
end

-- Each style's item (uv_floodlight, uv_spotlight) calls the export of the same name
for styleName in pairs(settings.styles) do
    exports(styleName, function(data, slot)
        if isPlacing then
            return
        end

        -- ox_inventory calls this export from its own resource, so the waiting runs in a thread
        isPlacing = true
        CreateThread(function()
            local success <const>, err <const> = pcall(placeLamp, styleName)
            isPlacing = false

            if not success then
                error(err)
            end
        end)
    end)
end

eventHandler.onLocal("onResourceStop", function(event)
    if event.arguments[1] == cache.resource then
        for id in pairs(lamps) do
            removeLamp(id)
        end
    end
end)
