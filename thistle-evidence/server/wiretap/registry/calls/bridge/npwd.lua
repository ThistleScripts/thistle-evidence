local phoneNumber = {}

function phoneNumber.getPhoneNumber(playerId)
    local playerData <const> = exports.npwd:getPlayerData({ source = playerId })
    return playerData and playerData.phoneNumber or nil
end

return phoneNumber