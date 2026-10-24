-- Bullets in players: a player hit by a gunshot carries the bullet, matched to the gun's serial number, until it's
-- collected from them (the player Evidence target, client/evidences/evidences.lua). The shooter's client leaves no
-- bullet when it hits a ped (client/evidences/registry/bullet.lua), so this is worked out here from the game's own
-- damage event, which also means no client can put a bullet in someone else.
local api <const> = require "server.evidences.api"

local function getHitEntities(data)
    if type(data.hitGlobalIds) == "table" then
        return data.hitGlobalIds
    end

    return { data.hitGlobalId }
end

AddEventHandler("weaponDamageEvent", function(sender, data)
    local shooter <const> = tonumber(sender)
    if not shooter or type(data) ~= "table" then
        return
    end

    -- only guns ox_inventory manages, and only the gun the shooter is holding
    local weapon <const> = exports.ox_inventory:GetCurrentWeapon(shooter)
    local item <const> = weapon and exports.ox_inventory:Items(weapon.name)
    if not item or not item.ammoname or (GetHashKey(weapon.name) & 0xFFFFFFFF) ~= ((tonumber(data.weaponType) or 0) & 0xFFFFFFFF) then
        return
    end

    -- if the serial number has been filed off, it's stored in imperfections
    local metadata <const> = weapon.metadata or {}
    local serial <const> = metadata.serial or metadata.imperfections
    if not serial then
        return
    end

    for _, netId in ipairs(getHitEntities(data)) do
        local entity <const> = tonumber(netId) and NetworkGetEntityFromNetworkId(netId) or 0

        if entity ~= 0 and DoesEntityExist(entity) and GetEntityType(entity) == 1 and IsPedAPlayer(entity) then
            local victim <const> = NetworkGetEntityOwner(entity)

            if victim and victim > 0 and victim ~= shooter and GetPlayerPed(victim) == entity then
                api.get("bullet", serial):atPlayer(victim, {
                    weaponType = weapon.label,
                    imperfections = serial,
                    type = "bullet"
                })
            end
        end
    end
end)
