local config <const> = require "config"
local eventHandler <const> = require "common.events.handler"
local player <const> = require "client.player"

local tempObject = nil
local isPlacing = false

local function placeLaptop()
    local info <const> = player.getInfo()
    if info.setupIncomplete then
        return
    end

    if not info.permissions.place then
        config.notify({ key = "laptop.notifications.no_permission" }, "error")
        return
    end

    local coords <const> = GetEntityCoords(cache.ped)
    tempObject = CreateObject(lib.requestModel("p_laptop_02_s"), coords.x, coords.y, coords.z + 1.5, false, true, false)

    SetEntityHeading(tempObject, 0)
    SetEntityAlpha(tempObject, 150)
    SetEntityCollision(tempObject, false, false)
    FreezeEntityPosition(tempObject, true)

    config.inputHelp.show(locale("laptop.notifications.input_help"), {
        tildeDelimitedCodes = { "~INPUT_FRONTEND_ACCEPT~", "~n~", "~INPUT_FRONTEND_CANCEL~" },
        mappedValues = { "[ENTER]", "\n", "[ESC]" }
    })

    local confirmed = false

    while true do
        if IsControlPressed(0, 202) then
            break
        end

        if IsControlPressed(0, 201) then
            confirmed = true
            break
        end

        local hit <const>, _, endCoords <const>, _, _ = lib.raycast.fromCamera(339, 4, 10)
        if hit and endCoords ~= vector3(0, 0, 0) then
            SetEntityCoords(tempObject, endCoords.x, endCoords.y, endCoords.z)

            local camCoords <const> = GetGameplayCamCoord()
            local heading <const> = math.deg(math.atan2(camCoords.y - endCoords.y, camCoords.x - endCoords.x))
            SetEntityHeading(tempObject, heading + 90.0)
        end

        Wait(0)
    end

    local x <const>, y <const>, z <const> = table.unpack(GetEntityCoords(tempObject))
    local finalCoords <const> = vector4(x, y, z, GetEntityHeading(tempObject))

    DeleteObject(tempObject)
    tempObject = nil

    config.inputHelp.hide()

    -- The server takes the item, so a laptop can't be placed without one
    if confirmed and Thistle.Callback.Await("evidences:placeLaptop", finalCoords) then
        lib.playAnim(cache.ped, "mp_common", "givetake1_a")
    end
end

exports("evidence_laptop", function(data, slot)
    if isPlacing then
        return
    end

    -- ox_inventory calls this export from its own resource, so the waiting (permission callback, model load, placement) runs in a thread
    isPlacing = true
    CreateThread(function()
        local success <const>, err <const> = pcall(placeLaptop)
        isPlacing = false

        if not success then
            error(err)
        end
    end)
end)

eventHandler.onLocal("onResourceStop", function(event)
    if event.arguments[1] == cache.resource then
        config.inputHelp.hide()
        DeleteObject(tempObject)
    end
end)
