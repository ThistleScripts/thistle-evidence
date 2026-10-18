local config <const> = require "config"
local framework <const> = require "server.framework"
local logger <const> = require "server.logger"
local ObservableSpyMicrophone <const> = require "server.wiretap.classes.observable_spy_microphone"
local spyMicrophones = {}

Thistle.Callback.Register("evidences:getSpyMicrophones", function()
    return spyMicrophones
end)

Thistle.Callback.Register("evidences:placeSpyMicrophone", function(source, label, coords)
    if type(label) ~= "string" or #label < 1 or #label > 25 or spyMicrophones[label] then
        return false
    end

    if type(coords) ~= "vector4" or #(GetEntityCoords(GetPlayerPed(source)) - coords.xyz) > 15.0 then
        return false
    end

    -- Take the microphone from the player here rather than trusting the client to use it up
    if not exports.ox_inventory:RemoveItem(source, "spy_microphone", 1) then
        return false
    end

    local observableSpyMicrophone <const> = ObservableSpyMicrophone:new(label, coords)
    observableSpyMicrophone:sync()
    spyMicrophones[label] = observableSpyMicrophone

    TriggerClientEvent("evidences:updateSpyMicrophones", -1, spyMicrophones)
    logger.log(source, "Spy microphone placed", { label = label, coords = tostring(coords) })
    return true
end)

RegisterNetEvent("evidences:destroySpyMicrophone", function(label)
    local playerId <const> = source
    local observableSpyMicrophone <const> = spyMicrophones[label]

    if observableSpyMicrophone then
        observableSpyMicrophone:destroy()
        spyMicrophones[label] = nil

        TriggerClientEvent("evidences:updateSpyMicrophones", -1, spyMicrophones)
        logger.log(source, "Spy microphone picked up", { label = label, coords = tostring(observableSpyMicrophone.coords) })
        exports.ox_inventory:AddItem(playerId, "spy_microphone", 1)
    end
end)


RegisterNetEvent("evidences:addSpyMicrophoneTarget", function(label)
    local playerId <const> = source
    local observableSpyMicrophone <const> = spyMicrophones[label]

    if observableSpyMicrophone then
        observableSpyMicrophone:addTarget(playerId)
    end
end)

RegisterNetEvent("evidences:removeSpyMicrophoneTarget", function(label)
    local playerId <const> = source
    local observableSpyMicrophone <const> = spyMicrophones[label]

    if observableSpyMicrophone then
        observableSpyMicrophone:removeTarget(playerId)
    end
end)

Thistle.Callback.Register("evidences:observeObservableSpyMicrophone", function(observer, arguments)
    if not framework.hasPermission(config.wiretap.spyMicrophones.permissions, observer) then
        return {
            success = false,
            response = "laptop.notifications.no_permission.description"
        }
    end

    if arguments and arguments.label then
        local observableSpyMicrophone <const> = spyMicrophones[arguments.label]
        return observableSpyMicrophone and observableSpyMicrophone:addObserver(observer)
    end
end)

Thistle.Callback.Register("evidences:ignoreObservableSpyMicrophone", function(observer, arguments)
    if arguments and arguments.label then
        local observableSpyMicrophone <const> = spyMicrophones[arguments.label]
        return observableSpyMicrophone and observableSpyMicrophone:removeObserver(observer)
    end
end)