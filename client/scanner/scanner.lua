local config <const> = require "config"
local eventHandler <const> = require "common.events.handler"

local scannerProp

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


local function cancel()
    if scannerProp then
        config.inputHelp.hide()
        ClearPedTasks(cache.ped)
        SetNuiFocus(false, false)
        DeleteEntity(scannerProp)
        scannerProp = nil
    end
end

eventHandler.onLocal("onResourceStop", function(event)
    if event.arguments[1] == cache.resource then
        cancel()
    end
end)

RegisterCommand("cancelFingerprintScan", function()
    cancel()

    -- removes all objects that are attached to the player
    for _, object in ipairs(lib.getNearbyObjects(GetEntityCoords(cache.ped))) do
        local entity <const> = object.object
        local entityAttachedTo <const> = GetEntityAttachedTo(entity) or 0

        if entityAttachedTo == cache.ped then
            SetEntityAsMissionEntity(entity)
            DeleteObject(entity)
            scannerProp = nil
        end
    end
end)

eventHandler.onNui("keydown", function(event)
    local key <const> = event.data.key
    if key and (key == "Escape" or key == "Backspace") then
        cancel()
    end
end)

-- Using the forensic_fingerprint_scanner item (setup/<lang>_items.lua). Using it again puts it away.
local function useScanner(data, slot)
    if scannerProp then
        -- Out already, or stuck from an attempt where the phone never appeared: either way, put it away
        cancel()
        return
    end

    local used = false

    exports.ox_inventory:useItem(data, function(data)
        used = true
        TriggerEvent("ox_inventory:disarm", cache.ped, true)
        SetNuiFocus(true, false)

        local coords <const> = GetEntityCoords(cache.ped)
        lib.requestModel(`p_cs_cam_phone`)

        scannerProp = CreateObject(`p_cs_cam_phone`, coords.x, coords.y, coords.z, true, true, true)
        if not scannerProp or scannerProp == 0 or not DoesEntityExist(scannerProp) then
            -- e.g. sv_entityLockdown strict, which stops clients creating networked objects
            lib.print.error("Couldn't create the fingerprint scanner's phone (p_cs_cam_phone). Check sv_entityLockdown isn't set to strict.")
            scannerProp = nil
            SetNuiFocus(false, false)
            return
        end

        AttachEntityToEntity(
            scannerProp,
            cache.ped,
            GetPedBoneIndex(cache.ped, 28422),
            0.02, 0.025, -0.025,
            -85.0, 180.0, 20.0,
            true, true, true, true, 1, true
        )

        lib.playAnim(cache.ped, "random@hitch_lift", "idle_f", 8.0, 8.0, -1, 49, 0.0, false, 0, false)

        config.inputHelp.show(locale("fingerprint_scanner.input_help"), {
            tildeDelimitedCodes = { "~INPUT_FRONTEND_CANCEL~" },
            mappedValues = { "[ESC]" }
        })
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
        Wait(1250)
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
            return IsEntityPlayingAnim(pedHoldingScanner, "random@hitch_lift", "idle_f", 3)
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

                lib.playAnim(cache.ped, "gestures@f@standing@casual", "gesture_point", 8.0, 8.0, 2000)
                return
            end

            config.notify({ key = "fingerprint_scanner.scan_error" }, "error")
        end
    end
})