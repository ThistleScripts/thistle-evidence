-- Officer permissions from the evidence admin panel (permissions.lua, html/dui/laptop/src/lab/AdminApp.tsx): which
-- parts of the script each officer may use, on top of the job and grade checks in config.lua.
-- "*" holds what everyone gets; each officer can then be allowed (true) or denied (false) each capability, and
-- anything left unset follows "*".
local framework <const> = require "server.framework"
local database <const> = require "server.database"
local logger <const> = require "server.logger"
local settings <const> = require "permissions"

local permissions = {}

-- In the order the panel shows them
permissions.capabilities = {
    { key = "laptop", group = "laptop" },
    { key = "app_citizens", group = "laptop", needs = "laptop" },
    { key = "app_firearms", group = "laptop", needs = "laptop" },
    { key = "app_evidence", group = "laptop", needs = "laptop" },
    { key = "app_cases", group = "laptop", needs = "laptop" },
    { key = "app_wiretap", group = "laptop", needs = "laptop" },
    { key = "microscope", group = "lab" },
    { key = "collect", group = "field" },
    { key = "swab", group = "field" },
    { key = "fingerprints", group = "field" },
    { key = "uv_flashlight", group = "equipment" },
    { key = "uv_lamps", group = "equipment" },
    { key = "markers", group = "equipment" },
    { key = "lockers", group = "equipment" }
}

local known = {}
for _, capability in ipairs(permissions.capabilities) do
    known[capability.key] = capability
end

MySQL.update.await(
    [[
        CREATE TABLE IF NOT EXISTS evidence_officer_permissions (
            identifier VARCHAR(100) NOT NULL PRIMARY KEY,
            name VARCHAR(100) NOT NULL,
            capabilities TEXT NOT NULL,
            updatedBy VARCHAR(100) NOT NULL,
            updatedAt BIGINT NOT NULL
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]]
)

local rows = {} -- identifier -> { name, capabilities, updatedBy, updatedAt }

-- Only known capabilities, as true or false
local function clean(capabilities)
    local result = {}
    for key, value in pairs(type(capabilities) == "table" and capabilities or {}) do
        if known[key] and type(value) == "boolean" then
            result[key] = value
        end
    end
    return result
end

local function load()
    local result <const> = database.query("SELECT * FROM evidence_officer_permissions")
    rows = {}

    for _, row in ipairs(result.success and result.response or {}) do
        local success <const>, capabilities <const> = pcall(json.decode, row.capabilities)
        rows[row.identifier] = {
            name = row.name,
            capabilities = clean(success and capabilities or {}),
            updatedBy = row.updatedBy,
            updatedAt = tonumber(row.updatedAt)
        }
    end
end

load()

-- What everyone gets: permissions.lua, as changed in the panel
function permissions.getDefaults()
    local defaults = {}
    for _, capability in ipairs(permissions.capabilities) do
        defaults[capability.key] = settings.defaults and settings.defaults[capability.key] == true or false
    end

    for key, value in pairs(rows["*"] and rows["*"].capabilities or {}) do
        defaults[key] = value
    end

    return defaults
end

-- Every capability for a player, true or false
---@param playerId number
---@return table<string, boolean>
function permissions.resolve(playerId)
    local result = {}

    if not settings.enabled then
        for _, capability in ipairs(permissions.capabilities) do
            result[capability.key] = true
        end
        return result
    end

    local defaults <const> = permissions.getDefaults()
    local identifier <const> = framework.getIdentifier(playerId)
    local own <const> = identifier and rows[identifier] and rows[identifier].capabilities or {}

    for _, capability in ipairs(permissions.capabilities) do
        local value = own[capability.key]
        if value == nil then
            value = defaults[capability.key]
        end
        result[capability.key] = value == true
    end

    -- a laptop app is no use without the laptop
    for _, capability in ipairs(permissions.capabilities) do
        if capability.needs and not result[capability.needs] then
            result[capability.key] = false
        end
    end

    return result
end

---@param playerId number
---@param capability string
---@return boolean
function permissions.has(playerId, capability)
    return permissions.resolve(playerId)[capability] == true
end

-- Collecting saliva and gunshot residue takes a swab; everything else at a scene is collecting
local swabTypes <const> = { saliva = true, gunshot_residue = true }

function permissions.canCollect(playerId, evidenceType)
    local capabilities <const> = permissions.resolve(playerId)
    if swabTypes[evidenceType] then
        return capabilities.swab or capabilities.collect
    end
    return capabilities.collect
end

local function isAdmin(playerId)
    local license <const> = Thistle.GetLicense(playerId)
    if not license then
        return false
    end

    local bare <const> = license:gsub("^license:", "")
    for _, admin in ipairs(settings.admins or {}) do
        if type(admin) == "string" and admin:gsub("^license:", "") == bare then
            return true
        end
    end

    return false
end

permissions.isAdmin = isAdmin

-- Tells online players their capabilities changed (client/permissions.lua keeps them for its targets)
local function pushAll()
    for _, playerId in ipairs(GetPlayers()) do
        TriggerClientEvent("evidences:capabilities", tonumber(playerId), permissions.resolve(tonumber(playerId)))
    end
end

Thistle.Callback.Register("evidences:getCapabilities", function(source)
    return permissions.resolve(source)
end)

lib.addCommand("evidenceadmin", {
    help = "Open the evidence admin panel"
}, function(source)
    if source <= 0 then
        return
    end

    if not isAdmin(source) then
        TriggerClientEvent("evidences:notify", source, { key = "laptop.notifications.no_permission" }, "error")
        return
    end

    TriggerClientEvent("evidences:openAdmin", source)
end)

local function adminCallback(name, handler)
    Thistle.Callback.Register(name, function(source, arguments)
        if not isAdmin(source) then
            return { success = false, response = "laptop.notifications.no_permission.description" }
        end

        return handler(source, type(arguments) == "table" and arguments or {})
    end)
end

-- Everything the panel shows: the capabilities, what everyone gets, every officer set up so far, and the officers
-- online now (anyone with the laptop job from config.permissions.access) to add
adminCallback("evidences:admin:get", function()
    local config <const> = require "config"
    local officers, online = {}, {}

    for identifier, row in pairs(rows) do
        if identifier ~= "*" then
            officers[#officers + 1] = {
                identifier = identifier,
                name = row.name,
                capabilities = row.capabilities,
                updatedBy = row.updatedBy,
                updatedAt = (row.updatedAt or 0) * 1000
            }
        end
    end
    table.sort(officers, function(a, b) return a.name:lower() < b.name:lower() end)

    for _, playerId in ipairs(GetPlayers()) do
        playerId = tonumber(playerId)
        if framework.hasPermission(config.permissions.access, playerId) then
            local identifier <const> = framework.getIdentifier(playerId)
            if identifier then
                online[#online + 1] = { identifier = identifier, name = framework.getPlayerName(playerId), serverId = playerId }
            end
        end
    end
    table.sort(online, function(a, b) return a.name:lower() < b.name:lower() end)

    return {
        success = true,
        response = {
            enabled = settings.enabled ~= false,
            capabilities = permissions.capabilities,
            defaults = permissions.getDefaults(),
            officers = officers,
            online = online
        }
    }
end)

-- Saves one officer's capabilities ("*" for everyone). Unset capabilities follow everyone's.
adminCallback("evidences:admin:save", function(source, arguments)
    local identifier <const> = type(arguments.identifier) == "string" and arguments.identifier:sub(1, 100) or nil
    if not identifier or identifier == "" then
        return { success = false }
    end

    local name <const> = identifier == "*" and "Everyone"
        or (type(arguments.name) == "string" and arguments.name:sub(1, 100))
        or (rows[identifier] and rows[identifier].name)
        or identifier
    local capabilities <const> = clean(arguments.capabilities)
    local admin <const> = framework.getPlayerName(source)

    local result <const> = database.update(
        [[
            INSERT INTO evidence_officer_permissions (identifier, name, capabilities, updatedBy, updatedAt) VALUES (?, ?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE name = VALUES(name), capabilities = VALUES(capabilities), updatedBy = VALUES(updatedBy), updatedAt = VALUES(updatedAt)
        ]],
        identifier, name, json.encode(capabilities), admin, os.time()
    )

    if not result.success then
        return { success = false }
    end

    rows[identifier] = { name = name, capabilities = capabilities, updatedBy = admin, updatedAt = os.time() }
    logger.log(source, "Evidence permissions changed", { officer = name, identifier = identifier, capabilities = json.encode(capabilities) })
    pushAll()

    return { success = true }
end)

adminCallback("evidences:admin:remove", function(source, arguments)
    local identifier <const> = type(arguments.identifier) == "string" and arguments.identifier or nil
    if not identifier or identifier == "*" or not rows[identifier] then
        return { success = false }
    end

    database.update("DELETE FROM evidence_officer_permissions WHERE identifier = ?", identifier)
    logger.log(source, "Evidence permissions changed", { officer = rows[identifier].name, identifier = identifier, capabilities = "removed" })
    rows[identifier] = nil
    pushAll()

    return { success = true }
end)

return permissions
