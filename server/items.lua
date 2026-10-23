local config <const> = require "config"
local logger <const> = require "server.logger"
local framework <const> = require "server.framework"

for _, item in pairs({"evidence_laptop", "evidence_box", "forensic_kit", "hydrogen_peroxide", "forensic_fingerprint_scanner", "collected_blood", "collected_saliva", "collected_fingerprint", "collected_magazine", "collected_casing", "collected_bullet", "collected_gunshot_residue"}) do
    if not exports.ox_inventory:Items(item) then
        lib.print.error("Setup step missing: The script requires you to create the " .. item .. " item")
        return false
    end
end

if config.wiretap.enabled and not exports.ox_inventory:Items("spy_microphone") then
    lib.print.error("Setup step missing: The script requires you to create the spy_microphone item")
    return false
end

for _, item in pairs(config.destroyItems) do
    if not exports.ox_inventory:Items(item) then
        lib.print.error("Setup step missing: The script requires you to create the " .. item .. " item (used in config.destroyItems)")
        return false
    end
end

if config.uvLight.required and not exports.ox_inventory:Items("WEAPON_UVFLASHLIGHT") then
    lib.print.error("Setup step missing: Add the WEAPON_UVFLASHLIGHT weapon to ox_inventory/data/weapons.lua (see setup/weapons.lua). Evidence is only visible under UV light, see config.uvLight")
    return false
end

if not exports.ox_inventory:Items("evidence_marker") then
    lib.print.warn("The evidence_marker item doesn't exist, so evidence markers can't be placed.")
end

if not exports.ox_inventory:Items("uv_floodlight") then
    lib.print.warn("The uv_floodlight item doesn't exist, so UV floodlights can't be placed.")
end


-- https://github.com/overextended/ox_inventory/commit/c7dee27c97a3ef2dc9e5ea402346cf6ea4cc1b16
-- https://github.com/overextended/ox_inventory/commit/895cca3c9f0cd140e75bdb050dc88843119b4418
if lib.checkDependency("ox_inventory", "2.44.4") then
    exports.ox_inventory:setContainerProperties("evidence_box", {
        slots = 20,
        maxWeight = 5000
    })
elseif lib.checkDependency("ox_inventory", "2.34.3") then
    -- Create a temporary stash to check if the item evidence_box is a container.
    -- That's needed because old versions of ox_inventory don't return the item metadata via exports.ox_inventory:Items(itemName).metadata.
    local temporaryInv <const> = exports.ox_inventory:CreateTemporaryStash({
        label = "Evidences",
        slots = 1,
        maxWeight = 0,
        groups = {},
        items = {{"evidence_box", 1}}
    })

    local evidenceBox <const> = exports.ox_inventory:GetSlot(temporaryInv, 1)
    exports.ox_inventory:RemoveInventory(temporaryInv)

    if evidenceBox and evidenceBox.metadata and (not evidenceBox.metadata.container) then
        lib.print.error("Setup step missing: Make the evidence_box a container item (https://overextended.dev/docs/ox_inventory/Guides/creatingItems#creating-container-items) or use ox_inventory version 2.44.4 or higher")
        return false
    end
else
    lib.print.warn("Your ox_inventory version is outdated. We do not guarantee compatibility and highly recommend updating ox_inventory!")
end


-- Labels the evidence box on the given slot in the player's inventory: a case number and a name, which make up the
-- box's label so boxes in a stash can be told apart by case, and a description
local function trimmed(value, maxLength)
    if type(value) ~= "string" then
        return nil
    end

    value = value:gsub("^%s+", ""):gsub("%s+$", ""):sub(1, maxLength)
    return value ~= "" and value or nil
end

RegisterNetEvent("evidences:renameEvidenceBox", function(slot, input)
    local playerId <const> = source
    if type(slot) ~= "number" or type(input) ~= "table" then
        return
    end

    local item <const> = exports.ox_inventory:GetSlot(playerId, slot)

    if item and item.name == "evidence_box" then
        local metadata <const> = item.metadata or {}
        local caseNumber <const> = trimmed(input[1], 20)
        local name <const> = trimmed(input[2], 30)

        metadata.caseNumber = caseNumber
        metadata.boxName = name
        metadata.description = trimmed(input[3], 500)

        if caseNumber and name then
            metadata.label = locale("evidences.evidence_box_label_dialog.case_label_with_name", caseNumber, name)
        elseif caseNumber then
            metadata.label = locale("evidences.evidence_box_label_dialog.case_label", caseNumber)
        else
            metadata.label = name -- nil puts the item's own label back
        end

        metadata.labelledBy = (caseNumber or name) and framework.getPlayerName(playerId) or nil
        exports.ox_inventory:SetMetadata(playerId, slot, metadata)
    end
end)


-- Set durability = 100 for newly created forensic_kit and steel_file items
exports.ox_inventory:registerHook("createItem", function(payload)
    local metadata <const> = payload.metadata
    metadata.durability = 100
    return metadata
end, {
    itemFilter = {
        forensic_kit = true,
        steel_file = true
    }
})


-- Every gun gets an ID that its bullets and casings carry. ox_inventory gives a serial to most guns, but not to
-- ones created with `registered = false` (crafted, black market...). Those get an ID in the same format, stored
-- where a filed-off serial goes, so they're unregistered and have no visible serial but can still be traced.
local function generateGunId()
    local letters = ""
    for _ = 1, 3 do
        letters = letters .. string.char(math.random(65, 90))
    end

    return ("%s%s%s"):format(math.random(100000, 999999), letters, math.random(100000, 999999))
end

exports.ox_inventory:registerHook("createItem", function(payload)
    local metadata <const> = payload.metadata
    if payload.item and payload.item.weapon and payload.item.ammoname
        and type(metadata) == "table" and not metadata.serial and not metadata.imperfections then
        metadata.imperfections = generateGunId()
    end

    return metadata
end)


RegisterNetEvent("evidences:removeSerialNumber", function()
    local playerId <const> = source

    -- The client sends this after using a steel file, so the player has to actually carry one
    if (exports.ox_inventory:Search(playerId, "count", "steel_file") or 0) < 1 then
        return
    end

    local weapon <const> = exports.ox_inventory:GetCurrentWeapon(playerId)

    if weapon and weapon.slot and weapon.metadata and weapon.metadata.serial then
        -- remove serial from weapon
        local metadata <const> = weapon.metadata
        metadata.imperfections = metadata.serial
        metadata.serial = nil
        exports.ox_inventory:SetMetadata(playerId, weapon.slot, metadata)

        TriggerClientEvent("evidences:notify", playerId, {key = "steel_file.serial_removed"}, "success")
    end
end)

return true