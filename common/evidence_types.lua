local config <const> = require "config"
local utils <const> = require "client.evidences.utils"

local bulletPath <const> = require "client.evidences.bullet_path"
local footprintMarks -- required on first use, like the UV light below (this file also loads on the server)

-- Required on first use: this file is also loaded on the server, where the UV flashlight doesn't exist
local uv
local function isUvLit(coords)
    uv = uv or require "client.evidences.uv"
    return uv.isLit(coords)
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
            distance = 4.0, -- bullets lodge high up in walls, so they can be reached from further away
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
            -- The path back to the shooter only shows while a UV light (the flashlight or a UV lamp) shines on the bullet
            show = function(point, data, no_thread)
                if no_thread then
                    -- called every frame by the entity evidence display thread
                    local shooterCoords <const> = bulletPath.getShooterCoords(point, data)
                    if shooterCoords and isUvLit(point.coords) then
                        bulletPath.draw(point.coords, shooterCoords)
                    end

                    return
                end

                local shooterCoords <const> = bulletPath.getShooterCoords(point, data)
                if not shooterCoords or not point.coords then
                    return
                end

                point.isThreadRunning = true

                CreateThread(function()
                    while point.isThreadRunning do
                        if isUvLit(point.coords) then
                            bulletPath.draw(point.coords, shooterCoords)
                            Wait(0)
                        else
                            Wait(100)
                        end
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
    },
    -- trace evidence: what was left behind, not who (see client/evidences/registry/footprint.lua and tyre_mark.lua)
    footprint = {
        trace = true, -- only ever on the ground, never on a player or vehicle
        target = {
            collect = {
                label = locale("evidences.footprint.collecting_label"),
                icon = "fa-solid fa-shoe-prints",
                requiredItem = "forensic_kit",
                collectedItem = "collected_footprint",
                createMetadata = createMetadata
            },
            destroy = {
                label = locale("evidences.footprint.destroying_label"),
                icon = "fa-solid fa-shoe-prints",
                requiredItem = config.destroyItems.footprint
            }
        },
        visualize = {
            show = function(point, data)
                footprintMarks = footprintMarks or require "client.evidences.footprint_marks"
                footprintMarks.add(point, data)
            end,
            hide = function(point)
                footprintMarks = footprintMarks or require "client.evidences.footprint_marks"
                footprintMarks.remove(point)
            end
        }
    },
    tyre_mark = {
        trace = true,
        target = {
            collect = {
                label = locale("evidences.tyre_mark.collecting_label"),
                icon = "fa-solid fa-camera",
                requiredItem = "forensic_kit",
                collectedItem = "collected_tyre_mark",
                createMetadata = createMetadata
            },
            destroy = {
                label = locale("evidences.tyre_mark.destroying_label"),
                icon = "fa-solid fa-car-burst",
                requiredItem = config.destroyItems.tyre_mark
            }
        },
        visualize = {} -- the game draws skid marks itself; under UV the mark gets the revealed-evidence dot
    }
}