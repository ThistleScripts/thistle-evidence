fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'noobsystems'
description 'Advanced FiveM evidence script'
version '1.3.1'

dependencies {
    '/onesync',
    'thistle-lib',
    'oxmysql',
    'ox_lib',
    'ox_inventory',
    'ox_target'
}

-- thistle-lib modules are @-included so Thistle.* lives in this resource's own Lua state.
shared_scripts {
    '@ox_lib/init.lua',
    '@thistle-lib/init.lua',
}

client_scripts {
    '@thistle-lib/client/ui.lua',
    '@thistle-lib/client/callback.lua',
    'client/init.lua',
    'client/evidences/evidence_at_coords.lua',
}

server_scripts {
    '@thistle-lib/server/framework.lua',
    '@thistle-lib/server/webhooks.lua',
    '@thistle-lib/server/callback.lua',
    '@oxmysql/lib/MySQL.lua',
    'server/init.lua',
}

files {
    'locales/*.json',
    'config.lua',

    'common/*.lua',
    'common/events/**.lua',

    'html/dui/laptop/dist/**',
    'html/dui/scanner/**',
    'html/nui/**',

    'client/**'
}

ui_page 'html/nui/index.html'
