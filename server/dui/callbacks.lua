local config <const> = require "config"
local framework <const> = require "server.framework"
local imagePath <const> = GetConvar("inventory:imagepath", "nui://ox_inventory/web/images") .. "/%s.png"

-- https://github.com/overextended/ox_inventory/blob/6be13009eebc618b282f584782d98ff16ea2f9ed/web/src/helpers/index.ts#L140
local function getItemImage(item)
    local metadata <const> = item.metadata

    if metadata then
        if metadata.imageurl then
            return metadata.imageurl
        elseif metadata.image then
            return string.format(imagePath, metadata.image)
        end
    end

    if item.image then
        return string.format(imagePath, item.image)
    end

    return string.format(imagePath, item.name)
end

---@param source number The players server id.
---@param filter func A function returning true if the item matches the filter. Additionaly, it can return a table with details or additionalData if they showed be added to the filtered items table returned by this function
local function getItemsMatchingFilter(source, filter)
    local result = {}

    local items <const> = exports.ox_inventory:GetInventoryItems(source)
    local filteredItems = {}

    for _, item in pairs(items or {}) do
        local slot <const> = item.slot
        local metadata <const> = item.metadata or {}

        local matchesFilter <const>, details <const> = filter(item)

        if matchesFilter then
            filteredItems[#filteredItems + 1] = {
                imagePath = getItemImage(item),
                label = metadata.label or item.label,
                slot = slot,
                details = details or {}
            }
        end

        -- for each item in the inventory holding a container
        if metadata.container then
            local containerData <const> = exports.ox_inventory:GetContainerFromSlot(source, slot)
            local filteredContainerItems = {}

            for _, containerItem in pairs(containerData and containerData.items or {}) do
                local containerItemMatchesFilter <const>, containerItemDetails <const> = filter(containerItem)

                if containerItemMatchesFilter then
                    local containerItemMetadata <const> = containerItem.metadata or {}

                    filteredContainerItems[#filteredContainerItems + 1] = {
                        imagePath = getItemImage(containerItem),
                        label = containerItemMetadata.label or containerItem.label,
                        slot = containerItem.slot,
                        details = containerItemDetails or {} -- was the outer item's details, so evidence in boxes showed none
                    }
                end
            end

            if #filteredContainerItems > 0 then
                result[#result + 1] = {
                    inventory = metadata.container,
                    label = metadata.label or item.label,
                    items = filteredContainerItems
                }
            end
        end
    end

    local playerInventory <const> = exports.ox_inventory:GetInventory(source)
    if #filteredItems > 0 then
        result[#result + 1] = {
            inventory = source,
            label = playerInventory and playerInventory.label or GetPlayerName(source),
            items = filteredItems
        }
    end

    return result
end

Thistle.Callback.Register("evidences:getPlayersFirearms", function(source, arguments)
    if not framework.hasPermission(config.permissions.access, source) then
        return {
            success = false,
            response = "laptop.notifications.no_permission.description"
        }
    end

    return getItemsMatchingFilter(source, function(item)
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

    return getItemsMatchingFilter(source, function(item)
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


-- Players may only change items in their own inventory or in a container (e.g. evidence box) they carry
local function getItem(source, inventory, slot)
    if type(slot) ~= "number" then
        return false
    end

    if inventory ~= source then
        local isCarriedContainer = false

        for _, item in pairs(exports.ox_inventory:GetInventoryItems(source) or {}) do
            if item.metadata and item.metadata.container and item.metadata.container == inventory then
                isCarriedContainer = true
                break
            end
        end

        if not isCarriedContainer then
            return false
        end
    end

    return exports.ox_inventory:GetSlot(inventory, slot)
end

Thistle.Callback.Register("evidences:updateAdditionalData", function(source, arguments)
    if not framework.hasPermission(config.permissions.access, source) then
        return {
            success = false,
            response = "laptop.notifications.no_permission.description"
        }
    end

    local item <const> = getItem(source, arguments.inventory, arguments.slot)

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

Thistle.Callback.Register("evidences:setAnalysed", function(source, arguments)
    if not framework.hasPermission(config.permissions.access, source) then
        return {
            success = false,
            response = "laptop.notifications.no_permission.description"
        }
    end

    local item <const> = getItem(source, arguments.inventory, arguments.slot)

    local evidenceType <const> = arguments.type
    if evidenceType ~= "dna" and evidenceType ~= "fingerprint" and evidenceType ~= "ballistics" then
        return
    end

    if item and item.metadata and type(item.metadata[evidenceType]) == "table" then
        item.metadata[evidenceType].analysed = true

        -- Update the description of the evidence item
        item.metadata.information = item.metadata.information or {}
        item.metadata.information[evidenceType] = item.metadata[evidenceType].owner -- for biometric evidences (dna, fingerprint)

        -- Only the analysis results shown in the description can be set (see evidence_information.lua).
        -- Biometric analyses send none.
        local information <const> = type(arguments.information) == "table" and arguments.information or {}
        for _, key in ipairs({ "weaponType", "serial" }) do
            if type(information[key]) == "string" then
                item.metadata.information[key] = information[key]:sub(1, 100)
            end
        end

        item.metadata.description = require "server.evidences.evidence_information"(item.metadata.information)

        exports.ox_inventory:SetMetadata(arguments.inventory, arguments.slot, item.metadata)

        TriggerEvent("evidences:evidenceItemAnalysed", source, item)
    end
end)