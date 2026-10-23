-- The UV flashlight: the WEAPON_UVFLASHLIGHT addon weapon (data/weapons), held and swung like the game's flashlight.
-- Right click points it and switches the blue beam on (held, or toggled with config.uvLight.mode): the right arm, which
-- holds the flashlight, points where the camera looks using GTA Online's pointing gesture, and the player can still walk
-- and strafe. Evidence caught in the beam shows up, and client/evidences/uv_hints.lua draws faint hints of the evidence
-- around while it's on.
local config <const> = require "config"
local eventHandler <const> = require "common.events.handler"

local uv = {}

local isEquipped = false
local equipCount = 0 -- so a quick unequip and equip doesn't leave two threads running
local isOn = false
local lastOnAt = 0
local revealedUntil = {} -- evidence (object or entity) -> GetGameTimer() until which it stays visible
local areas = {} -- lit areas (UV floodlights, client/evidences/floodlights.lua): id -> { coords, radius }

local minDot <const> = math.cos(math.rad(config.uvLight.angle))
local colour <const> = config.uvLight.colour or { r = 60, g = 90, b = 255 }
local isPointing = false

-- How far up and down the arm can point (degrees), as the pointing gesture allows
local minPitch <const>, maxPitch <const> = -70.0, 42.0

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

-- The arm points where the camera looks, so the beam does too
local function getBeamDirection()
    local rotation <const> = GetGameplayCamRot(2)
    local pitch <const> = math.rad(math.max(minPitch, math.min(maxPitch, rotation.x)))
    local yaw <const> = math.rad(rotation.z)
    local horizontal <const> = math.cos(pitch)

    return vector3(-math.sin(yaw) * horizontal, math.cos(yaw) * horizontal, math.sin(pitch))
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

-- A lit area, such as a UV floodlight: evidence inside it shows as if in the beam
---@param id any
---@param coords vector3
---@param radius number
function uv.setArea(id, coords, radius)
    areas[id] = { coords = coords, radius = radius }
end

function uv.removeArea(id)
    areas[id] = nil
end

function uv.hasAreas()
    return next(areas) ~= nil
end

---@param coords vector3
---@return boolean
function uv.isInArea(coords)
    if not coords then
        return false
    end

    for _, area in pairs(areas) do
        if #(coords - area.coords) <= area.radius then
            return true
        end
    end

    return false
end

-- Whether the beam has shown this evidence recently, without checking the beam again
---@param key any
---@return boolean
function uv.isRevealed(key)
    local visibleUntil <const> = revealedUntil[key]
    return visibleUntil ~= nil and visibleUntil > GetGameTimer()
end

-- Whether a piece of evidence can be seen: always when UV light isn't required, otherwise while it's in the beam or
-- a lit area, and for config.uvLight.memory ms after.
---@param key any The evidence object or entity, so it stays visible after the beam has passed
---@param coords vector3
---@return boolean
function uv.reveals(key, coords)
    if not config.uvLight.required then
        return true
    end

    if uv.isInBeam(coords) or uv.isInArea(coords) then
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

-- Pointing: GTA Online's pointing gesture (the task_mp_pointing move network) on the right arm, which holds the
-- flashlight. It only moves the arm, so the player can walk, run and strafe while shining it.
local function point()
    if cache.vehicle then
        return
    end

    local ped <const> = cache.ped

    if not isPointing or not IsTaskMoveNetworkActive(ped) then
        lib.requestAnimDict("anim@mp_point")
        SetPedConfigFlag(ped, 36, true)
        TaskMoveNetworkByName(ped, "task_mp_pointing", 0.5, false, "anim@mp_point", 24)
        RemoveAnimDict("anim@mp_point")
        isPointing = true
    end

    -- Standing still and looking behind: turn round, as the arm can't point backwards
    local relativeHeading = GetGameplayCamRelativeHeading()
    if math.abs(relativeHeading) > 100.0 and GetEntitySpeed(ped) < 0.5 then
        SetEntityHeading(ped, GetGameplayCamRot(2).z)
        relativeHeading = 0.0
    end

    local pitch <const> = (math.max(minPitch, math.min(maxPitch, GetGameplayCamRelativePitch())) - minPitch) / (maxPitch - minPitch)
    local heading <const> = (math.max(-180.0, math.min(180.0, relativeHeading)) + 180.0) / 360.0

    SetTaskMoveNetworkSignalFloat(ped, "Pitch", pitch)
    SetTaskMoveNetworkSignalFloat(ped, "Heading", heading * -1.0 + 1.0)
    SetTaskMoveNetworkSignalBool(ped, "isBlocked", false)
    SetTaskMoveNetworkSignalBool(ped, "isFirstPerson", GetCamViewModeForContext(GetCamActiveViewModeContext()) == 4)
end

local function stopPointing()
    if not isPointing then
        return
    end

    isPointing = false
    local ped <const> = cache.ped

    RequestTaskMoveNetworkStateTransition(ped, "Stop")
    if not IsPedInjured(ped) then
        ClearPedSecondaryTask(ped)
    end
    SetPedConfigFlag(ped, 36, false)
end

local function setLight(on)
    if isOn == on then
        return
    end

    isOn = on
    lastOnAt = GetGameTimer()
    PlaySoundFrontend(-1, "SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)

    if not on then
        stopPointing()
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
                point()

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
