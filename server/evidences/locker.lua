-- Evidence lockers (config.evidenceLockers): shared ox_inventory stashes at the station, with a log of everything put
-- in and taken out, by whom and when, so the chain of custody of every piece of evidence can be followed.
local config <const> = require "config"
local framework <const> = require "server.framework"
local database <const> = require "server.database"
local logger <const> = require "server.logger"

local lockers <const> = config.evidenceLockers or {}
local lockerIds = {}

MySQL.update.await(
    [[
        CREATE TABLE IF NOT EXISTS evidence_locker_log (
            id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
            locker VARCHAR(50) NOT NULL,
            action ENUM('deposit', 'withdraw') NOT NULL,
            item VARCHAR(100) NOT NULL,
            label TEXT NULL,
            caseNumber VARCHAR(20) NULL,
            amount INT NOT NULL,
            officer TEXT NOT NULL,
            at BIGINT NOT NULL,
            INDEX (locker, at)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]]
)

for _, locker in ipairs(lockers) do
    exports.ox_inventory:RegisterStash(locker.id, locker.label, locker.slots or 200, locker.weight or 1000000, false,
        locker.groups or config.permissions.access, locker.coords)
    lockerIds[locker.id] = true
end

local function record(source, lockerId, action, item, amount)
    local metadata <const> = item.metadata or {}

    database.insert(
        [[
            INSERT INTO evidence_locker_log (locker, action, item, label, caseNumber, amount, officer, at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ]],
        lockerId, action, item.name, metadata.label or item.label, metadata.caseNumber, amount or item.count or 1,
        framework.getPlayerName(source), os.time() * 1000
    )

    logger.log(source, action == "deposit" and "Evidence locker deposit" or "Evidence locker withdrawal", {
        locker = lockerId,
        item = metadata.label or item.label or item.name,
        caseNumber = metadata.caseNumber,
        amount = amount or item.count or 1
    })
end

-- Every move into or out of a locker is logged. Swapping an item in the locker for one in the player's inventory is
-- both: what goes in and what comes out.
if next(lockerIds) then
    local filter = {}
    for id in pairs(lockerIds) do
        filter[#filter + 1] = ("^%s$"):format(id:gsub("%p", "%%%0"))
    end

    exports.ox_inventory:registerHook("swapItems", function(payload)
        if payload.fromInventory == payload.toInventory then
            return true
        end

        local into <const> = lockerIds[payload.toInventory] and payload.toInventory or nil
        local outOf <const> = lockerIds[payload.fromInventory] and payload.fromInventory or nil

        if into and type(payload.fromSlot) == "table" then
            record(payload.source, into, "deposit", payload.fromSlot, payload.count)
        end

        if outOf and type(payload.fromSlot) == "table" then
            record(payload.source, outOf, "withdraw", payload.fromSlot, payload.count)
        end

        -- a swap brings the locker's item back out
        if into and type(payload.toSlot) == "table" then
            record(payload.source, into, "withdraw", payload.toSlot, payload.toSlot.count)
        end

        return true
    end, { inventoryFilter = filter })
end

Thistle.Callback.Register("evidences:getLockerLog", function(source, lockerId)
    if not lockerIds[lockerId] or not framework.hasPermission(config.permissions.access, source) then
        return {}
    end

    local result <const> = database.query(
        "SELECT * FROM evidence_locker_log WHERE locker = ? ORDER BY at DESC, id DESC LIMIT 40",
        lockerId
    )

    local entries <const> = result.success and result.response or {}
    for _, entry in ipairs(entries) do
        entry.when = os.date("%d/%m/%Y %H:%M", math.floor((tonumber(entry.at) or 0) / 1000)) -- clients have no os.date
    end

    return entries
end)
