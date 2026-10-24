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
    if not playerHoldingScanner or playerHoldingScanner == scanningPlayerId or not DoesPlayerExist(playerHoldingScanner)
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