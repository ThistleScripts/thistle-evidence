local config <const> = require "config"
local eventHandler <const> = require "common.events.handler"
local permissions <const> = require "client.permissions"

local scannerProp
local settings <const> = config.fingerprintScanner

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

-- Puts the phone away: the arm lowers with the exit animation, then the phone goes
local function cancel()
    if not scannerProp then
        return
    end

    local prop <const> = scannerProp
    scannerProp = nil
    config.inputHelp.hide()

    local exit <const> = settings.exitAnimation
    if exit and not cache.vehicle and not IsPedDeadOrDying(cache.ped, true) then
        lib.playAnim(cache.ped, exit.dict, exit.clip, 4.0, 4.0, exit.duration or 800, 48, 0.0, false, 0, false)
        Wait(exit.duration or 800)
    else
        StopAnimTask(cache.ped, settings.animation.dict, settings.animation.clip, 2.0)
    end

    StopAnimTask(cache.ped, settings.animation.dict, settings.animation.clip, 2.0)
    if DoesEntityExist(prop) then
        DeleteEntity(prop)
    end
end

eventHandler.onLocal("onResourceStop", function(event)
    if event.arguments[1] == cache.resource and scannerProp then
        config.inputHelp.hide()
        StopAnimTask(cache.ped, settings.animation.dict, settings.animation.clip, 1.0)
        if DoesEntityExist(scannerProp) then
            DeleteEntity(scannerProp)
        end
        scannerProp = nil
    end
end)

RegisterCommand("cancelFingerprintScan", function()
    CreateThread(cancel)

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
local function watchScanner(prop)
    CreateThread(function()
        while scannerProp == prop do
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

-- Using the forensic_fingerprint_scanner item (setup/<lang>_items.lua). Using it again puts it away.
local function useScanner(data, slot)
    if not permissions.has("fingerprints") then
        config.notify({ key = "laptop.notifications.no_permission" }, "error")
        return
    end

    if scannerProp then
        -- Out already, or stuck from an attempt where the phone never appeared: either way, put it away
        CreateThread(cancel)
        return
    end

    local used = false

    exports.ox_inventory:useItem(data, function(data)
        used = true
        TriggerEvent("ox_inventory:disarm", cache.ped, true)

        local coords <const> = GetEntityCoords(cache.ped)
        lib.requestModel(`p_cs_cam_phone`)

        local prop <const> = CreateObject(`p_cs_cam_phone`, coords.x, coords.y, coords.z, true, true, true)
        if not prop or prop == 0 or not DoesEntityExist(prop) then
            -- e.g. sv_entityLockdown strict, which stops clients creating networked objects
            lib.print.error("Couldn't create the fingerprint scanner's phone (p_cs_cam_phone). Check sv_entityLockdown isn't set to strict.")
            return
        end

        SetEntityCollision(prop, false, false)
        AttachEntityToEntity(
            prop,
            cache.ped,
            GetPedBoneIndex(cache.ped, settings.bone),
            settings.offset.x, settings.offset.y, settings.offset.z,
            settings.rotation.x, settings.rotation.y, settings.rotation.z,
            true, true, false, true, 1, true
        )

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

        scannerProp = prop
        watchScanner(prop)
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


exports.ox_target:addModel(`p_cs_cam_phone`, {
    label = locale("fingerprint_scanner.target"),
    icon = "fa-solid fa-fingerprint",
    distance = 1.5,
    canInteract = function(entity, distance, coords, name, bone)
        -- check if the targeted prop is attached to a ped playing the waiting for scan animation
        local pedHoldingScanner <const> = GetEntityAttachedTo(entity) -- the person holding the scanner
        if pedHoldingScanner and DoesEntityExist(pedHoldingScanner) and IsEntityAPed(pedHoldingScanner) then
            return isHoldingPose(pedHoldingScanner)
        end

        return false
    end,
    onSelect = function(data)
        local pedHoldingScanner <const> = GetEntityAttachedTo(data.entity) -- the person holding the scanner
        if pedHoldingScanner and DoesEntityExist(pedHoldingScanner) then
            if config.isPedWearingGloves() then
                config.notify({ key = "fingerprint_scanner.scan_gloves" }, "error")
                return
            end

            if Thistle.Callback.Await("evidences:scanFingerprint", GetPlayerServerId(NetworkGetPlayerIndexFromPed(pedHoldingScanner))) then
                local pedCoords <const> = GetEntityCoords(cache.ped)
                local coords <const> = GetEntityCoords(data.entity)
                SetEntityHeading(cache.ped, GetHeadingFromVector_2d(coords.x - pedCoords.x, coords.y - pedCoords.y))

                -- reach out and press a finger on the screen
                local press <const> = settings.pressAnimation
                lib.playAnim(cache.ped, press.dict, press.clip, 4.0, 4.0, press.duration or 1500, 48, 0.0, false, 0, false)
                return
            end

            config.notify({ key = "fingerprint_scanner.scan_error" }, "error")
        end
    end
})