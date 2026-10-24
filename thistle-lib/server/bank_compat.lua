-- =====================================================================
-- Thistle-Lib · Bank compat (SERVER)
-- ---------------------------------------------------------------------
-- Impersonates popular banking-resource exports IN-PROCESS so that
-- third-party scripts hardcoded against qb-banking / Renewed-Banking /
-- okokBanking / wasabi_banking Just Work when the only banking resource
-- on the server is Thistle-Banking.
--
-- HOW THE TRICK WORKS
--   FiveM's `exports['<res>']:<name>(...)` is sugar over a global event
--   named `__cfx_export_<res>_<name>`. Whoever registers a handler for
--   that event serves the call — the handler does NOT need to live in
--   a resource literally named `<res>`. That means we can register
--   every vendor's export signatures right here in thistle-lib and
--   every 3rd-party script's calls end up in Thistle.BankBridge, which
--   dispatches to Thistle-Banking.
--
--   No separate compat resources. No renaming folders. One file.
--
-- COEXISTENCE
--   If the real vendor resource is actually installed and started, we
--   skip impersonating its exports — otherwise two handlers respond to
--   the same event and the caller gets whichever registered last, which
--   is unpredictable.
--
-- IMPORTANT — SIGNATURES MATTER
--   Every vendor's exports have wildly different arg orders and
--   semantics. e.g. qb-banking's `AddMoney(accountName, amount, reason)`
--   is ACCOUNT-based, while wasabi's `AddMoney(type, accountID, amount)`
--   is polymorphic. Signatures here mirror each vendor's official docs
--   verbatim so 3rd-party scripts don't need any modification.
-- =====================================================================

Thistle = Thistle or {}
Thistle.BankCompat = { active = {} }

local function registerImpersonatedExport(vendor, name, fn)
    -- FiveM's export event convention. `exports['<vendor>']:<name>(...)`
    -- triggers `__cfx_export_<vendor>_<name>` and expects the handler
    -- to call `setCB(callback)` with the function that services the call.
    AddEventHandler(('__cfx_export_%s_%s'):format(vendor, name), function(setCB)
        setCB(fn)
    end)
end

local function shouldImpersonate(vendor)
    local state = GetResourceState(vendor)
    if state == 'started' or state == 'starting' then
        print(('^3[thistle-lib bank_compat]^0 real "%s" resource is %s — skipping impersonation.')
            :format(vendor, state))
        return false
    end
    return true
end

-- =====================================================================
-- Vendor: qb-banking
-- ---------------------------------------------------------------------
-- IMPORTANT: qb-banking's AddMoney / RemoveMoney are SOCIETY/ACCOUNT-based,
-- not player-based. First arg is an account name like "police" or "ambulance".
-- Player personal-bank money is manipulated via qb-core directly, not through
-- qb-banking exports. Our impersonation mirrors this exactly.
-- =====================================================================

local function installQbBanking()
    local V = 'qb-banking'
    if not shouldImpersonate(V) then return end

    --- AddMoney(accountName, amount, reason) — society/shared account add.
    registerImpersonatedExport(V, 'AddMoney', function(accountName, amount, reason)
        return Thistle.BankBridge.AddSocietyMoney(accountName, amount, reason or 'qb-banking:AddMoney')
    end)

    --- RemoveMoney(accountName, amount, reason) — returns false when insufficient funds.
    registerImpersonatedExport(V, 'RemoveMoney', function(accountName, amount, reason)
        return Thistle.BankBridge.RemoveSocietyMoney(accountName, amount, reason or 'qb-banking:RemoveMoney')
    end)

    --- GetAccountBalance(accountName) → number
    registerImpersonatedExport(V, 'GetAccountBalance', function(accountName)
        return Thistle.BankBridge.GetSocietyBalance(accountName)
    end)

    --- GetAccount(accountName) → table | nil
    --- qb-banking returns a full account descriptor. We fake the shape so
    --- consumers that iterate `for _, info in pairs(acc) do` still work.
    registerImpersonatedExport(V, 'GetAccount', function(accountName)
        if not accountName then return nil end
        local bal = Thistle.BankBridge.GetSocietyBalance(accountName)
        if bal == 0 and Thistle.BankBridge.GetBackend().name == 'thistle-lib.framework-fallback' then
            return nil
        end
        return { {
            account_name    = accountName,
            account_balance = bal,
            account_type    = 'job',  -- best-effort; caller usually only reads balance
        } }
    end)

    --- CreateJobAccount(accountName, accountBalance) → nil
    --- Thistle-Banking auto-creates society accounts on first-open, so we
    --- forward to its own export where possible.
    registerImpersonatedExport(V, 'CreateJobAccount', function(accountName, accountBalance)
        if exports['Thistle-Banking'] then
            local ok = pcall(function() exports['Thistle-Banking']:CreateJobAccount(accountName) end)
            if ok and accountBalance and accountBalance > 0 then
                Thistle.BankBridge.AddSocietyMoney(accountName, accountBalance, 'qb-banking:CreateJobAccount seed')
            end
            return ok
        end
        return false
    end)

    --- CreateGangAccount(accountName, accountBalance) → nil
    registerImpersonatedExport(V, 'CreateGangAccount', function(accountName, accountBalance)
        if exports['Thistle-Banking'] then
            local ok = pcall(function() exports['Thistle-Banking']:CreateJobAccount(accountName) end)
            if ok and accountBalance and accountBalance > 0 then
                Thistle.BankBridge.AddSocietyMoney(accountName, accountBalance, 'qb-banking:CreateGangAccount seed')
            end
            return ok
        end
        return false
    end)

    --- CreatePlayerAccount(playerId, accountName, accountBalance, accountUsers)
    --- qb-banking's "shared account" concept maps 1:1 to Thistle-Banking's
    --- shared/society accounts. Full parity requires reading the users list
    --- and adding them as members; we forward via Thistle exports when the
    --- helpers exist and best-effort otherwise.
    registerImpersonatedExport(V, 'CreatePlayerAccount', function(playerId, accountName, accountBalance, accountUsers)
        if not exports['Thistle-Banking'] then return false end
        local ok = pcall(function() exports['Thistle-Banking']:CreateJobAccount(accountName) end)
        if not ok then return false end
        if accountBalance and accountBalance > 0 then
            Thistle.BankBridge.AddSocietyMoney(accountName, accountBalance, 'qb-banking:CreatePlayerAccount seed')
        end
        -- accountUsers is either a JSON string or a table; parse either.
        local users = accountUsers
        if type(users) == 'string' then
            local decoded = pcall(function() users = json.decode(users) end)
            if not decoded then users = nil end
        end
        if type(users) == 'table' then
            for _, cid in ipairs(users) do
                pcall(function() exports['Thistle-Banking']:addAccountMember(accountName, cid) end)
            end
        end
        return true
    end)

    --- CreateBankStatement(playerId, account, amount, reason, statementType, accountType)
    --- qb-banking's audit-log helper. Forward to Thistle-Banking's
    --- handleTransaction export so the row shows up in-UI.
    registerImpersonatedExport(V, 'CreateBankStatement', function(playerId, account, amount, reason, statementType, accountType)
        if not exports['Thistle-Banking'] then return false end
        local ok = pcall(function()
            exports['Thistle-Banking']:handleTransaction(
                account, account, amount, reason or 'qb-banking:CreateBankStatement',
                tostring(playerId or 'external'), account,
                (statementType == 'withdraw') and 'withdraw' or 'deposit'
            )
        end)
        return ok
    end)

    Thistle.BankCompat.active[V] = true
end

-- =====================================================================
-- Vendor: Renewed-Banking
-- ---------------------------------------------------------------------
-- Renewed-Banking is the resource Thistle-Banking was forked from, so
-- these exports are essentially 1:1 mappings. Signatures verbatim from
-- the Renewed-Banking docs.
-- =====================================================================

local function installRenewedBanking()
    local V = 'Renewed-Banking'
    if not shouldImpersonate(V) then return end

    --- getAccountMoney(account) → number | false
    registerImpersonatedExport(V, 'getAccountMoney', function(account)
        if not account then return false end
        return Thistle.BankBridge.GetSocietyBalance(account)
    end)

    --- addAccountMoney(account, amount) → boolean
    registerImpersonatedExport(V, 'addAccountMoney', function(account, amount)
        local ok = Thistle.BankBridge.AddSocietyMoney(account, amount, 'Renewed-Banking:addAccountMoney')
        if not ok then
            -- Silently returning false is exactly why "the mechanic script
            -- doesn't pay my society" bugs are painful — log the miss so
            -- server owners can see the account name their vendor script
            -- is trying to credit, then map it to their real Thistle-
            -- Banking cachedAccounts key.
            print(('^3[thistle-lib bank_compat]^0 Renewed-Banking:addAccountMoney FAILED — account "%s" not found in the registered backend. Passed amount: %s. Check that your job/society name matches the Thistle-Banking account id.'):format(tostring(account), tostring(amount)))
        end
        return ok
    end)

    --- removeAccountMoney(account, amount) → boolean
    registerImpersonatedExport(V, 'removeAccountMoney', function(account, amount)
        local ok = Thistle.BankBridge.RemoveSocietyMoney(account, amount, 'Renewed-Banking:removeAccountMoney')
        if not ok then
            print(('^3[thistle-lib bank_compat]^0 Renewed-Banking:removeAccountMoney FAILED — account "%s" not found or insufficient funds. Passed amount: %s.'):format(tostring(account), tostring(amount)))
        end
        return ok
    end)

    --- handleTransaction(account, title, amount, message, issuer, receiver, type, transID)
    --- Thistle-Banking already publishes an identically-named export at
    --- resource level, but 3rd-party scripts reach for it via the
    --- Renewed-Banking name. Forward to Thistle-Banking's native export.
    registerImpersonatedExport(V, 'handleTransaction', function(account, title, amount, message, issuer, receiver, ttype, transID)
        if not exports['Thistle-Banking'] then return nil end
        local ok, res = pcall(function()
            return exports['Thistle-Banking']:handleTransaction(
                account, title, amount, message, issuer, receiver, ttype, transID)
        end)
        return ok and res or nil
    end)

    --- CreateJobAccount(job, initialBalance)
    --- job is a table { name, label }; initialBalance is a number.
    registerImpersonatedExport(V, 'CreateJobAccount', function(job, initialBalance)
        if not exports['Thistle-Banking'] then return nil end
        local jobName = (type(job) == 'table') and job.name or tostring(job)
        local ok = pcall(function() exports['Thistle-Banking']:CreateJobAccount(jobName) end)
        if ok and initialBalance and initialBalance > 0 then
            Thistle.BankBridge.AddSocietyMoney(jobName, initialBalance, 'Renewed-Banking:CreateJobAccount seed')
        end
        return ok and { name = jobName } or nil
    end)

    Thistle.BankCompat.active[V] = true
end

-- =====================================================================
-- Vendor: okokBanking (both legacy V1 and V2)
-- ---------------------------------------------------------------------
-- IMPORTANT: okok's GetAccount / AddMoney / RemoveMoney are
-- SOCIETY-based, not player-based. First arg is the society/account
-- identifier. V2 also adds transaction-log helpers.
-- =====================================================================

local function installOkokBanking()
    local V = 'okokBanking'
    if not shouldImpersonate(V) then return end

    --- GetAccount(society) → number
    registerImpersonatedExport(V, 'GetAccount', function(society)
        return Thistle.BankBridge.GetSocietyBalance(society)
    end)

    --- AddMoney(society, value) → boolean
    registerImpersonatedExport(V, 'AddMoney', function(society, value)
        return Thistle.BankBridge.AddSocietyMoney(society, value, 'okokBanking:AddMoney')
    end)

    --- RemoveMoney(society, value) → boolean
    registerImpersonatedExport(V, 'RemoveMoney', function(society, value)
        return Thistle.BankBridge.RemoveSocietyMoney(society, value, 'okokBanking:RemoveMoney')
    end)

    --- V2: AddTransaction(citizenid, transactionData, source?) — audit-only.
    --- Forward to Thistle-Banking's handleTransaction where possible so
    --- the row lands in-UI too.
    registerImpersonatedExport(V, 'AddTransaction', function(citizenid, transactionData, source)
        if not exports['Thistle-Banking'] or type(transactionData) ~= 'table' then return false end
        local ok = pcall(function()
            exports['Thistle-Banking']:handleTransaction(
                citizenid,
                citizenid,
                tonumber(transactionData.value) or 0,
                transactionData.reason or 'okokBanking:AddTransaction',
                transactionData.sender_name or 'External',
                transactionData.receiver_name or citizenid,
                (transactionData.type == 'withdraw' or transactionData.type == 'sent') and 'withdraw' or 'deposit'
            )
        end)
        return ok
    end)

    --- V2: GetPlayerTransactions(citizenid, limit?) → table
    --- Thistle-Banking exposes getAccountTransactions; forward and slice.
    registerImpersonatedExport(V, 'GetPlayerTransactions', function(citizenid, limit)
        if not exports['Thistle-Banking'] then return {} end
        local rows = {}
        pcall(function() rows = exports['Thistle-Banking']:getAccountTransactions(citizenid) or {} end)
        if type(limit) == 'number' and limit >= 0 then
            local sliced = {}
            for i = 1, math.min(limit, #rows) do sliced[i] = rows[i] end
            return sliced
        end
        return rows
    end)

    Thistle.BankCompat.active[V] = true
end

-- =====================================================================
-- Vendor: wasabi_banking (Complete Banking)
-- ---------------------------------------------------------------------
-- wasabi's API is polymorphic: `type` is the first arg on AddMoney /
-- RemoveMoney / GetAccountBalance and dictates which real account is
-- touched. Values:
--   'bank'    — player's bank money (accountID = source or citizenID)
--   'cash'    — player's cash on hand
--   'society' — society/job account (accountID = society name)
--   'shared'  — shared/joint account (accountID = shared account id)
--   'savings' — savings account. Thistle doesn't support savings — we
--              return false and print a one-time warning so consumers
--              can see the gap. Left explicit rather than silent.
-- =====================================================================

local function installWasabiBanking()
    local V = 'wasabi_banking'
    if not shouldImpersonate(V) then return end

    local warnedSavings = false
    local function warnSavings()
        if warnedSavings then return end
        warnedSavings = true
        print('^3[thistle-lib bank_compat]^0 wasabi_banking savings accounts are not supported by Thistle-Banking. Savings ops will return false.')
    end

    --- AddMoney(type, accountID, amount, source?) → boolean
    registerImpersonatedExport(V, 'AddMoney', function(atype, accountID, amount, source)
        if atype == 'bank' or atype == 'cash' then
            return Thistle.BankBridge.AddMoney(source or accountID, amount,
                'wasabi_banking:AddMoney', atype)
        elseif atype == 'society' or atype == 'shared' then
            return Thistle.BankBridge.AddSocietyMoney(accountID, amount,
                'wasabi_banking:AddMoney/' .. atype)
        elseif atype == 'savings' then
            warnSavings()
            return false
        end
        return false
    end)

    --- RemoveMoney(type, accountID, amount, source?) → boolean
    registerImpersonatedExport(V, 'RemoveMoney', function(atype, accountID, amount, source)
        if atype == 'bank' or atype == 'cash' then
            return Thistle.BankBridge.RemoveMoney(source or accountID, amount,
                'wasabi_banking:RemoveMoney', atype)
        elseif atype == 'society' or atype == 'shared' then
            return Thistle.BankBridge.RemoveSocietyMoney(accountID, amount,
                'wasabi_banking:RemoveMoney/' .. atype)
        elseif atype == 'savings' then
            warnSavings()
            return false
        end
        return false
    end)

    --- GetAccountBalance(accountID, type) → number | false
    registerImpersonatedExport(V, 'GetAccountBalance', function(accountID, atype)
        if atype == 'bank' then
            return Thistle.BankBridge.GetBalance(accountID, 'bank')
        elseif atype == 'society' or atype == 'shared' then
            return Thistle.BankBridge.GetSocietyBalance(accountID)
        elseif atype == 'savings' then
            warnSavings()
            return false
        end
        return false
    end)

    --- CreateJobAccount(jobName, balance) → boolean
    registerImpersonatedExport(V, 'CreateJobAccount', function(jobName, balance)
        if not exports['Thistle-Banking'] then return false end
        local ok = pcall(function() exports['Thistle-Banking']:CreateJobAccount(jobName) end)
        if ok and balance and balance > 0 then
            Thistle.BankBridge.AddSocietyMoney(jobName, balance, 'wasabi_banking:CreateJobAccount seed')
        end
        return ok
    end)

    --- Transaction(identifier, reason, amount, type, account) → boolean
    --- Audit-log helper. `type` here is 'deposit' | 'sent'. `account`
    --- is 'personal' | 'savings' | 'society'.
    registerImpersonatedExport(V, 'Transaction', function(identifier, reason, amount, ttype, account)
        if not exports['Thistle-Banking'] then return false end
        if account == 'savings' then warnSavings(); return false end
        local direction = (ttype == 'sent' or ttype == 'withdraw') and 'withdraw' or 'deposit'
        local ok = pcall(function()
            exports['Thistle-Banking']:handleTransaction(
                identifier, identifier, tonumber(amount) or 0, reason or 'wasabi_banking:Transaction',
                'External', identifier, direction)
        end)
        return ok
    end)

    --- GetPlayerAccounts(source) → table
    --- Best-effort passthrough; Thistle-Banking doesn't currently
    --- distinguish savings vs shared account types the same way wasabi
    --- does, so we return an empty list rather than lie about shapes.
    registerImpersonatedExport(V, 'GetPlayerAccounts', function(_source)
        return {}
    end)

    --- Savings / shared-account helpers wasabi ships that don't map onto
    --- Thistle-Banking. We stub them so calls don't error, but return false.
    registerImpersonatedExport(V, 'createSavingsAccount',        function() warnSavings(); return false end)
    registerImpersonatedExport(V, 'createSharedAccount',         function() return false end)
    registerImpersonatedExport(V, 'removeUserFromSharedAccount', function() return false end)
    registerImpersonatedExport(V, 'hireUserToSharedAccount',     function() return false end)

    Thistle.BankCompat.active[V] = true
end

-- =====================================================================
-- Vendor: fd_banking
-- ---------------------------------------------------------------------
-- Society-focused with the qb-management-equivalent block being the
-- one 3rd parties reach for most. The invoice / transfer / account-
-- lookup helpers are more specialised — we forward what maps cleanly
-- onto Thistle-Banking and return nil/false for what doesn't.
-- =====================================================================

local function installFdBanking()
    local V = 'fd_banking'
    if not shouldImpersonate(V) then return end

    -- qb-management-equivalent block (verbatim signatures from docs) --

    --- GetAccount(society) → number
    registerImpersonatedExport(V, 'GetAccount', function(society)
        return Thistle.BankBridge.GetSocietyBalance(society)
    end)

    --- GetGangAccount(gang) → number
    registerImpersonatedExport(V, 'GetGangAccount', function(gang)
        return Thistle.BankBridge.GetSocietyBalance(gang)
    end)

    --- AddMoney(society, amount, reason) → boolean
    registerImpersonatedExport(V, 'AddMoney', function(society, amount, reason)
        return Thistle.BankBridge.AddSocietyMoney(society, amount, reason or 'fd_banking:AddMoney')
    end)

    --- AddGangMoney(gang, amount, reason) → boolean
    registerImpersonatedExport(V, 'AddGangMoney', function(gang, amount, reason)
        return Thistle.BankBridge.AddSocietyMoney(gang, amount, reason or 'fd_banking:AddGangMoney')
    end)

    --- RemoveMoney(society, amount, reason) → boolean
    registerImpersonatedExport(V, 'RemoveMoney', function(society, amount, reason)
        return Thistle.BankBridge.RemoveSocietyMoney(society, amount, reason or 'fd_banking:RemoveMoney')
    end)

    --- RemoveGangMoney(gang, amount, reason) → boolean
    registerImpersonatedExport(V, 'RemoveGangMoney', function(gang, amount, reason)
        return Thistle.BankBridge.RemoveSocietyMoney(gang, amount, reason or 'fd_banking:RemoveGangMoney')
    end)

    -- Account-lookup helpers ------------------------------------------

    --- getPersonalAccount(identifier) → table | nil
    --- Best-effort account descriptor built from Thistle player data.
    registerImpersonatedExport(V, 'getPersonalAccount', function(identifier)
        if not identifier then return nil end
        local Player = Thistle.GetPlayerObjectFromID and Thistle.GetPlayerObjectFromID(identifier)
        if not Player then return nil end
        local funds = Thistle.GetFunds and Thistle.GetFunds(Player) or {}
        return {
            id       = identifier,
            balance  = funds.bank or 0,
            type     = 'personal',
            ownerId  = identifier,
        }
    end)

    --- getBusinessAccount(business) → table | nil
    registerImpersonatedExport(V, 'getBusinessAccount', function(business)
        local bal = Thistle.BankBridge.GetSocietyBalance(business)
        if bal == 0 and Thistle.BankBridge.GetBackend().name == 'thistle-lib.framework-fallback' then
            return nil
        end
        return { id = business, balance = bal, type = 'business', ownerId = business }
    end)

    --- getAccountById(id) / getAccountByIban(iban) → table | nil
    --- Thistle-Banking uses account ids interchangeably with IBANs, so
    --- we try the same lookup path for both.
    local function accountByRef(ref)
        if not ref then return nil end
        local bal = Thistle.BankBridge.GetSocietyBalance(ref)
        if bal ~= 0 or Thistle.BankBridge.GetBackend().name ~= 'thistle-lib.framework-fallback' then
            return { id = ref, iban = ref, balance = bal, type = 'business' }
        end
        return nil
    end
    registerImpersonatedExport(V, 'getAccountById',   function(id)   return accountByRef(id)   end)
    registerImpersonatedExport(V, 'getAccountByIban', function(iban) return accountByRef(iban) end)

    --- getAccountOwner(account) → string | nil
    registerImpersonatedExport(V, 'getAccountOwner', function(account)
        if not exports['Thistle-Banking'] then return nil end
        -- Thistle-Banking exposes no dedicated getOwner export today —
        -- listAccountMembers surfaces auth data. Best-effort: return
        -- the first member if any, otherwise the account id itself.
        local rows
        pcall(function() rows = exports['Thistle-Banking']:listAccountMembers(account) end)
        if type(rows) == 'table' and rows.members and rows.members[1] then
            return rows.members[1].cid
        end
        return account
    end)

    --- getMember(account_id, identifier) → table | nil
    registerImpersonatedExport(V, 'getMember', function(account_id, identifier)
        if not exports['Thistle-Banking'] or not account_id or not identifier then return nil end
        local rows
        pcall(function() rows = exports['Thistle-Banking']:listAccountMembers(account_id) end)
        if type(rows) == 'table' and rows.members then
            for _, m in ipairs(rows.members) do
                if m.cid == identifier then return m end
            end
        end
        return nil
    end)

    --- getAccountMembers(account_id) → table
    registerImpersonatedExport(V, 'getAccountMembers', function(account_id)
        if not exports['Thistle-Banking'] or not account_id then return {} end
        local rows = {}
        pcall(function() rows = exports['Thistle-Banking']:listAccountMembers(account_id) end)
        return (type(rows) == 'table' and rows.members) or {}
    end)

    -- Invoice + transfer helpers --------------------------------------
    -- These map ~1:1 onto Thistle-Banking's Contracts system. Full
    -- parity would require adapting the payload shape; for now we
    -- stub them so 3rd-party callers don't crash and return sensible
    -- defaults.

    local warnedInvoices = false
    local function warnInvoices()
        if warnedInvoices then return end
        warnedInvoices = true
        print('^3[thistle-lib bank_compat]^0 fd_banking invoice/transfer exports are stubbed. 3rd-party callers get `false`; use Thistle-Banking\'s native Contracts UI instead.')
    end
    registerImpersonatedExport(V, 'issueInvoice',  function() warnInvoices(); return false end)
    registerImpersonatedExport(V, 'payInvoice',    function() warnInvoices(); return false end)
    registerImpersonatedExport(V, 'lookupInvoice', function() warnInvoices(); return nil   end)
    registerImpersonatedExport(V, 'cancelInvoice', function() warnInvoices(); return false end)

    --- doTransfer(source, targetAccountId, playerId, amount, localAccountId, reason, transactionCallback, forcePay)
    --- Best-effort mapping to a straight society→society transfer.
    registerImpersonatedExport(V, 'doTransfer', function(source, targetAccountId, playerId, amount, localAccountId, reason, transactionCallback, forcePay)
        local ok = Thistle.BankBridge.Transfer(localAccountId, targetAccountId, amount, reason or 'fd_banking:doTransfer')
        if type(transactionCallback) == 'function' then
            pcall(transactionCallback, ok)
        end
        return ok
    end)

    Thistle.BankCompat.active[V] = true
end

-- =====================================================================
-- Vendor: tgg-banking (Teams GG)
-- ---------------------------------------------------------------------
-- Full-featured resource with a rich IAccount object shape, IBAN
-- lookups, and its own loans + credit-score system. We faithfully
-- impersonate the core money ops. Account descriptors are built from
-- Thistle-Banking data. Loans/credit exports are stubbed with clear
-- return shapes since Thistle-Banking has its own (differently-shaped)
-- loans system — full parity would require a translation layer that's
-- easier for a consumer to build script-side if they need it.
-- =====================================================================

local function installTggBanking()
    local V = 'tgg-banking'
    if not shouldImpersonate(V) then return end

    -- Helper: fake IAccount from a society account.
    local function societyIAccount(society)
        if not society then return nil end
        local bal = Thistle.BankBridge.GetSocietyBalance(society)
        if bal == 0 and Thistle.BankBridge.GetBackend().name == 'thistle-lib.framework-fallback' then
            return nil
        end
        return {
            id            = society,
            iban          = society,        -- Thistle uses id as IBAN
            balance       = bal,
            name          = society,
            ownerId       = society,
            type          = 'society',
            color         = 'blue',
            ownedAccount  = false,
            frozen        = false,
            closed        = false,
            createdAt     = 0,
            settings      = {},
            permissions   = {},
        }
    end

    local function personalIAccount(identifier)
        if not identifier then return nil end
        local Player = Thistle.GetPlayerObjectFromID and Thistle.GetPlayerObjectFromID(identifier)
        if not Player then return nil end
        local funds = Thistle.GetFunds and Thistle.GetFunds(Player) or {}
        local name  = Thistle.GetCharacterName and Thistle.GetCharacterName(Player) or identifier
        return {
            id            = identifier,
            iban          = identifier,
            balance       = funds.bank or 0,
            name          = name,
            ownerId       = identifier,
            type          = 'personal',
            color         = 'grey',
            ownedAccount  = true,
            frozen        = false,
            closed        = false,
            createdAt     = 0,
            settings      = {},
            permissions   = {},
        }
    end

    -- Accounts --------------------------------------------------------

    registerImpersonatedExport(V, 'GetSocietyAccount', function(society)
        return societyIAccount(society)
    end)

    registerImpersonatedExport(V, 'GetAccountByIban', function(iban)
        -- Personal account takes priority when the ref resolves to a
        -- real player (a citizen id). Society/IBAN identifiers won't
        -- resolve to a Player object, so they fall through cleanly.
        local Player = Thistle.GetPlayerObjectFromID and Thistle.GetPlayerObjectFromID(iban)
        if Player then
            return personalIAccount(iban)
        end
        return societyIAccount(iban)
    end)

    registerImpersonatedExport(V, 'GetPersonalAccountByPlayerId', function(playerId)
        local Player = Thistle.GetPlayerObject and Thistle.GetPlayerObject(playerId)
        if not Player then return nil end
        return personalIAccount(Thistle.GetIdentifier(Player))
    end)

    registerImpersonatedExport(V, 'GetPersonalAccountByPlayerIdentifier', function(identifier)
        return personalIAccount(identifier)
    end)

    --- CreateBusinessAccount(society, startBalance, displayName, color)
    --- Returns tgg's success envelope shape.
    registerImpersonatedExport(V, 'CreateBusinessAccount', function(society, startBalance, displayName, color)
        if not exports['Thistle-Banking'] then
            return { success = false, error = 'Thistle-Banking not started' }
        end
        local ok = pcall(function() exports['Thistle-Banking']:CreateJobAccount(society) end)
        if not ok then return { success = false, error = 'CreateJobAccount failed' } end
        if startBalance and startBalance > 0 then
            Thistle.BankBridge.AddSocietyMoney(society, startBalance, 'tgg-banking:CreateBusinessAccount seed')
        end
        return { success = true, account = societyIAccount(society) }
    end)

    -- Money -----------------------------------------------------------

    registerImpersonatedExport(V, 'GetAccountMoneyByIban', function(iban)
        local acc = societyIAccount(iban) or personalIAccount(iban)
        return acc and acc.balance or nil
    end)

    registerImpersonatedExport(V, 'GetSocietyAccountMoney', function(society)
        return Thistle.BankBridge.GetSocietyBalance(society)
    end)

    registerImpersonatedExport(V, 'AddSocietyMoney', function(society, amount)
        return Thistle.BankBridge.AddSocietyMoney(society, amount, 'tgg-banking:AddSocietyMoney')
    end)

    registerImpersonatedExport(V, 'RemoveSocietyMoney', function(society, amount)
        return Thistle.BankBridge.RemoveSocietyMoney(society, amount, 'tgg-banking:RemoveSocietyMoney')
    end)

    --- AddTransaction(toIban, fromIban, transactionType, amount, description?, playerId?, cardId?, customTitle?)
    --- → transaction id string | nil
    registerImpersonatedExport(V, 'AddTransaction', function(toIban, fromIban, transactionType, amount, description, playerId, cardId, customTitle)
        if not exports['Thistle-Banking'] then return nil end
        local account = toIban or fromIban
        if not account then return nil end
        local direction = (transactionType == 'withdraw' or transactionType == 'sent') and 'withdraw' or 'deposit'
        local title     = customTitle or description or ('tgg-banking:' .. tostring(transactionType))
        local issuer    = fromIban and tostring(fromIban) or 'External'
        local receiver  = toIban   and tostring(toIban)   or 'External'
        local result
        pcall(function()
            result = exports['Thistle-Banking']:handleTransaction(
                account, title, tonumber(amount) or 0, description or title,
                issuer, receiver, direction)
        end)
        if type(result) == 'table' then return tostring(result.trans_id) end
        return nil
    end)

    -- Freeze / terminate ----------------------------------------------
    -- Thistle-Banking has an `isFrozen` account flag but no dedicated
    -- freeze/unfreeze export today. We stub these to return false with
    -- a one-time warning so consumers see the gap rather than a silent
    -- no-op.

    local warnedFreeze = false
    local function warnFreeze()
        if warnedFreeze then return end
        warnedFreeze = true
        print('^3[thistle-lib bank_compat]^0 tgg-banking freeze/terminate exports are stubbed. Callers get `false`.')
    end
    registerImpersonatedExport(V, 'IsAccountFrozen',     function() return false end)
    registerImpersonatedExport(V, 'IsAccountTerminated', function() return false end)
    registerImpersonatedExport(V, 'FreezeAccount',       function() warnFreeze(); return false end)
    registerImpersonatedExport(V, 'UnfreezeAccount',     function() warnFreeze(); return false end)
    registerImpersonatedExport(V, 'TerminateAccount',    function() warnFreeze(); return false end)
    registerImpersonatedExport(V, 'IsCardFrozen',        function() return false end)
    registerImpersonatedExport(V, 'IsCardTerminated',    function() return false end)
    registerImpersonatedExport(V, 'FreezeCard',          function() warnFreeze(); return false end)
    registerImpersonatedExport(V, 'UnfreezeCard',        function() warnFreeze(); return false end)

    -- Loans / credit ---------------------------------------------------
    -- Thistle-Banking has its own loans + credit systems, but with a
    -- different data shape. We return sensible-but-explicit "not
    -- supported via compat" shapes rather than pretending — consumers
    -- who need real parity should use Thistle-Banking's native exports.

    local warnedLoans = false
    local function warnLoans()
        if warnedLoans then return end
        warnedLoans = true
        print('^3[thistle-lib bank_compat]^0 tgg-banking loans/credit exports are stubbed. Use Thistle-Banking\'s native loans API for full functionality.')
    end
    registerImpersonatedExport(V, 'GetCreditScore', function()
        warnLoans(); return nil
    end)
    registerImpersonatedExport(V, 'GetCreditProfile', function()
        warnLoans(); return nil
    end)
    registerImpersonatedExport(V, 'CanPlayerFinance', function()
        warnLoans(); return false, 'compat stub'
    end)
    local loanStub = function()
        warnLoans(); return { success = false, message = 'tgg-banking loans not supported via thistle-lib compat' }
    end
    registerImpersonatedExport(V, 'CreateLoan',            loanStub)
    registerImpersonatedExport(V, 'ApproveLoan',           loanStub)
    registerImpersonatedExport(V, 'RejectLoan',            loanStub)
    registerImpersonatedExport(V, 'CreateAndApproveLoan',  loanStub)
    registerImpersonatedExport(V, 'ApplyLoanPayment',      loanStub)
    registerImpersonatedExport(V, 'PayLoanDue',            loanStub)
    registerImpersonatedExport(V, 'GetLoan',               function() warnLoans(); return nil end)
    registerImpersonatedExport(V, 'GetPlayerLoans',        function() warnLoans(); return nil end)
    registerImpersonatedExport(V, 'GetActiveLoans',        function() warnLoans(); return {}  end)
    registerImpersonatedExport(V, 'GetLoanBalance',        function() warnLoans(); return nil end)
    registerImpersonatedExport(V, 'GetLoanPaymentDue',     function() warnLoans(); return nil end)
    registerImpersonatedExport(V, 'IsLoanDelinquent',      function() warnLoans(); return false, nil end)
    registerImpersonatedExport(V, 'GetPlayerDebtSummary',  function() warnLoans(); return { totalDebt = 0, activeLoansCount = 0, loans = {} } end)
    registerImpersonatedExport(V, 'GetLoanHistory',        function() warnLoans(); return {} end)

    Thistle.BankCompat.active[V] = true
end

-- =====================================================================
-- Boot
-- =====================================================================

CreateThread(function()
    Wait(100)  -- let resource-state probes settle
    installQbBanking()
    installRenewedBanking()
    installOkokBanking()
    installWasabiBanking()
    installFdBanking()
    installTggBanking()

    local names = {}
    for v in pairs(Thistle.BankCompat.active) do names[#names + 1] = v end
    if #names > 0 then
        table.sort(names)
        print(('^2[thistle-lib bank_compat]^0 impersonating vendor exports: %s')
            :format(table.concat(names, ', ')))
        print('^2[thistle-lib bank_compat]^0 third-party scripts calling these vendor exports will be transparently routed through Thistle.BankBridge to the registered backend.')
    else
        print('^3[thistle-lib bank_compat]^0 nothing to impersonate (real vendor resources appear to be running).')
    end
end)
