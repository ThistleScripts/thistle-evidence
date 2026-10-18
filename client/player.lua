-- The player's character name and laptop permissions, resolved by the server through thistle-lib.
-- Fetched on demand so job changes apply without a reconnect. The server re-checks every action anyway.
local player = {}

---@return { name: string, permissions: table<string, boolean> }
function player.getInfo()
    return Thistle.Callback.Await("evidences:getPlayerInfo") or { name = "undefined", permissions = {} }
end

return player
