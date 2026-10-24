-- =====================================================================
-- Thistle-Lib · Inventory helpers (SERVER)
-- ---------------------------------------------------------------------
-- Extends the existing Thistle.HasItem with count / remove helpers that
-- resolve through ox_inventory when it's running, or the framework's
-- native inventory otherwise. Consumers should NEVER call
-- exports.ox_inventory:… directly — go through here so the transport
-- stays swappable and every write is logged consistently.
-- =====================================================================

Thistle = Thistle or {}
Thistle.Inventory = Thistle.Inventory or {}

local function oxRunning()
    return GetResourceState('ox_inventory') == 'started'
end

--- Get the total count of `itemName` on the source's person.
---@param src number
---@param itemName string
---@return number
function Thistle.Inventory.GetCount(src, itemName)
    if not src or not itemName then return 0 end
    if oxRunning() then
        return tonumber(exports.ox_inventory:Search(src, 'count', itemName)) or 0
    end
    local Player = Thistle.GetPlayerObject and Thistle.GetPlayerObject(src)
    if not Player then return 0 end
    local fw = Thistle.GetFramework and Thistle.GetFramework() or 'unknown'
    if fw == 'qb' or fw == 'qbx' then
        if Player.Functions and Player.Functions.GetItemByName then
            local it = Player.Functions.GetItemByName(itemName)
            if it then return tonumber(it.amount) or tonumber(it.count) or 0 end
        end
        return 0
    end
    if fw == 'esx' then
        if Player.getInventoryItem then
            local it = Player.getInventoryItem(itemName)
            return it and (tonumber(it.count) or 0) or 0
        end
    end
    return 0
end

--- Remove `count` of `itemName` from the source. Returns true only when
--- the removal succeeded — callers can use this as an atomic guard.
--- Under ox_inventory, RemoveItem returns a boolean directly; under qb
--- / esx it doesn't, so we bracket the call with a pre-check.
---@param src number
---@param itemName string
---@param count number
---@return boolean
function Thistle.Inventory.RemoveItem(src, itemName, count)
    if not src or not itemName then return false end
    count = tonumber(count) or 0
    if count <= 0 then return false end
    if oxRunning() then
        local ok = exports.ox_inventory:RemoveItem(src, itemName, count)
        return ok and true or false
    end
    local have = Thistle.Inventory.GetCount(src, itemName)
    if have < count then return false end
    local Player = Thistle.GetPlayerObject and Thistle.GetPlayerObject(src)
    if not Player then return false end
    local fw = Thistle.GetFramework and Thistle.GetFramework() or 'unknown'
    if fw == 'qb' or fw == 'qbx' then
        if Player.Functions and Player.Functions.RemoveItem then
            return Player.Functions.RemoveItem(itemName, count) and true or false
        end
    end
    if fw == 'esx' then
        if Player.removeInventoryItem then
            Player.removeInventoryItem(itemName, count)
            return true
        end
    end
    return false
end

--- Add `count` of `itemName` to the source. Best-effort across inventories.
---@param src number
---@param itemName string
---@param count number
---@return boolean
function Thistle.Inventory.AddItem(src, itemName, count)
    if not src or not itemName then return false end
    count = tonumber(count) or 0
    if count <= 0 then return false end
    if oxRunning() then
        local ok = exports.ox_inventory:AddItem(src, itemName, count)
        return ok and true or false
    end
    local Player = Thistle.GetPlayerObject and Thistle.GetPlayerObject(src)
    if not Player then return false end
    local fw = Thistle.GetFramework and Thistle.GetFramework() or 'unknown'
    if fw == 'qb' or fw == 'qbx' then
        if Player.Functions and Player.Functions.AddItem then
            return Player.Functions.AddItem(itemName, count) and true or false
        end
    end
    if fw == 'esx' then
        if Player.addInventoryItem then
            Player.addInventoryItem(itemName, count)
            return true
        end
    end
    return false
end

local function coreItems()
    local fw = Thistle.GetFramework and Thistle.GetFramework() or 'unknown'
    if (fw == 'qb' or fw == 'qbx') and GetResourceState('qb-core') == 'started' then
        local ok, core = pcall(function() return exports['qb-core']:GetCoreObject() end)
        return ok and core and core.Shared and core.Shared.Items or {}
    end
    if fw == 'esx' then
        local ok, ESX = pcall(function() return exports['es_extended']:getSharedObject() end)
        if not ok or not ESX then return {} end
        return (ESX.GetItems and ESX.GetItems()) or ESX.Items or {}
    end
    return {}
end

--- Every item the server has registered, sorted by name.
---@return { name: string, label: string }[]
function Thistle.Inventory.ListItems()
    local defs = oxRunning() and (exports.ox_inventory:Items() or {}) or coreItems()
    local list = {}
    for name, def in pairs(defs) do
        if type(name) == 'string' then
            list[#list + 1] = { name = name, label = type(def) == 'table' and def.label or name }
        end
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

--- What the source is carrying: one entry per item name with its total count.
---@param src number
---@return { name: string, count: number }[]
function Thistle.Inventory.GetItems(src)
    local slots
    if oxRunning() then
        slots = exports.ox_inventory:GetInventoryItems(src)
    else
        local Player = Thistle.GetPlayerObject and Thistle.GetPlayerObject(src)
        if not Player then return {} end
        if Player.PlayerData then slots = Player.PlayerData.items
        elseif Player.getInventory then slots = Player.getInventory(true) end
    end
    local totals = {}
    for k, it in pairs(slots or {}) do
        local name = type(it) == 'table' and it.name or (type(k) == 'string' and k)
        local n = type(it) == 'table' and (tonumber(it.count) or tonumber(it.amount)) or tonumber(it)
        if name and n and n > 0 then totals[name] = (totals[name] or 0) + n end
    end
    local list = {}
    for name, n in pairs(totals) do list[#list + 1] = { name = name, count = n } end
    return list
end
