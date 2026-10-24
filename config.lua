--[[
  thistle-evidence · Thistle Scripts
]]
local config = {}

-- Your city's name. It's shown as "<name> Evidence" on the laptop, in the forensics lab and on Discord logs.
config.cityName = "Thistle"


-- Players don't leave fingerprints when wearing gloves. Gloves are worn on the arms (clothing component 3), and the
-- male and female freemode bodies number their arms differently, so each has its own list of arms WITHOUT gloves.
-- If you have custom clothing on your server, add the ids of its bare-handed arms to the right list.
config.barehandedArms = {
    [`mp_m_freemode_01`] = {
        0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 18, 26, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62,
        112, 113, 114, 118, 125, 132, 184, 196, 198
    },
    [`mp_f_freemode_01`] = {
        0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 19, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71,
        129, 130, 131, 135, 142, 149, 153, 157, 161, 165
    }
}

-- Note: Fingerprints are only created if the function returns false! This means you have to ability to add further conditions, which have to be fulfilled in order for a player not to leave any fingerprints.
config.isPedWearingGloves = function()
    local barehanded <const> = config.barehandedArms[GetEntityModel(cache.ped)]

    -- Other ped models (story characters, animals, add-on peds) have no glove clothing, so they always leave prints
    if not barehanded then
        return false
    end

    return not lib.table.contains(barehanded, GetPedDrawableVariation(cache.ped, 3))
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

-- The forensic_fingerprint_scanner item: the holder holds out a phone (p_cs_cam_phone) and another player puts their
-- finger on it. The holder can walk about while holding it; ESC, Backspace or using the item again puts it away.
config.fingerprintScanner = {
    animation = { dict = "cellphone@", clip = "cellphone_text_read_base" }, -- holding the phone out (loops)
    enterAnimation = { dict = "cellphone@", clip = "cellphone_text_in", duration = 600 }, -- raising it
    exitAnimation = { dict = "cellphone@", clip = "cellphone_text_out", duration = 700 }, -- lowering it
    pressAnimation = { dict = "mp_common", clip = "givetake1_a", duration = 1500 }, -- the scanned player's finger press

    -- How the phone sits in the right hand (bone 28422 is PH_R_Hand). Tune these if it floats or clips.
    bone = 28422,
    offset = vec3(0.0, 0.0, 0.0),
    rotation = vec3(0.0, 0.0, 0.0)
}

-- Booking terminals for the police cells: officers target one of these spots (e.g. a computer that's part of your MLO)
-- to open the booking screen, where they find or create the suspect's citizen record, put the fingerprint and DNA swab
-- taken from them on file, and add notes. It has nothing else from the laptop (no analysis, wiretaps or firearms).
-- Using it needs config.permissions.access.
config.bookingTerminals = {
    stations = {
        -- vec3(459.5, -989.0, 24.9), -- e.g. the booking room computer at Mission Row
    },
    radius = 0.6 -- how big the target is round each spot (metres)
}

-- Evidence lockers: shared stashes at the station where evidence is kept, with a log of who put in and took out what,
-- and when (target the locker and choose View log). Opening one needs its groups (config.permissions.access by default).
config.evidenceLockers = {
    -- {
    --     id = "mrpd_evidence", -- unique; the stash's id in ox_inventory
    --     label = "Mission Row Evidence",
    --     coords = vec3(474.3, -990.3, 26.3),
    --     radius = 0.8,
    --     slots = 200,
    --     weight = 1000000
    -- }
}

-- Labelling an evidence box with a case number seals it. Opening a sealed box breaks the seal and records who opened it
-- and when, shown on the box, so tampering is visible. Relabelling it reseals it.
config.evidenceBoxSeals = true

-- Evidence ages: traces left lying at a scene give worse samples the longer they're there before being collected.
-- On a sample's first analysis, its quality (0-100) is the chance of a full result. Otherwise it's partial (prints and
-- DNA list a few possible citizens, bullets and casings only give the weapon) or nothing usable. Samples taken straight
-- from a person are always perfect.
config.evidenceAging = {
    enabled = true,
    freshMinutes = 30, -- collected within this, a sample is perfect
    worstMinutes = 720, -- collected this long after (12 hours) or later, it's at minimumQuality
    minimumQuality = 20,
    partialCandidates = 3, -- how many possible citizens a partial print or DNA profile lists
    removeAfterMinutes = 2880 -- ground evidence older than this (2 days) disappears; 0 keeps it until a restart
}

-- Footprints: walking on soft ground (mud, sand, snow, marsh, soil, dirt tracks) leaves prints. A cast of one shows
-- men's or women's shoes, the size (fixed per character), the tread and which way they were going.
config.footprints = {
    enabled = true,
    spacing = 3.0 -- metres between prints; lower leaves more (and syncs more)
}

-- Tyre marks: braking hard or spinning the wheels leaves a mark that shows the vehicle's model and its direction
config.tyreMarks = {
    enabled = true,
    minimumSpeed = 10.0, -- m/s (about 22 mph) before braking leaves a mark
    brakingDrop = 1.6, -- speed lost in 0.15 s (m/s) that counts as braking hard
    wheelspin = 6.0, -- how much faster the driven wheels turn than the car moves (m/s)
    cooldown = 4000 -- ms between marks from one driver
}

-- The scene_cleaning_kit item: anyone can scrub a scene with bleach. Ground evidence within the radius is wiped, but each
-- piece has a chance of being missed, and the player isn't told how much. Evidence on vehicles and players isn't touched.
config.sceneCleaning = {
    duration = 30000, -- how long the scrubbing takes (ms); the kit is used up when it finishes
    radius = 4.0, -- metres around the player
    missChance = 0.15 -- the chance each piece is missed
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
    -- footprints and tyre marks can be scuffed out by anyone; add footprint = "..." or tyre_mark = "..." to need an item
}

-- The UV flashlight is an addon weapon, WEAPON_UVFLASHLIGHT, held and swung like the game's flashlight but with a blue
-- beam. Add it to ox_inventory/data/weapons.lua (see setup/weapons.lua), then give it or sell it in shops like any
-- other weapon. While it's equipped, evidence caught in its beam shows up and can be targeted.
config.uvLight = {
    -- true: blood, casings, bullets, magazines and traces on vehicles and props are only visible and targetable under UV light.
    -- false: they're always visible, as before. Gunshot residue on players and taking DNA or fingerprints never need it.
    required = true,

    -- Right click with the flashlight in hand shines it where the player looks (they can still walk and strafe).
    -- "hold": while right click is held. "toggle": right click on, right click again off.
    mode = "hold",

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

-- Evidence survives server restarts: ground evidence, evidence on vehicles (by plate, put back when a vehicle with that
-- plate spawns again) and on players (by character). Collected evidence is kept by ox_inventory anyway.
config.persistence = {
    enabled = true,
    maxAgeDays = 7 -- saved evidence nobody has touched for this long is dropped at start (ground evidence also expires with config.evidenceAging)
}

-- UV lamps officers stand at a crime scene. Evidence they light shows up (and can be collected) as if under the UV
-- flashlight. Only matters while config.uvLight.required is on. Each style is its own item, named by its key.
config.uvFloodlight = {
    styles = {
        -- "Evidence Spotlight": lights all round it
        uv_floodlight = {
            model = `bzzz_dream_of_lights_purple`,
            lamp = vec3(0.0, 0.0, 2.1), -- where the light comes from, from the lamp's base (metres)
            radius = 12.0 -- how far round it evidence shows up (metres)
        },

        -- "360 Evidence Light": lights all round it, further
        uv_spotlight = {
            model = `bzzz_world_of_lamps_purple`,
            lamp = vec3(0.0, -0.3, 1.45),
            radius = 25.0
        }

        -- A style can light only a cone in front of it instead, turned to shine away from the officer placing it:
        -- direction = vec3(0.0, -1.0, -0.35), -- which way the lamp head points on the model
        -- angle = 35.0, -- how wide the beam is (degrees from the centre)
    },

    intensity = 6.0, -- how bright the blue light is
    maxPerPlayer = 2, -- most lamps one player can have standing at once
    lifetime = 120, -- minutes before a lamp switches itself off (the item is lost; they're also gone after a restart)

    permissions = { -- Allowed jobs and their minimum grades required to place and pick up lamps
        police = 0,
        fib = 0
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
        ["Forensic match"] = true, -- an analysis identified a citizen or a registered gun
        ["Evidence box sealed"] = true,
        ["Evidence box seal broken"] = true,
        ["Evidence locker deposit"] = true,
        ["Evidence locker withdrawal"] = true,
        ["Scene cleaned"] = true,
        ["Evidence permissions changed"] = true, -- the evidence admin panel (/evidenceadmin)
        ["Case opened"] = true,
        ["Case closed"] = true,
        ["Case reopened"] = true,
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
        evidences = "", -- collecting, destroying and clearing evidence, taking biometrics, fingerprint scans, forensic matches
        citizens = "", -- citizens, notes and linked biometric data
        wiretap = "", -- observations and spy microphones
        firearms = "" -- firearms registry
    },

    -- Optional: your txAdmin players page, so each log links to the player (e.g. "https://YOUR-IP.NET:40120/players?playerModal=")
    txAdminUrl = ""
}

return config