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
local officerPermissions <const> = require "server.permissions"

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

-- Where in a vehicle a piece of evidence was found, for telling the people in it apart (added after the table)
for _, column in ipairs({ "vehicleLocation", "plate" }) do
    local exists <const> = MySQL.scalar.await(
        "SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'forensic_matches' AND COLUMN_NAME = ?",
        { column }
    )

    if tonumber(exists) == 0 then
        MySQL.update.await(("ALTER TABLE forensic_matches ADD COLUMN %s TEXT NULL"):format(column))
    end
end

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

-- How well a sample survived, 0-100: fresh traces are perfect, then they degrade with how long they lay at the scene
-- before being collected (config.evidenceAging). Samples taken straight from a person, and anything collected before
-- this was added, have no collection time and count as perfect.
local function getQuality(item)
    local settings <const> = config.evidenceAging
    local created <const>, collected <const> = tonumber(item.metadata.createdAt), tonumber(item.metadata.collectedAt)
    if not settings or not settings.enabled or not created or not collected then
        return 100
    end

    local ageMinutes <const> = math.max(0, collected - created) / 60
    if ageMinutes <= settings.freshMinutes then
        return 100
    end

    local decay <const> = math.min(1, (ageMinutes - settings.freshMinutes) / math.max(1, settings.worstMinutes - settings.freshMinutes))
    return math.floor(100 - (100 - settings.minimumQuality) * decay + 0.5)
end

-- The first analysis of a sample decides its result: full below its quality, otherwise a partial result or, worse,
-- nothing usable. Partial prints and DNA list a few possible citizens; a partial bullet or casing only gives the weapon.
local function rollResult(quality)
    local roll <const> = math.random(100)
    if roll <= quality then
        return "full"
    end

    return roll <= quality + (100 - quality) * 0.6 and "partial" or "failed"
end

-- Possible matches for a partial print or DNA profile: whoever it really belongs to (when they're on file) among
-- a couple of others on file, in random order. Stored on the item, so looking again shows the same list.
local function pickCandidates(kind, key)
    local candidates = {}

    local owner <const> = database.selectFirstColumn(("SELECT identifier FROM linked_%s WHERE %s = ?"):format(kind, kind), key)
    if owner.success and owner.response then
        candidates[1] = owner.response
    end

    local others <const> = database.query(
        ("SELECT identifier FROM linked_%s WHERE %s <> ? ORDER BY RAND() LIMIT ?"):format(kind, kind),
        key, (config.evidenceAging.partialCandidates or 3) - #candidates
    )
    for _, row in ipairs(others.success and others.response or {}) do
        candidates[#candidates + 1] = row.identifier
    end

    for i = #candidates, 2, -1 do
        local j <const> = math.random(i)
        candidates[i], candidates[j] = candidates[j], candidates[i]
    end

    return candidates
end

local function maskKey(key)
    return #key > 6 and (key:sub(1, 3) .. ("•"):rep(#key - 5) .. key:sub(-2)) or ("•"):rep(#key)
end

-- What the lab shows for one kind of evidence on an item. The key is only sent once the evidence has been analysed.
local function describe(item, kind)
    local data <const> = item.metadata[kind]
    local information <const> = item.metadata.information or {}

    local result <const> = data.result or (data.analysed and "full" or nil) -- analysed before results existed: full

    return {
        kind = kind,
        evidenceType = getEvidenceType(item, kind),
        analysed = data.analysed or false,
        result = result,
        quality = data.quality or getQuality(item),
        key = result == "full" and not isTypeOnly(item, kind) and data.owner or nil,
        partialKey = result == "partial" and kind ~= "ballistics" and maskKey(data.owner) or nil,
        createdAt = item.metadata.createdAt or data.createdAt, -- when the trace was left (a shot, for gunshot residue)
        weaponType = data.weaponType,
        weaponImage = data.weaponImage,
        crimeScene = information.crimeScene or "",
        vehicleLocation = information.vehicleLocation,
        plate = information.plate,
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
    if not framework.hasPermission(config.permissions.access, source) or not officerPermissions.has(source, "microscope") then
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
    if not framework.hasPermission(config.permissions.access, source) or not officerPermissions.has(source, "microscope") then
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

    -- the first analysis settles how much the sample gives up
    local firstAnalysis <const> = not data.analysed
    if firstAnalysis then
        data.quality = typeOnly and 100 or getQuality(item)
        data.result = typeOnly and "full" or rollResult(data.quality)

        if data.result == "partial" and kind ~= "ballistics" then
            data.candidates = pickCandidates(kind, key)
        end
    end

    local result <const> = data.result or "full"
    local caseFile = { kind = kind }
    if result == "full" and not typeOnly then
        caseFile = getCaseFile(kind, key)
    elseif result == "partial" and kind ~= "ballistics" then
        caseFile.candidates = {}
        for _, identifier in ipairs(data.candidates or {}) do
            local citizen <const> = citizens.getCitizen(identifier)
            if citizen and citizen.success and citizen.response then
                caseFile.candidates[#caseFile.candidates + 1] = citizen.response
            end
        end
    end
    caseFile.result = result

    if firstAnalysis then
        data.analysed = true

        local information <const> = item.metadata.information or {}
        if kind == "ballistics" then
            information.weaponType = (caseFile.firearm and caseFile.firearm.label) or data.weaponType
            information.serial = result == "full" and not typeOnly and key or nil
        elseif result == "full" then
            information[kind] = key
        elseif result == "partial" then
            information[kind] = locale("lab_results.partial_information", maskKey(key))
        else
            information[kind] = locale("lab_results.failed_information")
        end

        item.metadata.information = information
        item.metadata.description = createInformation(information)
        exports.ox_inventory:SetMetadata(arguments.inventory, arguments.slot, item.metadata)

        if result == "full" and not typeOnly then
            database.insert(
                [[
                    INSERT INTO forensic_matches (kind, matchKey, evidenceType, weaponType, crimeScene, vehicleLocation, plate, collectionTime, collectedAt, analysedAt, analysedBy)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ]],
                kind, key, getEvidenceType(item, kind), data.weaponType, information.crimeScene, information.vehicleLocation, information.plate, information.collectionTime,
                tonumber(data.createdAt), os.time() * 1000, framework.getPlayerName(source)
            )

            -- this analysis is now one of the matches
            caseFile.matches = getCaseFile(kind, key).matches
        end

        logger.log(source, "Evidence analysed", { evidenceType = getEvidenceType(item, kind), key = key, result = result, quality = data.quality })

        -- A match against a citizen or a registered gun gets its own log, so it can go to a channel detectives watch
        local identified <const> = result == "full" and (caseFile.citizen or caseFile.firearm)
        if identified then
            logger.log(source, "Forensic match", {
                evidence = getEvidenceType(item, kind),
                [kind == "ballistics" and "gunId" or kind] = key,
                identified = caseFile.citizen and caseFile.citizen.fullName or nil,
                firearm = caseFile.firearm and caseFile.firearm.label or nil,
                crimeScene = information.crimeScene,
                foundOn = information.vehicleLocation and ("%s %s"):format(information.vehicleLocation, information.plate or "") or nil,
                linkedEvidence = #(caseFile.matches or {})
            })
        end
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
    if not framework.hasPermission(config.permissions.access, source) or not (officerPermissions.has(source, "microscope") or officerPermissions.has(source, "app_evidence") or officerPermissions.has(source, "app_cases")) then
        return deny()
    end

    arguments = type(arguments) == "table" and arguments or {}
    if not lib.table.contains(kinds, arguments.kind) or type(arguments.key) ~= "string" or #arguments.key < 1 or #arguments.key > 50 then
        return { success = false }
    end

    return { success = true, response = getCaseFile(arguments.kind, arguments.key) }
end)

-- The laptop's evidence log: every analysis, newest first, ten at a time. Analysis itself only happens at a microscope.
Thistle.Callback.Register("evidences:getEvidenceLog", function(source, arguments)
    if not framework.hasPermission(config.permissions.access, source) or not officerPermissions.has(source, "app_evidence") then
        return deny()
    end

    arguments = type(arguments) == "table" and arguments or {}
    local searchText <const> = type(arguments.searchText) == "string" and arguments.searchText:sub(1, 50) or ""
    local offset <const> = math.max(0, math.floor(tonumber(arguments.offset) or 0))
    local pattern <const> = ("%%%s%%"):format(searchText)

    return database.query(
        [[
            SELECT * FROM forensic_matches
            WHERE ? = '' OR matchKey LIKE ? OR crimeScene LIKE ? OR evidenceType LIKE ? OR weaponType LIKE ? OR analysedBy LIKE ?
                OR plate LIKE ?
            ORDER BY analysedAt DESC
            LIMIT 10 OFFSET ?
        ]],
        searchText, pattern, pattern, pattern, pattern, pattern, pattern, offset
    )
end)
