-- Clearing ground evidence from the whole map, for the evidence admin panel (server/permissions.lua): every piece of
-- one type, or of every type. It's done as one batch: the pieces leave the server's memory, the saved copies leave
-- the database in one query, and clients get a single event to drop that type (client/evidences/evidence_at_coords.lua),
-- instead of one event and one query per piece.
-- Evidence on vehicles, props and players, and evidence already collected into items, isn't touched.
local persistence <const> = require "server.evidences.persistence"

local clearing = {}

-- How many pieces of each type are on the ground right now
---@return table<string, integer>
function clearing.count()
    local counts = {}
    for _, evidence in pairs(EvidencesAtCoords) do
        counts[evidence.__name] = (counts[evidence.__name] or 0) + 1
    end
    return counts
end

---@param evidenceType string? nil for every type
---@return integer cleared
function clearing.clear(evidenceType)
    local pieces = {}
    for coords, evidence in pairs(EvidencesAtCoords) do
        if not evidenceType or evidence.__name == evidenceType then
            pieces[#pieces + 1] = { evidence = evidence, coords = coords }
        end
    end

    for _, piece in ipairs(pieces) do
        piece.evidence:removeFromCoords(piece.coords, true)
    end

    persistence.groundCleared(evidenceType)
    TriggerClientEvent("evidences:clearGround", -1, evidenceType or false)

    return #pieces
end

return clearing
