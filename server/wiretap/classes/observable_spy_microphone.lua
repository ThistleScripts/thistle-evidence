---@class ObservableSpyMicrophone : Observation
---@field label string
---@field coords vector3
local ObservableSpyMicrophone = lib.class("ObservableSpyMicrophone", require "server.wiretap.classes.observation")

function ObservableSpyMicrophone:constructor(label, coords)
    self:super()
    self.label = label
    self.coords = coords
end

function ObservableSpyMicrophone:sync()
    TriggerClientEvent("evidences:registerSpyMicrophone", -1, self.label, self.coords)
end

function ObservableSpyMicrophone:destroy()
    TriggerClientEvent("evidences:unregisterSpyMicrophone", -1, self.label)
    self:clearTargets()
    self:clearObservers()
end

return ObservableSpyMicrophone