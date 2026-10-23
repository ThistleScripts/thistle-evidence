-- The UV flashlight: GTA's flashlight weapon (WEAPON_FLASHLIGHT) with metadata type "uv". While it's equipped the
-- game's white beam is switched off and a blue one is drawn instead; evidence caught in it shows up (config.uvLight).
local config <const> = require "config"
local eventHandler <const> = require "common.events.handler"

local uv = {}

local isOn = false
local revealedUntil = {} -- evidence (object or entity) -> GetGameTimer() until which it stays visible

local minDot <const> = math.cos(math.rad(config.uvLight.angle))
local colour <const> = config.uvLight.colour or { r = 60, g = 90, b = 255 }

local function isUvFlashlight(weapon)
    return weapon ~= nil and weapon.name == "WEAPON_FLASHLIGHT" and type(weapon.metadata) == "table" and weapon.metadata.type == "uv"
end

local function normalise(vector)
    local length <const> = #vector
    return length > 0 and vector / length or vector
end

-- Aiming points the light where the camera looks; otherwise it hangs in front of the player, angled at the ground
local function getBeamDirection()
    if IsPlayerFreeAiming(cache.playerId) then
        local rotation <const> = GetGameplayCamRot(2)
        local pitch <const>, yaw <const> = math.rad(rotation.x), math.rad(rotation.z)
        local flat <const> = math.abs(math.cos(pitch))
        return vector3(-math.sin(yaw) * flat, math.cos(yaw) * flat, math.sin(pitch))
    end

    local forward <const> = GetEntityForwardVector(cache.ped)
    return normalise(vector3(forward.x, forward.y, -0.35))
end

local function getBeamOrigin()
    local weapon <const> = GetCurrentPedWeaponEntityIndex(cache.ped)
    return (weapon ~= 0 and DoesEntityExist(weapon)) and GetEntityCoords(weapon) or GetEntityCoords(cache.ped)
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
    isOn = false
end

local function switchOn()
    if isOn then
        return
    end

    isOn = true

    CreateThread(function()
        local nextCleanup = 0

        while isOn do
            -- the game's own white flashlight beam, replaced by the blue one
            SetFlashLightEnabled(cache.ped, false)

            local origin <const> = getBeamOrigin()
            local direction <const> = getBeamDirection()
            DrawSpotLight(origin.x, origin.y, origin.z, direction.x, direction.y, direction.z, colour.r, colour.g, colour.b, config.uvLight.range + 3.0, 12.0, 0.0, config.uvLight.angle * 1.2, 1.0)

            if GetGameTimer() > nextCleanup then
                nextCleanup = GetGameTimer() + 5000

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

-- ox_inventory tells us whenever the equipped weapon changes (nil when holstered)
AddEventHandler("ox_inventory:currentWeapon", function(weapon)
    if isUvFlashlight(weapon) then
        switchOn()
    else
        switchOff()
    end
end)

CreateThread(function()
    if isUvFlashlight(exports.ox_inventory:getCurrentWeapon()) then
        switchOn()
    end
end)

eventHandler.onLocal("onResourceStop", function(event)
    if event.arguments[1] == cache.resource then
        switchOff()
    end
end)

return uv
