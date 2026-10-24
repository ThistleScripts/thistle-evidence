-- Tyre marks: braking hard or spinning the wheels leaves a mark matched to the vehicle's model. The game draws the
-- skid itself; the evidence sits where it starts.
local config <const> = require "config"

local settings <const> = config.tyreMarks

local function hasTyres(model)
    return IsThisModelACar(model) or IsThisModelABike(model) or IsThisModelAQuadbike(model)
end

if settings and settings.enabled then
    CreateThread(function()
        local lastSpeed = 0.0
        local lastMarkAt = 0

        while true do
            local vehicle <const> = cache.vehicle
            local driving <const> = vehicle and cache.seat == -1 and hasTyres(GetEntityModel(vehicle))

            if driving then
                local speed <const> = GetEntitySpeed(vehicle)
                local braking <const> = lastSpeed - speed >= settings.brakingDrop and lastSpeed >= settings.minimumSpeed
                local wheelspin <const> = GetVehicleWheelSpeed(vehicle, 2) - speed >= settings.wheelspin and IsVehicleOnAllWheels(vehicle)

                if (braking or wheelspin) and GetGameTimer() - lastMarkAt >= settings.cooldown then
                    lastMarkAt = GetGameTimer()

                    local model <const> = GetEntityModel(vehicle)
                    local coords <const> = GetOffsetFromEntityInWorldCoords(vehicle, 0.0, -1.2, 0.0)
                    local found <const>, groundZ <const> = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z + 1.0, false)

                    if found then
                        TriggerServerEvent("evidences:syncEvidence", "tyre_mark", ("model:%d"):format(model & 0xFFFFFFFF), "atCoords",
                            vector3(coords.x, coords.y, groundZ), {
                                model = GetLabelText(GetDisplayNameFromVehicleModel(model)),
                                heading = GetEntityHeading(vehicle)
                            })
                    end
                end

                lastSpeed = speed
            else
                lastSpeed = 0.0
            end

            Wait(driving and 150 or 1000)
        end
    end)
end
