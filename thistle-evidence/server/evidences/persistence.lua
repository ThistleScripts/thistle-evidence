-- Evidence survives server restarts (config.persistence):
--   ground evidence: one row per piece, written when it's left and deleted when it's collected, destroyed or expires
--   evidence on vehicles: saved by plate and put back when a vehicle with that plate spawns again
--   evidence on players (bullets, blood): saved by character and put back when they're next on
-- Evidence on props isn't kept (the props don't survive a restart), nor gunshot residue (it washes off in minutes).
-- Collected evidence is in ox_inventory items, which keep it themselves.
local config <const> = require "config"
local database <const> = require "server.database"
local framework <const> = require "server.framework"

local settings <const> = config.persistence or {}
local persistence = { restoring = false }

if not settings.enabled then
    function persistence.groundAdded() end
    function persistence.groundRemoved() end
    function persistence.groundCleared() end
    function persistence.entityChanged() end
    function persistence.playerChanged() end
    return persistence
end

local maxAge <const> = (settings.maxAgeDays or 7) * 86400
local skippedTypes <const> = { gunshot_residue = true }

MySQL.update.await(
    [[
        CREATE TABLE IF NOT EXISTS evidence_ground (
            coordsKey VARCHAR(64) NOT NULL PRIMARY KEY,
            evidenceType VARCHAR(30) NOT NULL,
            owner TEXT NOT NULL,
            x DOUBLE NOT NULL,
            y DOUBLE NOT NULL,
            z DOUBLE NOT NULL,
            metadata LONGTEXT NOT NULL,
            createdAt BIGINT NOT NULL
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]]
)

-- holder is a plate ("vehicle") or a character identifier ("player")
MySQL.update.await(
    [[
        CREATE TABLE IF NOT EXISTS evidence_holders (
            kind ENUM('vehicle', 'player') NOT NULL,
            holder VARCHAR(100) NOT NULL,
            evidence LONGTEXT NOT NULL,
            updatedAt BIGINT NOT NULL,
            PRIMARY KEY (kind, holder)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]]
)

-- JSON can't hold vectors, or tables keyed by vectors (bullet holes) or by -1 (the driver's seat), so every value is
-- written with its type
local function serialize(value)
    local valueType <const> = type(value)

    if valueType == "vector3" then
        return { t = "v3", x = value.x, y = value.y, z = value.z }
    elseif valueType == "vector4" then
        return { t = "v4", x = value.x, y = value.y, z = value.z, w = value.w }
    elseif valueType == "vector2" then
        return { t = "v2", x = value.x, y = value.y }
    elseif valueType == "table" then
        local entries = {}
        for key, entry in pairs(value) do
            entries[#entries + 1] = { k = serialize(key), v = serialize(entry) }
        end
        return { t = "t", e = entries }
    end

    return value
end

local function deserialize(value)
    if type(value) ~= "table" then
        return value
    end

    if value.t == "v3" then
        return vector3(value.x, value.y, value.z)
    elseif value.t == "v4" then
        return vector4(value.x, value.y, value.z, value.w)
    elseif value.t == "v2" then
        return vector2(value.x, value.y)
    elseif value.t == "t" then
        local result = {}
        for _, entry in ipairs(value.e or {}) do
            local key <const> = deserialize(entry.k)
            if key ~= nil then
                result[key] = deserialize(entry.v)
            end
        end
        return result
    end

    return value
end

local function encode(value)
    return json.encode(serialize(value))
end

local function decode(text)
    local success <const>, value <const> = pcall(json.decode, text)
    return success and deserialize(value) or nil
end

local function coordsKey(coords)
    return ("%.3f,%.3f,%.3f"):format(coords.x, coords.y, coords.z)
end

-- Ground evidence

function persistence.groundAdded(evidenceType, owner, coords, metadata)
    if persistence.restoring or skippedTypes[evidenceType] then
        return
    end

    MySQL.insert(
        "INSERT IGNORE INTO evidence_ground (coordsKey, evidenceType, owner, x, y, z, metadata, createdAt) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
        { coordsKey(coords), evidenceType, encode(owner), coords.x, coords.y, coords.z, encode(metadata or {}), tonumber(metadata and metadata.createdAt) or os.time() }
    )
end

function persistence.groundRemoved(coords)
    MySQL.update("DELETE FROM evidence_ground WHERE coordsKey = ?", { coordsKey(coords) })
end

-- All saved ground evidence of one type, or of every type (nil), in one go
---@param evidenceType string?
function persistence.groundCleared(evidenceType)
    if evidenceType then
        MySQL.update("DELETE FROM evidence_ground WHERE evidenceType = ?", { evidenceType })
    else
        MySQL.update("DELETE FROM evidence_ground")
    end
end

-- Vehicles and players: everything they hold is saved together, a moment after it last changed

local evidenceKeys -- the statebag keys, from server.evidences.api (which requires the evidence classes, which require this)

local function getEvidenceKeys()
    if not evidenceKeys then
        evidenceKeys = {}
        for name in pairs(require("server.evidences.api").evidenceTypes) do
            if not skippedTypes[name] then
                evidenceKeys[#evidenceKeys + 1] = ("evidences:%s"):format(name)
            end
        end
    end

    return evidenceKeys
end

local function collect(state)
    local evidence, any = {}, false

    for _, key in ipairs(getEvidenceKeys()) do
        local value <const> = state[key]
        if type(value) == "table" and next(value) then
            evidence[key], any = value, true
        end
    end

    return any and evidence or nil
end

local vehicleCache = {} -- plate -> evidence, so a spawning vehicle doesn't need a query
local pending = {} -- "kind:holder" -> true while a save is waiting

local function getPlate(vehicle)
    local plate <const> = (GetVehicleNumberPlateText(vehicle) or ""):gsub("^%s+", ""):gsub("%s+$", "")
    return plate ~= "" and plate or nil
end

local function save(kind, holder, evidence)
    if evidence then
        MySQL.prepare(
            "INSERT INTO evidence_holders (kind, holder, evidence, updatedAt) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE evidence = VALUES(evidence), updatedAt = VALUES(updatedAt)",
            { kind, holder, encode(evidence), os.time() }
        )
    else
        MySQL.prepare("DELETE FROM evidence_holders WHERE kind = ? AND holder = ?", { kind, holder })
    end
end

-- Waits a moment so a burst of changes (a magazine emptied into a car) is one write
local function saveSoon(kind, holder, read)
    local key <const> = ("%s:%s"):format(kind, holder)
    if pending[key] then
        return
    end

    pending[key] = true
    SetTimeout(2000, function()
        pending[key] = nil

        local found <const>, evidence <const> = read()
        if found then
            if kind == "vehicle" then
                vehicleCache[holder] = evidence
            end
            save(kind, holder, evidence)
        end
    end)
end

---@param entity number The vehicle or prop whose evidence changed
function persistence.entityChanged(entity)
    if persistence.restoring or not DoesEntityExist(entity) or GetEntityType(entity) ~= 2 then
        return
    end

    local plate <const> = getPlate(entity)
    if not plate then
        return
    end

    saveSoon("vehicle", plate, function()
        if not DoesEntityExist(entity) then
            return false -- gone (despawned): keep what was saved
        end
        return true, collect(Entity(entity).state)
    end)
end

local identifiers = {} -- player -> the character identifier their evidence is saved under

---@param playerId number
function persistence.playerChanged(playerId)
    playerId = tonumber(playerId)
    if persistence.restoring or not playerId then
        return
    end

    local identifier <const> = identifiers[playerId] or framework.getIdentifier(playerId)
    if not identifier then
        return
    end

    saveSoon("player", identifier, function()
        if not DoesPlayerExist(playerId) then
            return false
        end
        return true, collect(Player(playerId).state)
    end)
end

-- Puts saved evidence back, keeping anything the holder has picked up since
local function restore(state, evidence)
    persistence.restoring = true

    for key, records in pairs(evidence or {}) do
        local current = state[key] or {}
        local changed = false

        for owner, record in pairs(records) do
            if current[owner] == nil then
                current[owner] = record
                changed = true
            end
        end

        if changed then
            state[key] = current
        end
    end

    persistence.restoring = false
end

CreateThread(function()
    Wait(0) -- every module has loaded
    local oldest <const> = os.time() - maxAge
    MySQL.update.await("DELETE FROM evidence_holders WHERE updatedAt < ?", { oldest })
    MySQL.update.await("DELETE FROM evidence_ground WHERE createdAt < ?", { oldest })

    -- ground evidence
    local api <const> = require "server.evidences.api"
    local rows <const> = database.query("SELECT * FROM evidence_ground")
    local restored = 0

    persistence.restoring = true
    for _, row in ipairs(rows.success and rows.response or {}) do
        local owner <const> = decode(row.owner)
        local object <const> = api.evidenceTypes[row.evidenceType] and owner ~= nil and api.get(row.evidenceType, owner)

        if object then
            local metadata = decode(row.metadata) or {}
            metadata.createdAt = tonumber(row.createdAt)
            object:atCoords(vector3(row.x, row.y, row.z), metadata)
            restored += 1
        end
    end
    persistence.restoring = false

    -- vehicles: put back as they spawn
    local vehicles <const> = database.query("SELECT holder, evidence FROM evidence_holders WHERE kind = 'vehicle'")
    for _, row in ipairs(vehicles.success and vehicles.response or {}) do
        vehicleCache[row.holder] = decode(row.evidence)
    end

    lib.print.info(("Restored %d pieces of ground evidence; %d vehicles have saved evidence"):format(restored, #(vehicles.response or {})))
end)

-- Scripts set a vehicle's plate just after spawning it, so look a moment later
AddEventHandler("entityCreated", function(entity)
    if not DoesEntityExist(entity) or GetEntityType(entity) ~= 2 then
        return
    end

    SetTimeout(1500, function()
        if not DoesEntityExist(entity) then
            return
        end

        local plate <const> = getPlate(entity)
        local evidence <const> = plate and vehicleCache[plate]
        if evidence then
            restore(Entity(entity).state, evidence)
        end
    end)
end)

-- Players: put back once their character is known (the client reports in before a character is picked)
RegisterNetEvent("evidences:playerLoaded", function()
    local playerId <const> = tonumber(source)
    if not playerId then
        return
    end

    CreateThread(function()
        for _ = 1, 120 do -- ten minutes to pick a character
            if not DoesPlayerExist(playerId) then
                return
            end

            local identifier <const> = framework.getIdentifier(playerId)
            if identifier then
                identifiers[playerId] = identifier

                local row <const> = database.selectFirstColumn(
                    "SELECT evidence FROM evidence_holders WHERE kind = 'player' AND holder = ?", identifier
                )
                if row.success and row.response then
                    restore(Player(playerId).state, decode(row.response))
                end
                return
            end

            Wait(5000)
        end
    end)
end)

AddEventHandler("playerDropped", function()
    identifiers[source] = nil
end)

return persistence
