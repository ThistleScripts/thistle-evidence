local dna = lib.class("dna", require "server.evidences.classes.evidence")
dna.superClassName = "dna"

function dna:constructor(owner)
    self:super(owner)
end

return dna