local config <const> = require "config"
local supportedPhones <const> = {
    ["npwd"] = "npwd",
    ["roadphone"] = "roadphone",
    ["lb-phone"] = "lb-phone",
    ["yseries"] = "yseries"
}

if config.wiretap.calls.displayPhoneNumbers then
    for resource, phone in pairs(supportedPhones) do
        if GetResourceState(resource):find("start") then
            return require(("server.wiretap.registry.calls.bridge.%s"):format(phone))
        end
    end
end

return {
    getPhoneNumber = function()
        return nil
    end
}