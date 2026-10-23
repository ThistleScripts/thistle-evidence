-- Microscopes placed with the forensic_microscope item. They open the forensics lab (client/lab/microscopes.lua).
local config <const> = require "config"
local framework <const> = require "server.framework"
local database <const> = require "server.database"

local item <const> = "forensic_microscope"
local permissions <const> = config.forensicsLab.permissions

if not exports.ox_inventory:Items(item) then
    lib.print.warn(("The %s item doesn't exist, so microscopes can't be placed. Lab stations from config.forensicsLab.stations still work."):format(item))
end

MySQL.update.await(
    [[
        CREATE TABLE IF NOT EXISTS evidence_microscopes (
            id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
            x DOUBLE NOT NULL,
            y DOUBLE NOT NULL,
            z DOUBLE NOT NULL,
            w DOUBLE NOT NULL
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]]
)

Thistle.Callback.Register("evidences:getMicroscopes", function()
    local result <const> = database.query("SELECT * FROM evidence_microscopes")
    return result.success and result.response or {}
end)

Thistle.Callback.Register("evidences:placeMicroscope", function(source, coords)
    if not framework.hasPermission(permissions.place, source) then
        TriggerClientEvent("evidences:notify", source, { key = "laptop.notifications.no_permission" }, "error")
        return false
    end

    if type(coords) ~= "vector4" or #(GetEntityCoords(GetPlayerPed(source)) - coords.xyz) > 15.0 then
        return false
    end

    -- Take the microscope from the player here rather than trusting the client to use it up
    if not exports.ox_inventory:RemoveItem(source, item, 1) then
        return false
    end

    local result <const> = database.insert(
        "INSERT INTO evidence_microscopes (x, y, z, w) VALUES (?, ?, ?, ?)",
        coords.x, coords.y, coords.z, coords.w
    )

    if result.success and result.response then
        TriggerClientEvent("evidences:spawnMicroscopes", -1, { { id = result.response, x = coords.x, y = coords.y, z = coords.z, w = coords.w } })
        return true
    end

    exports.ox_inventory:AddItem(source, item, 1)
    TriggerClientEvent("evidences:notify", source, { key = "lab.notifications.error_creation" }, "error")
    return false
end)

Thistle.Callback.Register("evidences:pickupMicroscope", function(source, id)
    if not framework.hasPermission(permissions.pickup, source) then
        TriggerClientEvent("evidences:notify", source, { key = "laptop.notifications.no_permission" }, "error")
        return false
    end

    local row <const> = database.selectFirstRow("SELECT * FROM evidence_microscopes WHERE id = ?", tonumber(id))
    if not row.success or not row.response then
        return false
    end

    local microscope <const> = row.response
    if #(GetEntityCoords(GetPlayerPed(source)) - vector3(microscope.x, microscope.y, microscope.z)) > 5.0 then
        return false
    end

    if not exports.ox_inventory:CanCarryItem(source, item, 1) then
        TriggerClientEvent("evidences:notify", source, { key = "lab.notifications.error_pickup" }, "error")
        return false
    end

    -- Only hand out a microscope when one was actually removed, otherwise repeating the call would duplicate it
    local deleted <const> = database.update("DELETE FROM evidence_microscopes WHERE id = ?", microscope.id)
    if deleted.success and (tonumber(deleted.response) or 0) > 0 then
        TriggerClientEvent("evidences:removeMicroscope", -1, microscope.id)
        exports.ox_inventory:AddItem(source, item, 1)
        return true
    end

    return false
end)
