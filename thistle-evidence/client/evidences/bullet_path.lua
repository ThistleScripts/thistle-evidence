-- A bullet's path: a line from the bullet back to where it was fired from. Drawn only while a UV light points at the
-- bullet (ground bullets in common/evidence_types.lua, bullets in vehicles and props in client/evidences/uv_hints.lua).
local bulletPath = {}

-- Where the shot came from. Bullets in vehicles and props store it relative to the entity,
-- so the path still points the right way after the vehicle has moved.
---@param point { coords: vector3, entity: number? }
---@param data table The bullet's evidence data
---@return vector3?
function bulletPath.getShooterCoords(point, data)
    local offset <const> = data.shooterOffset
    if offset and point.entity and DoesEntityExist(point.entity) then
        return GetOffsetFromEntityInWorldCoords(point.entity, offset.x, offset.y, offset.z)
    end

    return data.shooterCoords
end

-- The line from the bullet to the shooter, with a dot at the shooter's end
---@param bulletCoords vector3
---@param shooterCoords vector3
function bulletPath.draw(bulletCoords, shooterCoords)
    DrawLine(bulletCoords.x, bulletCoords.y, bulletCoords.z, shooterCoords.x, shooterCoords.y, shooterCoords.z, 255, 0, 0, 200)
    DrawMarker(28, shooterCoords.x, shooterCoords.y, shooterCoords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.05, 0.05, 0.05, 255, 0, 0, 200, false, false, 2, false, nil, nil, false)
end

return bulletPath
