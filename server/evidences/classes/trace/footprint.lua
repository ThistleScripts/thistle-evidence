local footprint = lib.class("footprint", require "server.evidences.classes.evidence")
footprint.superClassName = "footprint"

function footprint:constructor(owner)
    self:super(owner)
end

return footprint
