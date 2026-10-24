local tyreMark = lib.class("tyre_mark", require "server.evidences.classes.evidence")
tyreMark.superClassName = "tyre_mark"

function tyreMark:constructor(owner)
    self:super(owner)
end

return tyreMark
