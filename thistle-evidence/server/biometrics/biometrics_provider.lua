local database <const> = require "server.database"
local logger <const> = require "server.logger"

local biometricsProvider = {}

local framework <const> = require "server.framework"
local cache = {}

MySQL.update.await(
    [[
        CREATE TABLE IF NOT EXISTS biometric_data (
            identifier VARCHAR(500) PRIMARY KEY NOT NULL,
            fingerprint VARCHAR(16) UNIQUE NOT NULL,
            dna VARCHAR(16) UNIQUE NOT NULL
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]]
)

-- Creates a 16-char fingerprint string
local function createFingerprint(identifier)
    local salt <const> = ("%s_%s"):format(identifier, GetGameTimer())
    local hash1 <const> = joaat("fp_" .. salt)
    local hash2 <const> = joaat("salt_" .. tostring(math.random(1, 1e9)))

    local mask <const> = 0xFFFFFFFF
    return string.format("%08X%08X", hash1 & mask, hash2 & mask)
end

-- Creates a 16-char DNA string
local function createDNA()
    local bases <const> = { "A", "T", "G", "C" }
    local dna = ""

    for i = 1, 16 do
        dna = dna .. bases[math.random(1, #bases)]
    end

    return dna
end

-- Saves new biometric data unless the player already has some. INSERT IGNORE, so a clash (another request saving this
-- player's data first, or a fingerprint or DNA that's already taken) isn't an error.
---@return boolean saved
local function insertBiometricData(identifier, fingerprint, dna)
    local result <const> = database.update("INSERT IGNORE INTO biometric_data (identifier, fingerprint, dna) VALUES (?, ?, ?)", identifier, fingerprint, dna)
    return result.success and (tonumber(result.response) or 0) > 0
end

local function selectBiometricData(identifier)
    local result <const> = database.selectFirstRow("SELECT fingerprint, dna FROM biometric_data WHERE identifier = ?", identifier)
    return result.success and result.response or nil
end

local function loadOrCreate(identifier)
    local existing <const> = selectBiometricData(identifier)
    if existing then
        return existing
    end

    for _ = 1, 5 do
        local fingerprint <const> = createFingerprint(identifier)
        local dna <const> = createDNA()

        if insertBiometricData(identifier, fingerprint, dna) then
            return { fingerprint = fingerprint, dna = dna }
        end

        -- not saved: either someone else saved this player's data first (use theirs), or the fingerprint or DNA
        -- belongs to another player already (try new ones)
        local saved <const> = selectBiometricData(identifier)
        if saved then
            return saved
        end

        Wait(0)
    end
end

local pending = {} -- identifier -> promise, while that player's data is being looked up or created

-- A player's fingerprint and DNA, created the first time they're needed. Getting in a car leaves several prints at
-- once, so requests for a new player arrive together: only the first looks up or creates the data, and the others
-- wait for it, so the player never gets two different fingerprints.
---@param identifier string The frameworks identifier of the player
---@return { fingerprint: string, dna: string }?
local function getBiometricData(identifier)
    if not identifier then
        return nil
    end

    identifier = tostring(identifier)

    if cache[identifier] then
        return cache[identifier]
    end

    if pending[identifier] then
        return Citizen.Await(pending[identifier])
    end

    local request <const> = promise.new()
    pending[identifier] = request

    local success <const>, data <const> = pcall(loadOrCreate, identifier)
    pending[identifier] = nil

    if not success then
        lib.print.error(("Couldn't get the biometric data of %s: %s"):format(identifier, data))
    end

    local result <const> = success and data or nil
    if result then
        cache[identifier] = result
    end

    request:resolve(result)
    return result
end

---@param playerId number The serverId of the player
---@param type? string The biometric data type to return
---@return string|{ fingerprint: string, dna: string }
function biometricsProvider.getBiometricData(playerId, type)
    local identifier <const> = framework.getIdentifier(playerId)
    if identifier then
        local data <const> = getBiometricData(identifier)
        if data then
            return data[type]
        end
    end
end

function biometricsProvider.getFingerprint(playerId)
    return biometricsProvider.getBiometricData(playerId, "fingerprint")
end

exports("getFingerprint", biometricsProvider.getFingerprint)

exports("getDNA", function(playerId)
    return biometricsProvider.getBiometricData(playerId, "dna")
end)

return biometricsProvider