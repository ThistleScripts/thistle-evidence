-- The UV flashlight: the WEAPON_UVFLASHLIGHT addon weapon (data/weapons), held and swung like the game's flashlight.
-- Right click raises it and switches the blue beam on (held, or toggled with config.uvLight.mode): the player turns to
-- where the camera looks and shines the torch from their hand. Evidence caught in the beam shows up, and
-- client/evidences/uv_hints.lua draws faint hints of the evidence around while it's on.
local config <const> = require "config"
local eventHandler <const> = require "common.events.handler"

local uv = {}

local isEquipped = false
local equipCount = 0 -- so a quick unequip and equip doesn't leave two threads running
local isOn = false
local lastOnAt = 0
local revealedUntil = {} -- evidence (object or entity) -> GetGameTimer() until which it stays visible

local minDot <const> = math.cos(math.rad(config.uvLight.angle))
local colour <const> = config.uvLight.colour or { r = 60, g = 90, b = 255 }
local animation <const> = config.uvLight.animation or { dict = "amb@world_human_security_shine_torch@male@base", clip = "base" }

-- How far up and down the torch can be pointed (degrees)
local minPitch <const>, maxPitch <const> = -70.0, 45.0

AddTextEntry("WT_UVFLASHLIGHT", "UV Flashlight") -- the weapon's name on the weapon wheel and HUD

local function isUvFlashlight(weapon)
    return weapon ~= nil and weapon.name == "WEAPON_UVFLASHLIGHT"
end

local function getWeaponEntity()
    local weapon <const> = GetCurrentPedWeaponEntityIndex(cache.ped)
    return (weapon ~= 0 and DoesEntityExist(weapon)) and weapon or nil
end

local function getBeamOrigin()
    local weapon <const> = getWeaponEntity()
    return weapon and GetEntityCoords(weapon) or GetEntityCoords(cache.ped)
end

-- The beam leaves the torch in the direction the hand points it (weapon models point along their X axis),
-- tilted up or down with the camera since the raised-torch pose can't. If the torch points somewhere odd
-- (mid-animation), the player's facing is used instead.
local function getBeamDirection()
    local pedForward <const> = GetEntityForwardVector(cache.ped)
    local flat = vector2(pedForward.x, pedForward.y)

    local weapon <const> = getWeaponEntity()
    if weapon then
        local axis <const> = GetOffsetFromEntityInWorldCoords(weapon, 1.0, 0.0, 0.0) - GetEntityCoords(weapon)
        local axisFlat <const> = vector2(axis.x, axis.y)

        if #axisFlat > 0.2 then
            local normalised <const> = axisFlat / #axisFlat
            if normalised.x * flat.x + normalised.y * flat.y > 0.5 then
                flat = normalised
            end
        end
    end

    local pitch <const> = math.rad(math.max(minPitch, math.min(maxPitch, GetGameplayCamRot(2).x)))
    local horizontal <const> = math.cos(pitch)
    local length <const> = #flat > 0 and #flat or 1.0

    return vector3(flat.x / length * horizontal, flat.y / length * horizontal, math.sin(pitch))
end

function uv.isOn()
    return isOn
end

-- Whether the light is on or was within the last config.uvLight.memory ms, while what it showed is still visible
function uv.wasOnRecently()
    return isOn or GetGameTimer() - lastOnAt < config.uvLight.memory
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

-- Whether the beam has shown this evidence recently, without checking the beam again
---@param key any
---@return boolean
function uv.isRevealed(key)
    local visibleUntil <const> = revealedUntil[key]
    return visibleUntil ~= nil and visibleUntil > GetGameTimer()
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

    if uv.isInBeam(coords) then
        revealedUntil[key] = GetGameTimer() + config.uvLight.memory
        return true
    end

    return uv.isRevealed(key)
end

local function cleanUpRevealed()
    local now <const> = GetGameTimer()
    for key, visibleUntil in pairs(revealedUntil) do
        if visibleUntil < now then
            revealedUntil[key] = nil
        end
    end
end

-- Raised torch: the shine-torch pose on the upper body, so the player can still walk
local function raiseTorch()
    if cache.vehicle then
        return
    end

    if not IsEntityPlayingAnim(cache.ped, animation.dict, animation.clip, 3) then
        lib.requestAnimDict(animation.dict)
        TaskPlayAnim(cache.ped, animation.dict, animation.clip, 4.0, 4.0, -1, 49, 0.0, false, false, false)
    end

    -- Turn to where the camera looks, as when aiming a gun
    SetEntityHeading(cache.ped, GetGameplayCamRot(2).z)
end

local function lowerTorch()
    if IsEntityPlayingAnim(cache.ped, animation.dict, animation.clip, 3) then
        StopAnimTask(cache.ped, animation.dict, animation.clip, 2.0)
    end
end

local function setLight(on)
    if isOn == on then
        return
    end

    isOn = on
    lastOnAt = GetGameTimer()
    PlaySoundFrontend(-1, "SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)

    if not on then
        lowerTorch()
    end
end

local function unequip()
    isEquipped = false
    setLight(false)
end

-- While the flashlight is in hand, right click (the aim key, kept from locking on with the baton) works the light
local function equip()
    if isEquipped then
        return
    end

    isEquipped = true
    equipCount += 1
    local current <const> = equipCount

    CreateThread(function()
        local toggle <const> = config.uvLight.mode == "toggle"
        local nextCleanup = 0

        while isEquipped and equipCount == current do
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 140, true) -- no swinging the torch while shining it
            DisableControlAction(0, 141, true)
            DisableControlAction(0, 142, true)

            if toggle then
                if IsDisabledControlJustPressed(0, 25) and not IsNuiFocused() then
                    setLight(not isOn)
                end
            else
                setLight(IsDisabledControlPressed(0, 25) and not IsNuiFocused())
            end

            if isOn then
                lastOnAt = GetGameTimer()
                raiseTorch()

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
