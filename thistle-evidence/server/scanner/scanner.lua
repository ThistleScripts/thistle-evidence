local logger <const> = require "server.logger"
local biometricsProvider <const> = require "server.biometrics.biometrics_provider"
local linkedBiometrics <const> = require "server.biometrics.linked_biometrics"
local officerPermissions <const> = require "server.permissions"

local function isPlayerNear(playerId, otherPlayerId, maxDistance)
    local ped <const>, otherPed <const> = GetPlayerPed(playerId), GetPlayerPed(otherPlayerId)
    return ped ~= 0 and otherPed ~= 0 and #(GetEntityCoords(ped) - GetEntityCoords(otherPed)) <= maxDistance
end

Thistle.Callback.Register("evidences:scanFingerprint", function(scanningPlayerId, playerHoldingScanner)
    -- The result goes to the player holding the scanner, so they must be right there and actually have one
    playerHoldingScanner = tonumber(playerHoldingScanner)
    if not playerHoldingScanner or playerHoldingScanner <= 0 or playerHoldingScanner == scanningPlayerId or not DoesPlayerExist(playerHoldingScanner)
        or not isPlayerNear(scanningPlayerId, playerHoldingScanner, 3.0)
        or (exports.ox_inventory:Search(playerHoldingScanner, "count", "forensic_fingerprint_scanner") or 0) < 1
        or not officerPermissions.has(playerHoldingScanner, "fingerprints") then
        return false
    end

    local fingerprint = biometricsProvider.getFingerprint(scanningPlayerId) -- correct/real fingerprint
    local citizen = linkedBiometrics.getCitizenLinkedToBiometricData("fingerprint", fingerprint) -- citizen linked to the fingerprint (can be a different one)

    TriggerClientEvent("evidences:fingerprintScanned", playerHoldingScanner, citizen)

    if citizen and citizen.success then
        logger.log(playerHoldingScanner, "Fingerprint scanned", { scanningPlayerId = scanningPlayerId, fingerprint = fingerprint })
        return true
    end

    return false
end)

-- An officer scanning a player's finger: they target the player and choose Scan fingerprint (client/scanner/scanner.lua).
-- The player is asked first, as when taking prints with a forensic kit, unless they're cuffed or down.
local config <const> = require "config"
local framework <const> = require "server.framework"

Thistle.Callback.Register("evidences:scanPlayerFingerprint", function(officer, targetId, enforce)
    targetId = tonumber(targetId)
    if not targetId or targetId <= 0 or targetId == officer or not DoesPlayerExist(targetId) or not isPlayerNear(officer, targetId, 3.0)
        or (exports.ox_inventory:Search(officer, "count", "forensic_fingerprint_scanner") or 0) < 1
        or not framework.hasPermission(config.permissions.collect, officer)
        or not officerPermissions.has(officer, "fingerprints") then
        return false
    end

    if not enforce then
        TriggerClientEvent("evidences:notify", officer, { key = "biometrics_taking.notifications.request_sent" }, "inform")

        if not Thistle.Callback.Await("evidences:requestConsent", targetId, framework.getPlayerName(officer), "fingerprint") then
            TriggerClientEvent("evidences:notify", officer, { key = "biometrics_taking.notifications.no_consent" }, "error")
            return false
        end
    end

    -- gloves are checked on the player being scanned
    if Thistle.Callback.Await("evidences:isWearingGloves", targetId) then
        TriggerClientEvent("evidences:notify", officer, { key = "fingerprint_scanner.scan_target_gloves" }, "error")
        return false
    end

    local fingerprint <const> = biometricsProvider.getFingerprint(targetId)
    local citizen <const> = linkedBiometrics.getCitizenLinkedToBiometricData("fingerprint", fingerprint)

    TriggerClientEvent("evidences:fingerprintScanned", officer, citizen)
    logger.log(officer, "Fingerprint scanned", { scanningPlayerId = targetId, fingerprint = fingerprint, enforced = enforce and "true" or "false" })

    return true
end)
