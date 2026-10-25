local config <const> = require "config"
local framework <const> = require "server.framework"
local database <const> = require "server.database"
local logger <const> = require "server.logger"

require "server.citizens.notes"
local records <const> = require "server.citizens.records"

local citizens = {}

if not config.citizens.synced then
    MySQL.update.await(
        [[
            CREATE TABLE IF NOT EXISTS citizens (
                identifier VARCHAR(500) PRIMARY KEY,
                fullName TEXT NOT NULL,
                birthdate TEXT NOT NULL,
                gender ENUM('male', 'female', 'non_binary') NOT NULL
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        ]]
    )

    Thistle.Callback.Register("evidences:storeCitizen", function(source, arguments)
        if not framework.hasPermission(config.permissions.access, source) then
            return {
                success = false,
                response = "laptop.notifications.no_permission.description"
            }
        end

        if arguments.identifier then
            return database.update(
                [[
                    UPDATE citizens SET
                        fullName = ?,
                        birthdate = ?,
                        gender = ?
                    WHERE identifier = ?
                ]],
                arguments.fullName, arguments.birthdate, arguments.gender, arguments.identifier,
                function()
                    logger.log(source, "Citizen updated", arguments)
                    return arguments
                end
            )
        end

        -- The ID is made first: INSERT ... RETURNING only works on MariaDB, so on MySQL no citizen was ever created
        local identifier <const> = database.selectFirstColumn("SELECT UUID()")
        if not identifier.success or not identifier.response then
            return identifier
        end

        return database.update(
            [[
                INSERT INTO citizens (identifier, fullName, birthdate, gender)
                VALUES (?, ?, ?, ?)
            ]],
            identifier.response, arguments.fullName, arguments.birthdate, arguments.gender,
            function()
                arguments.identifier = identifier.response
                logger.log(source, "Citizen created", arguments)
                return arguments
            end
        )
    end)

    Thistle.Callback.Register("evidences:deleteCitizen", function(source, arguments)
        if not framework.hasPermission(config.permissions.access, source) then
            return {
                success = false,
                response = "laptop.notifications.no_permission.description"
            }
        end

        local identifier <const> = arguments.identifier

        local result = database.update("DELETE FROM linked_fingerprint WHERE identifier = ?", identifier)
        if result.success then
            result = database.update("DELETE FROM linked_dna WHERE identifier = ?", identifier)

            if result.success then
                logger.log(source, "Citizen deletion requested", arguments)
                return database.update("DELETE FROM citizens WHERE identifier = ?", identifier)
            end
        end

        return result
    end)
end

Thistle.Callback.Register("evidences:getCitizens", function(source, arguments)
    if not framework.hasPermission(config.permissions.access, source) then
        return {
            success = false,
            response = "laptop.notifications.no_permission.description"
        }
    end

    arguments.searchText = arguments.searchText or ""
    arguments.offset = arguments.offset or 0

    if config.citizens.synced then
        local result <const> = framework.getCitizens(arguments.searchText, arguments.offset)

        -- citizens known by an alias like the search, on the first page
        if result.success and arguments.offset == 0 and arguments.searchText ~= "" then
            local listed = {}
            for _, citizen in ipairs(result.response or {}) do
                listed[citizen.identifier] = true
            end

            for _, identifier in ipairs(records.searchAliases(arguments.searchText)) do
                local citizen <const> = not listed[identifier] and framework.getCitizen(identifier)
                if citizen and citizen.success and citizen.response then
                    table.insert(result.response, citizen.response)
                end
            end
        end

        return result
    end

    local pattern <const> = "%" .. arguments.searchText:sub(1, 25):gsub("\\", "\\\\"):gsub("%%", "\\%%"):gsub("_", "\\_") .. "%"

    -- by name, or by an alias they've given (server/citizens/records.lua)
    return database.query(
        [[
            SELECT * FROM citizens
            WHERE fullName LIKE ?
                OR identifier IN (SELECT identifier FROM evidence_citizen_aliases WHERE alias LIKE ?)
            LIMIT 10 OFFSET ?
        ]],
        pattern, pattern, arguments.offset
    )
end)

function citizens.getCitizen(identifier)
    if identifier then
        if config.citizens.synced then
            return framework.getCitizen(identifier)
        end

        return database.selectFirstRow("SELECT * FROM citizens WHERE identifier = ?", identifier)
    end

    return nil
end

Thistle.Callback.Register("evidences:getCitizen", function(source, arguments)
    if not framework.hasPermission(config.permissions.access, source) then
        return {
            success = false,
            response = "laptop.notifications.no_permission.description"
        }
    end

    return citizens.getCitizen(arguments.identifier)
end)

return citizens