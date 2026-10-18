local config <const> = require "config"
local supportedFrameworks <const> = {
    ["es_extended"] = "esx",
    ["ND_Core"] = "nd",
    ["ox_core"] = "ox",
    ["qb-core"] = "qb",
    ["qbx_core"] = "qbx"
}

for resource, framework in pairs(supportedFrameworks) do
    if GetResourceState(resource):find("start") then
        local frameworkImplentation = require(("common.frameworks.%s.%s"):format(framework, lib.context))

        -- Checks whether a player has permission to perform a specific action.
        ---@param tableWithRequiredPermissions table The table containing the required permissions
        ---@param playerId? number The id of the player to execute the permission check for (only required on server)
        ---@return boolean true if the player has permission, false otherwise
        frameworkImplentation.hasPermission = function(tableWithRequiredPermissions, playerId)
            for job, minGrade in pairs(tableWithRequiredPermissions or {}) do
                local grade <const> = frameworkImplentation.getGrade(job, playerId)

                if grade and grade >= minGrade then
                    return true
                end
            end
            
            return false
        end

        return frameworkImplentation
    end
end

lib.print.error("No supported framework.")
return nil