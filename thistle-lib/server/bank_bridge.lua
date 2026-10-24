-- =====================================================================
-- Thistle-Lib · Bank bridge (SERVER)
-- ---------------------------------------------------------------------
-- The routing brain behind Thistle Scripts' bank compatibility layer.
--
-- WHAT IT SOLVES
--   Third-party job / shop / drug / heist scripts are usually hardcoded
--   to a specific banking resource's exports — `exports['qb-banking']:
--   AddMoney(src, 500)` or `exports['Renewed-Banking']:addAccountMoney(
--   'ambulance', 250)`. Server owners who run *only* Thistle-Banking
--   would otherwise have to patch every one of those scripts.
--
--   Instead, we ship tiny compat resources (Thistle-Compat-qb-banking,
--   Thistle-Compat-Renewed-Banking, …) whose folder name matches the
--   vendor script the third party expects. Each compat stub registers
--   the vendor's export signatures, then forwards the call into this
--   bridge, which dispatches to whichever backend registered itself
--   (Thistle-Banking, in practice).
--
--   Direction of travel: 3rd-party script → compat stub exports →
--   Thistle.BankBridge.* → registered backend handlers → real accounts.
--
-- BACKEND CONTRACT
--   A backend (Thistle-Banking) calls `Thistle.BankBridge.SetBackend`
--   at boot with a table of handlers. Any handler left nil transparently
--   falls back to Thistle.Framework (raw core money). All handler args
--   are normalised so backends receive predictable types:
--     playerRef  — always resolved to (src, Player, cid) triple.
--     amount     — always a positive integer.
--     account    — optional string identifier (society name, IBAN, …).
--     reason     — optional string, safe to log verbatim.
--
--   Handlers (all optional):
--     getBalance(src, Player, cid, account) → number
--     addMoney(src, Player, cid, amount, account, reason) → boolean
--     removeMoney(src, Player, cid, amount, account, reason) → boolean
--     getSocietyBalance(account) → number
--     addSocietyMoney(account, amount, reason) → boolean
--     removeSocietyMoney(account, amount, reason) → boolean
--     transfer(fromRef, toRef, amount, reason) → boolean
-- =====================================================================

Thistle = Thistle or {}
Thistle.BankBridge = {}

local backend = {}
local backendMeta = { name = 'thistle-lib.framework-fallback', registeredAt = 0 }

--- Register a banking backend. Repeated calls REPLACE the previous
--- backend — this is intentional so hot-reloading Thistle-Banking works
--- cleanly. Meta info is surfaced via `Thistle.BankBridge.GetBackend()`
--- so consumers can log which script actually handled a transaction.
---@param handlers table   see BACKEND CONTRACT above
---@param name    string?  short label ("Thistle-Banking", "custom")
function Thistle.BankBridge.SetBackend(handlers, name)
    if type(handlers) ~= 'table' then
        print('^1[thistle-lib bank_bridge]^0 SetBackend called with a non-table; ignoring.')
        return
    end
    backend = handlers
    backendMeta = { name = tostring(name or 'unnamed'), registeredAt = os.time() }
    print(('^2[thistle-lib bank_bridge]^0 backend registered by "%s"'):format(backendMeta.name))
end

function Thistle.BankBridge.GetBackend()
    return backendMeta
end

-- =====================================================================
-- Argument normalisation
-- ---------------------------------------------------------------------
-- Vendors are wildly inconsistent about whether they take a source id
-- or a citizen id, whether accounts are named or numeric, etc. We
-- accept both and always hand the backend a full (src, Player, cid)
-- triple so its handlers can pick whichever they prefer.
-- =====================================================================

local function resolvePlayer(ref)
    if not ref then return nil, nil, nil end
    -- Numeric source (net id): typical when called from event handlers.
    if type(ref) == 'number' then
        local P = Thistle.GetPlayerObject and Thistle.GetPlayerObject(ref)
        return ref, P, P and Thistle.GetIdentifier(P) or nil
    end
    -- Numeric-looking string: still treat as source first, fall through.
    if type(ref) == 'string' then
        local n = tonumber(ref)
        if n then
            local P = Thistle.GetPlayerObject and Thistle.GetPlayerObject(n)
            if P then return n, P, Thistle.GetIdentifier(P) end
        end
        -- Otherwise: citizen id.
        local P = Thistle.GetPlayerObjectFromID and Thistle.GetPlayerObjectFromID(ref)
        if P then
            local src = P.PlayerData and P.PlayerData.source or P.source
            return src, P, ref
        end
        return nil, nil, ref
    end
    -- Full Player object handed in directly.
    if type(ref) == 'table' then
        local src = ref.PlayerData and ref.PlayerData.source or ref.source
        return src, ref, Thistle.GetIdentifier and Thistle.GetIdentifier(ref) or nil
    end
    return nil, nil, nil
end

local function toPositiveInt(x)
    local n = tonumber(x)
    if not n or n <= 0 then return nil end
    return math.floor(n)
end

-- =====================================================================
-- Public API — personal balance
-- ---------------------------------------------------------------------
-- These forward to the backend when its handler is set; otherwise fall
-- back to the raw framework balance so a Thistle-less server still
-- works with the compat stubs (players' cash/bank are just qb/esx core
-- accounts).
-- =====================================================================

function Thistle.BankBridge.GetBalance(ref, account)
    local src, P, cid = resolvePlayer(ref)
    if backend.getBalance then
        return tonumber(backend.getBalance(src, P, cid, account)) or 0
    end
    -- Framework fallback: `account` in the fallback path only supports
    -- "cash" / "bank" (raw core money).
    if P and Thistle.GetFunds then
        local funds = Thistle.GetFunds(P)
        if account == 'cash' then return funds.cash or 0 end
        return funds.bank or 0  -- default to bank
    end
    return 0
end

function Thistle.BankBridge.AddMoney(ref, amount, reason, account)
    local amt = toPositiveInt(amount)
    if not amt then return false end
    local src, P, cid = resolvePlayer(ref)
    if backend.addMoney then
        return backend.addMoney(src, P, cid, amt, account, reason) and true or false
    end
    if P and Thistle.AddMoney then
        return Thistle.AddMoney(P, amt, (account == 'cash' and 'cash' or 'bank'), reason)
    end
    return false
end

function Thistle.BankBridge.RemoveMoney(ref, amount, reason, account)
    local amt = toPositiveInt(amount)
    if not amt then return false end
    local src, P, cid = resolvePlayer(ref)
    if backend.removeMoney then
        return backend.removeMoney(src, P, cid, amt, account, reason) and true or false
    end
    if P and Thistle.RemoveMoney then
        return Thistle.RemoveMoney(P, amt, (account == 'cash' and 'cash' or 'bank'), reason)
    end
    return false
end

function Thistle.BankBridge.Transfer(fromRef, toRef, amount, reason)
    local amt = toPositiveInt(amount)
    if not amt then return false end
    if backend.transfer then
        return backend.transfer(fromRef, toRef, amt, reason) and true or false
    end
    -- Fallback: remove from source, add to target. Not atomic; a
    -- production backend should override this.
    if Thistle.BankBridge.RemoveMoney(fromRef, amt, reason, 'bank') then
        if Thistle.BankBridge.AddMoney(toRef, amt, reason, 'bank') then
            return true
        end
        -- Refund on partial failure.
        Thistle.BankBridge.AddMoney(fromRef, amt, ('Refund: ' .. tostring(reason or '')), 'bank')
    end
    return false
end

-- =====================================================================
-- Public API — society / shared accounts
-- ---------------------------------------------------------------------
-- These operate on named accounts (e.g. "police", "ambulance", IBANs).
-- No framework fallback here — if the backend can't service the call,
-- we return false so the caller can react (rather than silently doing
-- nothing on player money).
-- =====================================================================

function Thistle.BankBridge.GetSocietyBalance(account)
    if not account or not backend.getSocietyBalance then return 0 end
    return tonumber(backend.getSocietyBalance(account)) or 0
end

function Thistle.BankBridge.AddSocietyMoney(account, amount, reason)
    local amt = toPositiveInt(amount)
    if not account or type(account) ~= 'string' or account == '' then
        print(('^1[thistle-lib BankBridge]^0 AddSocietyMoney called with bad account: got %s (%s). amount=%s reason=%s — probable colon/dot self-arg mis-strip in the caller.')
            :format(tostring(account), type(account), tostring(amount), tostring(reason)))
        return false
    end
    if not amt then
        print(('^1[thistle-lib BankBridge]^0 AddSocietyMoney called with bad amount: got %s for account "%s". reason=%s.')
            :format(tostring(amount), tostring(account), tostring(reason)))
        return false
    end
    if not backend.addSocietyMoney then
        print(('^1[thistle-lib BankBridge]^0 AddSocietyMoney: no backend registered — call from a vendor script will silently drop. account="%s" amount=%s.')
            :format(tostring(account), tostring(amt)))
        return false
    end
    return backend.addSocietyMoney(account, amt, reason) and true or false
end

function Thistle.BankBridge.RemoveSocietyMoney(account, amount, reason)
    local amt = toPositiveInt(amount)
    if not account or type(account) ~= 'string' or account == '' then
        print(('^1[thistle-lib BankBridge]^0 RemoveSocietyMoney called with bad account: got %s (%s). amount=%s reason=%s — probable colon/dot self-arg mis-strip in the caller.')
            :format(tostring(account), type(account), tostring(amount), tostring(reason)))
        return false
    end
    if not amt then return false end
    if not backend.removeSocietyMoney then return false end
    return backend.removeSocietyMoney(account, amt, reason) and true or false
end

-- =====================================================================
-- Exports — so compat stubs / consumers can call via
-- `exports['thistle-lib']:BankGetBalance(src, 'bank')` too.
--
-- Cross-resource export calling convention in FiveM is inconsistent:
-- - Colon call from another resource → sometimes forwards `self`, sometimes strips it.
-- - Dot call always strips.
-- The `pickArgs` helper detects which case we're in by sniffing the first
-- arg: if it looks like the intended payload, use it; otherwise drop it
-- as a stray `self`. Handlers table sniffing is done by looking for one
-- of the known top-level keys — that catches every real-world caller
-- without false positives on the resource-export proxy table.
-- =====================================================================

-- Colon-call drop: strip a leading FiveM cross-resource exports proxy so
-- both `res:Fn(x)` and `res.Fn(x)` reach the actual handler with the same
-- effective args.
--
-- HISTORY: original heuristic was "non-empty table => real payload, else
-- self". That silently corrupted every export whose first real arg was a
-- string or number, because the fallback `return ...` drops the string.
-- That was the "money movement stopped" bug (Feb 2026) — the vendor
-- proxy stubs pass a string account name first, which was being eaten
-- before it ever reached `Thistle.BankBridge.AddSocietyMoney`.
--
-- CORRECT DETECTION: FiveM's cross-resource `exports` proxy is a table
-- with a metatable (its `__index` dispatches to the actual export by
-- name). Every real payload table passed by callers in this codebase
-- (the BankSetBackend handlers dict, config tables, etc.) is a plain
-- literal table with NO metatable. That gives a bulletproof way to
-- distinguish the two without any type sniffing.
local function stripSelf(a, ...)
    if type(a) == 'table' and getmetatable(a) ~= nil then
        return ...           -- FiveM proxy table → drop, forward the rest.
    end
    return a, ...            -- Everything else (string, number, plain table, nil) → keep.
end

exports('BankSetBackend', function(...)
    local h, n = stripSelf(...)
    return Thistle.BankBridge.SetBackend(h, n)
end)
exports('BankGetBackend', function() return Thistle.BankBridge.GetBackend() end)
exports('BankGetBalance', function(...)
    local r, a = stripSelf(...)
    return Thistle.BankBridge.GetBalance(r, a)
end)
exports('BankAddMoney', function(...)
    local r, a, s, ac = stripSelf(...)
    return Thistle.BankBridge.AddMoney(r, a, s, ac)
end)
exports('BankRemoveMoney', function(...)
    local r, a, s, ac = stripSelf(...)
    return Thistle.BankBridge.RemoveMoney(r, a, s, ac)
end)
exports('BankTransfer', function(...)
    local f, t, a, s = stripSelf(...)
    return Thistle.BankBridge.Transfer(f, t, a, s)
end)
exports('BankGetSocietyBalance', function(...)
    local ac = stripSelf(...)
    return Thistle.BankBridge.GetSocietyBalance(ac)
end)
exports('BankAddSocietyMoney', function(...)
    local ac, a, s = stripSelf(...)
    return Thistle.BankBridge.AddSocietyMoney(ac, a, s)
end)
exports('BankRemoveSocietyMoney', function(...)
    local ac, a, s = stripSelf(...)
    return Thistle.BankBridge.RemoveSocietyMoney(ac, a, s)
end)
