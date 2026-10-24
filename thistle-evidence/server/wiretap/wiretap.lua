local config <const> = require "config"

if config.wiretap.enabled then
    if GetResourceState("pma-voice"):find("start") then
        require "server.wiretap.protocols"
        
        require "server.wiretap.registry.calls.calls"
        require "server.wiretap.registry.calls.notifications"

        require "server.wiretap.registry.radio"
        require "server.wiretap.registry.spy_microphones"
        return
    end

    lib.print.error("The wiretap app requires pma-voice to work!")
end