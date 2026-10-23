local config <const> = require "config"
local utils <const> = require "client.evidences.utils"

local forensicKitCheckedAt, forensicKitPresent = 0, false

-- ox_inventory's Search is an export call, so don't repeat it every frame for every bullet
local function hasForensicKit()
    if GetGameTimer() - forensicKitCheckedAt > 500 then
        forensicKitCheckedAt = GetGameTimer()
        forensicKitPresent = exports.ox_inventory:Search("count", "forensic_kit") > 0
    end

    return forensicKitPresent
end

-- Where the shot came from. Bullets in vehicles and props store it relative to the entity,
-- so the path still points the right way after the vehicle has moved.
local function getShooterCoords(point, data)
    local offset <const> = data.shooterOffset
    if offset and point.entity and DoesEntityExist(point.entity) then
        return GetOffsetFromEntityInWorldCoords(point.entity, offset.x, offset.y, offset.z)
    end

    return data.shooterCoords
end

-- The bullet's path: a line from the bullet back to where it was fired from, with a dot at the shooter's end
local function drawBulletPath(bulletCoords, shooterCoords)
    DrawLine(bulletCoords.x, bulletCoords.y, bulletCoords.z, shooterCoords.x, shooterCoords.y, shooterCoords.z, 255, 0, 0, 200)
    DrawMarker(28, shooterCoords.x, shooterCoords.y, shooterCoords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.05, 0.05, 0.05, 255, 0, 0, 200, false, false, 2, false, nil, nil, false)
end

local function createMetadata(evidenceType, data, coords, holder)
    local door <const> = (holder and holder.door) and locale(string.format("evidences.information.doors.%s", tostring(holder.door))) or nil
    local seat <const> = (holder and holder.seat) and locale(string.format("evidences.information.seats.%s", tostring(holder.seat))) or nil

    local additionalData = locale("evidences.information.at_coords")
    if (data.plate and (door or seat)) then
        additionalData = locale("evidences.information.in_vehicle", door or seat, data.plate)
    elseif (data.plate and (not (door or seat))) then
        additionalData = locale("evidences.information.at_vehicle", data.plate)
    elseif (holder and holder.player) then
        additionalData = locale("evidences.information.at_player")
    end

    local metadata = {
        createdAt = data.createdAt,
        information = {
            collectionTime = utils.getFormatedDateTime(),
            crimeScene = utils.getStreetName(coords),
            additionalData = additionalData
        }
    }

    -- Details for ballistics evidences
    metadata["ballistics"] = {
        weaponType = data.weaponType,
        weaponImage = data.weaponImage,
        serial = data.serial,
        imperfections = data.imperfections,
        type = data.type
    }

    return metadata
end

return {
    -- biometric evidences
    fingerprint = {
        target = {
            collect = {
                label = locale("evidences.fingerprint.collecting_label"),
                icon = "fa-solid fa-fingerprint",
                requiredItem = "forensic_kit",
                collectedItem = "collected_fingerprint",
                createMetadata = createMetadata
            },
            destroy = {
                label = locale("evidences.fingerprint.destroying_label"),
                icon = "fa-solid fa-fingerprint",
                requiredItem = config.destroyItems.fingerprint
            }
        },
        visualize = {}
    },
    blood = {
        target = {
            collect = {
                label = locale("evidences.blood.collecting_label"),
                icon = "fa-solid fa-droplet",
                requiredItem = "forensic_kit",
                collectedItem = "collected_blood",
                createMetadata = createMetadata
            },
            destroy = {
                label = locale("evidences.blood.destroying_label"),
                icon = "fa-solid fa-droplet",
                requiredItem = config.destroyItems.blood
            }
        },
        visualize = {
            show = function(point)
                if not point.decal then
                    point.decal = AddDecal(
                        1010,
                        point.coords.x, point.coords.y, point.coords.z,
                        0.0, 0.0, -1.0,
                        0.0, 1.0, 0.0,
                        0.65 /*width*/, 0.65 /*height*/,
                        0.2, 0.0, 0.0, 1.0,
                        -1 /*timeout*/,
                        true /*isLongRange*/,
                        false /*isDynamic*/,
                        true /*useComplexColn*/)
                end
            end,
            hide = function(point)
                if point.decal then
                    if IsDecalAlive(point.decal) then
                        RemoveDecal(point.decal)
                    end
                    point.decal = nil
                end
            end
        }
    },
    saliva = {
        target = {
            collect = {
                label = locale("evidences.saliva.collecting_label"),
                icon = "fa-solid fa-gun",
                requiredItem = "forensic_kit",
                collectedItem = "collected_saliva",
                createMetadata = createMetadata
            },
            destroy = {
                label = locale("evidences.saliva.destroying_label"),
                icon = "fa-solid fa-gun",
                requiredItem = config.destroyItems.saliva
            }
        },
        visualize = {}
    },
    -- ballistics evidences
    magazine = {
        target = {
            collect = {
                label = locale("evidences.magazine.collecting_label"),
                icon = "fa-solid fa-gun",
                requiredItem = "forensic_kit",
                collectedItem = "collected_magazine",
                createMetadata = createMetadata
            },
            destroy = {
                label = locale("evidences.magazine.destroying_label"),
                icon = "fa-solid fa-gun",
                requiredItem = config.destroyItems.magazine
            }
        },
        visualize = {
            show = function(point, data)
                local model <const> = data.magazineModel
                local rotation <const> = data.magazineRotation

                if model and rotation then
                    for _, nearbyObject in pairs(lib.getNearbyObjects(point.coords, 5)) do
                        nearbyObject = nearbyObject.object
                        if GetEntityModel(nearbyObject) == model then
                            if not DoesEntityBelongToThisScript(nearbyObject) then
                                if not IsEntityAttached(nearbyObject) then
                                    SetEntityAsMissionEntity(nearbyObject)
                                    DeleteObject(nearbyObject)
                                end
                            end
                        end
                    end

                    lib.requestModel(model)

                    point.entity = CreateObject(model, point.coords.x, point.coords.y, point.coords.z, false, false, false)
                    SetEntityRotation(point.entity, rotation.x, rotation.y, rotation.z)
                    SetEntityCoords(point.entity, point.coords.x, point.coords.y, point.coords.z)
                    SetEntityCollision(point.entity, false, false)
                    SetModelAsNoLongerNeeded(model)
                end
            end,
            hide = function(point)
                if point.entity then
                    DeleteObject(point.entity)
                end
            end
        }
    },
    casing = {
        target = {
            collect = {
                label = locale("evidences.casing.collecting_label"),
                icon = "fa-solid fa-gun",
                requiredItem = "forensic_kit",
                collectedItem = "collected_casing",
                createMetadata = createMetadata
            },
            destroy = {
                label = locale("evidences.casing.destroying_label"),
                icon = "fa-solid fa-gun",
                requiredItem = config.destroyItems.casing
            }
        },
        visualize = {
            show = function(point, data)
                local model <const> = `prop_sgun_casing`
                lib.requestModel(model)

                point.entity = CreateObject(model, point.coords.x, point.coords.y, point.coords.z, false, false, false)
                SetEntityCoords(point.entity, point.coords.x, point.coords.y, point.coords.z)
                SetEntityRotation(point.entity, 0.0, 0.0, math.random() * 360.0)
                SetEntityCollision(point.entity, false, false)
                SetModelAsNoLongerNeeded(model)
            end,
            hide = function(point)
                if point.entity then
                    DeleteObject(point.entity)
                end
            end
        }
    },
    bullet = {
        target = {
            collect = {
                label = locale("evidences.bullet.collecting_label"),
                icon = "fa-solid fa-gun",
                requiredItem = "forensic_kit",
                collectedItem = "collected_bullet",
                createMetadata = createMetadata
            },
            destroy = {
                label = locale("evidences.bullet.destroying_label"),
                icon = "fa-solid fa-gun",
                requiredItem = config.destroyItems.bullet
            }
        },
        visualize = {
            show = function(point, data, no_thread)
                if no_thread then
                    -- called every frame by the entity evidence display thread
                    local shooterCoords <const> = getShooterCoords(point, data)
                    if shooterCoords and hasForensicKit() then
                        drawBulletPath(point.coords, shooterCoords)
                    end

                    return
                end

                local shooterCoords <const> = getShooterCoords(point, data)
                if not shooterCoords or not point.coords then
                    return
                end

                point.isThreadRunning = true

                CreateThread(function()
                    while point.isThreadRunning do
                        if hasForensicKit() and exports.ox_target:isActive() then
                            drawBulletPath(point.coords, shooterCoords)
                        end

                        Wait(0)
                    end
                end)
            end,
            hide = function(point)
                point.isThreadRunning = false
            end
        }
    },
    gunshot_residue = {
        target = {
            collect = {
                label = locale("evidences.gunshot_residue.collecting_label"),
                icon = "fa-solid fa-gun",
                requiredItem = "forensic_kit",
                collectedItem = "collected_gunshot_residue",
                createMetadata = createMetadata
            },
            destroy = {
                label = locale("evidences.gunshot_residue.destroying_label"),
                icon = "fa-solid fa-gun",
                requiredItem = config.destroyItems.gunshot_residue
            }
        },
        visualize = {}
    }
}