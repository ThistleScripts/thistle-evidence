-- The forensics lab: analysing collected evidence and the case files that link evidence sharing a DNA, fingerprint or gun ID.
-- The server reads everything from the item itself, so the client only says which item to analyse.
local config <const> = require "config"
local framework <const> = require "server.framework"
local database <const> = require "server.database"
local inventory <const> = require "server.evidences.inventory"
local citizens <const> = require "server.citizens.citizens"
local linkedBiometrics <const> = require "server.biometrics.linked_biometrics"
local createInformation <const> = require "server.evidences.evidence_information"
local logger <const> = require "server.logger"

local kinds <const> = { "dna", "fingerprint", "ballistics" }

-- Ballistic evidence that carries the gun's ID. Magazines and gunshot residue only tell the weapon type.
local identifyingBallistics <const> = { bullet = true, casing = true }

MySQL.update.await(
    [[
        CREATE TABLE IF NOT EXISTS forensic_matches (
            id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
            kind ENUM('dna', 'fingerprint', 'ballistics') NOT NULL,
            matchKey VARCHAR(50) NOT NULL,
            evidenceType VARCHAR(30) NOT NULL,
            weaponType TEXT NULL,
            crimeScene TEXT NULL,
            collectionTime TEXT NULL,
            collectedAt BIGINT NULL,
            analysedAt BIGINT NOT NULL,
            analysedBy TEXT NOT NULL,
            INDEX (kind, matchKey)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]]
)

local function deny()
    return {
        success = false,
        response = "laptop.notifications.no_permission.description"
    }
end

-- blood, saliva, fingerprint, bullet, casing, magazine, gunshot_residue, or the item name for traces on other items (e.g. a weapon)
local function getEvidenceType(item, kind)
    if kind == "ballistics" then
        return item.metadata.ballistics.type or "bullet"
    end

    local name <const> = item.name:match("^collected_(.+)$")
    return name or item.name
end

local function isTypeOnly(item, kind)
    return kind == "ballistics" and not identifyingBallistics[getEvidenceType(item, kind)]
end

-- What the lab shows for one kind of evidence on an item. The key is only sent once the evidence has been analysed.
local function describe(item, kind)
    local data <const> = item.metadata[kind]
    local information <const> = item.metadata.information or {}

    return {
        kind = kind,
        evidenceType = getEvidenceType(item, kind),
        analysed = data.analysed or false,
        key = data.analysed and not isTypeOnly(item, kind) and data.owner or nil,
        createdAt = item.metadata.createdAt or data.createdAt, -- when the trace was left (a shot, for gunshot residue)
        weaponType = data.weaponType,
        weaponImage = data.weaponImage,
        crimeScene = information.crimeScene or "",
        collectionTime = information.collectionTime or "",
        additionalData = information.additionalData or ""
    }
end

---@param kind "dna"|"fingerprint"|"ballistics"
---@param key string The DNA, fingerprint or gun ID
local function getCaseFile(kind, key)
    local caseFile = { kind = kind, key = key }

    if kind == "ballistics" then
        if config.firearmsRegistry.enabled then
            local firearm <const> = database.selectFirstRow("SELECT * FROM firearms_registry WHERE serial = ?", key)
            caseFile.firearm = firearm.success and firearm.response or nil

            if caseFile.firearm then
                local owner <const> = citizens.getCitizen(caseFile.firearm.identifier)
                caseFile.citizen = owner and owner.success and owner.response or nil
            end
        end
    else
        local linkedCitizen <const> = linkedBiometrics.getCitizenLinkedToBiometricData(kind, key)
        caseFile.citizen = linkedCitizen and linkedCitizen.success and linkedCitizen.response or nil
    end

    local matches <const> = database.query(
        "SELECT * FROM forensic_matches WHERE kind = ? AND matchKey = ? ORDER BY analysedAt DESC LIMIT 50",
        kind, key
    )
    caseFile.matches = matches.success and matches.response or {}

    return caseFile
end

-- Every item in the player's inventory and carried evidence boxes holding evidence the lab can analyse
Thistle.Callback.Register("evidences:lab:getEvidence", function(source)
    if not framework.hasPermission(config.permissions.access, source) then
        return deny()
    end

    return inventory.getItemsMatchingFilter(source, function(item)
        local metadata <const> = item.metadata or {}
        local evidence = {}

        for _, kind in ipairs(kinds) do
            if type(metadata[kind]) == "table" and metadata[kind].owner then
                evidence[#evidence + 1] = describe(item, kind)
            end
        end

        if #evidence > 0 then
            return true, { evidence = evidence }
        end

        return false
    end)
end)

Thistle.Callback.Register("evidences:lab:analyse", function(source, arguments)
    if not framework.hasPermission(config.permissions.access, source) then
        return deny()
    end

    arguments = type(arguments) == "table" and arguments or {}
    local kind <const> = arguments.kind
    if not lib.table.contains(kinds, kind) then
        return { success = false }
    end

    local item <const> = inventory.getItem(source, arguments.inventory, arguments.slot)
    local data <const> = item and item.metadata and item.metadata[kind]
    if type(data) ~= "table" or not data.owner then
        return { success = false }
    end

    local key <const> = data.owner
    local typeOnly <const> = isTypeOnly(item, kind)
    local caseFile <const> = not typeOnly and getCaseFile(kind, key) or { kind = kind }

    if not data.analysed then
        data.analysed = true

        local information <const> = item.metadata.information or {}
        if kind == "ballistics" then
            information.weaponType = (caseFile.firearm and caseFile.firearm.label) or data.weaponType
            information.serial = not typeOnly and key or nil
        else
            information[kind] = key
        end

        item.metadata.information = information
        item.metadata.description = createInformation(information)
        exports.ox_inventory:SetMetadata(arguments.inventory, arguments.slot, item.metadata)

        if not typeOnly then
            database.insert(
                [[
                    INSERT INTO forensic_matches (kind, matchKey, evidenceType, weaponType, crimeScene, collectionTime, collectedAt, analysedAt, analysedBy)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                ]],
                kind, key, getEvidenceType(item, kind), data.weaponType, information.crimeScene, information.collectionTime,
                tonumber(data.createdAt), os.time() * 1000, framework.getPlayerName(source)
            )

            -- this analysis is now one of the matches
            caseFile.matches = getCaseFile(kind, key).matches
        end

        logger.log(source, "Evidence analysed", { evidenceType = getEvidenceType(item, kind), key = key })
        TriggerEvent("evidences:evidenceItemAnalysed", source, item)
    end

    return {
        success = true,
        response = {
            evidence = describe(item, kind),
            caseFile = caseFile
        }
    }
end)

Thistle.Callback.Register("evidences:lab:getCaseFile", function(source, arguments)
    if not framework.hasPermission(config.permissions.access, source) then
        return deny()
    end

    arguments = type(arguments) == "table" and arguments or {}
    if not lib.table.contains(kinds, arguments.kind) or type(arguments.key) ~= "string" or #arguments.key < 1 or #arguments.key > 50 then
        return { success = false }
    end

    return { success = true, response = getCaseFile(arguments.kind, arguments.key) }
end)
