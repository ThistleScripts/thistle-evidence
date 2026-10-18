local config <const> = require "config"
local framework <const> = require "server.framework"
local actions <const> = require "server.evidences.actions"
local logger <const> = require "server.logger"

Thistle.Callback.Register("evidences:takeBiometricData", function(playerId, targetId, type, enforce, metadata)
    if not framework.hasPermission(config.permissions.collect, playerId) then
        TriggerClientEvent("evidences:notify", playerId, { key = "biometrics_taking.notifications.no_permission" }, "error")
        return false
    end

    -- The target has to be a player standing next to the officer (the client offers this from 3 m away)
    targetId = tonumber(targetId)
    local ped <const>, targetPed <const> = GetPlayerPed(playerId), targetId and GetPlayerPed(targetId) or 0
    if (type ~= "dna" and type ~= "fingerprint") or not targetId or targetId == playerId or targetPed == 0
        or #(GetEntityCoords(ped) - GetEntityCoords(targetPed)) > 5.0 then
        return false
    end

    if not enforce then
        TriggerClientEvent("evidences:notify", playerId, { key = "biometrics_taking.notifications.request_sent" }, "inform")

        if not Thistle.Callback.Await("evidences:requestConsent", targetId, framework.getPlayerName(playerId), type) then
            TriggerClientEvent("evidences:notify", playerId, { key = "biometrics_taking.notifications.no_consent" }, "error")
            return false
        end

        TriggerClientEvent("evidences:notify", playerId, { key = "biometrics_taking.notifications.consent" }, "success")
    end

    if not actions.collect(playerId, type == "dna" and "saliva" or "fingerprint", targetId, nil, metadata) then
        TriggerClientEvent("evidences:notify", playerId, { key = "biometrics_taking.notifications.error" }, "error")
        return false
    end

    logger.log(playerId, "Biometric data taken", { target = targetId, evidenceType = type, enforced = enforce and "true" or "false" })
    return true
end)