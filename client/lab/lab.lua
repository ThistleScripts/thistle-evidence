-- The forensics lab screen (html/dui/laptop/src/lab), opened from a microscope (client/lab/microscopes.lua).
local config <const> = require "config"
local eventHandler <const> = require "common.events.handler"
local player <const> = require "client.player"
local permissions <const> = require "client.permissions"

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

    if not info.permissions.access or not permissions.has("microscope") then
        config.notify({ key = "laptop.notifications.no_permission" }, "error")
        return
    end

    isOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = "openLab",
        brand = ("%s Evidence"):format(config.cityName or "Thistle"),
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

eventHandler.onLocal("onResourceStop", function(event)
    if event.arguments[1] == cache.resource then
        lab.close()
    end
end)

return lab
