local fingerprint = lib.class("fingerprint", require "server.evidences.classes.evidence")
fingerprint.superClassName = "fingerprint"

function fingerprint:constructor(owner)
    self:super(owner)
end

return fingerprint