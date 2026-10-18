require "client.wiretap.spy_microphone.item"
require "client.wiretap.spy_microphone.sync"

local dui <const> = require "client.dui.dui"
local eventHandler <const> = require "common.events.handler"

-- Source: https://github.com/AvarianKnight/pma-voice/blob/main/client/init/main.lua
local submix <const> = CreateAudioSubmix("wiretap")
SetAudioSubmixEffectRadioFx(submix, 0)
SetAudioSubmixEffectParamInt(submix, 0, GetHashKey("default"), 1)
SetAudioSubmixOutputVolumes(submix, 0, 1.0, 0.25, 0.0, 1.0, 1.0, 1.0)
AddAudioSubmixOutput(submix, 0)


RegisterNetEvent("evidences:updateActiveCalls", function(activeCalls)
    dui:sendMessage({
        action = "updateActiveCalls",
        activeCalls = activeCalls
    })
end)


RegisterNetEvent("evidences:setAudioWaveActive", function(target, active)
    dui:sendMessage({
        action = "setAudioWaveActive",
        target = target,
        active = active
    })
end)


local targets = {} -- serverIds of the players this client is listening to
local observers = {} -- serverIds of the players that listen to this client
local running = false

local function checkForTalking()
    if not running then
        running = true

        CreateThread(function()
            local talking = nil

            while next(observers) do
                local nowTalking <const> = MumbleIsPlayerTalking(cache.playerId) == 1

                if talking ~= nowTalking then
                    talking = nowTalking
                    TriggerServerEvent("evidences:updateAudioWave", talking)
                end

                Wait(150)
            end

            running = false
        end)
    end
end

RegisterNetEvent("evidences:startTalkingTo", function(observer)
    MumbleAddVoiceTargetPlayerByServerId(1, observer)

    observers[observer] = true
    checkForTalking()
end)

RegisterNetEvent("evidences:stopTalkingTo", function(observer)
    MumbleRemoveVoiceTargetPlayerByServerId(1, observer)

    observers[observer] = nil
end)

RegisterNetEvent("evidences:startListeningTo", function(target)
    MumbleSetVolumeOverrideByServerId(target, 0.9)
    MumbleSetSubmixForServerId(target, submix)

    targets[target] = true
end)

RegisterNetEvent("evidences:stopListeningTo", function(target)
    MumbleSetSubmixForServerId(target, -1)
    MumbleSetVolumeOverrideByServerId(target, -1.0)

    targets[target] = false
end)


eventHandler.onLocal("onResourceStop", function(event)
    if event.arguments[1] == cache.resource then
        for target, _ in pairs(targets) do
            MumbleSetSubmixForServerId(target, -1)
            MumbleSetVolumeOverrideByServerId(target, -1.0)
        end

        for observer, _ in pairs(observers) do
            MumbleRemoveVoiceTargetPlayerByServerId(1, observer)
        end
    end
end)
