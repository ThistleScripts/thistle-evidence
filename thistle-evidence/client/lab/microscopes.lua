-- Microscopes open the forensics lab. They're spawned at the stations in config.forensicsLab.stations and wherever
-- an officer placed one with the forensic_microscope item (server/forensics/microscopes.lua).
local config <const> = require "config"
local eventHandler <const> = require "common.events.handler"
local lab <const> = require "client.lab.lab"
local player <const> = require "client.player"
local placement <const> = require "client.utils.placement"
local permissions <const> = require "client.permissions"

local model <const> = type(config.forensicsLab.model) == "string" and joaat(config.forensicsLab.model) or config.forensicsLab.model or `v_med_microscope`

local microscopes = {} -- key -> { point, entity, id? }

---@param key string
---@param coords vector4
---@param id? number Set for placed microscopes, which can be picked up again
local function spawnMicroscope(key, coords, id)
    if microscopes[key] then
        return
    end

    local microscope = { id = id }

    microscope.point = lib.points.new({
        coords = coords.xyz,
        distance = 25,
        onEnter = function()
            if microscope.entity then
                return
            end

            lib.requestModel(model)
            microscope.entity = CreateObject(model, coords.x, coords.y, coords.z, false, true, false)
            SetEntityHeading(microscope.entity, coords.w)
            FreezeEntityPosition(microscope.entity, true)
            SetModelAsNoLongerNeeded(model)
        end,
        onExit = function()
            if microscope.entity and DoesEntityExist(microscope.entity) then
                DeleteObject(microscope.entity)
            end

            microscope.entity = nil
        end
    })

    microscopes[key] = microscope
end

local function removeMicroscope(key)
    local microscope <const> = microscopes[key]
    if not microscope then
        return
    end

    microscope.point:onExit()
    microscope.point:remove()
    microscopes[key] = nil
end

local function getPlacedId(entity)
    for _, microscope in pairs(microscopes) do
        if microscope.entity == entity then
            return microscope.id
        end
    end
end

for index, coords in ipairs(config.forensicsLab.stations or {}) do
    spawnMicroscope("station:" .. index, vector4(coords.x, coords.y, coords.z, coords.w or 0.0))
end

local function spawnPlaced(rows)
    for _, row in ipairs(rows or {}) do
        spawnMicroscope("placed:" .. row.id, vector4(row.x, row.y, row.z, row.w), row.id)
    end
end

CreateThread(function()
    spawnPlaced(Thistle.Callback.Await("evidences:getMicroscopes"))
end)

RegisterNetEvent("evidences:spawnMicroscopes", spawnPlaced)

RegisterNetEvent("evidences:removeMicroscope", function(id)
    removeMicroscope("placed:" .. id)
end)

-- Every microscope of this model is a way into the lab, including ones placed by the map
exports.ox_target:addModel(model, {
    {
        name = "evidences:microscope_use",
        label = locale("lab.target"),
        icon = "fa-solid fa-microscope",
        distance = 2,
        groups = config.permissions.access or false,
        canInteract = function()
            return not config.isPedDead(cache.ped) and permissions.has("microscope")
        end,
        onSelect = function()
            lab.open()
        end
    },
    {
        name = "evidences:microscope_pickup",
        label = locale("lab.pickup"),
        icon = "fa-solid fa-arrow-up-from-bracket",
        distance = 2,
        groups = config.forensicsLab.permissions.pickup or false,
        canInteract = function(entity)
            return permissions.has("microscope") and getPlacedId(entity) ~= nil
        end,
        onSelect = function(data)
            local id <const> = getPlacedId(data.entity)
            if id and Thistle.Callback.Await("evidences:pickupMicroscope", id) then
                lib.playAnim(cache.ped, "mp_common", "givetake1_a")
            end
        end
    }
})

local isPlacing = false

local function placeMicroscope()
    local info <const> = player.getInfo()
    if info.setupIncomplete then
        return
    end

    if not info.permissions.placeMicroscope or not permissions.has("microscope") then
        config.notify({ key = "laptop.notifications.no_permission" }, "error")
        return
    end

    local coords <const> = placement.place(model, locale("lab.input_help"))

    -- The server takes the item, so a microscope can't be placed without one
    if coords and Thistle.Callback.Await("evidences:placeMicroscope", coords) then
        lib.playAnim(cache.ped, "mp_common", "givetake1_a")
    end
end

exports("forensic_microscope", function(data, slot)
    if isPlacing then
        return
    end

    -- ox_inventory calls this export from its own resource, so the waiting runs in a thread
    isPlacing = true
    CreateThread(function()
        local success <const>, err <const> = pcall(placeMicroscope)
        isPlacing = false

        if not success then
            error(err)
        end
    end)
end)

eventHandler.onLocal("onResourceStop", function(event)
    if event.arguments[1] == cache.resource then
        exports.ox_target:removeModel(model, { "evidences:microscope_use", "evidences:microscope_pickup" })

        for key in pairs(microscopes) do
            removeMicroscope(key)
        end
    end
end)
