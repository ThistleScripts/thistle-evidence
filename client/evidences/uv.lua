-- The UV flashlight: the WEAPON_UVFLASHLIGHT addon weapon (data/weapons), held and swung like the game's flashlight.
-- Right click switches the blue beam on (held, or toggled with config.uvLight.mode). The beam shines from the
-- flashlight where the camera looks, and the player can still walk and strafe. Evidence caught in the beam shows up, and client/evidences/uv_hints.lua draws faint hints of the evidence
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

-- The beam shines where the camera looks
local function getBeamDirection()
    local rotation <const> = GetGameplayCamRot(2)
    local pitch <const> = math.rad(rotation.x)
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

-- A lit area, such as a UV lamp: evidence inside it shows as if in the beam. With a direction, only a cone of
-- the given angle (degrees from the centre) is lit, like the flashlight's beam.
---@param id any
---@param coords vector3
---@param radius number
---@param direction vector3?
---@param angle number?
function uv.setArea(id, coords, radius, direction, angle)
    areas[id] = {
        coords = coords,
        radius = radius,
        direction = direction,
        minDot = direction and math.cos(math.rad(angle or 35.0)) or nil
    }
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
        local offset <const> = coords - area.coords
        local distance <const> = #offset

        if distance <= area.radius then
            if not area.direction or distance < 1.0 then
                return true
            end

            local direction <const> = area.direction
            if (offset.x * direction.x + offset.y * direction.y + offset.z * direction.z) / distance >= area.minDot then
                return true
            end
        end
    end

    return false
end

-- Whether the beam or a UV lamp shines on these coords right now
---@param coords vector3
---@return boolean
function uv.isLit(coords)
    return uv.isInBeam(coords) or uv.isInArea(coords)
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

    if uv.isLit(coords) then
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

local function setLight(on)
    if isOn == on then
        return
    end

    isOn = on
    lastOnAt = GetGameTimer()
    PlaySoundFrontend(-1, "SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)
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
