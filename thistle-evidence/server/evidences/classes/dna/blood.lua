local blood = lib.class("blood", require "server.evidences.classes.dna.dna")
blood.superClassName = "dna"

function blood:constructor(owner)
    self:super(owner)
end

return blood