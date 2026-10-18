---@class ObservableRadioFreq : Observation
---@field channel number The radio id of the call
local ObservableRadioFreq = lib.class("ObservableRadioFreq", require "server.wiretap.classes.observation")

function ObservableRadioFreq:constructor(channel)
    self:super()
    self.channel = channel
end

return ObservableRadioFreq