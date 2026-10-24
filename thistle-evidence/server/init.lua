math.randomseed(os.time()) -- Seed the PRNG

-- DoesPlayerExist(nil) is a native error ("Argument at index 0 was null") rather than false. Inside this resource
-- (our code, ox_lib and the included thistle-lib) a missing player now just doesn't exist, and the first time each
-- caller does it, the console shows where from so it can be fixed properly.
do
    local doesPlayerExist <const> = DoesPlayerExist
    local reported = {}

    DoesPlayerExist = function(playerId)
        if playerId == nil then
            local trace <const> = debug.traceback("", 2)
            if not reported[trace] then
                reported[trace] = true
                lib.print.warn(("DoesPlayerExist was called without a player id. Please report this:%s"):format(trace))
            end
            return false
        end

        return doesPlayerExist(playerId)
    end
end

lib.locale()

-- Clients read these to tell players why nothing works when the server stopped during setup
local readyKey <const>, setupErrorKey <const> = ("%s:ready"):format(cache.resource), ("%s:setupError"):format(cache.resource)
GlobalState[readyKey] = false
GlobalState[setupErrorKey] = nil

local function setupFailed(message)
    lib.print.error(message)
    GlobalState[setupErrorKey] = message
end

-- VersionAtLeast itself only exists from thistle-lib 0.3.0, so an older one is caught here too instead of erroring
if type(Thistle) ~= "table" or type(Thistle.VersionAtLeast) ~= "function" or not Thistle.VersionAtLeast("0.3.0") then
    local found <const> = type(Thistle) == "table" and (Thistle.VERSION or GetResourceMetadata("thistle-lib", "version", 0)) or nil
    setupFailed(("thistle-evidence requires thistle-lib 0.3.0 or newer (found %s). Please update thistle-lib."):format(found or "none"))
    return
end

if not LoadResourceFile(cache.resource, "html/dui/laptop/dist/index.html") then
    setupFailed("Setup step missing: the laptop UI isn't built. Use the release zip, or build it (cd html/dui/laptop && bun install && bun run build)")
    return
end

if not require "server.items" then
    setupFailed("Setup step missing: some thistle-evidence items aren't in ox_inventory. See the server console and setup/ for the item list.")
    return
end

require "server.permissions"

require "server.biometrics.biometrics_provider"

require "server.evidences.api"

require "server.evidences.actions"

require "server.dui.callbacks"
require "server.dui.laptops"

require "server.wiretap.wiretap"

require "server.commands"

require "server.citizens.citizens"
require "server.citizens.notes"

require "server.firearms.firearms"
require "server.firearms.terminal"

require "server.biometrics.linked_biometrics"
require "server.biometrics.biometrics_taking"

require "server.scanner.scanner"

require "server.forensics.lab"
require "server.forensics.microscopes"

require "server.evidences.markers"
require "server.evidences.floodlights"
require "server.evidences.locker"
require "server.evidences.aging"
require "server.evidences.scene_cleaning"
require "server.evidences.shot_players"
require "server.cases.cases"

GlobalState[readyKey] = true
