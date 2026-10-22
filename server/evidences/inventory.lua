-- Finding evidence items in a player's inventory and the containers (evidence boxes) they carry.
-- Shared by the laptop and the forensics lab.
local inventory = {}

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

inventory.getItemImage = getItemImage
inventory.getItemsMatchingFilter = getItemsMatchingFilter
inventory.getItem = getItem

return inventory
