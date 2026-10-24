math.randomseed(os.time()) -- Seed the PRNG

lib.locale()

-- Clients read these to tell players why nothing works when the server stopped during setup
local readyKey <const>, setupErrorKey <const> = ("%s:ready"):format(cache.resource), ("%s:setupError"):format(cache.resource)
GlobalState[readyKey] = false
GlobalState[setupErrorKey] = nil

local function setupFailed(message)
    lib.print.error(message)
    GlobalState[setupErrorKey] = message
end

if not Thistle.VersionAtLeast("0.3.0") then
    setupFailed("thistle-evidence requires thistle-lib 0.3.0 or newer. Please update thistle-lib.")
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

GlobalState[readyKey] = true
