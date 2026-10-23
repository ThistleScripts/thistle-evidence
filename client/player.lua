-- The player's character name and laptop permissions, resolved by the server through thistle-lib.
-- Fetched on demand so job changes apply without a reconnect. The server re-checks every action anyway.
local player = {}

local fallback <const> = { name = "undefined", permissions = {} }

---@return { name: string, permissions: table<string, boolean> }
function player.getInfo()
    -- The server registers its callbacks only once setup succeeded (server/init.lua)
    if not GlobalState[("%s:ready"):format(cache.resource)] then
        local setupError <const> = GlobalState[("%s:setupError"):format(cache.resource)]
            or "The server side of thistle-evidence isn't running. Check the server console."

        lib.print.error(setupError)
        Thistle.NotifyClient({ title = "thistle-evidence", description = setupError, type = "error", duration = 10000 })
        return fallback
    end

    return Thistle.Callback.Await("evidences:getPlayerInfo") or fallback
end

return player
