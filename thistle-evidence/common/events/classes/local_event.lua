---@class LocalEvent : Event
---@field arguments table
local LocalEvent = lib.class("LocalEvent", require "common.events.classes.event")

---@param eventName string The name of the AddEventHandler
---@param source number The server id of the executor (only server-side)
---@param arguments table Arguments of the callback function of the AddEventHandler
function LocalEvent:constructor(eventName, source, arguments)
    self:super(eventName)
    self.source = source
    self.arguments = arguments
end

return LocalEvent