-- Bleach residue left by cleaning up (server/evidences/bleach.lua): a faint smear on the ground that only shows under UV
-- light (the flashlight, a lamp, or another officer's beam), and stays visible a while after the light has passed, like
-- other evidence. Officers can examine it to see roughly how long ago the spot was cleaned.
local config <const> = require "config"
local eventHandler <const> = require "common.events.handler"
local uv <const> = require "client.evidences.uv"

local settings <const> = config.bleachResidue or {}
local colour <const> = settings.colour or { r = 190, g = 255, b = 140 }

local marks = {} -- id -> { id, coords, cleanedAt (GetGameTimer), zone }
local nearby = {} -- the marks close enough to draw, refreshed a few times a second

local function minutesAgo(mark)
    return math.max(1, math.floor((GetGameTimer() - mark.cleanedAt) / 60000 + 0.5))
end

local function removeMark(id)
    local mark <const> = marks[id]
    if mark and mark.zone then
        exports.ox_target:removeZone(mark.zone)
    end
    marks[id] = nil
end

RegisterNetEvent("evidences:bleach:add", function(data)
    if type(data) ~= "table" or not data.id or not data.coords then
        return
    end

    removeMark(data.id) -- freshened: same spot, new time

    -- on the ground itself, so the smear lies flat
    local coords = vector3(data.coords.x, data.coords.y, data.coords.z)
    local found <const>, groundZ <const> = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z + 1.0, false)
    if found and math.abs(groundZ - coords.z) < 2.0 then
        coords = vector3(coords.x, coords.y, groundZ)
    end

    local mark = { id = data.id, coords = coords, cleanedAt = GetGameTimer() - (tonumber(data.age) or 0) * 1000 }
    local key <const> = ("bleach:%s"):format(data.id)

    mark.zone = exports.ox_target:addSphereZone({
        coords = coords,
        radius = 0.8,
        drawSprite = false,
        options = {
            {
                name = "evidences:bleach_examine",
                label = locale("bleach.examine"),
                icon = "fa-solid fa-spray-can-sparkles",
                distance = 2.5,
                groups = config.permissions.collect or false,
                canInteract = function()
                    return uv.reveals(key, coords)
                end,
                onSelect = function()
                    config.notify({ key = "bleach.examined", arguments = { tostring(minutesAgo(mark)) } }, "inform", 7000)
                end
            }
        }
    })

    marks[data.id] = mark
end)

RegisterNetEvent("evidences:bleach:remove", removeMark)

CreateThread(function()
    local nextScan = 0

    while true do
        local lit <const> = uv.wasOnRecently() or uv.hasAreas() or uv.hasRemoteBeams()

        if lit and next(marks) then
            if GetGameTimer() >= nextScan then
                nextScan = GetGameTimer() + 500
                local pedCoords <const> = GetEntityCoords(cache.ped)
                nearby = {}
                for _, mark in pairs(marks) do
                    if #(pedCoords - mark.coords) <= 30.0 then
                        nearby[#nearby + 1] = mark
                    end
                end
            end

            for _, mark in ipairs(nearby) do
                if uv.reveals(("bleach:%s"):format(mark.id), mark.coords) then
                    local coords <const> = mark.coords
                    DrawMarker(25, coords.x, coords.y, coords.z + 0.03, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.4, 1.4, 1.0,
                        colour.r, colour.g, colour.b, 70, false, false, 2, false, nil, nil, false)
                end
            end

            Wait(0)
        else
            Wait(500)
        end
    end
end)

eventHandler.onLocal("onResourceStop", function(event)
    if event.arguments[1] == cache.resource then
        for id in pairs(marks) do
            removeMark(id)
        end
    end
end)
