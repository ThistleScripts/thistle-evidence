local config <const> = require "config"
local eventHandler <const> = require "common.events.handler"
local evidenceTypes <const> = require "common.evidence_types"
local utils <const> = require "client.evidences.utils"
local uv <const> = require "client.evidences.uv"

--[[
AddStateBagChangeHandler(nil, nil, function(bagName, key, value)
    if string.sub(key, 1, #"evidences:") == "evidences:" then
        local function fixKeys(t)
            if type(t) ~= "table" then return t end
            local out = {}
            for k, v in pairs(t) do
                out[tostring(k)] = fixKeys(v)
            end
            return out
        end

        lib.print.debug("statebag changed: " .. bagName .. " " .. key .. " " .. json.encode(fixKeys(value), {indent=true}))
    end
end)
]]

local function getTargetedEvidences(evidences, isTargeted)
    local targets = {}
    
    for owner, data in pairs(evidences or {}) do
        if isTargeted(data) then
            targets[#targets + 1] = {
                owner = owner,
                data = data
            }
        end
    end

    return targets
end

-- atPlayer
local function createPlayerTarget(evidenceType, options, action)
    return {
        name = string.format("%s:player:%s", evidenceType, action),
        label = options.target[action].label,
        icon = options.target[action].icon or "fa-solid fa-magnifying-glass",
        groups = config.permissions.collect or false,
        items = options.target[action].requiredItem or nil,
        menuName = "evidences",
        canInteract = function(entity, distance, coords, name, bone)
            if config.isPedDead(cache.ped) then
                return false
            end
            
            -- get all evidences of evidenceType on the player
            local player <const> = GetPlayerServerId(NetworkGetPlayerIndexFromPed(entity))
            local evidences <const> = Player(player).state[string.format("evidences:%s", evidenceType)] or {}
            return evidences and next(evidences)
        end,
        onSelect = function(data)
            local player <const> = GetPlayerServerId(NetworkGetPlayerIndexFromPed(data.entity))
            local evidences <const> = Player(player).state[string.format("evidences:%s", evidenceType)] or {}
            local targetedEvidences = getTargetedEvidences(evidences, function(_) return true end)

            for _, evidence in pairs(targetedEvidences) do
                local metadata <const> = options.target[action].createMetadata and options.target[action].createMetadata(evidenceType, evidence.data, data.coords, { player = true }) or nil

                local success <const> = Thistle.Callback.Await(string.format("evidences:%s", action), evidenceType, evidence.owner, {
                    fun = "removeFromPlayer",
                    arguments = { player }
                }, metadata)

                if not success then
                    config.notify({ key = string.format("evidences.notifications.common.errors.%s", action) }, "error")
                    return
                end

                lib.playAnim(cache.ped, "mp_common", "givetake1_a")
            end

            config.notify({
                key = string.format("evidences.notifications.%s", action),
                arguments = {locale("evidences.notifications.common.placeholders.at_player")}
            }, "success")
        end
    }
end

-- atVehicleDoor
-- may only be targeted when the player targets the vehicle door from outside
local function createVehicleDoorTarget(evidenceType, options, action)
    return {
        name = string.format("%s:vehicle_door:%s", evidenceType, action),
        label = options.target[action].label,
        icon = options.target[action].icon or "fa-solid fa-magnifying-glass",
        groups = config.permissions.collect or false,
        items = options.target[action].requiredItem or nil,
        distance = 2,
        bones = { "door_dside_f", "door_pside_f", "door_dside_r", "door_pside_r" },
        canInteract = function(entity, distance, coords, name, bone)
            if config.isPedDead(cache.ped) then
                return false
            end

            -- traces on vehicles and props only show under UV light (config.uvLight)
            if not uv.reveals(entity, coords) then
                return false
            end

            if cache.vehicle then
                return false
            end

            local targetedDoorId <const> = utils.getTargetedVehicleDoorId(entity, coords)
            if not targetedDoorId then
                return false
            end
            
            -- get all evidences of evidenceType at the targeted vehicle door
            local evidences <const> = Entity(entity).state[string.format("evidences:%s", evidenceType)] or {}
            return #getTargetedEvidences(evidences, function(data)
                return data.doorIds and data.doorIds[targetedDoorId]
            end) > 0
        end,
        onSelect = function(data)
            local targetedDoorId <const> = utils.getTargetedVehicleDoorId(data.entity, data.coords)
            if not targetedDoorId then
                return
            end
            
            -- get all evidences of evidenceType at the targeted vehicle door
            local evidences <const> = Entity(data.entity).state[string.format("evidences:%s", evidenceType)] or {}
            local targetedEvidences <const> = getTargetedEvidences(evidences, function(evidenceData)
                return evidenceData.doorIds and evidenceData.doorIds[targetedDoorId]
            end)

            for _, evidence in pairs(targetedEvidences) do
                local metadata <const> = options.target[action].createMetadata and options.target[action].createMetadata(evidenceType, evidence.data, data.coords, { door = targetedDoorId }) or nil

                local success <const> = Thistle.Callback.Await(string.format("evidences:%s", action), evidenceType, evidence.owner, {
                    fun = "removeFromVehicleDoors",
                    arguments = { VehToNet(data.entity), targetedDoorId }
                }, metadata)

                if not success then
                    config.notify({ key = string.format("evidences.notifications.common.errors.%s", action) }, "error")
                    return
                end

                lib.playAnim(cache.ped, "mp_common", "givetake1_a")
            end

            config.notify({
                key = string.format("evidences.notifications.%s", action),
                arguments = {locale("evidences.notifications.common.placeholders.at_vehicle_door")}
            }, "success")
        end
    }
end

-- atVehicleSeat
-- may only be targeted when the player targets the vehicle from the inside
local function createVehicleSeatTarget(evidenceType, options, action)
    return {
        name = string.format("%s:vehicle_seat:%s", evidenceType, action),
        label = options.target[action].label,
        icon = options.target[action].icon or "fa-solid fa-magnifying-glass",
        groups = config.permissions.collect or false,
        items = options.target[action].requiredItem or nil,
        canInteract = function(entity, distance, coords, name, bone)
            if config.isPedDead(cache.ped) then
                return false
            end

            if distance > 2 then
                return false
            end

            if not cache.vehicle or not cache.seat then
                return false
            end
            
            -- get all evidences of evidenceType at the player's vehicle seat
            local evidences <const> = Entity(cache.vehicle).state[string.format("evidences:%s", evidenceType)] or {}
            return #getTargetedEvidences(evidences, function(data)
                return data.seatIds and data.seatIds[cache.seat]
            end) > 0
        end,
        onSelect = function(data)
            -- get all evidences of evidenceType at the player's vehicle seat
            local evidences <const> = Entity(cache.vehicle).state[string.format("evidences:%s", evidenceType)] or {}
            local targetedEvidences <const> = getTargetedEvidences(evidences, function(evidenceData)
                return evidenceData.seatIds and evidenceData.seatIds[cache.seat]
            end)

            for _, evidence in pairs(targetedEvidences) do
                local metadata <const> = options.target[action].createMetadata and options.target[action].createMetadata(evidenceType, evidence.data, data.coords, { seat = cache.seat }) or nil

                local success <const> = Thistle.Callback.Await(string.format("evidences:%s", action), evidenceType, evidence.owner, {
                    fun = "removeFromVehicleSeats",
                    arguments = { VehToNet(cache.vehicle), cache.seat }
                }, metadata)

                if not success then
                    config.notify({ key = string.format("evidences.notifications.common.errors.%s", action) }, "error")
                    return
                end

                lib.playAnim(cache.ped, (cache.seat == -1 and "veh@helicopter@ds@base" or "veh@helicopter@ps@base"), "lean_forward_idle")
            end

            config.notify({
                key = string.format("evidences.notifications.%s", action),
                arguments = {locale("evidences.notifications.common.placeholders.at_vehicle_seat")}
            }, "success")
        end
    }
end

-- atEntity
local function createEntityTarget(evidenceType, options, action)
    return {
        name = string.format("%s:entity:%s", evidenceType, action),
        label = options.target[action].label,
        icon = options.target[action].icon or "fa-solid fa-magnifying-glass",
        groups = config.permissions.collect or false,
        items = options.target[action].requiredItem or nil,
        canInteract = function(entity, distance, coords, name, bone)
            if config.isPedDead(cache.ped) then
                return false
            end

            -- traces on vehicles and props only show under UV light (config.uvLight)
            if not uv.reveals(entity, coords) then
                return false
            end

            if distance > 2 then
                return false
            end

            if not entity or not DoesEntityExist(entity) then
                return false
            end

            -- get all evidences of evidenceType on the entity
            local evidences <const> = Entity(entity).state[string.format("evidences:%s", evidenceType)] or {}
            return #getTargetedEvidences(evidences, function(data)
                return not data.seatIds and not data.doorIds and not data.coords
            end) > 0
        end,
        onSelect = function(data)
            -- get all evidences of evidenceType on the entity
            local evidences <const> = Entity(data.entity).state[string.format("evidences:%s", evidenceType)] or {}
            local targetedEvidences <const> = getTargetedEvidences(evidences, function(evidenceData)
                return not evidenceData.seatIds and not evidenceData.doorIds
            end)

            for _, evidence in pairs(targetedEvidences) do
                local metadata <const> = options.target[action].createMetadata and options.target[action].createMetadata(evidenceType, evidence.data, data.coords) or nil

                local success <const> = Thistle.Callback.Await(string.format("evidences:%s", action), evidenceType, evidence.owner, {
                    fun = "removeFromEntity",
                    arguments = { NetworkGetNetworkIdFromEntity(data.entity) }
                }, metadata)

                if not success then
                    config.notify({ key = string.format("evidences.notifications.common.errors.%s", action) }, "error")
                    return
                end

                lib.playAnim(cache.ped, "mp_common", "givetake1_a")
            end

            config.notify({
                key = string.format("evidences.notifications.%s", action),
                arguments = {locale("evidences.notifications.common.placeholders.at_entity")}
            }, "success")
        end
    }
end

-- atRelativeEntityCoords
local isThreadRunning = false
local targettedRelativeEvidenceCoords = nil
local startDisplayThread

local function createRelativeEntityCoordsTarget(evidenceType, options, action)
    return {
        name = string.format("%s:relative_entity:%s", evidenceType, action),
        label = options.target[action].label,
        icon = options.target[action].icon or "fa-solid fa-magnifying-glass",
        groups = config.permissions.collect or false,
        items = options.target[action].requiredItem or nil,
        canInteract = function(entity, distance, coords, name, bone)
            if config.isPedDead(cache.ped) then
                return false
            end

            -- traces on vehicles and props only show under UV light (config.uvLight)
            if not uv.reveals(entity, coords) then
                return false
            end

            if distance > 5 then
                return false
            end

            if not entity or not DoesEntityExist(entity) then
                return false
            end

            if not isThreadRunning then
                startDisplayThread(entity)
            end

            local evidences <const> = Entity(entity).state[string.format("evidences:%s", evidenceType)] or {}

            local test = #getTargetedEvidences(evidences, function(data)
                for localEvidenceCoords, _ in pairs(data.coords or {}) do
                    local globalEvidenceCoords <const> = GetOffsetFromEntityInWorldCoords(entity, localEvidenceCoords.x, localEvidenceCoords.y, localEvidenceCoords.z)
                    local evidenceTargetted <const> = #(coords - globalEvidenceCoords) < 0.1
                    targettedRelativeEvidenceCoords = evidenceTargetted and localEvidenceCoords or nil
                    
                    if evidenceTargetted then
                        return evidenceTargetted
                    end
                end
                
                return false
            end) > 0
            
            return test
        end,
        onSelect = function(data)
            -- get all evidences of evidenceType on the entity
            local evidences <const> = Entity(data.entity).state[string.format("evidences:%s", evidenceType)] or {}
            local targetedEvidences <const> = getTargetedEvidences(evidences, function(evidenceData)
                return evidenceData.coords and evidenceData.coords[targettedRelativeEvidenceCoords]
            end)

            for _, evidence in pairs(targetedEvidences) do
                local metadata <const> = options.target[action].createMetadata and options.target[action].createMetadata(evidenceType, evidence.data, data.coords) or nil

                local success <const> = Thistle.Callback.Await(string.format("evidences:%s", action), evidenceType, evidence.owner, {
                    fun = "removeFromRelativeEntityCoords",
                    arguments = { NetworkGetNetworkIdFromEntity(data.entity), targettedRelativeEvidenceCoords }
                }, metadata)

                if not success then
                    config.notify({ key = string.format("evidences.notifications.common.errors.%s", action) }, "error")
                    return
                end

                lib.playAnim(cache.ped, "mp_common", "givetake1_a")
            end

            config.notify({
                key = string.format("evidences.notifications.%s", action),
                arguments = {locale("evidences.notifications.common.placeholders.at_entity")}
            }, "success")
        end
    }
end

function startDisplayThread(entity)
    isThreadRunning = true

    CreateThread(function()
        local dict <const>, texture <const> = lib.requestStreamedTextureDict("shared"), "emptydot_32"
        local color <const> = { r = 155, g = 155, b = 155, a = 175 }
        local hover <const> = { r = 98, g = 135, b = 236, a = 255 }

        while exports.ox_target:isActive() and #(GetEntityCoords(cache.ped) - GetEntityCoords(entity)) < 7 do
            for type, options in pairs(evidenceTypes) do
                local typeEvidences <const> = Entity(entity).state[string.format("evidences:%s", type)] or {}
                local relativeEvidences <const> = getTargetedEvidences(typeEvidences, function(data)
                    return data.coords
                end)

                for _, evidence in pairs(relativeEvidences) do
                    for localEvidenceCoords, specificMetadata in pairs(evidence.data.coords) do
                        local globalEvidenceCoords <const> = GetOffsetFromEntityInWorldCoords(entity, localEvidenceCoords.x, localEvidenceCoords.y, localEvidenceCoords.z)
                        local spriteColor = (targettedRelativeEvidenceCoords == localEvidenceCoords) and hover or color

                        SetDrawOrigin(globalEvidenceCoords.x, globalEvidenceCoords.y, globalEvidenceCoords.z)
                        DrawSprite(dict, texture, 0, 0, 0.02, 0.02 * GetAspectRatio(false), 0, spriteColor.r, spriteColor.g, spriteColor.b, spriteColor.a)

                        options.visualize.show({ coords = globalEvidenceCoords, entity = entity }, specificMetadata, true)
                    end
                end
            end

            ClearDrawOrigin()
            Wait(1)
        end

        SetStreamedTextureDictAsNoLongerNeeded(dict)
        isThreadRunning = false
    end)
end


for evidenceType, options in pairs(evidenceTypes) do
    exports.ox_target:addGlobalPlayer({
        createPlayerTarget(evidenceType, options, "collect"),
        createPlayerTarget(evidenceType, options, "destroy")
    })

    exports.ox_target:addGlobalVehicle({
        createVehicleDoorTarget(evidenceType, options, "collect"),
        createVehicleDoorTarget(evidenceType, options, "destroy")
    })

    exports.ox_target:addGlobalOption({
        createVehicleSeatTarget(evidenceType, options, "collect"),
        createVehicleSeatTarget(evidenceType, options, "destroy")
    })

    exports.ox_target:addGlobalOption({
        createEntityTarget(evidenceType, options, "collect"),
        createEntityTarget(evidenceType, options, "destroy")
    })

    exports.ox_target:addGlobalOption({
        createRelativeEntityCoordsTarget(evidenceType, options, "collect"),
        createRelativeEntityCoordsTarget(evidenceType, options, "destroy")
    })
end

RegisterNetEvent("evidences:sync:atCoords", function(evidenceType, owner, coords, data)
    EvidenceAtCoords:new(evidenceType, owner, coords, data)
end)

eventHandler.onLocal("onResourceStop", function(event)
    if event.arguments[1] == cache.resource then
        local actions <const> = {"collect", "destroy"}

        for evidenceType, _ in pairs(evidenceTypes) do
            for _, action in pairs(actions) do
                exports.ox_target:removeGlobalPlayer(string.format("%s:player:%s", evidenceType, action))
                exports.ox_target:removeGlobalVehicle(string.format("%s:vehicle_door:%s", evidenceType, action))
                exports.ox_target:removeGlobalOption(string.format("%s:vehicle_seat:%s", evidenceType, action))
                exports.ox_target:removeGlobalOption(string.format("%s:entity:%s", evidenceType, action))
                exports.ox_target:removeGlobalOption(string.format("%s:relative_entity:%s", evidenceType, action))
            end
        end
    end
end)


exports("hydrogen_peroxide", function(data, slot)
    local weapon <const> = exports.ox_inventory:getCurrentWeapon()
    if weapon and weapon.slot and weapon.metadata then
        exports.ox_inventory:useItem(data, function(data)
            if weapon.metadata.fingerprint then
                TriggerServerEvent("evidences:syncEvidence", "fingerprint", weapon.metadata["fingerprint"].owner,
                    "removeFromItem", cache.serverId, weapon.slot)
            end

            if weapon.metadata.dna then
                TriggerServerEvent("evidences:syncEvidence", "blood", weapon.metadata["dna"].owner,
                    "removeFromItem", cache.serverId, weapon.slot)
            end
            
            config.notify({
                key = "evidences.notifications.destroy", 
                arguments = { locale("evidences.notifications.common.placeholders.at_weapon") }
            }, "success")
        end)
    end
end)


local shotRayFlags <const> = 1 | 2 | 16 | 64 -- world, vehicles, objects, foliage
local impactRayFlags <const> = shotRayFlags | 4 | 8 -- and peds, so a shot into a player leaves no bullet in the air (bullet.lua ignores peds)
local lastImpactCoords = nil

-- Where the shot landed, traced from the gun rather than the camera so third person and angled shots are right.
-- GTA records the impact a frame or two after the shot, so wait briefly for a new one; fall back to the camera ray.
local function getShotImpact()
    for _ = 1, 3 do
        Wait(0)

        local hasImpact <const>, impactCoords <const> = GetPedLastWeaponImpactCoord(cache.ped)
        if hasImpact and impactCoords ~= lastImpactCoords then
            lastImpactCoords = impactCoords

            local weaponEntity <const> = GetCurrentPedWeaponEntityIndex(cache.ped)
            local muzzle <const> = GetEntityCoords(weaponEntity ~= 0 and weaponEntity or cache.ped)
            local path <const> = impactCoords - muzzle
            local distance <const> = #path

            if distance > 0.3 then
                -- trace a little past the impact point to find the entity that was hit
                local direction <const> = path / distance
                local hit <const>, entityHit <const>, endCoords <const> = lib.raycast.fromCoords(muzzle + direction * 0.3, impactCoords + direction * 0.25, impactRayFlags, 4)

                if hit then
                    return true, entityHit, endCoords
                end

                break
            end
        end
    end

    return lib.raycast.fromCamera(shotRayFlags, 4, 100)
end

CreateThread(function() -- detects shooting
    while true do
        Wait(0)

        if IsPedShooting(cache.ped) then
            local weapon <const> = exports.ox_inventory:getCurrentWeapon()
            if weapon and weapon.ammo and weapon.metadata then -- nil for weapons ox_inventory doesn't manage
                -- resolved in its own thread so waiting for the impact doesn't miss shots in automatic fire
                CreateThread(function()
                    local hit <const>, entityHit <const>, impactCoords <const> = getShotImpact()
                    TriggerEvent("evidences:playerShot", weapon, hit, entityHit, impactCoords)
                end)
            end
        end
    end
end)