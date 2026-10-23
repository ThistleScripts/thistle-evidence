-- While the UV light is on, evidence nearby that isn't in the beam yet glows faintly (config.uvLight.hints), so
-- officers know where to point it. Switching the light off or putting the flashlight away removes the hints.
-- Evidence the beam has shown that has nothing else to see (a bullet in a wall, saliva, traces on a vehicle)
-- glows brightly for as long as it stays revealed, so officers can find it to target it.
-- Bullets in vehicles and props also show their path back to the shooter while the beam is on them.
local config <const> = require "config"
local evidenceTypes <const> = require "common.evidence_types"
local bulletPath <const> = require "client.evidences.bullet_path"
local uv <const> = require "client.evidences.uv"

local settings <const> = config.uvLight.hints or {}
local range <const> = settings.range or 15.0
local size <const> = settings.size or 0.035
local alpha <const> = settings.alpha or 110

local doorHandles <const> = {
    [0] = "handle_dside_f",
    [1] = "handle_pside_f",
    [2] = "handle_dside_r",
    [3] = "handle_pside_r"
}

local stateKeys = {}
for evidenceType in pairs(evidenceTypes) do
    stateKeys[evidenceType] = ("evidences:%s"):format(evidenceType)
end

-- Evidence held by a vehicle or prop, as points that follow the entity: { entity, offset?, bone?, bullet? }
local function addEntityPoints(points, entity)
    -- Evidence is only ever kept on networked entities; local ones (like the casing props this script spawns) have none
    if not NetworkGetEntityIsNetworked(entity) then
        return
    end

    local state <const> = Entity(entity).state

    for evidenceType, key in pairs(stateKeys) do
        for _, data in pairs(state[key] or {}) do
            if data.coords then
                -- at a spot on the entity (bullet holes, blood on a prop)
                for offset, specificData in pairs(data.coords) do
                    points[#points + 1] = {
                        entity = entity,
                        offset = offset,
                        bullet = evidenceType == "bullet" and specificData or nil
                    }
                end
            elseif data.doorIds then
                for doorId in pairs(data.doorIds) do
                    local bone <const> = GetEntityBoneIndexByName(entity, doorHandles[tonumber(doorId)] or "")
                    if bone ~= -1 then
                        points[#points + 1] = { entity = entity, bone = bone }
                    end
                end
            elseif not data.seatIds then
                -- on the entity as a whole; seats are exempt from UV light (they can't be seen from outside)
                points[#points + 1] = { entity = entity }
            end
        end
    end
end

local function getPointCoords(point)
    if not DoesEntityExist(point.entity) then
        return nil
    end

    if point.offset then
        return GetOffsetFromEntityInWorldCoords(point.entity, point.offset.x, point.offset.y, point.offset.z)
    elseif point.bone then
        return GetWorldPositionOfEntityBone(point.entity, point.bone)
    end

    return GetEntityCoords(point.entity)
end

local function drawHint(coords, colour)
    DrawMarker(28, coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, size, size, size, colour.r, colour.g, colour.b, alpha, false, false, 2, false, nil, nil, false)
end

-- Revealed evidence: a bright dot, a little bigger than a hint
local function drawRevealed(coords, colour)
    local revealedSize <const> = size * 1.6
    DrawMarker(28, coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, revealedSize, revealedSize, revealedSize, colour.r, colour.g, colour.b, 230, false, false, 2, false, nil, nil, false)
end

-- Ground evidence the game shows nothing for once revealed (blood leaves a decal, casings and magazines a prop)
local function hasNoVisual(evidence)
    return evidence.evidenceType == "bullet" or not (evidence.options.visualize and evidence.options.visualize.show)
end

local groundHints = {} -- vector3s of ground evidence not showing yet
local groundRevealed = {} -- vector3s of revealed ground evidence with nothing else to see
local entityPoints = {}

-- Finding the evidence is too slow for every frame, so it's done a few times a second
local function scan()
    local pedCoords <const> = GetEntityCoords(cache.ped)

    local ground, revealed = {}, {}
    for _, evidence in ipairs(EvidencesAtCoords or {}) do
        if #(pedCoords - evidence.coords) <= range then
            if not evidence.visible then
                ground[#ground + 1] = evidence.coords
            elseif hasNoVisual(evidence) then
                revealed[#revealed + 1] = evidence.coords
            end
        end
    end

    local points = {}
    for _, vehicle in ipairs(lib.getNearbyVehicles(pedCoords, range, true)) do
        addEntityPoints(points, vehicle.vehicle)
    end
    for _, object in ipairs(lib.getNearbyObjects(pedCoords, range)) do
        addEntityPoints(points, object.object)
    end

    groundHints, groundRevealed, entityPoints = ground, revealed, points
end

CreateThread(function()
    while true do
        if uv.wasOnRecently() then
            local colour <const> = uv.getColour()
            local nextScan = 0

            while uv.wasOnRecently() do
                local isOn <const> = uv.isOn()

                if GetGameTimer() >= nextScan then
                    nextScan = GetGameTimer() + 300
                    scan()
                end

                if isOn and settings.enabled ~= false then
                    for _, coords in ipairs(groundHints) do
                        drawHint(coords, colour)
                    end
                end

                for _, coords in ipairs(groundRevealed) do
                    drawRevealed(coords, colour)
                end

                for _, point in ipairs(entityPoints) do
                    local coords <const> = getPointCoords(point)

                    if coords then
                        local inBeam <const> = uv.isInBeam(coords)

                        if inBeam or (config.uvLight.required and uv.isRevealed(point.entity)) then
                            drawRevealed(coords, colour)
                        elseif isOn and settings.enabled ~= false then
                            drawHint(coords, colour)
                        end

                        if inBeam and point.bullet then
                            local shooterCoords <const> = bulletPath.getShooterCoords({ coords = coords, entity = point.entity }, point.bullet)
                            if shooterCoords then
                                bulletPath.draw(coords, shooterCoords)
                            end
                        end
                    end
                end

                Wait(0)
            end

            groundHints, groundRevealed, entityPoints = {}, {}, {}
        end

        Wait(250)
    end
end)
