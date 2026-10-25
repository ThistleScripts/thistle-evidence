-- Extra details on a citizen's record, kept for synced and unsynced citizens alike:
--   aliases: other names they've given ("also known as"), found by the citizen search
--   flags: warnings officers put on the record (wanted, armed and dangerous, bail conditions, a note), shown wherever
--          the record comes up as a match: the fingerprint scanner and the forensics lab
local config <const> = require "config"
local framework <const> = require "server.framework"
local database <const> = require "server.database"
local logger <const> = require "server.logger"

local records = {}

records.flagTypes = { "wanted", "armed", "bail", "warning" }

MySQL.update.await(
    [[
        CREATE TABLE IF NOT EXISTS evidence_citizen_aliases (
            id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
            identifier VARCHAR(500) NOT NULL,
            alias VARCHAR(100) NOT NULL,
            addedBy VARCHAR(100) NOT NULL,
            addedAt BIGINT NOT NULL,
            UNIQUE (identifier, alias),
            INDEX (alias)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]]
)

MySQL.update.await(
    [[
        CREATE TABLE IF NOT EXISTS evidence_citizen_flags (
            id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
            identifier VARCHAR(500) NOT NULL,
            flag VARCHAR(20) NOT NULL,
            note VARCHAR(250) NOT NULL DEFAULT '',
            addedBy VARCHAR(100) NOT NULL,
            addedAt BIGINT NOT NULL,
            INDEX (identifier)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]]
)

local function text(value, maxLength)
    if type(value) ~= "string" then
        return nil
    end

    value = value:gsub("^%s+", ""):gsub("%s+$", ""):sub(1, maxLength)
    return value ~= "" and value or nil
end

---@return { id: number, flag: string, note: string, addedBy: string, addedAt: number }[]
function records.getFlags(identifier)
    if not identifier then
        return {}
    end

    local result <const> = database.query("SELECT * FROM evidence_citizen_flags WHERE identifier = ? ORDER BY addedAt DESC", identifier)
    return result.success and result.response or {}
end

-- The flags as short labels for a notification, e.g. "⚠ WANTED, ARMED & DANGEROUS", or "" when there are none
function records.describeFlags(identifier)
    local labels = {}
    for _, flag in ipairs(records.getFlags(identifier)) do
        local label = locale(("records.flags.%s"):format(flag.flag))
        if flag.flag == "warning" and flag.note ~= "" then
            label = ("%s: %s"):format(label, flag.note)
        end
        labels[#labels + 1] = label
    end

    return #labels > 0 and (" ⚠ " .. table.concat(labels, ", ")) or ""
end

-- Identifiers of citizens with an alias like the search text
function records.searchAliases(searchText)
    if not searchText or searchText == "" then
        return {}
    end

    local pattern <const> = "%" .. searchText:sub(1, 25):gsub("\\", "\\\\"):gsub("%%", "\\%%"):gsub("_", "\\_") .. "%"
    local result <const> = database.query("SELECT DISTINCT identifier FROM evidence_citizen_aliases WHERE alias LIKE ? LIMIT 10", pattern)

    local identifiers = {}
    for _, row in ipairs(result.success and result.response or {}) do
        identifiers[#identifiers + 1] = row.identifier
    end
    return identifiers
end

local function register(name, handler)
    Thistle.Callback.Register(name, function(source, arguments)
        if not framework.hasPermission(config.permissions.access, source) then
            return { success = false, response = "laptop.notifications.no_permission.description" }
        end

        return handler(source, type(arguments) == "table" and arguments or {})
    end)
end

-- A record's aliases and flags
register("evidences:records:get", function(_, arguments)
    if type(arguments.identifier) ~= "string" then
        return { success = false }
    end

    local aliases <const> = database.query("SELECT * FROM evidence_citizen_aliases WHERE identifier = ? ORDER BY addedAt", arguments.identifier)

    return {
        success = true,
        response = {
            aliases = aliases.success and aliases.response or {},
            flags = records.getFlags(arguments.identifier)
        }
    }
end)

register("evidences:records:addAlias", function(source, arguments)
    local alias <const> = text(arguments.alias, 100)
    if type(arguments.identifier) ~= "string" or not alias then
        return { success = false }
    end

    local result <const> = database.update(
        "INSERT IGNORE INTO evidence_citizen_aliases (identifier, alias, addedBy, addedAt) VALUES (?, ?, ?, ?)",
        arguments.identifier, alias, framework.getPlayerName(source), os.time() * 1000
    )

    if result.success then
        logger.log(source, "Citizen alias added", { identifier = arguments.identifier, alias = alias })
    end

    return result
end)

register("evidences:records:removeAlias", function(source, arguments)
    local id <const> = tonumber(arguments.id)
    if not id then
        return { success = false }
    end

    logger.log(source, "Citizen alias removed", { id = id })
    return database.update("DELETE FROM evidence_citizen_aliases WHERE id = ?", id)
end)

register("evidences:records:addFlag", function(source, arguments)
    local flag <const> = lib.table.contains(records.flagTypes, arguments.flag) and arguments.flag or nil
    if type(arguments.identifier) ~= "string" or not flag then
        return { success = false }
    end

    local note <const> = text(arguments.note, 250) or ""
    local result <const> = database.insert(
        "INSERT INTO evidence_citizen_flags (identifier, flag, note, addedBy, addedAt) VALUES (?, ?, ?, ?, ?)",
        arguments.identifier, flag, note, framework.getPlayerName(source), os.time() * 1000
    )

    if result.success then
        logger.log(source, "Citizen flagged", { identifier = arguments.identifier, flag = flag, note = note })
    end

    return result
end)

register("evidences:records:removeFlag", function(source, arguments)
    local id <const> = tonumber(arguments.id)
    if not id then
        return { success = false }
    end

    logger.log(source, "Citizen flag removed", { id = id })
    return database.update("DELETE FROM evidence_citizen_flags WHERE id = ?", id)
end)

return records
