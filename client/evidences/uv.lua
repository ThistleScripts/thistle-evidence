-- The UV flashlight: the WEAPON_UVFLASHLIGHT addon weapon (data/weapons), held and swung like the game's flashlight.
-- Right click switches the blue beam on and off (or holds it on, config.uvLight.mode); evidence caught in the beam
-- shows up, and client/evidences/uv_hints.lua draws faint hints of the evidence around while it's on.
local config <const> = require "config"
local eventHandler <const> = require "common.events.handler"

local uv = {}

local isEquipped = false
local equipCount = 0 -- so a quick unequip and equip doesn't leave two threads running
local isOn = false
local revealedUntil = {} -- evidence (object or entity) -> GetGameTimer() until which it stays visible

local minDot <const> = math.cos(math.rad(config.uvLight.angle))
local colour <const> = config.uvLight.colour or { r = 60, g = 90, b = 255 }

AddTextEntry("WT_UVFLASHLIGHT", "UV Flashlight") -- the weapon's name on the weapon wheel and HUD

local function isUvFlashlight(weapon)
    return weapon ~= nil and weapon.name == "WEAPON_UVFLASHLIGHT"
end

local function normalise(vector)
    local length <const> = #vector
    return length > 0 and vector / length or vector
end

-- The light points where the camera looks
local function getBeamDirection()
    local rotation <const> = GetGameplayCamRot(2)
    local pitch <const>, yaw <const> = math.rad(rotation.x), math.rad(rotation.z)
    local flat <const> = math.abs(math.cos(pitch))
    return vector3(-math.sin(yaw) * flat, math.cos(yaw) * flat, math.sin(pitch))
end

local function getBeamOrigin()
    local weapon <const> = GetCurrentPedWeaponEntityIndex(cache.ped)
    return (weapon ~= 0 and DoesEntityExist(weapon)) and GetEntityCoords(weapon) or GetEntityCoords(cache.ped)
end

function uv.isOn()
    return isOn
end

---@return { r: integer, g: integer, b: integer }
function uv.getColour()
    return colour
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

local function cleanUpRevealed()
    local now <const> = GetGameTimer()
    for key, visibleUntil in pairs(revealedUntil) do
        if visibleUntil < now then
            revealedUntil[key] = nil
        end
    end
end

local function setLight(on)
    if isOn ~= on then
        isOn = on
        PlaySoundFrontend(-1, "SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)
    end
end

local function unequip()
    isEquipped = false
    isOn = false
end

-- While the flashlight is in hand, right click (the aim key, kept from aiming the baton) works the light
local function equip()
    if isEquipped then
        return
    end

    isEquipped = true
    equipCount += 1
    local current <const> = equipCount

    CreateThread(function()
        local hold <const> = config.uvLight.mode == "hold"
        local nextCleanup = 0

        while isEquipped and equipCount == current do
            DisableControlAction(0, 25, true)

            if hold then
                setLight(IsDisabledControlPressed(0, 25) and not IsNuiFocused())
            elseif IsDisabledControlJustPressed(0, 25) and not IsNuiFocused() then
                setLight(not isOn)
            end

            if isOn then
                local origin <const> = getBeamOrigin()
                local direction <const> = getBeamDirection()
                DrawSpotLight(origin.x, origin.y, origin.z, direction.x, direction.y, direction.z, colour.r, colour.g, colour.b, config.uvLight.range + 3.0, 12.0, 0.0, config.uvLight.angle * 1.2, 1.0)
            end

            if GetGameTimer() > nextCleanup then
                nextCleanup = GetGameTimer() + 5000
                cleanUpRevealed()
            end

            Wait(0)
        end
    end)
end

-- ox_inventory tells us whenever the equipped weapon changes (nil when holstered)
AddEventHandler("ox_inventory:currentWeapon", function(weapon)
    if isUvFlashlight(weapon) then
        equip()
    else
        unequip()
    end
end)

CreateThread(function()
    if isUvFlashlight(exports.ox_inventory:getCurrentWeapon()) then
        equip()
    end
end)

eventHandler.onLocal("onResourceStop", function(event)
    if event.arguments[1] == cache.resource then
        unequip()
    end
end)

return uv
