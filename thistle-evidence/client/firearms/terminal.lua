-- Firearm registration terminals (config.firearmTerminals, server/firearms/terminal.lua): officers target a spot and a
-- registration screen opens (html/dui/laptop/src/lab/FirearmTerminalApp.tsx), where they find or create the citizen
-- and register a gun they're carrying to them. It shares the forensics lab's NUI page.
local config <const> = require "config"
local eventHandler <const> = require "common.events.handler"
local player <const> = require "client.player"

local settings <const> = config.firearmTerminals or {}
local zones = {}
local isOpen = false

local function open()
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
        action = "openFirearmTerminal",
        brand = ("%s Evidence"):format(config.cityName or "Thistle"),
        playerName = info.name,
        language = GetConvar("ox:locale", "en"),
        citizensSynced = config.citizens.synced
    })
end

local function close()
    if not isOpen then
        return
    end

    isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = "closeFirearmTerminal" })
end

eventHandler.onNui("firearmTerminal:close", close)

if config.firearmsRegistry.enabled then
    for index, coords in ipairs(settings.stations or {}) do
        zones[index] = exports.ox_target:addSphereZone({
            coords = vector3(coords.x, coords.y, coords.z),
            radius = settings.radius or 0.6,
            drawSprite = true,
            options = {
                {
                    name = "evidences:firearm_terminal",
                    label = locale("firearm_terminal.target"),
                    icon = "fa-solid fa-gun",
                    distance = 2.0,
                    groups = config.permissions.access or false,
                    onSelect = open
                }
            }
        })
    end
end

eventHandler.onLocal("onResourceStop", function(event)
    if event.arguments[1] == cache.resource then
        close()

        for _, zone in pairs(zones) do
            exports.ox_target:removeZone(zone, true)
        end
    end
end)
