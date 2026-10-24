-- Ground evidence left lying long enough is gone (config.evidenceAging.removeAfterMinutes): rain, traffic and cleaners
-- get to it. Evidence on vehicles, props and players goes when they do.
local config <const> = require "config"

local settings <const> = config.evidenceAging

if settings and settings.enabled and (settings.removeAfterMinutes or 0) > 0 then
    lib.cron.new("*/10 * * * *", function()
        local oldest <const> = os.time() - settings.removeAfterMinutes * 60
        local expired = {}

        for coords, evidence in pairs(EvidencesAtCoords) do
            local metadata <const> = evidence.coordsMetadata and evidence.coordsMetadata[coords]
            if metadata and (tonumber(metadata.createdAt) or oldest) < oldest then
                expired[#expired + 1] = { evidence = evidence, coords = coords }
            end
        end

        for _, entry in ipairs(expired) do
            entry.evidence:removeFromCoords(entry.coords)
        end
    end)
end
