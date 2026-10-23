local config <const> = require "config"
local eventHandler <const> = require "common.events.handler"
local evidenceTypes <const> = require "common.evidence_types"
local uv <const> = require "client.evidences.uv"

EvidencesAtCoords = {}

-- Ground evidence of one type lying close together (casings from automatic fire, a trail of blood) forms a pile
-- with a single target that collects or destroys all of it. Each piece still shows on the ground on its own.
local pileRadius <const> = 1.5
local maxPileSize <const> = 50 -- the server takes up to 50 pieces at once (server/evidences/actions.lua)
local piles = {}

-- Only pieces the player can see (under UV light, see config.uvLight) are part of the pile's target
local function getVisibleMembers(pile)
    local visible = {}
    for _, evidence in ipairs(pile.members) do
        if evidence.visible then
            visible[#visible + 1] = evidence
        end
    end
    return visible
end

local function getPileLabel(pile, action)
    local label <const> = pile.options.target[action].label
    local count <const> = #getVisibleMembers(pile)
    return count > 1 and ("%s (%d)"):format(label, count) or label
end

-- What the server needs to check every piece; the item metadata is built once per owner (gun or DNA)
local function getPileEntries(pile, targetCoords, withMetadata)
    local entries, metadataBuilt = {}, {}

    for index, evidence in ipairs(getVisibleMembers(pile)) do
        if index > maxPileSize then
            break
        end

        local metadata
        if withMetadata and not metadataBuilt[evidence.owner] then
            metadataBuilt[evidence.owner] = true
            metadata = pile.options.target.collect.createMetadata(pile.evidenceType, evidence.data, targetCoords)
        end

        entries[#entries + 1] = { owner = evidence.owner, coords = evidence.coords, metadata = metadata }
    end

    return entries
end

local function faceAndPickUp(coords)
    local ped <const> = cache.ped
    local pedCoords <const> = GetEntityCoords(ped)
    SetEntityHeading(ped, GetHeadingFromVector_2d(coords.x - pedCoords.x, coords.y - pedCoords.y)) -- make player look at the evidence
    lib.playAnim(ped, "random@domestic", "pickup_low")
end

local function refreshPileZone(pile)
    if pile.zone then
        exports.ox_target:removeZone(pile.zone)
        pile.zone = nil
    end

    if #getVisibleMembers(pile) == 0 then
        return
    end

    pile.zone = exports.ox_target:addSphereZone({
        coords = pile.center,
        radius = 0.3,
        drawSprite = true,
        options = {
            {
                label = getPileLabel(pile, "collect"),
                icon = pile.options.target.collect.icon or "fa-solid fa-magnifying-glass",
                distance = 2,
                groups = config.permissions.collect or false,
                items = pile.options.target.collect.requiredItem or nil,
                canInteract = function()
                    return not config.isPedDead(cache.ped)
                end,
                onSelect = function(data)
                    local collected <const> = Thistle.Callback.Await("evidences:collectPile", pile.evidenceType, getPileEntries(pile, data.coords, true))

                    if not collected or collected < 1 then
                        config.notify({ key = "evidences.notifications.common.errors.collect" }, "error")
                        return
                    end

                    faceAndPickUp(pile.center)
                    config.notify({
                        key = "evidences.notifications.collect",
                        arguments = {locale("evidences.notifications.common.placeholders.at_coords")}
                    }, "success")
                end
            },
            {
                label = getPileLabel(pile, "destroy"),
                icon = pile.options.target.destroy.icon or "fa-solid fa-hand-back-fist",
                distance = 2,
                items = pile.options.target.destroy.requiredItem or nil,
                canInteract = function()
                    return not config.isPedDead(cache.ped)
                end,
                onSelect = function(data)
                    local destroyed <const> = Thistle.Callback.Await("evidences:destroyPile", pile.evidenceType, getPileEntries(pile, data.coords, false))

                    if not destroyed or destroyed < 1 then
                        config.notify({ key = "evidences.notifications.common.errors.destroy" }, "error")
                        return
                    end

                    faceAndPickUp(pile.center)
                    config.notify({
                        key = "evidences.notifications.destroy",
                        arguments = {locale("evidences.notifications.common.placeholders.at_coords")}
                    }, "success")
                end
            }
        }
    })
end

local function addToPile(evidence)
    for _, pile in ipairs(piles) do
        if pile.evidenceType == evidence.evidenceType and #(pile.center - evidence.coords) <= pileRadius then
            table.insert(pile.members, evidence)
            evidence.pile = pile
            refreshPileZone(pile)
            return
        end
    end

    local pile <const> = {
        evidenceType = evidence.evidenceType,
        options = evidence.options,
        center = evidence.coords,
        members = { evidence }
    }

    piles[#piles + 1] = pile
    evidence.pile = pile
    refreshPileZone(pile)
end

local function removeFromPile(evidence)
    local pile <const> = evidence.pile
    if not pile then
        return
    end

    evidence.pile = nil

    for index, member in ipairs(pile.members) do
        if member == evidence then
            table.remove(pile.members, index)
            break
        end
    end

    refreshPileZone(pile)

    if #pile.members == 0 then
        for index, other in ipairs(piles) do
            if other == pile then
                table.remove(piles, index)
                break
            end
        end
    end
end

EvidenceAtCoords = lib.class("EvidenceAtCoords")

function EvidenceAtCoords:constructor(evidenceType, owner, coords, data)
    if not evidenceTypes[evidenceType] then
        lib.print.error("Server tried to sync a ground-evidence of an invalid type: ", evidenceType)
        return
    end

    self.evidenceType = evidenceType
    self.options = evidenceTypes[evidenceType]
    self.owner = owner
    self.coords = coords
    self.data = data or {}

    self.visible = false
    self.visual = { coords = coords } -- what the visualize functions in common/evidence_types.lua draw with

    table.insert(EvidencesAtCoords, self)
    addToPile(self)
end

-- Shows or hides the piece on the ground (blood decal, casing, magazine, bullet path)
function EvidenceAtCoords:setVisible(visible)
    if self.visible == visible then
        return
    end

    self.visible = visible
    local visualize <const> = self.options.visualize

    if visible and visualize.show then
        visualize.show(self.visual, self.data)
    elseif not visible and visualize.hide then
        visualize.hide(self.visual, self.data)
    end
end

-- One handler pair for all ground evidence. Registering them per evidence never removed them,
-- so every blood drop or casing left two more handlers behind.
eventHandler.onNet("evidences:remove:atCoords", function(event)
    local evidenceType <const>, coords <const> = event.arguments[1], event.arguments[2]

    for i = #EvidencesAtCoords, 1, -1 do
        local evidence <const> = EvidencesAtCoords[i]
        if evidence.evidenceType == evidenceType and evidence.coords == coords then
            evidence:destroy()
        end
    end
end)

eventHandler.onLocal("onResourceStop", function(event)
    if event.arguments[1] == cache.resource then
        for i = #EvidencesAtCoords, 1, -1 do
            EvidencesAtCoords[i]:destroy()
        end
    end
end)

function EvidenceAtCoords:destroy()
    self:setVisible(false)
    removeFromPile(self)

    for index, evidence in ipairs(EvidencesAtCoords) do
        if evidence == self then
            table.remove(EvidencesAtCoords, index)
            break
        end
    end
end

-- Shows nearby ground evidence that is visible (always, or under UV light) and updates the piles' targets
CreateThread(function()
    while true do
        local pedCoords <const> = GetEntityCoords(cache.ped)
        local changedPiles = {}

        for _, evidence in ipairs(EvidencesAtCoords) do
            local visible <const> = #(pedCoords - evidence.coords) <= 25.0 and uv.reveals(evidence, evidence.coords)

            if visible ~= evidence.visible then
                evidence:setVisible(visible)

                if evidence.pile then
                    changedPiles[evidence.pile] = true
                end
            end
        end

        for pile in pairs(changedPiles) do
            refreshPileZone(pile)
        end

        Wait(uv.isOn() and 100 or 250)
    end
end)

function EvidenceAtCoords:isExposedToRain()
    if GetRainLevel() > 0 then
        local success <const>, groundZ <const> = GetGroundZFor_3dCoord(self.coords.x, self.coords.y, 99999.0, true)
        return success and groundZ <= self.coords.z + 1.5
    end

    return false
end