---@class Event : OxClass
---@field name string
---@field arguments table
local Event = lib.class("Event")

function Event:constructor(name, arguments)
    self.name = name
    self.arguments = arguments
end

return Event