-- Bleach residue (config.bleachResidue): cleaning up leaves a trace of its own. Destroying ground evidence with an item
-- (hydrogen peroxide, a cleaning kit) and scrubbing a scene with a scene cleaning kit leave residue where they were used,
-- which glows under UV light (client/evidences/bleach.lua), so officers can tell a scene was cleaned, where, and
-- roughly when. It fades after config.bleachResidue.lifetime minutes, and isn't kept over a restart.
local config <const> = require "config"

local settings <const> = config.bleachResidue or {}
local bleach = {}

if settings.enabled == false then
    function bleach.leave() end
    return bleach
end

local lifetime <const> = (settings.lifetime or 120) * 60
local marks = {} -- id -> { id, coords, at }
local nextId = 1

-- What clients need: where, and how long ago (they have no clock of their own to compare os.time() with)
local function forClient(mark)
    return { id = mark.id, coords = mark.coords, age = os.time() - mark.at }
end

-- Leaves residue at coords. Cleaning the same spot again freshens the mark already there rather than adding another.
---@param coords vector3
function bleach.leave(coords)
    if type(coords) ~= "vector3" then
        return
    end

    for _, mark in pairs(marks) do
        if #(mark.coords - coords) < 1.5 then
            mark.at = os.time()
            TriggerClientEvent("evidences:bleach:add", -1, forClient(mark))
            return
        end
    end

    local mark <const> = { id = nextId, coords = coords, at = os.time() }
    nextId += 1
    marks[mark.id] = mark

    TriggerClientEvent("evidences:bleach:add", -1, forClient(mark))
end

-- Players joining (or this resource restarting under them) get the marks there already
RegisterNetEvent("evidences:playerLoaded", function()
    local playerId <const> = tonumber(source)
    if not playerId then
        return
    end

    for _, mark in pairs(marks) do
        TriggerClientEvent("evidences:bleach:add", playerId, forClient(mark))
    end
end)

lib.cron.new("*/5 * * * *", function()
    local oldest <const> = os.time() - lifetime
    for id, mark in pairs(marks) do
        if mark.at < oldest then
            marks[id] = nil
            TriggerClientEvent("evidences:bleach:remove", -1, id)
        end
    end
end)

return bleach
