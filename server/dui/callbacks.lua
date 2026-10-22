local config <const> = require "config"
local framework <const> = require "server.framework"
local inventory <const> = require "server.evidences.inventory"

Thistle.Callback.Register("evidences:getPlayersFirearms", function(source, arguments)
    if not framework.hasPermission(config.permissions.access, source) then
        return {
            success = false,
            response = "laptop.notifications.no_permission.description"
        }
    end

    return inventory.getItemsMatchingFilter(source, function(item)
        local metadata <const> = item.metadata or {}
        local serial <const> = metadata.serial
        local imperfections <const> = metadata.imperfections

        if serial or imperfections then
            return true, {
                serial = serial,
                imperfections = imperfections
            }
        end

        return false
    end)
end)

Thistle.Callback.Register("evidences:getPlayersItemsWithEvidence", function(source, arguments)
    if not framework.hasPermission(config.permissions.access, source) then
        return {
            success = false,
            response = "laptop.notifications.no_permission.description"
        }
    end

    local type <const> = arguments.type
    if not type then return {} end

    return inventory.getItemsMatchingFilter(source, function(item)
        local metadata <const> = item.metadata or {}

        if metadata[type] and metadata[type].owner then
            local information <const> = metadata.information or {}

            return true, {
                createdAt = metadata.createdAt,
                crimeScene = information.crimeScene or "",
                collectionTime = information.collectionTime or "",
                additionalData = information.additionalData or "",
                weaponType = metadata[type].weaponType,
                weaponImage = metadata[type].weaponImage,
                serial = metadata[type].serial,
                imperfections = metadata[type].imperfections,
                type = metadata[type].type,
                identifier = metadata[type].owner,
                analysed = metadata[type].analysed or false
            }
        end

        return false
    end)
end)


Thistle.Callback.Register("evidences:updateAdditionalData", function(source, arguments)
    if not framework.hasPermission(config.permissions.access, source) then
        return {
            success = false,
            response = "laptop.notifications.no_permission.description"
        }
    end

    local item <const> = inventory.getItem(source, arguments.inventory, arguments.slot)

    if item then
        local evidenceInformation <const> = item.metadata and item.metadata.information or {}
        evidenceInformation.additionalData = type(arguments.additionalData) == "string" and arguments.additionalData:sub(1, 500) or nil
        local description <const> = require "server.evidences.evidence_information"(evidenceInformation)

        item.metadata = item.metadata or {}
        item.metadata.information = evidenceInformation
        item.metadata.description = description

        exports.ox_inventory:SetMetadata(arguments.inventory, arguments.slot, item.metadata)
    end
end)
