local phoneNumber = {}

function phoneNumber.getPhoneNumber(playerId)
    if GetResourceState("es_extended") == "started" or GetResourceState("qbx_core") == "started" then
        local identifier <const> = framework.getIdentifier(playerId)
        return identifier and exports.roadphone:getNumberFromIdentifier(identifier) or nil
    end

    return nil
end

return phoneNumber
