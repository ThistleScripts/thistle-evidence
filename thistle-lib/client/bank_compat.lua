-- =====================================================================
-- Thistle-Lib · Bank compat (CLIENT)
-- ---------------------------------------------------------------------
-- Client-side impersonation for vendors that expose client-facing
-- exports (UI open/close toggles, etc). Same event-driven trick as
-- the server file — register handlers for `__cfx_export_<vendor>_<name>`
-- so `exports['<vendor>']:<name>()` calls resolve into us.
-- =====================================================================

Thistle = Thistle or {}
Thistle.BankCompat = Thistle.BankCompat or { active = {} }

local function registerImpersonatedExport(vendor, name, fn)
    AddEventHandler(('__cfx_export_%s_%s'):format(vendor, name), function(setCB)
        setCB(fn)
    end)
end

local function shouldImpersonate(vendor)
    local state = GetResourceState(vendor)
    if state == 'started' or state == 'starting' then
        print(('^3[thistle-lib bank_compat client]^0 real "%s" resource is %s — skipping impersonation.')
            :format(vendor, state))
        return false
    end
    return true
end

-- =====================================================================
-- Vendor: tgg-banking (client)
-- =====================================================================

local tggDisabled = false

local function installTggBankingClient()
    local V = 'tgg-banking'
    if not shouldImpersonate(V) then return end

    --- OpenBank() — force-open the banking UI.
    --- Thistle-Banking listens on `Thistle-Banking:client:openBankUI` for
    --- exactly this purpose. We defer to it so all the auth / card /
    --- distance checks in the target's own handler still run.
    registerImpersonatedExport(V, 'OpenBank', function()
        if tggDisabled then return end
        TriggerEvent('Thistle-Banking:client:openBankUI', {})
    end)

    --- CloseBank() — close the UI.
    registerImpersonatedExport(V, 'CloseBank', function()
        SendNUIMessage({ action = 'setVisible', status = false })
    end)

    --- IsDisabled() → boolean
    registerImpersonatedExport(V, 'IsDisabled', function()
        return tggDisabled
    end)

    --- ToggleDisabled(disabled)
    registerImpersonatedExport(V, 'ToggleDisabled', function(disabled)
        tggDisabled = disabled and true or false
    end)

    Thistle.BankCompat.active[V] = true
end

CreateThread(function()
    Wait(100)
    installTggBankingClient()

    local names = {}
    for v in pairs(Thistle.BankCompat.active) do names[#names + 1] = v end
    if #names > 0 then
        table.sort(names)
        print(('^2[thistle-lib bank_compat client]^0 impersonating vendor client exports: %s')
            :format(table.concat(names, ', ')))
    end
end)
