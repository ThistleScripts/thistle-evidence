---@class NetEvent : Event
---@field arguments table
local NetEvent = lib.class("NetEvent", require "common.events.classes.event")

---@param eventName string The name of the RegisterNetEvent
---@param source number The server id of the executor (only server-side)
---@param arguments table Arguments of the callback function of the RegisterNetEvent
function NetEvent:constructor(eventName, source, arguments)
    self:super(eventName)
    self.source = source
    self.arguments = arguments
end

return NetEvent