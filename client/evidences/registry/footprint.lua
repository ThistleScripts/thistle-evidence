-- Footprints: walking on soft ground (mud, sand, snow, soil, dirt tracks) leaves prints every few steps. The server
-- turns the shoes into a profile (men's or women's, size, tread), so prints can be matched to a pair of shoes.
local config <const> = require "config"

local settings <const> = config.footprints

-- Surface materials soft enough to take a print (collision material hashes)
local softGround <const> = {
    [0xA0EBF7E4] = true, [0x1E6D775E] = true, [0x363CBCD5] = true, [0x8E4D8AFF] = true, -- sand: loose, compact, wet, track
    [0x1E5E7A48] = true, [0x4CCC2AFF] = true, -- sand: dry deep, wet deep
    [0x8C8308CA] = true, [0xCBA23987] = true, [0x608ABC80] = true, -- snow: loose, compact, deep
    [0x8C31B7EA] = true, [0x129ECA2A] = true, [0x61826E7A] = true, [0x42251DC0] = true, -- mud: hard, pothole, soft, deep
    [0x0D4C07E2] = true, [0x5E73A22E] = true, -- marsh, marsh deep
    [0xD63CCDDB] = true, [0x216FF3F0] = true, [0x8F9CD58F] = true -- soil, soft clay, dirt track
}

-- The ground under the player and its material, from a short downward probe
local function getGround(ped)
    local coords <const> = GetEntityCoords(ped)
    local handle <const> = StartShapeTestLosProbe(coords.x, coords.y, coords.z, coords.x, coords.y, coords.z - 2.0, 1, ped, 7)

    local status, hit, endCoords, material
    repeat
        Wait(0)
        status, hit, endCoords, _, material = GetShapeTestResultIncludingMaterial(handle)
    until status ~= 1

    if status ~= 2 or hit ~= 1 then
        return nil
    end

    return endCoords, material & 0xFFFFFFFF
end

if settings and settings.enabled then
    CreateThread(function()
        local lastCoords = nil

        while true do
            local ped <const> = cache.ped
            local moving <const> = not cache.vehicle and GetEntitySpeed(ped) > 0.8 and not IsPedSwimming(ped)
                and not IsPedFalling(ped) and not IsPedInParachuteFreeFall(ped)

            if moving then
                local coords <const> = GetEntityCoords(ped)

                if not lastCoords or #(coords - lastCoords) >= settings.spacing then
                    local groundCoords <const>, material <const> = getGround(ped)

                    if groundCoords and softGround[material] then
                        lastCoords = coords

                        -- the client says which shoes; the server makes the profile and checks it's this player
                        local shoes <const> = ("%s-%d"):format(IsPedMale(ped) and "M" or "F", GetPedDrawableVariation(ped, 6))
                        TriggerServerEvent("evidences:syncEvidence", "footprint", shoes, "atCoords", groundCoords, {
                            heading = GetEntityHeading(ped)
                        })
                    end
                end
            end

            Wait(moving and 250 or 750)
        end
    end)
end
