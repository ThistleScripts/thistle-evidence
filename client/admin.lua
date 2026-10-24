-- The evidence admin panel (/evidenceadmin, server/permissions.lua): a screen on the forensics lab's NUI page
-- (html/dui/laptop/src/lab/AdminApp.tsx) for choosing which parts of the script each officer may use.
local config <const> = require "config"
local eventHandler <const> = require "common.events.handler"

local isOpen = false

local function close()
    if not isOpen then
        return
    end

    isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = "closeAdmin" })
end

-- The server only sends this to admins (permissions.lua), and checks again on everything the panel does
RegisterNetEvent("evidences:openAdmin", function()
    if isOpen then
        return
    end

    isOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = "openAdmin",
        brand = ("%s Evidence"):format(config.cityName or "Thistle"),
        language = GetConvar("ox:locale", "en")
    })
end)

eventHandler.onNui("admin:close", close)

eventHandler.onLocal("onResourceStop", function(event)
    if event.arguments[1] == cache.resource then
        close()
    end
end)
