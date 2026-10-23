-- The UV flashlight: the WEAPON_UVFLASHLIGHT addon weapon (data/weapons), held and swung like the game's flashlight.
-- Right click raises it and switches the blue beam on (held, or toggled with config.uvLight.mode): the player turns to
-- where the camera looks and shines a torch held in the left hand, as the shine-torch pose expects. The weapon in the
-- right hand is hidden meanwhile. Evidence caught in the beam shows up, and
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
local torch <const> = config.uvLight.torch or { model = `prop_cs_police_torch`, bone = 60309, offset = vec3(0.0, 0.0, 0.0), rotation = vec3(0.0, 0.0, 0.0) }
local torchObject = nil -- the torch in the left hand while it's raised

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
    if torchObject and DoesEntityExist(torchObject) then
        return GetEntityCoords(torchObject)
    end

    local weapon <const> = getWeaponEntity()
    return weapon and GetEntityCoords(weapon) or GetEntityCoords(cache.ped)
end

-- The player faces where the camera looks while the torch is raised, so the beam goes the way they face,
-- tilted up or down with the camera since the raised-torch pose can't
local function getBeamDirection()
    local forward <const> = GetEntityForwardVector(cache.ped)
    local flat <const> = vector2(forward.x, forward.y)
    local length <const> = #flat > 0 and #flat or 1.0

    local pitch <const> = math.rad(math.max(minPitch, math.min(maxPitch, GetGameplayCamRot(2).x)))
    local horizontal <const> = math.cos(pitch)

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

local function removeTorchObject()
    if torchObject and DoesEntityExist(torchObject) then
        DeleteObject(torchObject)
    end
    torchObject = nil
end

-- Raised torch: the shine-torch pose on the upper body, so the player can still walk. The pose holds the torch in
-- the left hand, so a torch is put there (config.uvLight.torch) and the flashlight weapon in the right hand is hidden.
local function raiseTorch()
    if cache.vehicle then
        removeTorchObject()
        return
    end

    if not IsEntityPlayingAnim(cache.ped, animation.dict, animation.clip, 3) then
        lib.requestAnimDict(animation.dict)
        TaskPlayAnim(cache.ped, animation.dict, animation.clip, 4.0, 4.0, -1, 49, 0.0, false, false, false)
    end

    if not torchObject or not DoesEntityExist(torchObject) then
        local coords <const> = GetEntityCoords(cache.ped)
        torchObject = CreateObject(lib.requestModel(torch.model), coords.x, coords.y, coords.z, false, false, false)
        SetModelAsNoLongerNeeded(torch.model)
        SetEntityCollision(torchObject, false, false)
        AttachEntityToEntity(torchObject, cache.ped, GetPedBoneIndex(cache.ped, torch.bone),
            torch.offset.x, torch.offset.y, torch.offset.z, torch.rotation.x, torch.rotation.y, torch.rotation.z,
            true, true, false, true, 1, true)
    end

    SetPedCurrentWeaponVisible(cache.ped, false, true, false, false)

    -- Turn to where the camera looks, as when aiming a gun
    SetEntityHeading(cache.ped, GetGameplayCamRot(2).z)
end

local function lowerTorch()
    if IsEntityPlayingAnim(cache.ped, animation.dict, animation.clip, 3) then
        StopAnimTask(cache.ped, animation.dict, animation.clip, 2.0)
    end

    removeTorchObject()
    SetPedCurrentWeaponVisible(cache.ped, true, true, false, false)
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
        removeTorchObject()
    end
end)

return uv
