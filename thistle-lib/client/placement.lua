-- =====================================================================
-- Thistle-Lib · Placement (CLIENT)
-- ---------------------------------------------------------------------
-- In-world picker for positions and props: aim with the camera, adjust,
-- confirm. Used for placing stashes, event objects, checkpoints, spawn
-- points — anything a staff member positions by hand.
--
--   CreateThread(function()
--       local r = Thistle.Placement.Start({ mode = 'prop', model = 'prop_laptop_01a' })
--       if r then print(r.coords.x, r.coords.y, r.coords.z, r.heading) end
--   end)
--
-- Two pickers share one module (only one runs at a time):
--   Start(opts) — ghost model / point picker with rotate, height, model
--                 cycling and radius (World Builder, events).
--   run(opts)   — lightweight raycast point / box / sphere picker
--                 (stashes). See the section near the end of this file.
--
-- Include with client_scripts { '@thistle-lib/client/placement.lua' } or
-- call exports['thistle-lib']:PlacementStart(opts) (yields either way).
-- =====================================================================

Thistle = Thistle or {}
Thistle.Placement = Thistle.Placement or {}

local P = Thistle.Placement
local active = false

local KEYS = {
    confirm = 38,      -- E
    click = 24,        -- left mouse
    cancel = 177,      -- Backspace / Esc
    cancelAlt = 25,    -- right mouse
    rotLeft = 241,     -- scroll up
    rotRight = 242,    -- scroll down
    up = 10,           -- Page Up
    down = 11,         -- Page Down
    prevModel = 174,   -- ←
    nextModel = 175,   -- →
    radiusUp = 172,    -- ↑
    radiusDown = 173,  -- ↓
    self = 47,         -- G
}

-- Weapons, attacks and the weapon wheel would fight the placement controls.
local BLOCKED = { 14, 15, 16, 17, 24, 25, 37, 44, 45, 47, 140, 141, 142, 257, 263 }

local function round(n) return math.floor(n * 100 + 0.5) / 100 end

local function requestModel(model)
    if Thistle.Anim and Thistle.Anim.RequestModel then return Thistle.Anim.RequestModel(model) end
    if not IsModelInCdimage(model) then return false end
    RequestModel(model)
    local deadline = GetGameTimer() + 5000
    while not HasModelLoaded(model) do
        if GetGameTimer() > deadline then return false end
        Wait(10)
    end
    return true
end

-- Ghost preview: a local, see-through prop, ped or vehicle (peds and
-- vehicles can't be created as objects). Returns entity, kind.
local function makeGhost(name, at)
    local model = type(name) == 'number' and name or joaat(name)
    if not requestModel(model) then return nil end
    local kind = IsModelAPed(model) and 'ped' or (IsModelAVehicle(model) and 'vehicle') or 'object'
    local ghost
    if kind == 'vehicle' then
        ghost = CreateVehicle(model, at.x, at.y, at.z, 0.0, false, false)
        SetVehicleDoorsLocked(ghost, 2)
    elseif kind == 'ped' then
        ghost = CreatePed(4, model, at.x, at.y, at.z, 0.0, false, false)
        SetEntityInvincible(ghost, true)
        SetBlockingOfNonTemporaryEvents(ghost, true)
    else
        ghost = CreateObjectNoOffset(model, at.x, at.y, at.z, false, false, false)
    end
    SetModelAsNoLongerNeeded(model)
    SetEntityAlpha(ghost, 170, false)
    SetEntityCollision(ghost, false, false)
    FreezeEntityPosition(ghost, true)
    return ghost, kind
end

-- Camera ray, ignoring the player and the ghost. Returns hit, coords.
local function aim(distance, ignore)
    local from = GetGameplayCamCoord()
    local rot = GetGameplayCamRot(2)
    local rx, rz = math.rad(rot.x), math.rad(rot.z)
    local dir = vector3(-math.sin(rz) * math.abs(math.cos(rx)), math.cos(rz) * math.abs(math.cos(rx)), math.sin(rx))
    local to = from + dir * distance
    local ray = StartExpensiveSynchronousShapeTestLosProbe(from.x, from.y, from.z, to.x, to.y, to.z, -1, ignore or PlayerPedId(), 4)
    local _, hit, coords = GetShapeTestResult(ray)
    return hit == 1 or hit == true, coords
end

local function helpLines(opts, models)
    local lines = { { key = 'E / Click', label = 'Confirm' }, { key = 'Backspace', label = 'Cancel' } }
    if opts.allowSelf ~= false then lines[#lines + 1] = { key = 'G', label = 'Use my position' } end
    if opts.rotate ~= false then lines[#lines + 1] = { key = 'Scroll', label = 'Rotate' } end
    if opts.mode == 'prop' and opts.height ~= false then lines[#lines + 1] = { key = 'PgUp / PgDn', label = 'Height' } end
    if #models > 1 then lines[#lines + 1] = { key = '← / →', label = 'Change model' } end
    if opts.radius then lines[#lines + 1] = { key = '↑ / ↓', label = 'Radius' } end
    return lines
end

local function defaultShowHelp(lines)
    if not (lib and lib.showTextUI) then return end
    local text = {}
    for _, l in ipairs(lines) do text[#text + 1] = ('[%s] %s'):format(l.key, l.label) end
    lib.showTextUI(table.concat(text, '  \n'), { position = 'left-center' })
end
local function defaultHideHelp() if lib and lib.hideTextUI then lib.hideTextUI() end end

--- Run the picker. Yields until the player confirms or cancels, so call it
--- from a thread. Only one placement runs at a time.
---
--- opts (all optional):
---   mode       'point' (marker, default) | 'prop' (ghost of `model`: prop, ped or vehicle)
---   model      prop model name/hash for mode 'prop'
---   models     list of model names the player can cycle with ←/→
---   heading    starting heading (default: player's)
---   radius     show a radius ring the player can resize with ↑/↓
---   minRadius  smallest radius (default 0.5)
---   distance   max aim distance in metres (default 40)
---   requireHit only confirm while aiming at a surface (default false;
---              otherwise falls back to the player's position)
---   startAt    {x,y,z} to teleport the player near before starting
---   colour     { r, g, b, a } for the point marker
---   allowSelf / rotate / height   set false to disable those controls
---   showHelp(lines) / hideHelp()  replace the default ox_lib text UI;
---              lines = { { key = 'E', label = 'Confirm' }, … }
---
--- Ped and vehicle models get a ped / vehicle preview (they can't be
--- created as objects). result.kind is 'object' | 'ped' | 'vehicle'; for
--- peds coords are at the feet (what CreatePed expects), for vehicles the
--- vehicle sits on its wheels.
---
--- Returns { coords = {x,y,z}, heading, model?, kind?, isPed?, radius? } or nil if
--- cancelled (or another placement is already running).
---@param opts table?
---@return table|nil
function P.Start(opts)
    if active then return nil end
    active = true
    opts = opts or {}
    local ped = PlayerPedId()

    if opts.startAt and opts.startAt.x then
        SetPedCoordsKeepVehicle(ped, opts.startAt.x + 0.0, opts.startAt.y + 0.0, opts.startAt.z + 1.0)
        Wait(150)
    end

    local models = opts.models or {}
    local modelIndex = 1
    for i, m in ipairs(models) do if m == opts.model then modelIndex = i end end
    local model = opts.model or models[1]
    local heading = (opts.heading or GetEntityHeading(ped)) + 0.0
    local height = 0.0
    local radius = opts.radius and (opts.radius + 0.0) or nil
    local minRadius = opts.minRadius or 0.5
    local distance = opts.distance or 40.0
    local colour = opts.colour or { r = 168, g = 85, b = 247, a = 200 }
    local ghost, ghostKind
    if opts.mode == 'prop' and model then ghost, ghostKind = makeGhost(model, GetEntityCoords(ped)) end
    local showHelp, hideHelp = opts.showHelp or defaultShowHelp, opts.hideHelp or defaultHideHelp
    local result

    showHelp(helpLines(opts, ghost and models or {}))

    while true do
        for _, c in ipairs(BLOCKED) do DisableControlAction(0, c, true) end
        DisableControlAction(0, KEYS.cancel, true)

        local hit, aimed = aim(distance, ghost or ped)
        local pos
        if opts.allowSelf ~= false and IsDisabledControlPressed(0, KEYS.self) then
            pos, hit = GetEntityCoords(ped), true
        elseif hit then
            pos = aimed
        else
            pos = GetEntityCoords(ped)
        end

        if opts.rotate ~= false then
            if IsDisabledControlJustPressed(0, KEYS.rotLeft) then heading = (heading + 7.5) % 360 end
            if IsDisabledControlJustPressed(0, KEYS.rotRight) then heading = (heading - 7.5) % 360 end
        end
        if ghost and opts.height ~= false then
            if IsControlPressed(0, KEYS.up) then height = height + 0.01 end
            if IsControlPressed(0, KEYS.down) then height = height - 0.01 end
        end
        if radius then
            if IsControlJustPressed(0, KEYS.radiusUp) then radius = radius + 0.5 end
            if IsControlJustPressed(0, KEYS.radiusDown) then radius = math.max(minRadius, radius - 0.5) end
        end
        if ghost and #models > 1 and (IsControlJustPressed(0, KEYS.nextModel) or IsControlJustPressed(0, KEYS.prevModel)) then
            local step = IsControlJustPressed(0, KEYS.nextModel) and 1 or -1
            modelIndex = (modelIndex - 1 + step) % #models + 1
            local swapped, swappedKind = makeGhost(models[modelIndex], pos)
            if swapped then DeleteEntity(ghost); ghost, ghostKind, model = swapped, swappedKind, models[modelIndex] end
        end

        local final
        if ghost and ghostKind == 'vehicle' then
            SetEntityCoordsNoOffset(ghost, pos.x, pos.y, pos.z + 1.0, false, false, false)
            SetEntityHeading(ghost, heading)
            SetVehicleOnGroundProperly(ghost)
            local g = GetEntityCoords(ghost)
            final = vector3(g.x, g.y, g.z + height)
            SetEntityCoordsNoOffset(ghost, final.x, final.y, final.z, false, false, false)
        elseif ghost and ghostKind == 'ped' then
            -- a ped's origin is ~1 m above its feet; `final` is where the feet
            -- stand, which is what CreatePed expects when spawning it later
            final = vector3(pos.x, pos.y, pos.z + height)
            SetEntityCoordsNoOffset(ghost, final.x, final.y, final.z + 1.0, false, false, false)
            SetEntityHeading(ghost, heading)
        elseif ghost then
            SetEntityCoordsNoOffset(ghost, pos.x, pos.y, pos.z, false, false, false)
            SetEntityHeading(ghost, heading)
            PlaceObjectOnGroundProperly(ghost)
            local g = GetEntityCoords(ghost)
            final = vector3(g.x, g.y, g.z + height)
            SetEntityCoordsNoOffset(ghost, final.x, final.y, final.z, false, false, false)
        else
            final = vector3(pos.x, pos.y, pos.z)
            DrawMarker(28, final.x, final.y, final.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                0.12, 0.12, 0.12, colour.r, colour.g, colour.b, colour.a, false, false, 2, false, nil, nil, false)
            if opts.rotate ~= false then
                -- arrow showing the facing direction
                DrawMarker(2, final.x, final.y, final.z + 1.0, 0.0, 0.0, 0.0, 0.0, 180.0, -heading,
                    0.4, 0.4, 0.4, colour.r, colour.g, colour.b, colour.a, false, false, 2, false, nil, nil, false)
            end
        end
        if radius then
            DrawMarker(1, final.x, final.y, final.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                radius * 2.0, radius * 2.0, 1.5, 6, 182, 212, 90, false, false, 2, false, nil, nil, false)
        end

        local confirm = IsDisabledControlJustPressed(0, KEYS.confirm) or IsControlJustPressed(0, KEYS.confirm)
            or IsDisabledControlJustPressed(0, KEYS.click)
        if confirm and (hit or not opts.requireHit) then
            result = {
                coords = { x = round(final.x), y = round(final.y), z = round(final.z) },
                heading = round(heading),
                model = ghost and model or nil,
                kind = ghost and ghostKind or nil,
                isPed = ghost and ghostKind == 'ped' or nil,
                radius = radius and round(radius) or nil,
            }
            break
        end
        if IsDisabledControlJustPressed(0, KEYS.cancel) or IsDisabledControlJustPressed(0, KEYS.cancelAlt) then break end
        Wait(0)
    end

    if ghost and DoesEntityExist(ghost) then DeleteEntity(ghost) end
    hideHelp()
    active = false
    return result
end

--- True while a placement is running.
function P.IsActive() return active end

-- ---------------------------------------------------------------------
-- Raycast placer — Thistle.Placement.run(opts)
-- Aim the camera at a surface, see a live point / box / sphere preview,
-- confirm with E / LMB. Returns { x, y, z, w } or nil. Lighter than Start()
-- (no ghost model); used by Thistle-StashCreator. Hide your NUI and drop
-- NUI focus before calling it, and bring them back afterwards.
-- Also exposes P.raycast, P.camDirection, P.drawBox and P.drawSphere.
-- ---------------------------------------------------------------------
do
    local INTERACT, ATTACK, AIM, CANCEL, PAUSE = 38, 24, 25, 177, 200
    local SCROLL_UP, SCROLL_DOWN, SPRINT = 241, 242, 21

    -- Weapon wheel, attack, aim, melee, cover, phone, pause: blocked while picking.
    local BLOCKED = { 14, 15, 16, 17, 24, 25, 37, 44, 45, 140, 141, 142, 143, 199, 200, 257, 261, 262, 263, 264, 241, 242 }

    local DEFAULT_FLAGS = 1 | 2 | 16 -- world, vehicles, objects (not peds)

    local function ped() return (cache and cache.ped) or PlayerPedId() end

    --- Unit vector the rendered camera is facing (first person, third person and scripted cams).
    function P.camDirection()
        local rot = GetFinalRenderedCamRot(2)
        local rx, rz = math.rad(rot.x), math.rad(rot.z)
        local c = math.abs(math.cos(rx))
        return vec3(-math.sin(rz) * c, math.cos(rz) * c, math.sin(rx))
    end

    --- Raycast from the camera through the screen centre.
    --- @param distance number? metres (default 60)
    --- @param flags number? shape test flags (default world | vehicles | objects)
    --- @param ignore number? entity to ignore (default the player ped)
    --- @return vector3|nil coords, number|nil entity, vector3|nil normal
    function P.raycast(distance, flags, ignore)
        local from = GetFinalRenderedCamCoord()
        local to = from + P.camDirection() * (distance or 60.0)
        local handle = StartExpensiveSynchronousShapeTestLosProbe(from.x, from.y, from.z, to.x, to.y, to.z, flags or DEFAULT_FLAGS, ignore or ped(), 7)
        local _, hit, coords, normal, entity = GetShapeTestResult(handle)
        -- FiveM returns BOOL out-params as 1/0 or true/false depending on runtime; accept both.
        if (hit == 1 or hit == true) and coords and #(coords - from) > 0.01 then return coords, entity, normal end
        return nil
    end

    local function forward(heading)
        local r = math.rad(heading)
        return vec3(-math.sin(r), math.cos(r), 0.0)
    end

    local function drawCrosshair()
        DrawRect(0.5, 0.5, 0.012, 0.0018, 255, 255, 255, 230)
        DrawRect(0.5, 0.5, 0.001, 0.02, 255, 255, 255, 230)
    end

    local function drawDot(p, c, scale)
        scale = scale or 0.08
        DrawMarker(28, p.x, p.y, p.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, scale, scale, scale, c.r, c.g, c.b, c.a or 230, false, true, 2, false, nil, nil, false)
    end

    --- Wireframe box with its base at p.z + zOffset, rotated to `heading`, plus a facing arrow.
    function P.drawBox(p, heading, size, colour, zOffset)
        local c = colour or { r = 59, g = 130, b = 246, a = 255 }
        local f = forward(heading)
        local r = vec3(f.y, -f.x, 0.0)
        local hx, hy = (size.x or 1.0) / 2, (size.y or 1.0) / 2
        local z0 = p.z + (zOffset or 0.0)
        local z1 = z0 + (size.z or 2.0)
        local corners = { p + r * hx + f * hy, p - r * hx + f * hy, p - r * hx - f * hy, p + r * hx - f * hy }
        for i = 1, 4 do
            local a, b = corners[i], corners[i % 4 + 1]
            DrawLine(a.x, a.y, z0, b.x, b.y, z0, c.r, c.g, c.b, 255)
            DrawLine(a.x, a.y, z1, b.x, b.y, z1, c.r, c.g, c.b, 160)
            DrawLine(a.x, a.y, z0, a.x, a.y, z1, c.r, c.g, c.b, 160)
        end
        local tip = p + f * 0.9
        DrawLine(p.x, p.y, p.z + 0.02, tip.x, tip.y, p.z + 0.02, 52, 211, 153, 255)
    end

    function P.drawSphere(p, radius, colour)
        local c = colour or { r = 59, g = 130, b = 246, a = 90 }
        local d = (radius or 1.0) * 2
        DrawMarker(28, p.x, p.y, p.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, d, d, d, c.r, c.g, c.b, c.a or 90, false, false, 2, false, nil, nil, false)
    end

    local function helpText(opts)
        if opts.help == false then return nil end
        if type(opts.help) == 'string' then return opts.help end
        local cancel = '[RMB / BACKSPACE / ESC] Cancel'
        if opts.rotate then return '[E / LMB] Set  ·  [SCROLL] Rotate (hold SHIFT = fine)  ·  ' .. cancel end
        return '[E / LMB] Set  ·  ' .. cancel
    end

    --- Runs the picker until the player confirms or cancels.
    --- @param opts table?
    ---   shape        'point' | 'box' | 'sphere'  (default 'point')
    ---   size         vec3/table for 'box' (x = width, y = depth, z = height)
    ---   radius       number for 'sphere'
    ---   zOffset      number, box base relative to the hit point (default 0)
    ---   rotate       boolean, scroll wheel rotates the heading (default false)
    ---   heading      number, starting heading; when nil it follows the camera
    ---   headingOffset number added to the camera yaw while following it (default 180 = facing the player)
    ---   distance     number, max ray length in metres (default 60)
    ---   flags        number, shape test flags (default world | vehicles | objects)
    ---   colour       { r, g, b, a } preview colour
    ---   help         string | false, custom ox_lib text UI line, or false to show none (draw your own)
    ---   onFrame      function(coords|nil, heading) called every frame for extra drawing
    --- @return table|nil { x, y, z, w } or nil when cancelled
    function P.run(opts)
        if active then return nil end
        active = true
        opts = opts or {}
        local shape = opts.shape or 'point'
        local manual = opts.heading ~= nil
        local heading = (opts.heading or 0.0) + 0.0
        local offset = opts.headingOffset or 180.0
        local text = helpText(opts)
        local textUI = text and lib and lib.showTextUI
        if textUI then lib.showTextUI(text, { position = 'top-center' }) end

        -- Ignore input briefly so the click that started picking can't also set or cancel it.
        local armAt = GetGameTimer() + 250
        local result
        local ok, err = pcall(function()
            while true do
                Wait(0)
                DisablePlayerFiring(PlayerId(), true)
                for i = 1, #BLOCKED do DisableControlAction(0, BLOCKED[i], true) end
                drawCrosshair()

                if not manual then heading = (GetFinalRenderedCamRot(2).z + offset) % 360.0 end
                if opts.rotate then
                    local step = IsControlPressed(0, SPRINT) and 1.0 or 15.0
                    if IsDisabledControlJustPressed(0, SCROLL_UP) then heading = (heading + step) % 360.0 manual = true end
                    if IsDisabledControlJustPressed(0, SCROLL_DOWN) then heading = (heading - step) % 360.0 manual = true end
                end

                local p = P.raycast(opts.distance, opts.flags)
                if p then
                    if shape == 'box' then P.drawBox(p, heading, opts.size or { x = 1.0, y = 1.0, z = 2.0 }, opts.colour, opts.zOffset)
                    elseif shape == 'sphere' then P.drawSphere(p, opts.radius, opts.colour) end
                    drawDot(p, opts.colour or { r = 255, g = 255, b = 255, a = 230 }, shape == 'point' and 0.08 or 0.07)
                end
                if opts.onFrame then opts.onFrame(p, heading) end

                if GetGameTimer() >= armAt then
                    if p and (IsControlJustPressed(0, INTERACT) or IsDisabledControlJustPressed(0, ATTACK)) then
                        result = { x = p.x, y = p.y, z = p.z, w = (heading % 360.0 + 360.0) % 360.0 }
                        return
                    end
                    if IsDisabledControlJustPressed(0, AIM) or IsControlJustPressed(0, CANCEL) or IsDisabledControlJustPressed(0, PAUSE) then return end
                end
            end
        end)
        if textUI then lib.hideTextUI() end
        active = false
        if not ok then
            print(('^1[thistle-lib] Placement.run error: %s^0'):format(tostring(err)))
            return nil
        end
        return result
    end
end

-- Plain name check (not Thistle.IsLibResource) so this file also works when a
-- consumer includes it on its own, without '@thistle-lib/init.lua'.
if GetCurrentResourceName() == 'thistle-lib' then
    -- Function options (showHelp/hideHelp) can't cross resources reliably;
    -- include the module instead if you need them.
    exports('PlacementStart', function(...) local opts = Thistle.StripSelf(...) return P.Start(opts) end)
    exports('PlacementIsActive', function() return active end)
end
