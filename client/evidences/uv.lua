-- The UV flashlight (uv_flashlight item). Using it switches a police torch on in the player's hand with a purple beam;
-- evidence caught in the beam shows up (see config.uvLight). Using it again, or losing the item, switches it off.
local config <const> = require "config"
local eventHandler <const> = require "common.events.handler"

local uv = {}

local isOn = false
local torch = nil
local revealedUntil = {} -- evidence (object or entity) -> GetGameTimer() until which it stays visible

local torchModel <const> = `prop_cs_police_torch`
local animDict <const>, animClip <const> = "amb@world_human_security_shine_torch@male@base", "base"
local minDot <const> = math.cos(math.rad(config.uvLight.angle))

-- Where the camera points, which is where the player aims the torch
local function getBeamDirection()
    local rotation <const> = GetGameplayCamRot(2)
    local pitch <const>, yaw <const> = math.rad(rotation.x), math.rad(rotation.z)
    local flat <const> = math.abs(math.cos(pitch))
    return vector3(-math.sin(yaw) * flat, math.cos(yaw) * flat, math.sin(pitch))
end

local function getBeamOrigin()
    return (torch and DoesEntityExist(torch)) and GetEntityCoords(torch) or GetEntityCoords(cache.ped)
end

function uv.isOn()
    return isOn
end

---@param coords vector3
---@return boolean
function uv.isInBeam(coords)
    if not isOn or not coords then
        return false
    end

    local offset <const> = coords - getBeamOrigin()
    local distance <const> = #offset
    if distance > config.uvLight.range then
        return false
    end

    if distance < 1.0 then
        return true
    end

    local direction <const> = getBeamDirection()
    return (offset.x * direction.x + offset.y * direction.y + offset.z * direction.z) / distance >= minDot
end

-- Whether a piece of evidence can be seen: always when UV light isn't required, otherwise while it's in the beam
-- and for config.uvLight.memory ms after.
---@param key any The evidence object or entity, so it stays visible after the beam has passed
---@param coords vector3
---@return boolean
function uv.reveals(key, coords)
    if not config.uvLight.required then
        return true
    end

    local now <const> = GetGameTimer()

    if uv.isInBeam(coords) then
        revealedUntil[key] = now + config.uvLight.memory
        return true
    end

    local visibleUntil <const> = revealedUntil[key]
    return visibleUntil ~= nil and visibleUntil > now
end

local function switchOff()
    if not isOn then
        return
    end

    isOn = false

    if torch and DoesEntityExist(torch) then
        DeleteEntity(torch)
    end
    torch = nil

    StopAnimTask(cache.ped, animDict, animClip, 1.0)
end

local function switchOn()
    if isOn then
        return
    end

    TriggerEvent("ox_inventory:disarm", cache.ped, true)

    lib.requestModel(torchModel)
    local coords <const> = GetEntityCoords(cache.ped)
    torch = CreateObject(torchModel, coords.x, coords.y, coords.z, true, true, false)
    SetModelAsNoLongerNeeded(torchModel)
    AttachEntityToEntity(torch, cache.ped, GetPedBoneIndex(cache.ped, 57005), 0.12, 0.02, -0.02, -80.0, 0.0, 0.0, true, true, false, true, 1, true)

    lib.playAnim(cache.ped, animDict, animClip, 2.0, 2.0, -1, 49)
    isOn = true

    CreateThread(function()
        local nextCheck = 0

        while isOn do
            local origin <const> = getBeamOrigin()
            local direction <const> = getBeamDirection()
            DrawSpotLight(origin.x, origin.y, origin.z, direction.x, direction.y, direction.z, 120, 40, 255, config.uvLight.range + 3.0, 12.0, 0.0, config.uvLight.angle * 1.2, 1.0)
            DisablePlayerFiring(cache.playerId, true)

            -- switch off when the torch is gone, the item was dropped, or the player can't hold it
            if GetGameTimer() > nextCheck then
                nextCheck = GetGameTimer() + 1000

                if not (torch and DoesEntityExist(torch)) or cache.vehicle or config.isPedDead(cache.ped)
                    or exports.ox_inventory:Search("count", "uv_flashlight") < 1 then
                    switchOff()
                    break
                end

                if not IsEntityPlayingAnim(cache.ped, animDict, animClip, 3) then
                    lib.playAnim(cache.ped, animDict, animClip, 2.0, 2.0, -1, 49)
                end

                local now <const> = GetGameTimer()
                for key, visibleUntil in pairs(revealedUntil) do
                    if visibleUntil < now then
                        revealedUntil[key] = nil
                    end
                end
            end

            Wait(0)
        end
    end)
end

exports("uv_flashlight", function(data, slot)
    -- ox_inventory calls this export from its own resource, and switching on loads a model, so do it in a thread
    CreateThread(function()
        if isOn then
            switchOff()
        else
            switchOn()
        end
    end)
end)

eventHandler.onLocal("onResourceStop", function(event)
    if event.arguments[1] == cache.resource then
        switchOff()
    end
end)

return uv
