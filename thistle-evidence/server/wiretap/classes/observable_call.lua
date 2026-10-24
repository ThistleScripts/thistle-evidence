---@class ObservableCall : Observation
---@field channel number The channel id of the call
local ObservableCall = lib.class("ObservableCall", require "server.wiretap.classes.observation")

function ObservableCall:constructor(channel)
    self:super()
    self.channel = channel
end

return ObservableCall