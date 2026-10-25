local config <const> = require "config"
local framework <const> = require "server.framework"
local database <const> = require "server.database"
local citizens <const> = require "server.citizens.citizens"
local allowedTypes <const> = { "fingerprint", "dna" }
local logger <const> = require "server.logger"

local linkedBiometrics = {}

MySQL.update.await(
    [[
        CREATE TABLE IF NOT EXISTS linked_fingerprint (
            fingerprint VARCHAR(16) PRIMARY KEY NOT NULL,
            identifier VARCHAR(500) NOT NULL UNIQUE,
            FOREIGN KEY (fingerprint) REFERENCES biometric_data(fingerprint)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]]
)

MySQL.update.await(
    [[
        CREATE TABLE IF NOT EXISTS linked_dna (
            dna VARCHAR(16) PRIMARY KEY NOT NULL,
            identifier VARCHAR(500) NOT NULL UNIQUE,
            FOREIGN KEY (dna) REFERENCES biometric_data(dna)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]]
)

Thistle.Callback.Register("evidences:linkBiometricDataToIdentifier", function(source, arguments)
    if not framework.hasPermission(config.permissions.access, source) then
        return {
            success = false,
            response = "laptop.notifications.no_permission.description"
        }
    end

    local type <const> = arguments.type
    local biometricData <const> = arguments.biometricData
    local identifier <const> = arguments.identifier

    if lib.table.contains(allowedTypes, type) then
        -- already on another record: say whose, rather than quietly moving it (a false name, or the wrong person
        -- booked). arguments.move moves it anyway, once the officer has seen whose it was.
        if biometricData and not arguments.move then
            local owner <const> = database.selectFirstColumn(string.format("SELECT identifier FROM linked_%s WHERE %s = ?", type, type), biometricData)
            local ownerIdentifier <const> = owner.success and owner.response

            if ownerIdentifier and ownerIdentifier ~= identifier then
                local citizen <const> = citizens.getCitizen(ownerIdentifier)
                local record <const> = citizen and citizen.success and citizen.response or { identifier = ownerIdentifier, fullName = "?" }

                TriggerClientEvent("evidences:notify", source, {
                    key = "records.notifications.already_on_file",
                    arguments = { locale(("laptop.desktop_screen.common.%s"):format(type)), record.fullName or "?" }
                }, "error", 10000)

                return {
                    success = false,
                    response = "records.notifications.not_linked",
                    conflict = { identifier = record.identifier, fullName = record.fullName, birthdate = record.birthdate, gender = record.gender }
                }
            end
        end

        local result <const> = database.update(string.format("DELETE FROM linked_%s WHERE identifier = ?", type), identifier)

        if result.success then
            if biometricData then
                logger.log(source, "Biometric data linked to citizen", { evidenceType = type, biometricData = biometricData, identifier = identifier })

                return database.update(string.format([[
                    INSERT INTO linked_%s (%s, identifier) VALUES (?, ?)
                    ON DUPLICATE KEY UPDATE identifier = ?
                ]], type, type), biometricData, identifier, identifier)
            end
        end

        return result
    end
end)

function linkedBiometrics.getCitizenLinkedToBiometricData(type, biometricData)    
    if lib.table.contains(allowedTypes, type) then
        local identifierLinkedToBiometricData <const> = database.selectFirstColumn(
            string.format("SELECT identifier FROM linked_%s WHERE %s = ?", type, type), 
            biometricData
        )

        if identifierLinkedToBiometricData.success then
            return citizens.getCitizen(identifierLinkedToBiometricData.response)
        end

        return identifierLinkedToBiometricData
    end
end

Thistle.Callback.Register("evidences:getBiometricDataLinkedToIdentifier", function(source, arguments)
    if not framework.hasPermission(config.permissions.access, source) then
        return {
            success = false,
            response = "laptop.notifications.no_permission.description"
        }
    end

    return database.selectFirstRow(
        [[
            SELECT lf.fingerprint, ld.dna
            FROM (SELECT ? AS identifier) AS dummy
            LEFT JOIN linked_fingerprint lf ON dummy.identifier = lf.identifier
            LEFT JOIN linked_dna ld ON dummy.identifier = ld.identifier
        ]],
        arguments.identifier,
        function(response)
            return response or {}
        end
    )
end)

return linkedBiometrics
