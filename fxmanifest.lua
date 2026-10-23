fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'thistle-evidence'
author 'Thistle Scripts'
description 'Forensic evidence, evidence laptop and wiretaps. Powered by Thistle-Lib.'
version '2.0.0'

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
    'data/weapons/*.meta',
    'locales/*.json',
    'config.lua',

    'common/*.lua',
    'common/events/**.lua',

    'html/dui/laptop/dist/**',
    'html/dui/scanner/**',

    'client/**'
}

-- Evidence marker props marker1 to marker3 (the models themselves are in stream/)
data_file 'DLC_ITYP_REQUEST' 'stream/markers.ytyp'
-- UV lamps: bzzz_dream_of_lights_purple (360°) and bzzz_world_of_lamps_purple (directional)
data_file 'DLC_ITYP_REQUEST' 'stream/thistle_uv_lamps.ytyp'

-- The UV flashlight addon weapon (WEAPON_UVFLASHLIGHT), using the game's flashlight model
data_file 'WEAPON_ANIMATIONS_FILE' 'data/weapons/weaponanimations.meta'
data_file 'WEAPONINFO_FILE' 'data/weapons/weapons.meta'

-- The forensics lab is the NUI page; the laptop is a DUI built from the same project (html/dui/laptop)
ui_page 'html/dui/laptop/dist/lab.html'
