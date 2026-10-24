-- Firearm registration terminals (config.firearmTerminals, client/firearms/terminal.lua): like the booking terminal,
-- any officer with config.permissions.access can use one, without the laptop's Firearms registry app. They find the
-- citizen, pick a gun they're carrying and register it to them.
-- The terminal only works at a terminal: every call checks the officer is standing at one, and the gun's details come
-- from their own inventory, not from the screen.
local config <const> = require "config"
local framework <const> = require "server.framework"
local database <const> = require "server.database"
local logger <const> = require "server.logger"
local firearms <const> = require "server.firearms.firearms"

local settings <const> = config.firearmTerminals or {}
local stations <const> = settings.stations or {}

if not config.firearmsRegistry.enabled or #stations == 0 or not firearms.register then
    return
end

local reach <const> = 3.0
local imagePath <const> = GetConvar("inventory:imagepath", "nui://ox_inventory/web/images") .. "/%s.png"

local function isAtTerminal(source)
    local ped <const> = GetPlayerPed(source)
    if ped == 0 then
        return false
    end

    local coords <const> = GetEntityCoords(ped)
    for _, station in ipairs(stations) do
        if #(coords - vector3(station.x, station.y, station.z)) <= reach then
            return true
        end
    end

    return false
end

local function register(name, handler)
    Thistle.Callback.Register(name, function(source, arguments)
        if not framework.hasPermission(config.permissions.access, source) or not isAtTerminal(source) then
            return { success = false, response = "laptop.notifications.no_permission.description" }
        end

        return handler(source, type(arguments) == "table" and arguments or {})
    end)
end

-- The guns the officer is carrying that have a serial number (a filed-off one can't be registered)
local function getCarriedFirearms(source)
    local firearms = {}

    for _, item in pairs(exports.ox_inventory:GetInventoryItems(source) or {}) do
        local metadata <const> = item.metadata or {}
        if metadata.serial and item.name and item.name:upper():find("^WEAPON_") then
            firearms[#firearms + 1] = {
                serial = metadata.serial,
                label = metadata.label or item.label,
                imagePath = metadata.imageurl or (metadata.image and imagePath:format(metadata.image)) or imagePath:format(item.name)
            }
        end
    end

    return firearms
end

register("evidences:firearmTerminal:getCarried", function(source)
    local carried <const> = getCarriedFirearms(source)

    -- which of them are already on the registry, and to whom
    for _, firearm in ipairs(carried) do
        local row <const> = database.selectFirstRow("SELECT identifier, status FROM firearms_registry WHERE serial = ?", firearm.serial)
        if row.success and row.response then
            firearm.registeredTo = row.response.identifier
            firearm.status = row.response.status
        end
    end

    return { success = true, response = carried }
end)

register("evidences:firearmTerminal:getRegistered", function(_, arguments)
    if type(arguments.identifier) ~= "string" then
        return { success = false }
    end

    return database.query("SELECT * FROM firearms_registry WHERE identifier = ? ORDER BY registeredAt DESC", arguments.identifier)
end)

-- Registers a carried gun to a citizen. A gun already registered to someone else isn't moved; that's for the laptop.
register("evidences:firearmTerminal:register", function(source, arguments)
    local serial <const>, identifier <const> = arguments.serial, arguments.identifier
    if type(serial) ~= "string" or type(identifier) ~= "string" or identifier == "" then
        return { success = false }
    end

    local firearm
    for _, carried in ipairs(getCarriedFirearms(source)) do
        if carried.serial == serial then
            firearm = carried
            break
        end
    end

    if not firearm then
        return { success = false, response = "firearm_terminal.errors.not_carried" }
    end

    local existing <const> = database.selectFirstColumn("SELECT identifier FROM firearms_registry WHERE serial = ?", serial)
    if existing.success and existing.response and existing.response ~= identifier then
        return { success = false, response = "firearm_terminal.errors.registered_to_someone_else" }
    end

    local result <const> = firearms.register({
        serial = serial,
        label = firearm.label,
        imagePath = firearm.imagePath,
        identifier = identifier,
        reason = type(arguments.reason) == "string" and arguments.reason:sub(1, 500) or "",
        registeredBy = framework.getPlayerName(source),
        status = "registered"
    })

    if not result or not result.success then
        return { success = false }
    end

    logger.log(source, "Firearm registered", result.response)
    return { success = true, response = result.response }
end)
