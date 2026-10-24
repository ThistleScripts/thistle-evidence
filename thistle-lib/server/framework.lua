-- =====================================================================
-- Thistle-Lib · Framework bridge (SERVER)
-- ---------------------------------------------------------------------
-- Detects qb-core / qbx / ESX at boot and provides a single set of
-- helpers so consumer scripts don't have to care which framework the
-- server actually runs. Mirror of the historically-battle-tested
-- Thistle-Banking server/framework.lua, minus the banking-specific
-- bank-card / account glue (that belongs in each script).
-- =====================================================================

local Framework = 'unknown'
local QBCore, ESX, Jobs, Gangs = nil, nil, nil, nil
local deadPlayers = {}

-- Public: what framework did we detect?
function Thistle.GetFramework() return Framework end

-- Boot: probe for supported cores. Fatal-log if none — consumers can
-- still load the library, but everything below returns nil.
CreateThread(function()
    if GetResourceState('es_extended') == 'started' then
        Framework = 'esx'
        ESX = exports['es_extended']:getSharedObject()
        if ESX.RefreshJobs then ESX.RefreshJobs() end
        Jobs  = ESX.GetJobs and ESX.GetJobs() or {}
        Gangs = {}
    elseif GetResourceState('qbx_core') == 'started' then
        Framework = 'qbx'
        Jobs  = exports.qbx_core:GetJobs()  or {}
        Gangs = exports.qbx_core:GetGangs() or {}
    elseif GetResourceState('qb-core') == 'started' then
        Framework = 'qb'
        QBCore = exports['qb-core']:GetCoreObject()
        Jobs   = QBCore.Shared.Jobs  or {}
        Gangs  = QBCore.Shared.Gangs or {}
    else
        print('^1[thistle-lib]^0 No supported framework detected (qb-core / qbx_core / es_extended). Consumers will get nil from Thistle.* helpers.')
    end
end)

-- =====================================================================
-- Player lookup
-- =====================================================================

function Thistle.GetPlayerObject(source)
    if Framework == 'qb'  then return QBCore.Functions.GetPlayer(source) end
    if Framework == 'qbx' then return exports.qbx_core:GetPlayer(source) end
    if Framework == 'esx' then return ESX.GetPlayerFromId(source) end
end

function Thistle.GetPlayerObjectFromID(identifier)
    if not identifier then return nil end
    if Framework == 'qb'  then return QBCore.Functions.GetPlayerByCitizenId(tostring(identifier):upper()) end
    if Framework == 'qbx' then return exports.qbx_core:GetPlayerByCitizenId(tostring(identifier):upper()) end
    if Framework == 'esx' then return ESX.GetPlayerFromIdentifier(identifier) end
end

function Thistle.GetIdentifier(Player)
    if not Player then return nil end
    if Framework == 'qb' or Framework == 'qbx' then return Player.PlayerData and Player.PlayerData.citizenid end
    if Framework == 'esx' then return Player.identifier end
end

function Thistle.GetCharacterName(Player)
    if not Player then return nil end
    if Framework == 'qb' or Framework == 'qbx' then
        local ci = Player.PlayerData and Player.PlayerData.charinfo
        if not ci then return nil end
        return ('%s %s'):format(ci.firstname or '?', ci.lastname or '?')
    end
    if Framework == 'esx' then return Player.name end
end

-- =====================================================================
-- Money
-- =====================================================================

function Thistle.GetFunds(Player)
    if not Player then return { cash = 0, bank = 0 } end
    if Framework == 'qb' or Framework == 'qbx' then
        return {
            cash = (Player.PlayerData.money and Player.PlayerData.money.cash) or 0,
            bank = (Player.PlayerData.money and Player.PlayerData.money.bank) or 0,
        }
    end
    if Framework == 'esx' then
        return {
            cash = Player.getAccount('money').money,
            bank = Player.getAccount('bank').money,
        }
    end
    return { cash = 0, bank = 0 }
end

function Thistle.AddMoney(Player, amount, moneyType, comment)
    if not Player or not amount or amount <= 0 then return false end
    moneyType = moneyType or 'cash'
    if Framework == 'qb' or Framework == 'qbx' then
        Player.Functions.AddMoney(moneyType, amount, comment or 'thistle-lib')
        return true
    end
    if Framework == 'esx' then
        local acc = (moneyType == 'bank') and 'bank' or 'money'
        Player.addAccountMoney(acc, amount, comment or 'thistle-lib')
        return true
    end
    return false
end

--- Returns true only if the player actually had the money and it was removed.
function Thistle.RemoveMoney(Player, amount, moneyType, comment)
    if not Player or not amount or amount <= 0 then return false end
    moneyType = moneyType or 'cash'
    if Framework == 'qb' or Framework == 'qbx' then
        local have = Player.Functions.GetMoney(moneyType) or 0
        if have < amount then return false end
        Player.Functions.RemoveMoney(moneyType, amount, comment or 'thistle-lib')
        return true
    end
    if Framework == 'esx' then
        local acc = (moneyType == 'bank') and 'bank' or 'money'
        local have = Player.getAccount(acc).money or 0
        if have < amount then return false end
        Player.removeAccountMoney(acc, amount, comment or 'thistle-lib')
        return true
    end
    return false
end

-- =====================================================================
-- Notifications & misc UX
-- =====================================================================

--- Uses ox_lib notify on the client — matches the pattern the rest of
--- the Thistle scripts use.  `settings` = { title, description, type }.
function Thistle.Notify(src, settings)
    if not src or not settings then return end
    TriggerClientEvent('ox_lib:notify', src, settings)
end

function Thistle.IsDead(Player)
    if not Player then return false end
    if Framework == 'qb' or Framework == 'qbx' then
        return Player.PlayerData and Player.PlayerData.metadata and Player.PlayerData.metadata.isdead or false
    end
    if Framework == 'esx' then return deadPlayers[Player.source] == true end
    return false
end

RegisterNetEvent('esx:onPlayerDeath',  function() deadPlayers[source] = true  end)
RegisterNetEvent('esx:onPlayerSpawn',  function() deadPlayers[source] = nil   end)
AddEventHandler ('esx:playerDropped',  function(id) deadPlayers[id]  = nil    end)

-- =====================================================================
-- Groups (jobs / gangs) — thin wrappers, returns the framework's raw
-- data so consumers can drill into it however they like.
-- =====================================================================

function Thistle.GetJobs(Player)
    if not Player then return { name = nil, grade = nil } end
    if Framework == 'qb' or Framework == 'qbx' then
        return {
            name  = Player.PlayerData.job.name,
            grade = tostring(Player.PlayerData.job.grade.level),
        }
    end
    if Framework == 'esx' then
        return { name = Player.job.name, grade = tostring(Player.job.grade) }
    end
    return { name = nil, grade = nil }
end

function Thistle.GetGang(Player)
    if not Player then return nil end
    if Framework == 'qb' or Framework == 'qbx' then return Player.PlayerData.gang and Player.PlayerData.gang.name end
    return nil
end

--- True when Player currently holds `jobName` at grade ≥ minGrade.
--- If minGrade is nil / 0, any grade counts (just checks employment).
--- Works across qb / qbx / esx.
---@param Player any
---@param jobName string
---@param minGrade number?
---@return boolean
function Thistle.HasJob(Player, jobName, minGrade)
    if not Player or not jobName then return false end
    minGrade = tonumber(minGrade) or 0
    if Framework == 'qb' or Framework == 'qbx' then
        local job = Player.PlayerData and Player.PlayerData.job
        if not job or job.name ~= jobName then return false end
        local grade = tonumber(job.grade and job.grade.level) or 0
        return grade >= minGrade
    end
    if Framework == 'esx' then
        local job = Player.job
        if not job or job.name ~= jobName then return false end
        return (tonumber(job.grade) or 0) >= minGrade
    end
    return false
end

--- True when Player is the boss/owner of `jobName`.
--- Resolution order:
---   1. If minGrade is provided, defers to HasJob(Player, jobName, minGrade).
---   2. Otherwise, uses the framework's native boss flag when available
---      (qb / qbx: `PlayerData.job.isboss`).
---   3. Falls back to "highest grade in Jobs table" so custom job files
---      that don't set isboss still work.
---@param Player any
---@param jobName string
---@param minGrade number?
---@return boolean
function Thistle.IsJobBoss(Player, jobName, minGrade)
    if not Player or not jobName then return false end
    if minGrade then return Thistle.HasJob(Player, jobName, minGrade) end
    if Framework == 'qb' or Framework == 'qbx' then
        local job = Player.PlayerData and Player.PlayerData.job
        if not job or job.name ~= jobName then return false end
        if job.isboss then return true end
        -- Fallback: is this the highest defined grade for the job?
        local def = Jobs and Jobs[jobName]
        if def and def.grades then
            local maxGrade = 0
            for k, _ in pairs(def.grades) do
                local n = tonumber(k) or 0
                if n > maxGrade then maxGrade = n end
            end
            return (tonumber(job.grade and job.grade.level) or 0) >= maxGrade
        end
        return false
    end
    if Framework == 'esx' then
        local job = Player.job
        if not job or job.name ~= jobName then return false end
        local def = Jobs and Jobs[jobName]
        if def and def.grades then
            local maxGrade = 0
            for _, g in pairs(def.grades) do
                local n = tonumber(g.grade) or 0
                if n > maxGrade then maxGrade = n end
            end
            return (tonumber(job.grade) or 0) >= maxGrade
        end
        return false
    end
    return false
end

function Thistle.GetGroups() return Jobs, Gangs end

-- =====================================================================
-- Inventory helpers (ox_inventory > qb-inventory > esx)
-- =====================================================================

function Thistle.HasItem(Player, src, itemName)
    if not itemName then return false end
    if GetResourceState('ox_inventory') == 'started' then
        return (tonumber(exports.ox_inventory:Search(src, 'count', itemName)) or 0) > 0
    end
    if Framework == 'qb' or Framework == 'qbx' then
        if Player and Player.Functions and Player.Functions.GetItemByName then
            local it = Player.Functions.GetItemByName(itemName)
            if it then return (tonumber(it.amount) or tonumber(it.count) or 0) > 0 end
        end
        return false
    end
    if Framework == 'esx' then
        if Player and Player.getInventoryItem then
            local it = Player.getInventoryItem(itemName)
            return it and (tonumber(it.count) or 0) > 0 or false
        end
    end
    return false
end

--- Register a usable item across whichever inventory / core is running.
--- cb signature: function(source, item)
function Thistle.RegisterUsableItem(name, cb)
    if not name or type(cb) ~= 'function' then return false end
    if Framework == 'qb' or Framework == 'qbx' then
        if QBCore and QBCore.Functions and QBCore.Functions.CreateUseableItem then
            QBCore.Functions.CreateUseableItem(name, function(source, item) cb(source, item) end)
            return true
        elseif Framework == 'qbx' then
            -- qbx exposes the same helper via exports on older builds.
            local ok = pcall(function()
                exports.qbx_core:CreateUseableItem(name, function(source, item) cb(source, item) end)
            end)
            return ok
        end
    end
    if Framework == 'esx' then
        if ESX and ESX.RegisterUsableItem then
            ESX.RegisterUsableItem(name, function(source, item) cb(source, item) end)
            return true
        end
    end
    return false
end

-- =====================================================================
-- Online-player helpers
-- =====================================================================

--- Returns { { cid, name }, ... } sorted by name. `excludeCid` skips the
--- caller so they don't appear in their own player picker.
function Thistle.GetAllPlayers(excludeCid)
    local list = {}
    for _, src in ipairs(GetPlayers()) do
        local P = Thistle.GetPlayerObject(tonumber(src))
        if P then
            local cid = Thistle.GetIdentifier(P)
            if cid and cid ~= excludeCid then
                list[#list + 1] = { cid = cid, name = Thistle.GetCharacterName(P) or cid }
            end
        end
    end
    table.sort(list, function(a, b) return (a.name or '') < (b.name or '') end)
    return list
end

-- =====================================================================
-- Account identifiers
-- =====================================================================

--- The player's Rockstar license ('license:…'), which stays the same across
--- characters — use it for staff lists and anything account-wide. Falls
--- back to license2, then any identifier.
---@param src number
---@return string|nil
function Thistle.GetLicense(src)
    if not src then return nil end
    return GetPlayerIdentifierByType(src, 'license')
        or GetPlayerIdentifierByType(src, 'license2')
        or GetPlayerIdentifier(src, 0)
end

-- =====================================================================
-- Export bindings — mirrors the fxmanifest server_exports list so
-- consumers can call `exports['thistle-lib']:GetPlayerObject(src)` as an
-- alternative to using the global. Registered only inside thistle-lib
-- (this file can also be included into a consumer with
-- '@thistle-lib/server/framework.lua'). Arguments go through StripSelf so
-- both `exports.x:fn()` and `exports.x.fn()` call styles work.
-- =====================================================================

if Thistle.IsLibResource() then
    local S = Thistle.StripSelf
    exports('Version',               function() return Thistle.VERSION end)
    exports('GetPlayerObject',       function(...) local src = S(...) return Thistle.GetPlayerObject(src) end)
    exports('GetPlayerObjectFromID', function(...) local id = S(...) return Thistle.GetPlayerObjectFromID(id) end)
    exports('GetIdentifier',         function(...) local P = S(...) return Thistle.GetIdentifier(P) end)
    exports('GetLicense',            function(...) local src = S(...) return Thistle.GetLicense(src) end)
    exports('GetCharacterName',      function(...) local P = S(...) return Thistle.GetCharacterName(P) end)
    exports('GetFunds',              function(...) local P = S(...) return Thistle.GetFunds(P) end)
    exports('AddMoney',              function(...) local P, a, t, c = S(...) return Thistle.AddMoney(P, a, t, c) end)
    exports('RemoveMoney',           function(...) local P, a, t, c = S(...) return Thistle.RemoveMoney(P, a, t, c) end)
    exports('Notify',                function(...) local src, opts = S(...) return Thistle.Notify(src, opts) end)
    exports('HasItem',               function(...) local P, src, n = S(...) return Thistle.HasItem(P, src, n) end)
    exports('RegisterUsableItem',    function(...) local name, cb = S(...) return Thistle.RegisterUsableItem(name, cb) end)
    exports('GetAllPlayers',         function(...) local exclude = S(...) return Thistle.GetAllPlayers(exclude) end)
    exports('FormatMoney',           function(...) local n, preset, sym = S(...) return Thistle.Region.money(n, preset, sym) end)
end
