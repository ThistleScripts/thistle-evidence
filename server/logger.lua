local config <const> = require "config"

local logger = {}

-- Which webhook category each logged event is posted to (see config.logging.webhooks)
local categories <const> = {
    ["Evidences cleared"] = "evidences",
    ["Evidence destroyed"] = "evidences",
    ["Evidence collected"] = "evidences",
    ["Biometric data taken"] = "evidences",
    ["Fingerprint scanned"] = "evidences",
    ["Evidence analysed"] = "evidences",
    ["Forensic match"] = "evidences",
    ["Evidence box sealed"] = "evidences",
    ["Evidence box seal broken"] = "evidences",
    ["Evidence locker deposit"] = "evidences",
    ["Evidence locker withdrawal"] = "evidences",
    ["Scene cleaned"] = "evidences",
    ["Case opened"] = "evidences",
    ["Case closed"] = "evidences",
    ["Case reopened"] = "evidences",
    ["Biometric data linked to citizen"] = "citizens",
    ["Citizen created"] = "citizens",
    ["Citizen updated"] = "citizens",
    ["Citizen deletion requested"] = "citizens",
    ["Note created"] = "citizens",
    ["Note edited"] = "citizens",
    ["Note deletion requested"] = "citizens",
    ["Observation started"] = "wiretap",
    ["Observation ended"] = "wiretap",
    ["Spy microphone placed"] = "wiretap",
    ["Spy microphone picked up"] = "wiretap",
    ["Firearm registered"] = "firearms",
    ["Firearm unregistering requested"] = "firearms"
}

if config.logging and config.logging.service == "discord" then
    local webhooks <const> = config.logging.webhooks or {}
    Thistle.Webhook.configure({
        default = webhooks.default,
        evidences = webhooks.evidences,
        citizens = webhooks.citizens,
        wiretap = webhooks.wiretap,
        firearms = webhooks.firearms,
        botName = ("%s Evidence"):format(config.cityName or "Thistle")
    })
end

-- Builds the embed fields: who did it first, then the event's own data (short values side by side)
local function createFields(source, arguments)
    local license <const> = Thistle.GetLicense(source)
    local txAdminUrl <const> = config.logging.txAdminUrl
    local fields = Thistle.Webhook.fields(
        { "Player", ("%s (%s)"):format(GetPlayerName(source) or "unknown", source) },
        { "License", license or "n/a" }
    )

    if license and txAdminUrl and txAdminUrl ~= "" then
        fields[#fields + 1] = { name = "txAdmin", value = ("[View player](%s%s)"):format(txAdminUrl, (license:gsub("license:", ""))), inline = true }
    end

    local keys = {}
    for key in pairs(arguments or {}) do
        keys[#keys + 1] = key
    end

    table.sort(keys, function(a, b)
        return #tostring(arguments[a]) < #tostring(arguments[b])
    end)

    for _, key in ipairs(keys) do
        local value <const> = tostring(arguments[key]):sub(1, 1000) -- Discord rejects field values over 1024 characters
        fields[#fields + 1] = {
            name = key,
            value = "```" .. value .. "```",
            inline = #value <= 25
        }
    end

    return fields
end

-- Log an event to the configured logging service
---@param source number The player who caused the event
---@param event string The event name, as listed in config.logging.loggedEvents
---@param arguments? table<string, any> Event details
function logger.log(source, event, arguments)
    if not config.logging
        or not config.logging.enabled
        or not config.logging.loggedEvents[event] then
            return
    end

    local service <const> = config.logging.service

    if service == "ox_lib" then
        local tags = {}
        for key, value in pairs(arguments or {}) do
            tags[#tags + 1] = ("%s:%s"):format(key, tostring(value))
        end

        lib.logger(source, event, "", table.unpack(tags))
        return
    end

    if service == "discord" then
        Thistle.Webhook.send(categories[event] or "default", {
            title = event,
            color = 0x113962,
            fields = createFields(source, arguments)
        })
    end
end

return logger
