local config <const> = require "config"
local eventHandler <const> = require "common.events.handler"
local permissions <const> = require "client.permissions"

local settings <const> = config.fingerprintScanner
local stateKey <const> = "evidences:scanner"

-- Whether this player is holding the scanner out. Everyone nearby sees it: the player's state says the scanner is
-- out, and each client (this one too) puts its own local phone in that player's hand. Nothing is networked, so it
-- shows whatever sv_entityLockdown is set to, and other players can target the phone to give a print.
local scannerOut = false
local props = {} -- server id -> the local phone in that player's hand

-- Create dui on phone
lib.requestModel("p_cs_cam_phone")
RemoveReplaceTexture("p_cs_cam_phone", "phone_screen")

local dui <const> = lib.dui:new({
    url = string.format("nui://%s/html/dui/scanner/index.html", cache.resource),
    width = 128,
    height = 256,
    debug = false
})

AddReplaceTexture("p_cs_cam_phone", "phone_screen", dui.dictName, dui.txtName)


local function isHoldingPose(ped)
    return IsEntityPlayingAnim(ped, settings.animation.dict, settings.animation.clip, 3)
end

local function attachProp(serverId, ped)
    local prop <const> = CreateObject(`p_cs_cam_phone`, GetEntityCoords(ped), false, false, false)
    if not prop or prop == 0 then
        return nil
    end

    SetEntityCollision(prop, false, false)
    AttachEntityToEntity(
        prop,
        ped,
        GetPedBoneIndex(ped, settings.bone),
        settings.offset.x, settings.offset.y, settings.offset.z,
        settings.rotation.x, settings.rotation.y, settings.rotation.z,
        true, true, false, true, 1, true
    )

    props[serverId] = { prop = prop, ped = ped }
    return prop
end

local function removeProp(serverId)
    local entry <const> = props[serverId]
    if entry and DoesEntityExist(entry.prop) then
        DeleteEntity(entry.prop)
    end
    props[serverId] = nil
end

-- Keeps a phone in the hand of every player nearby with the scanner out, and none in anyone else's
local function syncProps()
    local active = {}

    for _, player in ipairs(GetActivePlayers()) do
        local serverId <const> = GetPlayerServerId(player)
        local ped <const> = GetPlayerPed(player)

        if Player(serverId).state[stateKey] and DoesEntityExist(ped) then
            active[serverId] = true
            local entry <const> = props[serverId]

            if not entry or entry.ped ~= ped or not DoesEntityExist(entry.prop) then
                removeProp(serverId)
                lib.requestModel(`p_cs_cam_phone`)
                attachProp(serverId, ped)
            end
        end
    end

    for serverId in pairs(props) do
        if not active[serverId] then
            removeProp(serverId)
        end
    end
end

-- A player taking the scanner out or putting it away shows straight away; players coming into range are picked up
-- by the loop below
AddStateBagChangeHandler(stateKey, nil, function()
    SetTimeout(0, syncProps) -- after the state bag has its new value
end)

CreateThread(function()
    LocalPlayer.state:set(stateKey, false, true) -- not left out by a restart of this resource

    while true do
        syncProps()
        Wait(1000)
    end
end)

-- Puts the phone away: the arm lowers with the exit animation, then the phone goes
local function cancel()
    if not scannerOut then
        return
    end

    scannerOut = false
    config.inputHelp.hide()

    local exit <const> = settings.exitAnimation
    if exit and not cache.vehicle and not IsPedDeadOrDying(cache.ped, true) then
        lib.playAnim(cache.ped, exit.dict, exit.clip, 4.0, 4.0, exit.duration or 800, 48, 0.0, false, 0, false)
        Wait(exit.duration or 800)
    else
        StopAnimTask(cache.ped, settings.animation.dict, settings.animation.clip, 2.0)
    end

    StopAnimTask(cache.ped, settings.animation.dict, settings.animation.clip, 2.0)
    LocalPlayer.state:set(stateKey, false, true)
    removeProp(cache.serverId)
end

eventHandler.onLocal("onResourceStop", function(event)
    if event.arguments[1] == cache.resource then
        if scannerOut then
            config.inputHelp.hide()
            StopAnimTask(cache.ped, settings.animation.dict, settings.animation.clip, 1.0)
            LocalPlayer.state:set(stateKey, false, true)
            scannerOut = false
        end

        for serverId in pairs(props) do
            removeProp(serverId)
        end
    end
end)

RegisterCommand("cancelFingerprintScan", function()
    CreateThread(cancel)
    LocalPlayer.state:set(stateKey, false, true)

    -- removes all objects that are attached to the player
    for _, object in ipairs(lib.getNearbyObjects(GetEntityCoords(cache.ped))) do
        local entity <const> = object.object
        local entityAttachedTo <const> = GetEntityAttachedTo(entity) or 0

        if entityAttachedTo == cache.ped and GetEntityModel(entity) == `p_cs_cam_phone` then
            SetEntityAsMissionEntity(entity)
            DeleteObject(entity)
        end
    end
end)

-- While the phone is out the player can walk about. ESC or Backspace puts it away, as does anything that would
-- make holding it out odd (dying, getting in a vehicle, drawing a weapon).
local function watchScanner()
    CreateThread(function()
        while scannerOut do
            DisableControlAction(0, 200, true) -- the pause menu, so ESC can put the phone away instead
            DisableControlAction(0, 24, true) -- no punching with the phone out
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 140, true)
            DisableControlAction(0, 141, true)
            DisableControlAction(0, 142, true)

            if IsDisabledControlJustPressed(0, 200) or IsControlJustPressed(0, 177)
                or IsPedDeadOrDying(cache.ped, true) or cache.vehicle or (cache.weapon and cache.weapon ~= `WEAPON_UNARMED`) then
                cancel()
                break
            end

            -- something else (an emote, a ragdoll) stopped the pose: hold the phone out again
            if not isHoldingPose(cache.ped) and not IsPedRagdoll(cache.ped) then
                lib.playAnim(cache.ped, settings.animation.dict, settings.animation.clip, 4.0, 4.0, -1, 49, 0.0, false, 0, false)
            end

            Wait(0)
        end

        -- keep ESC from opening the pause menu as it's released
        local releaseUntil <const> = GetGameTimer() + 400
        while GetGameTimer() < releaseUntil do
            DisableControlAction(0, 200, true)
            Wait(0)
        end
    end)
end

-- Raises the phone for a scan of someone the officer targeted (Scan fingerprint below). The result
-- (evidences:fingerprintScanned) puts it away again.
local function holdUpPhone()
    if scannerOut then
        return
    end

    TriggerEvent("ox_inventory:disarm", cache.ped, true)
    scannerOut = true
    LocalPlayer.state:set(stateKey, true, true)
    lib.requestModel(`p_cs_cam_phone`)
    syncProps()

    local enter <const> = settings.enterAnimation
    if enter then
        lib.playAnim(cache.ped, enter.dict, enter.clip, 4.0, 4.0, enter.duration or 600, 48, 0.0, false, 0, false)
        Wait(enter.duration or 600)
    end

    lib.playAnim(cache.ped, settings.animation.dict, settings.animation.clip, 4.0, 4.0, -1, 49, 0.0, false, 0, false)
end

-- Using the forensic_fingerprint_scanner item (setup/<lang>_items.lua). Using it again puts it away.
local function useScanner(data, slot)
    if not permissions.has("fingerprints") then
        config.notify({ key = "laptop.notifications.no_permission" }, "error")
        return
    end

    if scannerOut then
        -- Out already, or stuck from an attempt where the phone never appeared: either way, put it away
        CreateThread(cancel)
        return
    end

    local used = false

    exports.ox_inventory:useItem(data, function(data)
        used = true
        TriggerEvent("ox_inventory:disarm", cache.ped, true)

        -- the phone appears in this player's hand on every client nearby (syncProps above)
        scannerOut = true
        LocalPlayer.state:set(stateKey, true, true)
        lib.requestModel(`p_cs_cam_phone`)
        syncProps()

        local enter <const> = settings.enterAnimation
        if enter then
            lib.playAnim(cache.ped, enter.dict, enter.clip, 4.0, 4.0, enter.duration or 600, 48, 0.0, false, 0, false)
            Wait(enter.duration or 600)
        end

        lib.playAnim(cache.ped, settings.animation.dict, settings.animation.clip, 4.0, 4.0, -1, 49, 0.0, false, 0, false)

        config.inputHelp.show(locale("fingerprint_scanner.input_help"), {
            tildeDelimitedCodes = { "~INPUT_FRONTEND_CANCEL~" },
            mappedValues = { "[ESC]" }
        })

        watchScanner()
    end)

    if not used then
        lib.print.warn("ox_inventory didn't use the fingerprint scanner (busy, dead, ragdolling, or the item's server use was refused)")
    end
end

exports("forensic_fingerprint_scanner", useScanner)
-- The item's export before it was renamed, so an items.lua entry that still calls it keeps working
exports("fingerprint_scanner", useScanner)

RegisterNetEvent("evidences:fingerprintScanned", function(result)
    CreateThread(function()
        Wait(1500)
        cancel()
    end)

    if not result then
        config.notify({ key = "fingerprint_scanner.scan_no_match" }, "inform")
        return
    end

    if not result.success then
        config.notify({ key = "fingerprint_scanner.scan_error" }, "error")
        return
    end

    local citizen <const> = result.response
    config.notify({
        key = "fingerprint_scanner.scan_match",
        arguments = {
            citizen.fullName,
            citizen.birthdate,
            locale("laptop.desktop_screen.citizens_app.gender." .. citizen.gender)
        }
    }, "success", 7500)
end)


-- Giving a print: the player targets whoever is holding a scanner out. The target is the player, not the phone: the
-- phone has no collision (so it doesn't knock into things), and ox_target's aim only finds things with collision.
local function giveFingerprint(pedHoldingScanner)
    if not pedHoldingScanner or not DoesEntityExist(pedHoldingScanner) then
        return
    end

    if config.isPedWearingGloves() then
        config.notify({ key = "fingerprint_scanner.scan_gloves" }, "error")
        return
    end

    if Thistle.Callback.Await("evidences:scanFingerprint", GetPlayerServerId(NetworkGetPlayerIndexFromPed(pedHoldingScanner))) then
        local pedCoords <const> = GetEntityCoords(cache.ped)
        local coords <const> = GetEntityCoords(pedHoldingScanner)
        SetEntityHeading(cache.ped, GetHeadingFromVector_2d(coords.x - pedCoords.x, coords.y - pedCoords.y))

        -- reach out and press a finger on the screen
        local press <const> = settings.pressAnimation
        lib.playAnim(cache.ped, press.dict, press.clip, 4.0, 4.0, press.duration or 1500, 48, 0.0, false, 0, false)
        return
    end

    config.notify({ key = "fingerprint_scanner.scan_error" }, "error")
end

exports.ox_target:addGlobalPlayer({
    {
        name = "evidences:give_fingerprint",
        label = locale("fingerprint_scanner.target"),
        icon = "fa-solid fa-fingerprint",
        distance = 2.0,
        canInteract = function(entity)
            if config.isPedDead(cache.ped) then
                return false
            end

            local serverId <const> = GetPlayerServerId(NetworkGetPlayerIndexFromPed(entity))
            return serverId > 0 and Player(serverId).state[stateKey] == true
        end,
        onSelect = function(data)
            giveFingerprint(data.entity)
        end
    }
})

-- Aiming right at the phone works too, where it can be hit
exports.ox_target:addModel(`p_cs_cam_phone`, {
    {
        name = "evidences:give_fingerprint_phone",
        label = locale("fingerprint_scanner.target"),
        icon = "fa-solid fa-fingerprint",
        distance = 2.0,
        canInteract = function(entity)
            local pedHoldingScanner <const> = GetEntityAttachedTo(entity)
            if not pedHoldingScanner or not DoesEntityExist(pedHoldingScanner) or not IsPedAPlayer(pedHoldingScanner) or pedHoldingScanner == cache.ped then
                return false
            end

            local serverId <const> = GetPlayerServerId(NetworkGetPlayerIndexFromPed(pedHoldingScanner))
            return serverId > 0 and Player(serverId).state[stateKey] == true
        end,
        onSelect = function(data)
            giveFingerprint(GetEntityAttachedTo(data.entity))
        end
    }
})

eventHandler.onLocal("onResourceStop", function(event)
    if event.arguments[1] == cache.resource then
        exports.ox_target:removeGlobalPlayer("evidences:give_fingerprint")
        exports.ox_target:removeModel(`p_cs_cam_phone`, "evidences:give_fingerprint_phone")
    end
end)


-- Officers scan a player's finger by targeting them, as long as they carry the scanner. The player is asked first, as
-- when taking prints with a forensic kit, unless they're cuffed or down (server/scanner/scanner.lua).
local scanning = false

Thistle.Callback.Register("evidences:isWearingGloves", function()
    return config.isPedWearingGloves()
end)

exports.ox_target:addGlobalPlayer({
    {
        name = "evidences:scan_fingerprint",
        label = locale("fingerprint_scanner.scan_player"),
        icon = "fa-solid fa-mobile-screen",
        distance = 2.5,
        items = "forensic_fingerprint_scanner",
        canInteract = function(entity)
            return not scanning and not config.isPedDead(cache.ped) and not config.isPedCuffed(cache.ped)
                and permissions.has("fingerprints")
        end,
        onSelect = function(data)
            if scanning then
                return
            end

            scanning = true
            CreateThread(function()
                local target <const> = data.entity
                local targetId <const> = GetPlayerServerId(NetworkGetPlayerIndexFromPed(target))
                local enforce <const> = config.isPedCuffed(target) or config.isPedDead(target)

                holdUpPhone()
                local scanned <const> = Thistle.Callback.Await("evidences:scanPlayerFingerprint", targetId, enforce)
                scanning = false

                -- a scan puts the phone away when its result arrives; anything else puts it away now
                if not scanned then
                    cancel()
                end
            end)
        end
    }
})

eventHandler.onLocal("onResourceStop", function(event)
    if event.arguments[1] == cache.resource then
        exports.ox_target:removeGlobalPlayer("evidences:scan_fingerprint")
    end
end)
