-- The forensics lab screen (html/dui/laptop/src/lab), opened at a lab station or from an evidence laptop.
local config <const> = require "config"
local eventHandler <const> = require "common.events.handler"
local player <const> = require "client.player"

local lab = {}
local isOpen = false

function lab.open()
    if isOpen then
        return
    end

    local info <const> = player.getInfo()
    if info.setupIncomplete then
        return
    end

    if not info.permissions.access then
        config.notify({ key = "laptop.notifications.no_permission" }, "error")
        return
    end

    isOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = "openLab",
        playerName = info.name,
        language = GetConvar("ox:locale", "en")
    })
end

function lab.close()
    if not isOpen then
        return
    end

    isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = "closeLab" })
end

eventHandler.onNui("lab:close", function()
    lab.close()
end)

-- The laptop's Forensics Lab tile: step away from the laptop and open the lab
eventHandler.onNui("lab:openFromLaptop", function()
    require("client.dui.focus").stop()
    lab.open()
end)

local zones = {}

for index, station in ipairs(config.forensicsLab.stations or {}) do
    zones[index] = exports.ox_target:addSphereZone({
        coords = station.coords,
        radius = station.radius or 1.0,
        drawSprite = true,
        options = {
            {
                name = "evidences:forensics_lab",
                label = locale("lab.target"),
                icon = "fa-solid fa-microscope",
                distance = 2,
                groups = config.permissions.access or false,
                canInteract = function()
                    return not config.isPedDead(cache.ped)
                end,
                onSelect = function()
                    lab.open()
                end
            }
        }
    })
end

eventHandler.onLocal("onResourceStop", function(event)
    if event.arguments[1] == cache.resource then
        lab.close()

        for _, zone in pairs(zones) do
            exports.ox_target:removeZone(zone)
        end
    end
end)

return lab
