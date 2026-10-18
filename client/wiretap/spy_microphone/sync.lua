local eventHandler <const> = require "common.events.handler"
local dui <const> = require "client.dui.dui"
local SpyMicrophone <const> = require "client.wiretap.spy_microphone.spy_microphone"

local spyMicrophones = {}

lib.callback("evidences:getSpyMicrophones", false, function(result)
    for label, spyMicrophone in pairs(result or {}) do
        spyMicrophones[label] = SpyMicrophone:new(label, spyMicrophone.coords)
    end
end)

RegisterNetEvent("evidences:registerSpyMicrophone", function(label, coords)
    spyMicrophones[label] = SpyMicrophone:new(label, coords)
end)

RegisterNetEvent("evidences:unregisterSpyMicrophone", function(label)
    local spyMicrophone <const> = spyMicrophones[label]

    if spyMicrophone then
        spyMicrophone:unregister()
        spyMicrophones[label] = nil
    end
end)

RegisterNetEvent("evidences:updateSpyMicrophones", function(spyMicrophones)
    dui:sendMessage({
        action = "updateSpyMicrophones",
        spyMicrophones = spyMicrophones
    })
end)

eventHandler.onLocal("onResourceStop", function(event)
    if event.arguments[1] == cache.resource then
        for _, spyMicrophone in pairs(spyMicrophones) do
            spyMicrophone:unregister()
        end
    end
end)