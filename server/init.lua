math.randomseed(os.time()) -- Seed the PRNG

lib.locale()

if not Thistle.VersionAtLeast("0.3.0") then
    lib.print.error("thistle-evidence requires thistle-lib 0.3.0 or newer. Please update thistle-lib.")
    return
end

if not LoadResourceFile(cache.resource, "html/dui/laptop/dist/index.html") then
    lib.print.error("Setup step missing: Use the release zip, or build the laptop DUI (cd html/dui/laptop && bun install && bun run build)")
    return
end

if require "server.items" then
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
end