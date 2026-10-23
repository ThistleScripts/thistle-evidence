-- Ghost-preview placement for laptops and microscopes: aim to move the object, ENTER to place, ESC to cancel.
local config <const> = require "config"
local eventHandler <const> = require "common.events.handler"

local placement = {}
local tempObject = nil

---@param model string|number
---@param inputHelpText string Placement help with placeholders for the accept key, a line break and the cancel key
---@return vector4|nil coords Where the object was placed, or nil when cancelled
function placement.place(model, inputHelpText)
    if tempObject then
        return nil
    end

    local coords <const> = GetEntityCoords(cache.ped)
    tempObject = CreateObject(lib.requestModel(model), coords.x, coords.y, coords.z + 1.5, false, true, false)

    SetEntityHeading(tempObject, 0)
    SetEntityAlpha(tempObject, 150)
    SetEntityCollision(tempObject, false, false)
    FreezeEntityPosition(tempObject, true)

    config.inputHelp.show(inputHelpText, {
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

    return confirmed and finalCoords or nil
end

eventHandler.onLocal("onResourceStop", function(event)
    if event.arguments[1] == cache.resource and tempObject then
        config.inputHelp.hide()
        DeleteObject(tempObject)
    end
end)

return placement
