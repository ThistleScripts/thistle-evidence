local config <const> = require "config"
local framework <const> = require "common.frameworks.framework"
local eventHandler <const> = require "common.events.handler"

local subscribers = {}

eventHandler.on("observationTargetAdded", function(event)
    local observation <const> = event.arguments.observation
    if observation.__name == "ObservableCall" then
        local target <const> = event.arguments.addedTarget

        for subscriber, targetName in pairs(subscribers) do
            if targetName == target.name then
                TriggerClientEvent("evidences:notify", subscriber, {
                    key = "laptop.desktop_screen.wiretap_app.phone_calls.notifications.notification",
                    arguments = { targetName }
                }, "inform", 10000)
            end
        end
    end
end)

lib.callback.register("evidences:subscribe", function(source, arguments)
    if not framework.hasPermission(config.wiretap.calls.permissions, source) then
        return {
            success = false,
            response = "laptop.notifications.no_permission.description"
        }
    end

    if arguments then
        subscribers[source] = arguments.target or nil
    end
end)

lib.callback.register("evidences:getSubscriptionTarget", function(source, arguments)
    return subscribers[source] or ""
end)

eventHandler.onLocal("playerDropped", function(event)
    if event.source then
        subscribers[event.source] = nil
    end
end)