-- Draws the footprints that are showing (under UV light when that's required): a shoe-shaped smudge pointing the way
-- the person walked. One thread draws them all, only while any are close.
local marks = {} -- point -> { coords, heading }
local count = 0
local drawing = false

local footprintMarks = {}

local function draw()
    drawing = true

    CreateThread(function()
        while count > 0 do
            local pedCoords <const> = GetEntityCoords(cache.ped)
            local anyClose = false

            for _, mark in pairs(marks) do
                if #(pedCoords - mark.coords) < 20.0 then
                    anyClose = true
                    DrawMarker(25, mark.coords.x, mark.coords.y, mark.coords.z + 0.02, 0.0, 0.0, 0.0, 0.0, 0.0, mark.heading,
                        0.11, 0.27, 0.05, 58, 44, 30, 200, false, false, 2, false, nil, nil, false)
                end
            end

            Wait(anyClose and 0 or 500)
        end

        drawing = false
    end)
end

function footprintMarks.add(point, data)
    if marks[point] then
        return
    end

    marks[point] = { coords = point.coords, heading = tonumber(data and data.heading) or 0.0 }
    count += 1

    if not drawing then
        draw()
    end
end

function footprintMarks.remove(point)
    if marks[point] then
        marks[point] = nil
        count -= 1
    end
end

return footprintMarks
