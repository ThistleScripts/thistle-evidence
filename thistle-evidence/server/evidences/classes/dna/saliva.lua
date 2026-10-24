local saliva = lib.class("saliva", require "server.evidences.classes.dna.dna")
saliva.superClassName = "dna"

function saliva:constructor(owner)
    self:super(owner)
end

return saliva