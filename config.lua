--[[
  thistle-evidence · Thistle Scripts
]]
local config = {}

-- Your city's name. It's shown as "<name> Evidence" on the laptop, in the forensics lab and on Discord logs.
config.cityName = "Thistle"


-- Players don't leave fingerprints when wearing gloves. If you have custom clothing on your server, you need to add the ids of hands without gloves to this exceptions-list.
-- Note: Fingerprints are only created if the function returns false! This means you have to ability to add further conditions, which have to be fulfilled in order for a player not to leave any fingerprints.
config.isPedWearingGloves = function()
    local handsVariation <const> = GetPedDrawableVariation(cache.ped, 3)
    local exceptions <const>  = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 112, 113, 114, 184, 196, 198}

    return not lib.table.contains(exceptions, handsVariation)
end


-- Players don't need to give consent if they are cuffed and an officer takes their DNA or fingerprints.
-- If your police script uses a different cuff system, adjust the check (if a person is cuffed) here.
config.isPedCuffed = function(ped)
    return IsPedCuffed(ped) or IsEntityPlayingAnim(ped, "mp_arresting", "idle", 3)
end


-- If your server uses a custom death/down system, adjust the check (isPedDeadOrDying) accordingly here.
-- Return true if the ped is dead and false if alive
config.isPedDead = function(ped)
    return IsPedDeadOrDying(ped, true)
end


config.wiretap = {
    -- Enable or disable the wiretap app itself (requires pma-voice)
    enabled = true,

    -- Every action inside the wiretap app gets logged so everyone can check if the action was taken without justification.
    -- How long should these logs keep stored before deleting them on server start? (in milliseconds)
    -- Set to -1 to keep the actions logged forever.
    actionStorageDuration = 1000 * 60 * 60 * 24 * 7, -- default: one week in millis

    calls = {
        -- If you have npwd, roadphone, lb-phone or yphone installed on your server you can choose between phone numbers or player names
        displayPhoneNumbers = false,

        -- Allowed jobs and their minimum grades required to intercept phone calls.
        -- If permissions = {} the phone call section is disabled for everyone.
        permissions = {
            police = 0,
            fib = 0
        }
    },

    -- Spy microphenes can be placed by everyone on the server (they do not percist during server restarts)
    -- If someone is talking in the specified radius around a spy microphone, permitted players can listen to them using the wiretap app on the laptop
    spyMicrophones = {
        radius = 5,

        -- Allowed jobs and their minimum grades required to listen to spy microphones.
        -- If permissions = {} the spy microphones section is disabled for everyone.
        permissions = {
            police = 0,
            fib = 0
        }
    },

    radio = {
        -- Allowed jobs and their minimum grades required to intercept radio channels.
        -- If permissions = {} the radio section is disabled for everyone.
        permissions = {
            police = 0,
            fib = 0
        }
    }
}


-- Defines the conditions a player must match to perform specific actions of this script.
config.permissions = {
    pickup = { -- Allowed jobs and their minimum grades required to pick up a laptop
        police = 0,
        fib = 0
    },

    place = { -- Allowed jobs and their minimum grades required to place a laptop
        police = 0,
        fib = 0
    },

    access = { -- Allowed jobs and their minimum grades required to access the laptop (log in)
        police = 0,
        fib = 0
    },

    collect = { -- Allowed jobs and their minimum grades required to collect evidence
        police = 0,
        fib = 0
    }
}


-- if set to false, all citizens must be registered manually by police
-- if set to true, citizens are synced; they cannot be edited or deleted (buttons for that actions are not visible, too)
config.citizens = {
    synced = true
}

-- The forensics lab is where evidence gets analysed (DNA, fingerprints, ballistics) and case files are looked up.
-- Officers open it by targeting a microscope. The laptop doesn't analyse anything.
-- Who can use it is set by config.permissions.access.
config.forensicsLab = {
    -- The microscope prop
    model = `v_med_microscope`,

    -- Microscopes spawned at fixed spots, e.g. on a lab bench in your PD (x, y, z, heading).
    -- Officers can also place microscopes anywhere with the forensic_microscope item.
    stations = {
        -- vec4(0.0, 0.0, 0.0, 0.0),
    },

    permissions = {
        place = { -- Allowed jobs and their minimum grades required to place a microscope
            police = 0,
            fib = 0
        },

        pickup = { -- Allowed jobs and their minimum grades required to pick up a placed microscope
            police = 0,
            fib = 0
        }
    }
}

-- Items needed to destroy each kind of evidence. One is used up per destroy (a whole pile counts as one).
config.destroyItems = {
    fingerprint = "hydrogen_peroxide",
    blood = "hydrogen_peroxide",
    saliva = "hydrogen_peroxide",
    gunshot_residue = "hydrogen_peroxide",
    casing = "cleaning_kit",
    bullet = "cleaning_kit",
    magazine = "cleaning_kit"
}

-- The UV flashlight is an addon weapon, WEAPON_UVFLASHLIGHT, held and swung like the game's flashlight but with a blue
-- beam. Add it to ox_inventory/data/weapons.lua (see setup/weapons.lua), then give it or sell it in shops like any
-- other weapon. While it's equipped, evidence caught in its beam shows up and can be targeted.
config.uvLight = {
    -- true: blood, casings, bullets, magazines and traces on vehicles and props are only visible and targetable under UV light.
    -- false: they're always visible, as before. Gunshot residue on players and taking DNA or fingerprints never need it.
    required = true,

    -- Right click with the flashlight in hand raises it and shines it where the player looks.
    -- "hold": while right click is held. "toggle": right click raises it and right click again lowers it.
    mode = "hold",
    animation = { dict = "amb@world_human_security_shine_torch@male@base", clip = "base" }, -- the raised-torch pose
    -- The pose holds the torch in the left hand, so while it's raised this torch is put there and the flashlight in
    -- the right hand is hidden. bone 60309 is PH_L_Hand; offset and rotation fine-tune how it sits in the hand.
    torch = {
        model = `prop_cs_police_torch`,
        bone = 60309,
        offset = vec3(0.0, 0.0, 0.0),
        rotation = vec3(0.0, 0.0, 0.0)
    },

    range = 12.0, -- how far the beam reaches (metres)
    angle = 30.0, -- how wide the beam is (degrees from the centre)
    memory = 15000, -- how long evidence stays visible and targetable after the beam has passed over it (ms)
    colour = { r = 60, g = 90, b = 255 }, -- the beam's colour

    -- While the light is on, evidence nearby that isn't in the beam yet glows faintly so officers know where to look
    hints = {
        enabled = true,
        range = 15.0, -- how far away evidence gets a hint (metres)
        size = 0.035, -- the hint's size (metres)
        alpha = 110 -- how strong the hint is (0-255)
    }
}

-- The evidence_marker item: a reusable kit of marker props officers put down at a crime scene. Using it opens a menu
-- to pick the prop, then click to place as many as needed. Officers target a marker to pick it up, or all at the scene.
config.evidenceMarkers = {
    -- The props in the menu, in order. The three numbered markers are streamed by this resource (stream/markers.ytyp).
    props = {
        { label = "Marker 1", model = `marker1` },
        { label = "Marker 2", model = `marker2` },
        { label = "Marker 3", model = `marker3` },
        { label = "Cone", model = `prop_roadcone02c` }
    },

    sceneRadius = 50.0, -- "Pick up all markers" picks up every marker within this distance of the targeted one
    maxPerPlayer = 50, -- most markers one player can have down at once
    lifetime = 120, -- minutes before a marker removes itself (they're also gone after a restart)

    permissions = { -- Allowed jobs and their minimum grades required to place and pick up markers
        police = 0,
        fib = 0
    }
}

-- Enable or disable the firearms registry app
config.firearmsRegistry = {
    enabled = true
}

config.gunshotResidues = {
    -- Cron expression defining when gunshot residues on players shall be removed.
    -- See https://overextended.dev/docs/ox_lib/Cron/Server#cron-expression to learn more about the syntax of cron expressions.
    -- This adds some intended randomness, e.g. when the cron job runs every 15 minutes, it could happen that the gunshot residues are already
    -- removed after 1 minute or as late as 15 minutes depending on the time the cron job started.
    decayCron = "*/15 * * * *" -- default: run every 15 minutes
}


-- Here you can customize key hints and help texts.
-- This is currently only used when placing the evidence laptop.
config.inputHelp = {
    -- Display an input help message
    ---@param text string The text to be displayed (contains placeholders)
    ---@param codes table<"tildeDelimitedCodes"|"mappedValues", string[]> A list of elements to fill the placeholders with
    show = function(text, codes)
        -- Use the string array in codes under key "tildeDelimitedCodes" to replace the placeholders in text when using natives.
        -- codes.tildeDelimitedCodes values are formatted using the classical Rockstar Noth-style "~" formatting tags (e.g. ~INPUT_CONTEXT~)
        local replacements <const> = codes.tildeDelimitedCodes
        text = string.format(text, table.unpack(replacements))

        AddTextEntry("EVIDENCES_INPUT_HELP", text)
        BeginTextCommandDisplayHelp("EVIDENCES_INPUT_HELP")
        EndTextCommandDisplayHelp(0, true, true, -1)


        -- codes.mappedValues values are formatted as "[E]" or similar
        -- Therefore, they should be used to integrate custom input help uis.
        -- Here is an example for ox_lib's text ui (like https://overextended.dev/docs/ox_lib/Interface/Client/textui)
        -- local replacements <const> = codes.mappedValues
        -- text = string.format(text, table.unpack(replacements))
        
        -- lib.showTextUI(text, {
        --     position = "top-center",
        --     icon = "fa-solid fa-keyboard",
        --     ...
        -- })
    end,

    -- Hides all currently displayed input help messages
    -- You can replace ClearAllHelpMessages() with e.g. lib.hideTextUI()
    hide = function()
        ClearAllHelpMessages()
    end
}


-- Replace the body of this function if you want to use a different notification system.
-- By default, notifications go through thistle-lib (Thistle.NotifyClient, which uses ox_lib's notify)
---@param translation { key: string, arguments: string[] }
---@param notifyType? string The type of the notification (e.g. "success" or "error")
---@param duration? number The duration for the notify ui in milliseconds
function config.notify(translation, notifyType, duration)
    if not translation or type(translation) ~= "table" then
        return
    end

    local arguments <const> = translation.arguments or {}

    Thistle.NotifyClient({
        title = locale(translation.key .. ".title"),
        description = locale(translation.key .. ".description", table.unpack(arguments)),
        type = notifyType or "inform",
        duration = duration or 3000
    })
end


config.logging = {
    enabled = false,

    -- By default every event is logged.
    -- You can disable logging for specific events here.
    loggedEvents = {
        ["Evidences cleared"] = true,
        ["Biometric data taken"] = true,
        ["Biometric data linked to citizen"] = true,
        ["Citizen created"] = true,
        ["Citizen updated"] = true,
        ["Citizen deletion requested"] = true,
        ["Note created"] = true,
        ["Note edited"] = true,
        ["Note deletion requested"] = true,
        ["Evidence destroyed"] = true,
        ["Evidence collected"] = true,
        ["Evidence analysed"] = true,
        ["Fingerprint scanned"] = true,
        ["Observation started"] = true,
        ["Observation ended"] = true,
        ["Spy microphone placed"] = true,
        ["Spy microphone picked up"] = true,
        ["Firearm registered"] = true,
        ["Firearm unregistering requested"] = true
    },

    -- Define which logging service you want to use if enabled.
    -- You can choose between "discord" (sent through thistle-lib's Thistle.Webhook) and "ox_lib" (it supports Datadog, Grafana Loki and Fivemanage, see https://overextended.dev/docs/ox_lib/Logger/Server).
    service = "discord",

    -- Discord webhooks (https://support.discord.com/hc/en-us/articles/228383668-Intro-to-Webhooks).
    -- Each category falls back to `default` when left empty; leave everything empty to send nothing.
    webhooks = {
        default = "",
        evidences = "", -- collecting, destroying and clearing evidence, taking biometrics, fingerprint scans
        citizens = "", -- citizens, notes and linked biometric data
        wiretap = "", -- observations and spy microphones
        firearms = "" -- firearms registry
    },

    -- Optional: your txAdmin players page, so each log links to the player (e.g. "https://YOUR-IP.NET:40120/players?playerModal=")
    txAdminUrl = ""
}

return config