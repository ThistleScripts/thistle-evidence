fx_version 'cerulean'
game 'gta5'

name        'thistle-lib'
description 'Shared helpers for Thistle Scripts (framework bridge, inventory, targets, placement, Discord webhooks, region formatting, UI, callbacks).'
author      'Thistle Scripts'
version     '0.5.0'

lua54 'yes'

-- Loaded before anything else so `Thistle` global is available to
-- both server and client scripts that require this resource.
shared_scripts {
    '@ox_lib/init.lua',
    'init.lua',
    'shared/util.lua',
}

server_scripts {
    'server/framework.lua',
    'server/webhooks.lua',
    'server/bank_bridge.lua',
    'server/bank_compat.lua',
    'server/perms.lua',
    'server/callback.lua',
    'server/inventory.lua',
}

client_scripts {
    'client/bank_compat.lua',
    'client/ui.lua',
    'client/callback.lua',
    'client/anim.lua',
    'client/target.lua',
    'client/placement.lua',
}

-- Everything is surfaced via the global `Thistle` table AND via exports so
-- consumers can pick whichever style they prefer.
--
-- Global (any resource that lists `@thistle-lib/init.lua` in its
-- shared_scripts):
--   Thistle.Framework.GetPlayerObject(src)
--   Thistle.Webhook.send('category', { ... })
--   Thistle.Region.money(1234, 'US')
--
-- Exports (any resource that has thistle-lib started):
--   exports['thistle-lib']:GetPlayerObject(src)
--   exports['thistle-lib']:WebhookSend('category', { ... })
--   exports['thistle-lib']:FormatMoney(1234, 'US')
server_exports {
    'Version',
    'GetPlayerObject',
    'GetPlayerObjectFromID',
    'GetIdentifier',
    'GetLicense',
    'GetCharacterName',
    'GetFunds',
    'AddMoney',
    'RemoveMoney',
    'Notify',
    'HasItem',
    'RegisterUsableItem',
    'GetAllPlayers',
    'WebhookSend',
    'WebhookConfigure',
    'FormatMoney',
    -- BankBridge (compat / integration layer)
    'BankSetBackend',
    'BankGetBackend',
    'BankGetBalance',
    'BankAddMoney',
    'BankRemoveMoney',
    'BankTransfer',
    'BankGetSocietyBalance',
    'BankAddSocietyMoney',
    'BankRemoveSocietyMoney',
    -- Perms
    'PermsHasAceAny',
}

client_exports {
    'TargetBackend',
    'TargetAddEntity',
    'TargetRemoveEntity',
    'TargetAddSphereZone',
    'TargetAddBoxZone',
    'TargetRemove',
    'PlacementStart',
    'PlacementIsActive',
}

-- Modules can also be included straight into a consumer's own Lua state
-- (no export hop):  shared '@thistle-lib/init.lua', server
-- '@thistle-lib/server/framework.lua', client '@thistle-lib/client/target.lua'…
-- Client and shared modules are already downloadable via client_scripts /
-- shared_scripts above, so no `files {}` entry is needed.
