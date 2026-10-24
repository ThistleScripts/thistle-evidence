-- Evidence markers at crime scenes (server/evidences/markers.lua). Using the evidence_marker kit opens a menu of the
-- props in config.evidenceMarkers.props; the chosen one follows the camera and every click puts one down until the
-- officer presses ENTER or ESC. Officers target a marker to pick it up, or every marker at the scene.
local config <const> = require "config"
local eventHandler <const> = require "common.events.handler"
local player <const> = require "client.player"
local permissions <const> = require "client.permissions"

local settings <const> = config.evidenceMarkers

local allModels = {}
for _, prop in ipairs(settings.props) do
    allModels[#allModels + 1] = prop.model
end

local markers = {} -- id -> { point, entity }

local function addMarker(data)
    local prop <const> = settings.props[data.prop]
    if markers[data.id] or not prop then
        return
    end

    local coords <const> = vector4(data.coords.x, data.coords.y, data.coords.z, data.coords.w)
    local marker = {}

    marker.point = lib.points.new({
        coords = coords.xyz,
        distance = 60,
        onEnter = function()
            if marker.entity then
                return
            end

            lib.requestModel(prop.model)
            marker.entity = CreateObject(prop.model, coords.x, coords.y, coords.z, false, true, false)
            SetEntityHeading(marker.entity, coords.w)
            PlaceObjectOnGroundProperly(marker.entity)
            FreezeEntityPosition(marker.entity, true)
            SetModelAsNoLongerNeeded(prop.model)
        end,
        onExit = function()
            if marker.entity and DoesEntityExist(marker.entity) then
                DeleteObject(marker.entity)
            end
            marker.entity = nil
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
            return permissions.has("markers") and getMarkerId(entity) ~= nil
        end,
        onSelect = function(data)
            local id <const> = getMarkerId(data.entity)
            if id and Thistle.Callback.Await("evidences:pickupEvidenceMarker", id) then
                lib.playAnim(cache.ped, "random@domestic", "pickup_low")
            end
        end
    },
    {
        name = "evidences:evidence_marker_pickup_all",
        label = locale("markers.pickup_all"),
        icon = "fa-solid fa-layer-group",
        distance = 2,
        groups = settings.permissions or false,
        canInteract = function(entity)
            return permissions.has("markers") and getMarkerId(entity) ~= nil
        end,
        onSelect = function(data)
            local id <const> = getMarkerId(data.entity)
            local count <const> = id and Thistle.Callback.Await("evidences:pickupAllEvidenceMarkers", id) or 0
            if count > 0 then
                lib.playAnim(cache.ped, "random@domestic", "pickup_low")
                config.notify({ key = "markers.picked_up_all", arguments = { count } }, "success")
            end
        end
    }
})

local ghost = nil

-- Keeps the game's own use of the placer's keys (shooting, the weapon wheel, the pause menu) off for this frame
local function disablePlacerControls()
    DisablePlayerFiring(cache.playerId, true)
    DisableControlAction(0, 24, true) -- attack
    DisableControlAction(0, 25, true) -- aim
    DisableControlAction(0, 140, true) -- melee attacks
    DisableControlAction(0, 141, true)
    DisableControlAction(0, 142, true)
    DisableControlAction(0, 14, true) -- weapon wheel scroll
    DisableControlAction(0, 15, true)
    DisableControlAction(0, 16, true)
    DisableControlAction(0, 17, true)
    DisableControlAction(0, 37, true) -- weapon wheel
    DisableControlAction(0, 200, true) -- pause menu
end

-- Click to place the prop, scroll to rotate it, ENTER or ESC to stop
local function runPlacer(propIndex)
    local model <const> = settings.props[propIndex].model
    local pedCoords <const> = GetEntityCoords(cache.ped)

    ghost = CreateObject(lib.requestModel(model), pedCoords.x, pedCoords.y, pedCoords.z - 5.0, false, true, false)
    SetModelAsNoLongerNeeded(model)
    SetEntityAlpha(ghost, 150, false)
    SetEntityCollision(ghost, false, false)
    FreezeEntityPosition(ghost, true)

    config.inputHelp.show(locale("markers.placer_help"), {
        tildeDelimitedCodes = { "~INPUT_ATTACK~", "~n~", "~INPUT_WEAPON_WHEEL_PREV~", "~n~", "~INPUT_FRONTEND_ACCEPT~", "~INPUT_FRONTEND_CANCEL~" },
        mappedValues = { "[LMB]", "\n", "[SCROLL]", "\n", "[ENTER]", "[ESC]" }
    })

    local rotation = 0.0
    local sending = false

    while true do
        disablePlacerControls()

        if IsControlJustPressed(0, 201) or IsControlJustPressed(0, 202) or IsDisabledControlJustPressed(0, 200) then
            break
        end

        if IsDisabledControlJustPressed(0, 15) then
            rotation += 15.0
        elseif IsDisabledControlJustPressed(0, 14) then
            rotation -= 15.0
        end

        local hit <const>, _, endCoords <const> = lib.raycast.fromCamera(339, 4, 10)
        local valid <const> = hit and endCoords ~= vector3(0, 0, 0)

        if valid then
            local camCoords <const> = GetGameplayCamCoord()
            local heading <const> = math.deg(math.atan(camCoords.y - endCoords.y, camCoords.x - endCoords.x)) + 90.0 + rotation

            SetEntityCoords(ghost, endCoords.x, endCoords.y, endCoords.z, false, false, false, false)
            SetEntityHeading(ghost, heading % 360.0)
        end

        if valid and not sending and IsDisabledControlJustPressed(0, 24) then
            local coords <const> = GetEntityCoords(ghost)
            local placeAt <const> = vector4(coords.x, coords.y, coords.z, GetEntityHeading(ghost))

            -- Sent from its own thread so the preview keeps following the camera while the server answers
            sending = true
            CreateThread(function()
                if Thistle.Callback.Await("evidences:placeEvidenceMarker", placeAt, propIndex) then
                    PlaySoundFrontend(-1, "SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)
                end
                sending = false
            end)
        end

        Wait(0)
    end

    DeleteObject(ghost)
    ghost = nil
    config.inputHelp.hide()

    -- ESC is held for a moment after stopping; keep it from opening the pause menu
    local releaseUntil <const> = GetGameTimer() + 500
    while GetGameTimer() < releaseUntil do
        DisableControlAction(0, 200, true)
        Wait(0)
    end
end

exports("evidence_marker", function()
    if ghost then
        return
    end

    -- ox_inventory calls this export from its own resource, so the permission check runs in a thread
    CreateThread(function()
        local info <const> = player.getInfo()
        if info.setupIncomplete then
            return
        end

        if not info.permissions.placeMarkers or not permissions.has("markers") then
            config.notify({ key = "laptop.notifications.no_permission" }, "error")
            return
        end

        local options = {}
        for index, prop in ipairs(settings.props) do
            options[index] = {
                title = prop.label,
                description = locale("markers.menu_description"),
                icon = "location-dot",
                onSelect = function()
                    if not ghost then
                        CreateThread(function()
                            runPlacer(index)
                        end)
                    end
                end
            }
        end

        lib.registerContext({
            id = "evidences:evidence_markers",
            title = locale("markers.menu_title"),
            options = options
        })
        lib.showContext("evidences:evidence_markers")
    end)
end)

eventHandler.onLocal("onResourceStop", function(event)
    if event.arguments[1] == cache.resource then
        exports.ox_target:removeModel(allModels, { "evidences:evidence_marker_pickup", "evidences:evidence_marker_pickup_all" })

        if ghost then
            DeleteObject(ghost)
            config.inputHelp.hide()
        end

        for id in pairs(markers) do
            removeMarker(id)
        end
    end
end)
