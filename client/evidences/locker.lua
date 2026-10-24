-- Evidence lockers (config.evidenceLockers, server/evidences/locker.lua): target the locker to open it, or to see who
-- put what in and took what out.
local config <const> = require "config"
local eventHandler <const> = require "common.events.handler"

local zones = {}

local function showLog(locker)
    local entries <const> = Thistle.Callback.Await("evidences:getLockerLog", locker.id) or {}
    local options = {}

    for _, entry in ipairs(entries) do
        local deposit <const> = entry.action == "deposit"
        local label <const> = entry.label or entry.item -- a labelled box's label already starts with its case

        options[#options + 1] = {
            title = ("%s %s ×%d"):format(locale(deposit and "locker.deposit" or "locker.withdraw"), label, entry.amount or 1),
            description = ("%s · %s"):format(entry.officer, entry.when or ""),
            icon = deposit and "arrow-right-to-bracket" or "arrow-right-from-bracket",
            iconColor = deposit and "#34d399" or "#fbbf24",
            readOnly = true
        }
    end

    if #options == 0 then
        options[1] = { title = locale("locker.empty_log"), readOnly = true }
    end

    lib.registerContext({ id = "evidences:locker_log", title = locale("locker.log_title", locker.label), options = options })
    lib.showContext("evidences:locker_log")
end

for index, locker in ipairs(config.evidenceLockers or {}) do
    zones[index] = exports.ox_target:addSphereZone({
        coords = locker.coords,
        radius = locker.radius or 0.8,
        drawSprite = true,
        options = {
            {
                name = "evidences:locker_open",
                label = locale("locker.open", locker.label),
                icon = "fa-solid fa-box-archive",
                distance = 2.0,
                groups = locker.groups or config.permissions.access or false,
                onSelect = function()
                    exports.ox_inventory:openInventory("stash", locker.id)
                end
            },
            {
                name = "evidences:locker_log",
                label = locale("locker.view_log"),
                icon = "fa-solid fa-list",
                distance = 2.0,
                groups = config.permissions.access or false,
                onSelect = function()
                    showLog(locker)
                end
            }
        }
    })
end

eventHandler.onLocal("onResourceStop", function(event)
    if event.arguments[1] == cache.resource then
        for _, zone in pairs(zones) do
            exports.ox_target:removeZone(zone, true)
        end
    end
end)
