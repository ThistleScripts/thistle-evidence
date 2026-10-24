-- =====================================================================
-- Thistle-Lib · Target bridge (CLIENT)
-- ---------------------------------------------------------------------
-- One API over ox_target, qb-target, or a built-in "[E] to interact"
-- fallback when neither is running. Options use the ox_target shape:
--   { label = 'Open', icon = 'fas fa-box', onSelect = fn(data),
--     canInteract = fn(entity, distance, coords) -> bool, items = 'item' }
-- and are converted for qb-target automatically.
--
-- Use it from a consumer either via exports['thistle-lib']:Target…(…) or,
-- with no cross-resource hop, by including it in the consumer manifest:
--   client_scripts { '@thistle-lib/client/target.lua', … }
-- =====================================================================

Thistle = Thistle or {}
Thistle.Target = Thistle.Target or {}

local T = Thistle.Target
local backend          -- 'ox_target' | 'qb-target' | 'fallback'

--- Which target system is in use. Detected on first use, not at load, so
--- the lib doesn't depend on start order with the target resource.
---@return string
function T.Backend()
    if backend then return backend end
    if GetResourceState('ox_target') == 'started' then backend = 'ox_target'
    elseif GetResourceState('qb-target') == 'started' then backend = 'qb-target'
    else backend = 'fallback' end
    return backend
end

-- ---------------------------------------------------------------------
-- qb-target conversion
-- ---------------------------------------------------------------------
local function toQb(options)
    local out = {}
    for _, o in ipairs(options or {}) do
        out[#out + 1] = {
            label = o.label, icon = o.icon, item = o.items,
            canInteract = o.canInteract,
            action = function(entity) if o.onSelect then o.onSelect({ entity = entity }) end end,
        }
    end
    return out
end

local function qbName(name) return name or ('thistle_%d_%d'):format(GetGameTimer(), math.random(1000, 9999)) end

-- ---------------------------------------------------------------------
-- Fallback: nearest zone within range shows "[E] label"; only runs
-- while at least one fallback zone exists.
-- ---------------------------------------------------------------------
local zones, nextId, looping = {}, 0, false

local function fallbackLoop()
    if looping then return end
    looping = true
    CreateThread(function()
        local shown
        while next(zones) do
            local sleep = 750
            local pos = GetEntityCoords(PlayerPedId())
            local nearest, nearestDist
            for _, z in pairs(zones) do
                local c = z.entity and DoesEntityExist(z.entity) and GetEntityCoords(z.entity) or z.coords
                local d = c and #(pos - c) or math.huge
                if d <= z.radius and (not nearestDist or d < nearestDist) then nearest, nearestDist = z, d end
            end
            local opt = nearest and nearest.options[1]
            if opt and (not opt.canInteract or opt.canInteract(nearest.entity, nearestDist, pos)) then
                sleep = 0
                if shown ~= opt.label then
                    if lib and lib.showTextUI then lib.showTextUI(('[E] %s'):format(opt.label or 'Interact')) end
                    shown = opt.label
                end
                if IsControlJustReleased(0, 38) and opt.onSelect then opt.onSelect({ entity = nearest.entity }) end
            elseif shown then
                if lib and lib.hideTextUI then lib.hideTextUI() end
                shown = nil
            end
            Wait(sleep)
        end
        if shown and lib and lib.hideTextUI then lib.hideTextUI() end
        looping = false
    end)
end

local function fallbackAdd(z)
    local c = z.coords
    if type(c) == 'table' then z.coords = vector3(c.x + 0.0, c.y + 0.0, c.z + 0.0) end
    nextId = nextId + 1
    zones[nextId] = z
    fallbackLoop()
    return nextId
end

-- ---------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------

--- Target a local entity. Returns a handle for RemoveEntity.
---@param entity number
---@param options table  list of ox-style options
---@param distance number?  interaction range (default 2.5)
---@return any handle
function T.AddEntity(entity, options, distance)
    local b = T.Backend()
    if b == 'ox_target' then
        for _, o in ipairs(options) do o.distance = o.distance or distance or 2.5 end
        exports.ox_target:addLocalEntity(entity, options)
        return entity
    elseif b == 'qb-target' then
        exports['qb-target']:AddTargetEntity(entity, { options = toQb(options), distance = distance or 2.5 })
        return entity
    end
    return fallbackAdd({ entity = entity, radius = distance or 2.5, options = options })
end

--- Remove a target added with AddEntity.
function T.RemoveEntity(handle)
    local b = T.Backend()
    if b == 'ox_target' then exports.ox_target:removeLocalEntity(handle)
    elseif b == 'qb-target' then exports['qb-target']:RemoveTargetEntity(handle)
    else zones[handle] = nil end
end

--- Sphere zone. data = { coords = vector3, radius?, options, name? }
---@return any id for Remove
function T.AddSphereZone(data)
    local b = T.Backend()
    local radius = data.radius or 1.5
    if b == 'ox_target' then
        return exports.ox_target:addSphereZone({ coords = data.coords, radius = radius, options = data.options })
    elseif b == 'qb-target' then
        local name = qbName(data.name)
        exports['qb-target']:AddCircleZone(name, data.coords, radius, { name = name, useZ = true },
            { options = toQb(data.options), distance = radius + 1.0 })
        return name
    end
    return fallbackAdd({ coords = data.coords, radius = radius, options = data.options })
end

--- Box zone. data = { coords = vector3, size = vector3, rotation?, options, name? }
---@return any id for Remove
function T.AddBoxZone(data)
    local b = T.Backend()
    local size = data.size or vec3(2.0, 2.0, 2.0)
    if b == 'ox_target' then
        return exports.ox_target:addBoxZone({ coords = data.coords, size = size, rotation = data.rotation or 0.0, options = data.options })
    elseif b == 'qb-target' then
        local name = qbName(data.name)
        exports['qb-target']:AddBoxZone(name, data.coords, size.x, size.y, {
            name = name, heading = data.rotation or 0.0,
            minZ = data.coords.z - size.z / 2, maxZ = data.coords.z + size.z / 2,
        }, { options = toQb(data.options), distance = 2.5 })
        return name
    end
    return fallbackAdd({ coords = data.coords, radius = math.max(size.x, size.y) / 2 + 1.0, options = data.options })
end

--- Remove a zone added with AddSphereZone / AddBoxZone.
function T.Remove(id)
    local b = T.Backend()
    if b == 'ox_target' then exports.ox_target:removeZone(id)
    elseif b == 'qb-target' then exports['qb-target']:RemoveZone(id)
    else zones[id] = nil end
end

-- ---------------------------------------------------------------------
-- Exports (thistle-lib only). Handles stay valid across resources because
-- entities and zones are per-client, not per-resource.
-- ---------------------------------------------------------------------
if Thistle.IsLibResource() then
    local S = Thistle.StripSelf
    exports('TargetBackend',      function() return T.Backend() end)
    exports('TargetAddEntity',    function(...) local e, o, d = S(...) return T.AddEntity(e, o, d) end)
    exports('TargetRemoveEntity', function(...) local h = S(...) return T.RemoveEntity(h) end)
    exports('TargetAddSphereZone', function(...) local d = S(...) return T.AddSphereZone(d) end)
    exports('TargetAddBoxZone',   function(...) local d = S(...) return T.AddBoxZone(d) end)
    exports('TargetRemove',       function(...) local id = S(...) return T.Remove(id) end)
end
